// تاريخ سريان سعر الإخوة: الشهور قبله بالسعر الفردي، وبعده بسعر الإخوة،
// و null = كل الشهور (سلوك قديم).
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

Student _s({DateTime? from}) => Student(
      id: 1,
      name: 'طالب',
      code: 'A1',
      groupId: 1,
      price: 80,
      siblingsTotal: 150,
      siblingGroupId: 1,
      siblingsFrom: from,
      attendanceStart: DateTime(2026, 8, 1),
    );

double _due(Student s, DateTime month) => PricingHelper.monthlyDue(
      student: s,
      group: null,
      month: month,
      allAttendance: const [],
      siblingGroupMembers: [s, s.copyWith(id: 2)],
    );

void main() {
  test('بلا تاريخ: سعر الإخوة على كل الشهور (القديم)', () {
    final s = _s();
    expect(_due(s, DateTime(2026, 9, 1)), 75);
    expect(_due(s, DateTime(2026, 11, 1)), 75);
  });

  test('بتاريخ: قبله السعر الفردي وبعده سعر الإخوة', () {
    final s = _s(from: DateTime(2026, 10, 1));
    expect(_due(s, DateTime(2026, 9, 1)), 80);
    expect(_due(s, DateTime(2026, 10, 1)), 75);
    expect(_due(s, DateTime(2026, 11, 1)), 75);
  });

  test('toMap/fromMap والمسح', () {
    final s = _s(from: DateTime(2026, 10, 1));
    expect(Student.fromMap(s.toMap()).siblingsFrom, DateTime(2026, 10, 1));
    expect(s.unlinkedFromSiblings().siblingsFrom, isNull);
    expect(s.copyWith(clearSiblingsFrom: true).siblingsFrom, isNull);
  });
}
