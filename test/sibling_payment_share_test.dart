// نصيب الأخ في دفعة الإخوة لازم يطابق المستحق شهر بشهر (قبل تاريخ سريان
// سعر الإخوة = السعر الفردي) — وإلا بتظهر مديونية وهمية (مثلًا 10 ج).
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

Student _s(int id, {DateTime? from}) => Student(
      id: id,
      name: 'طالب$id',
      code: 'A$id',
      groupId: 1,
      price: 80,
      siblingsTotal: 140,
      siblingGroupId: 1,
      siblingsFrom: from,
      attendanceStart: DateTime(2026, 8, 1),
    );

void main() {
  final from = DateTime(2026, 9, 1);

  test('شهر قبل سريان الإخوة بيتدفع بالسعر الفردي', () {
    final s = _s(1, from: from);
    expect(
        PricingHelper.siblingPaymentShare(
            member: s, months: [DateTime(2026, 8, 1)], memberCount: 2),
        80);
  });

  test('شهر بعد السريان بنصيب الإخوة', () {
    final s = _s(1, from: from);
    expect(
        PricingHelper.siblingPaymentShare(
            member: s, months: [DateTime(2026, 9, 1)], memberCount: 2),
        70);
  });

  test('أكتر من شهر: مجموع كل شهر بسعره', () {
    final s = _s(1, from: from);
    expect(
        PricingHelper.siblingPaymentShare(member: s, months: [
          DateTime(2026, 8, 1),
          DateTime(2026, 9, 1),
          DateTime(2026, 10, 1)
        ], memberCount: 2),
        220);
  });

  test('بلا تاريخ سريان: سعر الإخوة على كل الشهور', () {
    final s = _s(1);
    expect(
        PricingHelper.siblingPaymentShare(
            member: s, months: [DateTime(2026, 8, 1)], memberCount: 2),
        70);
  });
}
