// lib/utils/pricing_helper.dart
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';

/// حساب المستحق الشهري على طالب، مراعيًا نوع تسعير مجموعته:
/// - شهري: سعر ثابت (زي ما كان دايمًا).
/// - بالحصة: سعر الحصة الواحدة × عدد الحصص اللي حضرها الطالب فعليًا
///   في الشهر المطلوب (من سجل الحضور)، ثم تُطبَّق نسبة الإعفاء لو موجودة.
class PricingHelper {
  static int sessionsAttended({
    required Student student,
    required DateTime month,
    required List<Attendance> allAttendance,
  }) {
    return allAttendance
        .where((a) =>
            a.studentId == student.id &&
            // "متأخر" حصة محضورة كاملة زي "حاضر" (spec 011)
            attendanceCountsAsPresent(a.status) &&
            a.date.year == month.year &&
            a.date.month == month.month)
        .length;
  }

  /// عدد أعضاء مجموعة إخوة طالب معيّن (بحد أقصى 3) — لو الطالب مش
  /// مربوط أصلاً بيرجع 1. راجع specs/007-three-sibling-support.
  static int siblingGroupSize(Student student, List<Student> allStudents) {
    if (student.siblingGroupId == null) return 1;
    final count = allStudents
        .where((s) => s.siblingGroupId == student.siblingGroupId)
        .length;
    return count >= 1 ? count : 1;
  }

  static double monthlyDue({
    required Student student,
    required Group? group,
    required DateTime month,
    required List<Attendance> allAttendance,
    // كل طلاب نفس مجموعة الإخوة (بما فيهم الطالب نفسه) — لازمة عشان
    // نقسم الإجمالي المشترك على العدد الفعلي (2 أو 3) بدل /2.0 ثابتة.
    // لو مش متبعتة (استدعاءات قديمة لسه ما اتحدّثتش)، بنفترض 2 توافقًا
    // مع السلوك القديم.
    List<Student>? siblingGroupMembers,
  }) {
    if (student.isFullyExempt) return 0;

    final double base;
    if (group != null && group.isPerSession) {
      final attended = sessionsAttended(
          student: student, month: month, allAttendance: allAttendance);
      base = student.price * attended;
    } else if (student.siblingGroupId != null &&
        student.siblingsTotal != null) {
      // عرض الإخوة (2-3): المستحق الشهري الفعلي على كل طالب = الإجمالي
      // المشترك (siblingsTotal) ÷ عدد الأعضاء الفعلي، مش سعره الفردي
      // (student.price) — وإلا كان بيُحتسب عليه كل شهر سعر كامل رغم إن
      // الدفعات الفعلية (عبر مسار الدفع بالـQR) بتسجَّل بنصيبه بس، فكانت
      // المديونية بتتراكم بلا داعي حتى مع الدفع المنتظم بالخصم.
      final count = siblingGroupMembers != null
          ? siblingGroupSize(student, siblingGroupMembers)
          : 2;
      base = student.siblingsTotal! / count;
    } else if (student.siblingId != null && student.siblingsTotal != null) {
      // بيانات قديمة لسه ما اتحوّلتش لـsiblingGroupId (نادر جدًا بعد
      // migration الإصدار 18 — لو حصل، نفترض زوج بس زي القديم).
      base = student.siblingsTotal! / 2.0;
    } else {
      base = student.price;
    }

    return base * (1 - student.exemptPercent / 100);
  }

  /// المديونية المتراكمة على طالب من شهر انضمامه لحد الشهر الحالي —
  /// إجمالي المستحق على كل الشهور مطروح منه إجمالي كل الدفعات (بغض
  /// النظر عن تاريخ كل دفعة). يعني أي دفعة جديدة بتقلّل المديونية
  /// الكلية على طول، حتى لو كانت مسجّلة بتاريخ شهر تاني — الفلوس
  /// بتتحسب كرصيد واحد مش مربوطة بشهر بعينه، فلو الطالب عليه شهر قديم
  /// ودفع دلوقتي، الدفعة دي بتغطّي القديم الأول تلقائيًا.
  static double accumulatedDebt({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    List<Student>? siblingGroupMembers,
  }) {
    return accumulatedDebtThrough(
      student: student,
      group: group,
      allAttendance: allAttendance,
      payments: payments,
      month: DateTime.now(),
      siblingGroupMembers: siblingGroupMembers,
    );
  }

