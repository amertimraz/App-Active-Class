import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/siblings_from_inference.dart';

Student _s({DateTime? from, double? total = 150}) => Student(
      id: 1,
      name: 'ط',
      code: 'A',
      groupId: 1,
      price: 80,
      siblingsTotal: total,
      siblingGroupId: 1,
      siblingsFrom: from,
    );

Payment _p(double amount, DateTime date) =>
    Payment(studentId: 1, amount: amount, date: date);

void main() {
  test('أول دفعة بنصيب الإخوة (75) تحدد الشهر', () {
    final r = inferSiblingsFrom(
      student: _s(),
      payments: [
        _p(75, DateTime(2026, 10, 10)),
        _p(80, DateTime(2026, 8, 24)),
        _p(75, DateTime(2026, 9, 24)),
      ],
      groupSize: 2,
    );
    expect(r, DateTime(2026, 9, 1));
  });

  test('مفيش دفعة بالنصيب → null', () {
    expect(
        inferSiblingsFrom(
            student: _s(),
            payments: [_p(80, DateTime(2026, 8, 24))],
            groupSize: 2),
        isNull);
  });

  test('عنده تاريخ بالفعل أو بلا إجمالي → null', () {
    final pays = [_p(75, DateTime(2026, 9, 24))];
    expect(
        inferSiblingsFrom(
            student: _s(from: DateTime(2026, 10, 1)),
            payments: pays,
            groupSize: 2),
        isNull);
    expect(
        inferSiblingsFrom(
            student: _s(total: null), payments: pays, groupSize: 2),
        isNull);
  });
}
