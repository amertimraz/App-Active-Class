// test/archive_history_test.dart — spec 047 (سجل أرشفة الطالب)
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/utils/archive_history.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveEvent ev(String type, DateTime at) =>
    ArchiveEvent(studentId: 1, type: type, at: at);
Attendance att(DateTime d) =>
    Attendance(studentId: 1, date: d, status: ATTENDANCE_PRESENT);

void main() {
  final now = DateTime(2026, 10, 7, 18, 0);

  group('archiveEventLabel', () {
    test('اليوم', () {
      expect(archiveEventLabel(ev(kArchiveEventArchived, DateTime(2026, 10, 7, 15, 20)), now),
          'تمت أرشفته — اليوم 3:20 م');
    });
    test('أمس صباحًا', () {
      expect(archiveEventLabel(ev(kArchiveEventRestored, DateTime(2026, 10, 6, 9, 5)), now),
          'أُعيد من الأرشيف — أمس 9:05 ص');
    });
    test('تاريخ كامل', () {
      expect(archiveEventLabel(ev(kArchiveEventArchived, DateTime(2026, 9, 12, 0, 10)), now),
          'تمت أرشفته — 12 سبتمبر 2026 12:10 ص');
    });
    test('الظهر = 12 م', () {
      expect(archiveEventLabel(ev(kArchiveEventArchived, DateTime(2026, 10, 7, 12, 0)), now),
          'تمت أرشفته — اليوم 12:00 م');
    });
  });

  group('mergeAttendanceAndArchive', () {
    test('ترتيب تنازلي بين السجلات والأحداث', () {
      final merged = mergeAttendanceAndArchive(
        [att(DateTime(2026, 10, 1)), att(DateTime(2026, 10, 5))],
        [
          ev(kArchiveEventArchived, DateTime(2026, 10, 3)),
          ev(kArchiveEventRestored, DateTime(2026, 10, 6)),
        ],
      );
      expect(merged.map((e) => e.at.day), [6, 5, 3, 1]);
      expect(merged[0], isA<ArchiveItem>());
      expect(merged[1], isA<AttendanceItem>());
    });
    test('عند التساوي الحدث قبل السجل', () {
      final t = DateTime(2026, 10, 3, 10);
      final merged = mergeAttendanceAndArchive(
          [att(t)], [ev(kArchiveEventArchived, t)]);
      expect(merged.first, isA<ArchiveItem>());
    });
    test('قوائم فاضية', () {
      expect(mergeAttendanceAndArchive([], []), isEmpty);
    });
  });

  group('archiveEventVisible', () {
    bool v({String status = '', String q = '', int? gf, int? sg = 1}) =>
        archiveEventVisible(
            statusFilter: status,
            query: q,
            studentName: 'أحمد علي',
            groupFilter: gf,
            studentGroupId: sg);
    test('الكل ظاهر', () => expect(v(), true));
    test('فلتر حالة يخفيه', () => expect(v(status: ATTENDANCE_ABSENT), false));
    test('بحث بالاسم', () {
      expect(v(q: 'أحمد'), true);
      expect(v(q: 'محمود'), false);
    });
    test('فلتر المجموعة', () {
      expect(v(gf: 1), true);
      expect(v(gf: 2), false);
    });
  });

  test('shouldRecordArchiveEvent', () {
    expect(shouldRecordArchiveEvent(wasArchived: false, type: kArchiveEventArchived), true);
    expect(shouldRecordArchiveEvent(wasArchived: true, type: kArchiveEventArchived), false);
    expect(shouldRecordArchiveEvent(wasArchived: true, type: kArchiveEventRestored), true);
    expect(shouldRecordArchiveEvent(wasArchived: false, type: kArchiveEventRestored), false);
    expect(shouldRecordArchiveEvent(wasArchived: false, type: 'x'), false);
  });
}