  /// زي [accumulatedDebt] بالظبط لكن بيحسب المديونية "لحد" شهر معيّن
  /// بدل شهر النهاردة دايمًا — مستخدَمة في شاشات التقارير اللي المدرس
  /// بيتصفّح فيها شهور سابقة (فمينفعش نفترض إن المقصود دايمًا "دلوقتي").
  static double accumulatedDebtThrough({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    required DateTime month,
    List<Student>? siblingGroupMembers,
  }) {
    return _remainingThrough(
      student: student,
      group: group,
      allAttendance: allAttendance,
      payments: payments,
      lastMonth: DateTime(month.year, month.month, 1),
      siblingGroupMembers: siblingGroupMembers,
    );
  }

  /// إجمالي المستحق (بدون خصم أي دفعات) من شهر انضمام الطالب لحد شهر
  /// معيّن — مفيد لعرض "الإجمالي" لوحده منفصل عن "المتبقي" (زي شريط
  /// التقدّم في تقرير الطلاب المتأخرين).
  static double totalDueThrough({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required DateTime month,
    List<Student>? siblingGroupMembers,
  }) {
    if (student.isFullyExempt) return 0;
    final start = student.attendanceStart ?? student.createdAt;
    if (start == null) return 0;
    final lastMonth = DateTime(month.year, month.month, 1);
    var cursor = DateTime(start.year, start.month, 1);
    if (cursor.isAfter(lastMonth)) return 0;

    double totalDue = 0;
    while (!cursor.isAfter(lastMonth)) {
      totalDue += monthlyDue(
          student: student,
          group: group,
          month: cursor,
          allAttendance: allAttendance,
          siblingGroupMembers: siblingGroupMembers);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return totalDue;
  }

  /// زي [accumulatedDebt] بالظبط، لكن بيُستخدم بس لتحديد وقت ظهور
  /// تنبيه/شارة "متأخر" — مش لحساب المبلغ المستحق نفسه. لو المدرس
  /// حدّد "مهلة سماح" (graceDays) ولسه في أول الشهر (مايتعدّاش يوم
  /// المهلة)، بنستثني الشهر الحالي من الحساب هنا (بس هنا)، فطالب
  /// مديونيته كلها من الشهر الحالي بس هيفضل مايتعتبرش "متأخر" لحد ما
  /// المهلة تخلص — لكن لو عليه شهر أقدم برضو، هيتعتبر متأخر فورًا
  /// (المهلة بتغطي بس الشهر الحالي).
  static bool isOverdue({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    required int graceDays,
    List<Student>? siblingGroupMembers,
  }) {
    final now = DateTime.now();
    final withinGrace = graceDays > 0 && now.day <= graceDays;
    final lastMonth = withinGrace
        ? DateTime(now.year, now.month - 1, 1)
        : DateTime(now.year, now.month, 1);
    return _remainingThrough(
          student: student,
          group: group,
          allAttendance: allAttendance,
          payments: payments,
          lastMonth: lastMonth,
          siblingGroupMembers: siblingGroupMembers,
        ) >
        0;
  }

  static double _remainingThrough({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    required DateTime lastMonth,
    List<Student>? siblingGroupMembers,
  }) {
    if (student.isFullyExempt) return 0;
    final totalDue = totalDueThrough(
        student: student,
        group: group,
        allAttendance: allAttendance,
        month: lastMonth,
        siblingGroupMembers: siblingGroupMembers);
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final remaining = totalDue - totalPaid;
    return remaining > 0 ? remaining : 0;
  }
}
