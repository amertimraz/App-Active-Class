// lib/utils/debts_overview.dart
//
// نظرة على كل المديونيات: لكل طالب عليه متبقي، الشهور اللي عليها متبقي
// (من كشف الحساب) ومقارنتها بسعر الشهر عشان نطلّع «الفتات» — متبقي أقل من
// سعر الشهر (زي 10 أو 20 من 80). دالة صرفة بلا GetX/DB عشان تتختبر.
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/student_statement.dart';

class DebtMonthRow {
  final DateTime month;

  /// المستحق على الطالب في الشهر ده.
  final double due;

  /// المتبقي بعد خصم المدفوع والمُسقَط.
  final double remaining;

  /// أقل من سعر الشهر الكامل للطالب.
  final bool isSmall;

  const DebtMonthRow({
    required this.month,
    required this.due,
    required this.remaining,
    required this.isSmall,
  });

  /// اتدفع أو اتسقط جزء منه (مش شهر لسه كامل).
  bool get isPartial => remaining < due - 0.5;
}

class StudentDebtRow {
  final Student student;
  final Group? group;

  /// سعر الشهر الكامل للطالب (أكبر مستحق شهري عليه).
  final double monthPrice;

  /// الشهور اللي عليها متبقي، الأقدم أولًا.
  final List<DebtMonthRow> months;

  const StudentDebtRow({
    required this.student,
    required this.group,
    required this.monthPrice,
    required this.months,
  });

  double get total => months.fold(0.0, (s, m) => s + m.remaining);

  List<DebtMonthRow> get smallMonths =>
      months.where((m) => m.isSmall).toList();

  bool get hasSmall => months.any((m) => m.isSmall);

  /// الفتات اللي ينفع يتسقط بدقة: الشهور الصغيرة المتتالية من أقدم شهر.
  /// الإسقاط بيتوزع على الأقدم أولًا (زي الدفع)، فمينفعش نسقط شهر صغير
  /// وقبله شهر كامل من غير ما الكامل ياخد الإسقاط.
  List<DebtMonthRow> get writablePrefix {
    final out = <DebtMonthRow>[];
    for (final m in months) {
      if (!m.isSmall) break;
      out.add(m);
    }
    return out;
  }

  double get writablePrefixTotal =>
      writablePrefix.fold(0.0, (s, m) => s + m.remaining);
}

/// كل الطلاب اللي عليهم متبقي. [students] تشمل المؤرشفين لو عايز تظهرهم.
List<StudentDebtRow> computeDebtRows({
  required List<Student> students,
  required List<Group> groups,
  required List<Attendance> allAttendance,
  required List<Payment> payments,
  List<Student>? siblingGroupMembers,
  DateTime? now,
}) {
  final byStudent = <int, List<Payment>>{};
  for (final p in payments) {
    byStudent.putIfAbsent(p.studentId, () => []).add(p);
  }
  final groupById = {for (final g in groups) g.id: g};
  final rows = <StudentDebtRow>[];
  for (final s in students) {
    if (s.id == null || s.isFullyExempt) continue;
    final group = groupById[s.groupId];
    final st = StudentStatement.build(
      student: s,
      group: group,
      allAttendance: allAttendance,
      payments: byStudent[s.id] ?? const [],
      siblingGroupMembers: siblingGroupMembers ?? students,
      now: now,
    );
    final unpaid = st.unpaidMonths;
    if (unpaid.isEmpty) continue;
    var price = 0.0;
    for (final m in st.months) {
      if (m.due > price) price = m.due;
    }
    rows.add(StudentDebtRow(
      student: s,
      group: group,
      monthPrice: price,
      months: [
        for (final m in unpaid)
          DebtMonthRow(
            month: m.month,
            due: m.due,
            remaining: m.remaining,
            isSmall: m.remaining < price - 0.5,
          ),
      ],
    ));
  }
  rows.sort((a, b) => b.total.compareTo(a.total));
  return rows;
}
