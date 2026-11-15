// المستحق الشهري لمجموعة — مصدر واحد لرأس «تفاصيل المجموعة» وموديل «رسوم الشهر».
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/group_fees.dart';

Student _s(int id,
        {double price = 100,
        double exempt = 0,
        DateTime? start,
        int? sib,
        double? total}) =>
    Student(
      id: id,
      name: 'طالب $id',
      code: 'G1-0$id',
      groupId: 1,
      price: price,
      exemptPercent: exempt,
      attendanceStart: start,
      siblingGroupId: sib,
      siblingsTotal: total,
    );

void main() {
  final group = Group(id: 1, name: 'ج', price: 100);
  final month = DateTime(2026, 10, 1);

  Map<int, double> due(List<Student> list, {List<Student>? all}) =>
      GroupFees.dueByStudent(
        students: list,
        group: group,
        month: month,
        attendance: const [],
        siblingGroupMembers: all ?? list,
      );

  test('سعر كامل + إعفاء جزئي + إعفاء كامل', () {
    final m = due([
      _s(1),
      _s(2, exempt: 50),
      _s(3, exempt: 100),
    ]);
    expect(m[1], 100);
    expect(m[2], 50);
    expect(m[3], 0);
    expect(GroupFees.total(m), 150);
  });

  test('طالب بدأ حضوره بعد الشهر مش بيدخل الحساب', () {
    final m = due([
      _s(1),
      _s(2, start: DateTime(2026, 11, 5)), // بعد أكتوبر
      _s(3, start: DateTime(2026, 10, 20)), // في أكتوبر نفسه: بيدخل
    ]);
    expect(m.keys.toSet(), {1, 3});
    expect(GroupFees.total(m), 200);
  });

  test('نصيب الإخوة بيتقسم على كل أعضاء مجموعة الإخوة حتى من مجموعة تانية', () {
    final a = _s(1, sib: 7, total: 300);
    // أخ في مجموعة تانية (مش في قايمة طلاب المجموعة دي).
    final b = Student(
        id: 9,
        name: 'أخ',
        code: 'G2-09',
        groupId: 2,
        price: 100,
        siblingGroupId: 7,
        siblingsTotal: 300);
    final onlyGroup = due([a]);
    final withAll = due([a], all: [a, b]);
    // لو الأخ مش محسوب الإجمالي بيتحمّل على طالب واحد بس (غلط).
    expect(onlyGroup[1], isNot(equals(withAll[1])));
    expect(withAll[1], 150); // 300 ÷ 2
  });

  test('قايمة فاضية: صفر', () {
    expect(GroupFees.total(due(const [])), 0);
  });
}
