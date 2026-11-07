import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/receipt_message.dart';
import 'package:active_class/utils/student_statement.dart';

void main() {
  setUp(() {
    PricingHelper.billingArrears = false;
    PricingHelper.prorateFirstMonth = false;
  });

  final group =
      Group(id: 1, name: 'مجموعة أ', pricingType: GroupPricingType.monthly);
  final student = Student(
      id: 1,
      name: 'أحمد',
      code: 'S1',
      groupId: 1,
      price: 200,
      attendanceStart: DateTime(2026, 9, 1));
  final now = DateTime(2026, 11, 6);

  Payment pay(double a, {PaymentKind? k, String? note}) => Payment(
      studentId: 1,
      date: DateTime(2026, 10, 2),
      amount: a,
      note: note,
      storedKind: k);

  StudentStatement build(List<Payment> p) => StudentStatement.build(
      student: student,
      group: group,
      allAttendance: const [],
      payments: p,
      now: now);

  test('3 شهور مستحقة بلا دفع = متبقي 600', () {
    final s = build([]);
    expect(s.months.length, 3);
    expect(s.totalDue, 600);
    expect(s.balance, 600);
    expect(s.unpaidMonths.length, 3);
  });

  test('دفع 250 يغطي الأول وجزء من التاني (FIFO)', () {
    final s = build([pay(250, note: 'months=2026-09')]);
    expect(s.months[0].paid, 200);
    expect(s.months[1].paid, 50);
    expect(s.balance, 350);
    expect(s.payments.single.months, [DateTime(2026, 9)]);
  });

  test('الإسقاط مش مدفوع، وبيخفض المتبقي', () {
    final s = build([pay(100), pay(400, k: PaymentKind.writeOff)]);
    expect(s.totalPaid, 100);
    expect(s.totalWrittenOff, 400);
    expect(s.balance, 100);
    expect(s.months.fold(0.0, (a, m) => a + m.writtenOff), 400);
    expect(s.payments.length, 1);
  });

  test('مدفوع أكتر من المستحق = رصيد زيادة', () {
    final s = build([pay(700)]);
    expect(s.balance, 0);
    expect(s.advance, 100);
  });

  test('الرسائل', () {
    final s = build([pay(100), pay(300, k: PaymentKind.writeOff)]);
    String money(double v) => '${v.toInt()} ج';
    final msg = buildStatementMessage(
        studentName: 'أحمد',
        studentCode: 'S1',
        statement: s,
        money: money,
        monthLabel: (d) => '${d.month}/${d.year}');
    expect(msg, contains('كشف حساب'));
    expect(msg, contains('المتبقي: 200 ج'));
    expect(msg, contains('مُسقَط: 300 ج'));
    final r = buildReceiptMessage(
        studentName: 'أحمد',
        amount: 200,
        date: DateTime(2026, 10, 2),
        months: [DateTime(2026, 10)],
        remaining: 0,
        money: money,
        monthLabel: (d) => '${d.month}/${d.year}',
        dateLabel: (d) => '${d.day}');
    expect(r, contains('إيصال دفع'));
    expect(r, contains('10/2026'));
    expect(r, contains('مفيش متبقي'));
  });
}
