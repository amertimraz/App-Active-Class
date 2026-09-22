// test/student_interaction_test.dart
//
// وحدة للدوال الصرفة الجديدة في lib/models/attendance_model.dart (spec 040)
// — تفاعل الطالب: canRecordInteraction, interactionEmoji, interactionLabel,
// normalizeInteraction. راجع specs/040-student-interaction/quickstart.md.
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canRecordInteraction', () {
    test('حاضر → true', () {
      expect(canRecordInteraction(ATTENDANCE_PRESENT), isTrue);
    });

    test('متأخر → true', () {
      expect(canRecordInteraction(ATTENDANCE_LATE), isTrue);
    });

    test('غائب → false', () {
      expect(canRecordInteraction(ATTENDANCE_ABSENT), isFalse);
    });

    test('بلا حالة (null) → false', () {
      expect(canRecordInteraction(null), isFalse);
    });
  });

  group('interactionEmoji', () {
    test('نشيط → 😃', () {
      expect(interactionEmoji(STUDENT_INTERACTION_ACTIVE), '😃');
    });

    test('عادي → 😐', () {
      expect(interactionEmoji(STUDENT_INTERACTION_NEUTRAL), '😐');
    });

    test('غير متفاعل → 😴', () {
      expect(interactionEmoji(STUDENT_INTERACTION_DISENGAGED), '😴');
    });

    test('null → نص فاضي', () {
      expect(interactionEmoji(null), '');
    });

    test('قيمة غير معروفة → نص فاضي', () {
      expect(interactionEmoji('حاجة غريبة'), '');
    });
  });

  group('normalizeInteraction', () {
    test('قيمة صحيحة ترجع كما هي', () {
      expect(normalizeInteraction(STUDENT_INTERACTION_ACTIVE),
          STUDENT_INTERACTION_ACTIVE);
    });

    test('قيمة غير معروفة → null', () {
      expect(normalizeInteraction('غريب'), isNull);
    });

    test('نص فاضي → null', () {
      expect(normalizeInteraction(''), isNull);
    });
  });

  group('interactionLabel', () {
    test('نشيط → نشيط', () {
      expect(interactionLabel(STUDENT_INTERACTION_ACTIVE),
          STUDENT_INTERACTION_ACTIVE);
    });

    test('null → نص فاضي', () {
      expect(interactionLabel(null), '');
    });
  });
}
