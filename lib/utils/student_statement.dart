// lib/utils/student_statement.dart
//
// كشف حساب الطالب: لكل شهر (من بداية الطالب لحد دلوقتي) المستحق والمدفوع
// والمُسقَط والمتبقي، + إجمالي ورصيد، + قايمة الدفعات الفعلية.
// دالة صرفة (بلا GetX/DB) عشان تتختبر، وبتستخدم نفس حساب PricingHelper
// عشان «المتبقي» هنا = نفس «المديونية المتراكمة» في باقي التطبيق.
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/payment_note.dart';
import 'package:active_class/utils/pricing_helper.dart';

class StatementMonth {
  final DateTime month;
  final double due;
  final double paid;
  final double writtenOff;
  const StatementMonth({
    required this.month,
    required this.due,
    required this.paid,
    required this.writtenOff,
  });

  double get remaining =>
      (due - paid - writtenOff).clamp(0.0, double.infinity).toDouble();
}

class StatementPayment {
  final DateTime date;
  final double amount;
  final List<DateTime> months;
  const StatementPayment(this.date, this.amount, this.months);
}

class StudentStatement {
  final List<StatementMonth> months;
  final List<StatementPayment> payments; // الأحدث أولًا
  final double totalDue;
  final double totalPaid;
  final double totalWrittenOff;

  /// رصيد زيادة (دفع/إسقاط أكتر من المستحق).
  final double advance;

  const StudentStatement({
    required this.months,
    required this.payments,
    required this.totalDue,
    required this.totalPaid,
    required this.totalWrittenOff,
    required this.advance,
  });

  /// المتبقي الحالي = مجموع متبقي الشهور.
  double get balance => months.fold(0.0, (s, m) => s + m.remaining);

  /// الشهور اللي لسه عليها متبقي.
  List<StatementMonth> get unpaidMonths =>
      months.where((m) => m.remaining > 0.5).toList();

  static StudentStatement build({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    List<Student>? siblingGroupMembers,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final collections = payments.where((p) => p.isCollection).toList();
    final writeOffs = payments.where((p) => p.isWriteOff).toList();
    var collLeft = collections.fold(0.0, (s, p) => s + p.amount);
    var woLeft = writeOffs.fold(0.0, (s, p) => s + p.amount);
    final totalPaid = collLeft;
    final totalWo = woLeft;

    final start = student.attendanceStart ?? student.createdAt;
    final rows = <StatementMonth>[];
    var totalDue = 0.0;
    if (start != null && !student.isFullyExempt) {
      var cursor = DateTime(start.year, start.month, 1);
      final last = DateTime(today.year, today.month, 1);
      var prevCum = 0.0;
      while (!cursor.isAfter(last)) {
        final cum = PricingHelper.totalDueThrough(
          student: student,
          group: group,
          allAttendance: allAttendance,
          month: cursor,
          siblingGroupMembers: siblingGroupMembers,
        );
        final due = (cum - prevCum).clamp(0.0, double.infinity).toDouble();
        prevCum = cum;
        final paid = due < collLeft ? due : collLeft;
        collLeft -= paid;
        final rest = due - paid;
        final wo = rest < woLeft ? rest : woLeft;
        woLeft -= wo;
        totalDue += due;
        rows.add(StatementMonth(
            month: cursor, due: due, paid: paid, writtenOff: wo));
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    }

    final pays = [
      for (final p in collections)
        StatementPayment(p.date, p.amount, PaymentNote.parse(p.note).months)
    ]..sort((a, b) => b.date.compareTo(a.date));

    return StudentStatement(
      months: rows,
      payments: pays,
      totalDue: totalDue,
      totalPaid: totalPaid,
      totalWrittenOff: totalWo,
      advance: collLeft + woLeft,
    );
  }
}
