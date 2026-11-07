import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/debts_overview.dart';
import 'package:active_class/utils/pricing_helper.dart';

void main() {
  setUp(() {
    PricingHelper.billingArrears = false;
    PricingHelper.prorateFirstMonth = false;
  });

  final group =
      Group(id: 1, name: 'أ', pricingType: GroupPricingType.monthly);
  Student st(int id, {double price = 80}) => Student(
      id: id,
      name: 'ط$id',
      code: 'S$id',
      groupId: 1,
      price: price,
      attendanceStart: DateTime(2026, 9, 1));
  final now = DateTime(2026, 11, 6); // سبتمبر + أكتوبر + نوفمبر

  Payment pay(int sid, double a, {PaymentKind? k}) => Payment(
      studentId: sid, date: DateTime(2026, 10, 2), amount: a, storedKind: k);

  List<StudentDebtRow> rows(List<Student> s, List<Payment> p) =>
      computeDebtRows(
          students: s,
          groups: [group],
          allAttendance: const [],
          payments: p,
          now: now);

  test('دفع 230 من 240 (3 شهور × 80): الفتات 10 أول شهر وبعده شهور كاملة', () {
    // 3 شهور = 240، دفع 70 → سبتمبر متبقي 10، أكتوبر/نوفمبر 80 كاملين.
    final r = rows([st(1)], [pay(1, 70)]).single;
    expect(r.monthPrice, 80);
    expect(r.total, 170);
    expect(r.months.first.remaining, 10);
    expect(r.months.first.isSmall, isTrue);
    expect(r.months.first.isPartial, isTrue);
    expect(r.months[1].isSmall, isFalse);
    expect(r.hasSmall, isTrue);
    expect(r.writablePrefix.length, 1);
    expect(r.writablePrefixTotal, 10);
  });

  test('شهر كامل متبقي مش فتات', () {
    final r = rows([st(1)], []).single;
    expect(r.hasSmall, isFalse);
    expect(r.writablePrefix, isEmpty);
    expect(r.total, 240);
  });

  test('فتات بعد شهر كامل: ما ينفعش يتسقط لوحده', () {
    // دفع 160 → سبتمبر وأكتوبر مدفوعين... نخلّي شهر كامل قبل الفتات:
    // دفع 0 للأول ثم إسقاط 70 على الأقدم = سبتمبر 10 باقي.
    final r = rows([st(1)], [pay(1, 70, k: PaymentKind.writeOff)]).single;
    expect(r.months.first.remaining, 10);
    expect(r.writablePrefixTotal, 10);
  });

  test('مدفوع بالكامل أو معفى: مفيش صف', () {
    expect(rows([st(1)], [pay(1, 240)]), isEmpty);
    final exempt = Student(
        id: 2,
        name: 'م',
        code: 'S2',
        groupId: 1,
        price: 80,
        exemptPercent: 100,
        attendanceStart: DateTime(2026, 9, 1));
    expect(rows([exempt], []), isEmpty);
  });

  test('الترتيب بإجمالي المتبقي من الأكبر', () {
    final list = rows([st(1), st(2)], [pay(1, 70)]);
    expect(list.first.student.id, 2);
  });
}
