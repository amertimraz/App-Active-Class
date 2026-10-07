// test/auto_absent_test.dart — spec 046 (الغياب التلقائي بعد انتهاء الحصة)
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/auto_absent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 7);
  DateTime at(int h, int m, [int d = 7]) => DateTime(2026, 10, d, h, m);

  group('sessionEndFor', () {
    test('نهاية عادية', () {
      expect(sessionEndFor(day, '10:00 - 11:30'), at(11, 30));
      expect(sessionEndFor(day, '9:05-10:00'), at(10, 0));
    });
    test('عابرة لمنتصف الليل', () {
      expect(sessionEndFor(day, '23:00 - 00:30'), at(0, 30, 8));
    });
    test('بلا نهاية أو صيغة غلط → null', () {
      expect(sessionEndFor(day, null), isNull);
      expect(sessionEndFor(day, '10:00'), isNull);
      expect(sessionEndFor(day, ''), isNull);
      expect(sessionEndFor(day, '10:00 - xx'), isNull);
      expect(sessionEndFor(day, '25:00 - 26:00'), isNull);
    });
  });

  group('isSessionClosed', () {
    final end = at(11, 0);
    test('قبل النهاية وداخل المهلة → لا', () {
      expect(isSessionClosed(end: end, now: at(10, 50), graceMinutes: 15),
          false);
      expect(isSessionClosed(end: end, now: at(11, 14), graceMinutes: 15),
          false);
    });
    test('عند حد المهلة وبعده → نعم', () {
      expect(isSessionClosed(end: end, now: at(11, 15), graceMinutes: 15),
          true);
      expect(isSessionClosed(end: end, now: at(12, 0), graceMinutes: 15),
          true);
    });
    test('مهلة 0', () {
      expect(isSessionClosed(end: end, now: at(11, 0), graceMinutes: 0), true);
    });
  });

  test('lookbackDays: 4 أيام الأقدم أولًا بالتاريخ فقط', () {
    final d = lookbackDays(at(15, 30));
    expect(d.length, 4);
    expect(d.first, DateTime(2026, 10, 4));
    expect(d.last, DateTime(2026, 10, 7));
  });

  group('sessionEligible', () {
    final end = at(11, 0);
    final key = autoAbsentKey(1, day);
    bool el({DateTime? now, DateTime? enabledAt, Set<String>? processed}) =>
        sessionEligible(
          end: end,
          now: now ?? at(12, 0),
          graceMinutes: 15,
          enabledAt: enabledAt ?? at(8, 0),
          key: key,
          processed: processed ?? {},
        );
    test('مقفولة ومفعّل من قبل → نعم', () => expect(el(), true));
    test('لسه ما قفلتش → لا', () => expect(el(now: at(11, 5)), false));
    test('اتعالجت قبل كده → لا',
        () => expect(el(processed: {key}), false));
    test('التفعيل بعد وقت الإغلاق → لا (مفيش أثر رجعي)',
        () => expect(el(enabledAt: at(11, 30)), false));
  });

  group('studentsToMarkAbsent', () {
    Student st(int id,
            {bool archived = false, DateTime? start, DateTime? created}) =>
        Student(
          id: id,
          name: 's$id',
          code: 'c$id',
          groupId: 1,
          price: 100,
          isArchived: archived,
          attendanceStart: start,
          createdAt: created,
        );
    test('يستبعد المؤرشف ومن له سجل ومن بدأ بعد اليوم', () {
      final res = studentsToMarkAbsent(
        groupStudents: [
          st(1),
          st(2, archived: true),
          st(3),
          st(4, start: DateTime(2026, 10, 8)),
          st(5, start: DateTime(2026, 10, 7, 18)),
          st(6, created: DateTime(2026, 9, 1)),
        ],
        day: day,
        studentIdsWithRecord: {3},
      );
      expect(res.map((s) => s.id), [1, 5, 6]);
    });
  });

  test('isAutoAbsent', () {
    Attendance a(String status, String? notes) => Attendance(
        studentId: 1, date: day, status: status, notes: notes);
    expect(isAutoAbsent(a(ATTENDANCE_ABSENT, kAutoAbsentNote)), true);
    expect(isAutoAbsent(a(ATTENDANCE_ABSENT, null)), false);
    expect(isAutoAbsent(a(ATTENDANCE_PRESENT, kAutoAbsentNote)), false);
  });

  test('pruneProcessed يشيل الأقدم من النافذة', () {
    final now = at(12, 0);
    final keys = {
      autoAbsentKey(1, DateTime(2026, 10, 7)),
      autoAbsentKey(1, DateTime(2026, 10, 4)),
      autoAbsentKey(2, DateTime(2026, 10, 3)),
      'garbage',
    };
    expect(pruneProcessed(keys, now), {
      autoAbsentKey(1, DateTime(2026, 10, 7)),
      autoAbsentKey(1, DateTime(2026, 10, 4)),
    });
  });

  test('clampAutoAbsentGrace', () {
    expect(clampAutoAbsentGrace(null), 15);
    expect(clampAutoAbsentGrace(-5), 0);
    expect(clampAutoAbsentGrace(999), 180);
    expect(clampAutoAbsentGrace(30), 30);
  });
}
