// test/group_schedule_conflict_test.dart
//
// وحدة لدوال lib/views/groups/group_form/group_schedule_conflict.dart
// (spec 039) — أول تغطية اختبارية آلية لمنطق كان مكرَّرًا بلا اختبار في
// كل من groups_page.dart وgroup_details_page.dart قبل التوحيد. راجع
// specs/039-ui-forms-refactor/research.md #4 وquickstart.md.
import 'package:active_class/models/group_model.dart';
import 'package:active_class/views/groups/group_form/group_schedule_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Group makeGroup(int id, String name, String schedule) => Group(
        id: id,
        name: name,
        pricingType: GroupPricingType.monthly,
        schedule: schedule,
      );

  group('hasScheduleOverlap', () {
    test('مواعيد بلا أي تعارض (أيام مختلفة) → false', () {
      expect(hasScheduleOverlap('السبت 10:00-11:00, الأحد 12:00-13:00'),
          isFalse);
    });

    test('نفس اليوم بأوقات غير متداخلة → false', () {
      expect(hasScheduleOverlap('السبت 10:00-11:00, السبت 11:00-12:00'),
          isFalse);
    });

    test('تداخل داخل نص الجدول نفسه (نفس اليوم) → true', () {
      expect(hasScheduleOverlap('السبت 10:00-12:00, السبت 11:00-13:00'),
          isTrue);
    });

    test('نص جدول فاضي أو تالف (بدون وقت كامل) → false بلا استثناء', () {
      expect(hasScheduleOverlap(''), isFalse);
      expect(hasScheduleOverlap('السبت'), isFalse);
      expect(hasScheduleOverlap('السبت 10:00'), isFalse);
    });
  });

  group('findConflictingGroup', () {
    test('بلا أي تعارض مع مجموعات أخرى → null', () {
      final others = [makeGroup(2, 'ب', 'الأحد 10:00-11:00')];
      expect(findConflictingGroup('السبت 10:00-11:00', others), isNull);
    });

    test('تعارض جزئي في نفس اليوم → يرجع المجموعة المتعارضة', () {
      final others = [makeGroup(2, 'ب', 'السبت 10:30-11:30')];
      final result = findConflictingGroup('السبت 10:00-11:00', others);
      expect(result?.id, 2);
    });

    test('مجموعة بلا جدول (schedule=null) → تُتجاهَل بلا خطأ', () {
      final others = [Group(id: 3, name: 'ج', pricingType: GroupPricingType.monthly)];
      expect(findConflictingGroup('السبت 10:00-11:00', others), isNull);
    });
  });

  group('validateScheduleText', () {
    test('نص صالح → null', () {
      expect(validateScheduleText('السبت 10:00-11:00'), isNull);
    });

    test('يوم بلا وقت → رسالة خطأ', () {
      expect(validateScheduleText('السبت'), isNotNull);
    });

    test('تداخل داخل نفس النص → رسالة خطأ', () {
      expect(
          validateScheduleText('السبت 10:00-12:00, السبت 11:00-13:00'),
          isNotNull);
    });
  });
}
