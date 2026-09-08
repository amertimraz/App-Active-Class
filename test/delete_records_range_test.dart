// test/delete_records_range_test.dart
//
// وحدة لمنطق حذف السجلات بمدى (spec 028) — الأجزاء النقية القابلة
// للعزل: حدود المدى، خصائص الأنواع، فلترة الأنواع المُزامَنة.
// (تنفيذ الحذف الفعلي على القاعدة يُتحقَّق يدويًا عبر quickstart —
// لا بنية اختبار DB in-memory في المشروع.)
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/deletable_record_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rangeIsoBounds', () {
    test('حدود تاريخ فقط: يوم البداية شامل، اليوم التالي للنهاية حصري', () {
      final b = rangeIsoBounds(
        DateTime(2025, 9, 1, 14, 30), // جزء الوقت يُتجاهَل
        DateTime(2025, 9, 30, 3, 0),
      );
      expect(b.fromIso, '2025-09-01');
      expect(b.toIso, '2025-10-01');
    });

    test('صف تاريخ-فقط في يوم البداية داخل المدى', () {
      final b = rangeIsoBounds(DateTime(2025, 9, 1), DateTime(2025, 9, 1));
      const dateOnlyRow = '2025-09-01';
      final fullIsoRow = DateTime(2025, 9, 1, 23, 0).toIso8601String();
      expect(dateOnlyRow.compareTo(b.fromIso) >= 0, isTrue); // كان بيفشل قبل الإصلاح
      expect(dateOnlyRow.compareTo(b.toIso) < 0, isTrue);
      expect(fullIsoRow.compareTo(b.fromIso) >= 0, isTrue);
      expect(fullIsoRow.compareTo(b.toIso) < 0, isTrue);
    });

    test('صف في اليوم التالي للنهاية خارج المدى (تاريخ-فقط و ISO كامل)', () {
      final b = rangeIsoBounds(DateTime(2025, 9, 1), DateTime(2025, 9, 30));
      expect('2025-10-01'.compareTo(b.toIso) < 0, isFalse);
      expect(DateTime(2025, 10, 1, 0, 0)
              .toIso8601String()
              .compareTo(b.toIso) <
          0, isFalse);
    });
  });

  group('خصائص DeletableRecordType', () {
    test('report_logs هو الوحيد غير المُزامَن', () {
      for (final t in DeletableRecordType.values) {
        expect(t.isTeamSynced, t != DeletableRecordType.reportLogs);
      }
    });

    test('examGrades وحدها بلا عمود تاريخ مباشر (تُفلتَر بالامتحان الأب)', () {
      expect(DeletableRecordType.examGrades.dateColumn, isNull);
      expect(DeletableRecordType.attendance.dateColumn, COL_ATTENDANCE_DATE);
      expect(DeletableRecordType.payments.dateColumn, COL_PAYMENT_DATE);
      expect(DeletableRecordType.homework.dateColumn, COL_HOMEWORK_DATE);
      expect(DeletableRecordType.exams.dateColumn, COL_EXAM_DATE);
      expect(DeletableRecordType.reportLogs.dateColumn, COL_REPORT_SENT_AT);
    });

    test('mainTable صحيح لكل نوع', () {
      expect(DeletableRecordType.attendance.mainTable, TABLE_ATTENDANCE);
      expect(DeletableRecordType.payments.mainTable, TABLE_PAYMENTS);
      expect(DeletableRecordType.examGrades.mainTable, TABLE_EXAM_GRADES);
      expect(DeletableRecordType.exams.mainTable, TABLE_EXAMS);
      expect(DeletableRecordType.homework.mainTable, TABLE_HOMEWORK);
      expect(DeletableRecordType.reportLogs.mainTable, TABLE_REPORT_LOGS);
    });

    test('كل نوع له label غير فارغ، ولا يوجد نوع للروستر', () {
      for (final t in DeletableRecordType.values) {
        expect(t.label.trim(), isNotEmpty);
      }
      final tables = DeletableRecordType.values.map((t) => t.mainTable).toSet();
      expect(tables.contains(TABLE_STUDENTS), isFalse);
      expect(tables.contains(TABLE_GROUPS), isFalse);
    });
  });

  group('عتبة التأكيد', () {
    bool needsConfirm(int total) => total > kBulkDeleteThreshold;
    test('101 → يتطلب كتابة، 100 → لا', () {
      expect(needsConfirm(101), isTrue);
      expect(needsConfirm(100), isFalse);
      expect(needsConfirm(0), isFalse);
    });
    test('كلمة التأكيد = حذف', () => expect(kDeleteConfirmWord, 'حذف'));
  });
}
