// lib/utils/pricing_helper.dart
import 'package:active_class/config/constants.dart';
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
            a.status == ATTENDANCE_PRESENT &&
            a.date.year == month.year &&
            a.date.month == month.month)
        .length;
  }

  static double monthlyDue({
    required Student student,
    required Group? group,
    required DateTime month,
    required List<Attendance> allAttendance,
  }) {
    if (student.isFullyExempt) return 0;

    final double base;
    if (group != null && group.isPerSession) {
      final attended = sessionsAttended(
          student: student, month: month, allAttendance: allAttendance);
      base = student.price * attended;
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
  }) {
    return _remainingThrough(
      student: student,
      group: group,
      allAttendance: allAttendance,
      payments: payments,
      lastMonth: DateTime(DateTime.now().year, DateTime.now().month, 1),
    );
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
        ) >
        0;
  }

  static double _remainingThrough({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    required DateTime lastMonth,
  }) {
    if (student.isFullyExempt) return 0;
    // attendanceStart هو تاريخ الانضمام الفعلي اللي المدرّس بيحدده يدوي
    // (ممكن يكون قبل تاريخ إضافة السجل نفسه على التطبيق) — نفس المرجع
    // المستخدم في باقي التطبيق (تقرير المدفوعات، معرض QR..). createdAt
    // بديل احتياطي بس لو مفيش تاريخ انضمام محدَّد.
    final start = student.attendanceStart ?? student.createdAt;
    if (start == null) return 0;

    var cursor = DateTime(start.year, start.month, 1);
    if (cursor.isAfter(lastMonth)) return 0;

    double totalDue = 0;
    while (!cursor.isAfter(lastMonth)) {
      totalDue += monthlyDue(
          student: student,
          group: group,
          month: cursor,
          allAttendance: allAttendance);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final remaining = totalDue - totalPaid;
    return remaining > 0 ? remaining : 0;
  }
}
