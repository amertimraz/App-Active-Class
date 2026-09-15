// test/pricing_helper_departure_test.dart
// spec 035 — اختبار وحدة لـ PricingHelper.siblingGroupDepartureAlert.
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

Student _s({
  required int id,
  required String name,
  int? siblingGroupId,
  int? siblingGroupCommittedCount,
  bool isArchived = false,
}) {
  return Student(
    id: id,
    name: name,
    code: 'S$id',
    groupId: 1,
    price: 100,
    siblingGroupId: siblingGroupId,
    siblingGroupCommittedCount: siblingGroupCommittedCount,
    siblingsTotal: siblingGroupId != null ? 150 : null,
    isArchived: isArchived,
  );
}

void main() {
  group('siblingGroupDepartureAlert', () {
    test('طالب مش في مجموعة إخوة → null', () {
      final student = _s(id: 1, name: 'a');
      final result =
          PricingHelper.siblingGroupDepartureAlert(student, [student]);
      expect(result, isNull);
    });

    test('٣ أعضاء نشطين، مفيش خروج → null', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final b = _s(id: 2, name: 'b', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final c = _s(id: 3, name: 'c', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final all = [a, b, c];
      expect(PricingHelper.siblingGroupDepartureAlert(a, all), isNull);
    });

    test('عضو خرج (٣→٢) → تنبيه بالعدد القديم والجديد', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final b = _s(id: 2, name: 'b', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      // العضو الثالث خرج (مش موجود في allStudents — نفس نمط الاستدعاء
      // الحقيقي اللي بيمرّر الطلاب النشطين بس).
      final all = [a, b];
      final result = PricingHelper.siblingGroupDepartureAlert(a, all);
      expect(result, isNotNull);
      expect(result!.oldCount, 3);
      expect(result.newCount, 2);
    });

    test('العدد رجع يطابق بعد استرجاع العضو → null تاني', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final b = _s(id: 2, name: 'b', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final c = _s(id: 3, name: 'c', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final all = [a, b, c]; // العضو رجع للقايمة (اتلغى أرشفته)
      expect(PricingHelper.siblingGroupDepartureAlert(a, all), isNull);
    });

    test('نزلت لعضو واحد (خارج النطاق — FR-009) → null', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1, siblingGroupCommittedCount: 2);
      final all = [a];
      expect(PricingHelper.siblingGroupDepartureAlert(a, all), isNull);
    });

    test('committedCount = null (بيانات قديمة قبل الميزة) → null', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1);
      final b = _s(id: 2, name: 'b', siblingGroupId: 1);
      final all = [a];
      expect(PricingHelper.siblingGroupDepartureAlert(a, all), isNull);
      // ignore: unused_local_variable
      final _ = b;
    });
  });

  group('monthlyDue يستخدم committedCount كقاسم', () {
    test('القاسم يفضل ٣ لحد ما المدرّس يقرر، مش العدد الحي (٢)', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final b = _s(id: 2, name: 'b', siblingGroupId: 1, siblingGroupCommittedCount: 3);
      final remainingOnly = [a, b]; // عضو ثالث خرج، لسه معملهوش قرار
      final due = PricingHelper.monthlyDue(
        student: a,
        group: null,
        month: DateTime(2026, 9, 1),
        allAttendance: const [],
        siblingGroupMembers: remainingOnly,
      );
      expect(due, 50.0); // 150 / 3 (القديم)، مش 150 / 2 (الحي)
    });

    test('بعد التأكيد (committedCount=2) القاسم بقى ٢', () {
      final a = _s(id: 1, name: 'a', siblingGroupId: 1, siblingGroupCommittedCount: 2);
      final b = _s(id: 2, name: 'b', siblingGroupId: 1, siblingGroupCommittedCount: 2);
      final remainingOnly = [a, b];
      final due = PricingHelper.monthlyDue(
        student: a,
        group: null,
        month: DateTime(2026, 9, 1),
        allAttendance: const [],
        siblingGroupMembers: remainingOnly,
      );
      expect(due, 75.0); // 150 / 2
    });
  });
}
