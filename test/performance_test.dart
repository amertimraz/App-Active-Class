// test/performance_test.dart — spec 050 (تقرير أداء الطالب)
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final oct = DateTime(2026, 10, 1);
final sep = DateTime(2026, 9, 1);

StudentExamRecord ex(DateTime reportMonth, double? g, double max,
        {bool absent = false}) =>
    StudentExamRecord(
      examId: 1,
      examName: 'x',
      examDate: reportMonth,
      reportMonth: reportMonth,
      maxGrade: max,
      passingGrade: max / 2,
      grade: g,
      isAbsent: absent,
      groupName: 'g',
    );

Attendance att(DateTime d, String status, {int? rec}) =>
    Attendance(studentId: 1, date: d, status: status, recitation: rec);

Homework hw(DateTime d, String status) =>
    Homework(studentId: 1, date: d, status: status);

Student st() => Student(id: 1, name: 'أحمد', code: 'c', groupId: 1, price: 100);

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));

  group('النسب', () {
    test('امتحانات: متوسط النسب، غياب وبلا درجة خارج الحساب', () {
      final r = [
        ex(oct, 70, 100), ex(oct, 8, 10), // 70 و80 → 75
        ex(oct, null, 100), ex(oct, 0, 100, absent: true),
        ex(sep, 60, 100),
      ];
      expect(examsPercent(r, oct), 75.0);
      expect(examsCount(r, oct), 2);
      expect(examsPercent(r, sep), 60.0);
      expect(examsPercent(r, DateTime(2026, 8, 1)), isNull);
    });
    test('حضور: متأخر حضور، فراغ → null', () {
      final a = [
        att(DateTime(2026, 10, 1), ATTENDANCE_PRESENT),
        att(DateTime(2026, 10, 2), ATTENDANCE_LATE),
        att(DateTime(2026, 10, 3), ATTENDANCE_ABSENT),
        att(DateTime(2026, 10, 4), ATTENDANCE_PRESENT),
      ];
      expect(attendancePercent(a, oct), 75.0);
      expect(attendanceCount(a, oct), 4);
      expect(attendancePercent(a, sep), isNull);
    });
    test('واجب: تم + نص ناقص', () {
      final h = [
        hw(DateTime(2026, 10, 1), HOMEWORK_DONE),
        hw(DateTime(2026, 10, 2), HOMEWORK_PARTIAL),
        hw(DateTime(2026, 10, 3), HOMEWORK_NOT_DONE),
        hw(DateTime(2026, 10, 4), HOMEWORK_DONE),
      ];
      expect(homeworkPercent(h, oct), 62.5);
      expect(homeworkCount(h, oct), 4);
    });
    test('تسميع: متوسط ÷ 10', () {
      final a = [
        att(DateTime(2026, 10, 1), ATTENDANCE_PRESENT, rec: 8),
        att(DateTime(2026, 10, 2), ATTENDANCE_PRESENT, rec: 6),
        att(DateTime(2026, 10, 3), ATTENDANCE_PRESENT),
      ];
      expect(recitationPercent(a, oct), 70.0);
      expect(recitationPercent(a, sep), isNull);
    });
  });

  group('الاتجاه والتقييم', () {
    test('حدود ±3', () {
      expect(trendOf(70, 60), PerfTrend.up);
      expect(trendOf(63, 60), PerfTrend.up);
      expect(trendOf(62.9, 60), PerfTrend.steady);
      expect(trendOf(57.1, 60), PerfTrend.steady);
      expect(trendOf(57, 60), PerfTrend.down);
      expect(trendOf(null, 60), PerfTrend.none);
      expect(trendOf(60, null), PerfTrend.none);
    });
    test('التقييم اللفظي', () {
      expect(levelOf(85), 'ممتاز');
      expect(levelOf(84.9), 'جيد جدًا');
      expect(levelOf(75), 'جيد جدًا');
      expect(levelOf(65), 'جيد');
      expect(levelOf(50), 'مقبول');
      expect(levelOf(49.9), 'يحتاج دعمًا');
      expect(levelOf(null), '');
    });
    test('monthsBack عبر السنة', () {
      final m = monthsBack(DateTime(2027, 2, 15));
      expect(m.length, 6);
      expect(m.first, DateTime(2026, 9, 1));
      expect(m.last, DateTime(2027, 2, 1));
    });
  });

  group('buildPerformance', () {
    final exams = [ex(sep, 60, 100), ex(oct, 70, 100)];
    final atts = [
      att(DateTime(2026, 9, 5), ATTENDANCE_PRESENT),
      att(DateTime(2026, 9, 6), ATTENDANCE_ABSENT),
      att(DateTime(2026, 10, 5), ATTENDANCE_PRESENT),
    ];
    test('الامتحانات 60 → 70 صعود +10', () {
      final p = buildPerformance(
          student: st(),
          groupName: 'ش',
          month: oct,
          attendance: atts,
          homework: const [],
          exams: exams);
      final e = p.indicator(PerfKind.exams)!;
      expect(e.current, 70.0);
      expect(e.previous, 60.0);
      expect(e.delta, 10.0);
      expect(e.trend, PerfTrend.up);
      expect(e.level, 'جيد');
      final a = p.indicator(PerfKind.attendance)!;
      expect(a.current, 100.0);
      expect(a.previous, 50.0);
      expect(a.trend, PerfTrend.up);
      // الواجب والتسميع بلا بيانات
      expect(p.indicator(PerfKind.homework)!.current, isNull);
      expect(p.overall, 85.0);
      expect(p.overallTrend, PerfTrend.up);
      expect(p.hasData, true);
      expect(p.indicator(PerfKind.exams)!.series.length, 6);
      expect(p.indicator(PerfKind.exams)!.series.last, 70.0);
      expect(p.indicator(PerfKind.exams)!.series[4], 60.0);
      expect(p.indicator(PerfKind.exams)!.series.first, isNull);
    });
    test('المؤشرات المخفية غير موجودة', () {
      final p = buildPerformance(
          student: st(),
          groupName: 'ش',
          month: oct,
          attendance: atts,
          homework: [hw(DateTime(2026, 10, 1), HOMEWORK_DONE)],
          exams: exams,
          enabled: {PerfKind.exams, PerfKind.attendance});
      expect(p.indicators.map((i) => i.kind),
          [PerfKind.exams, PerfKind.attendance]);
      expect(p.indicator(PerfKind.homework), isNull);
    });
    test('شهر بلا سابق → بلا اتجاه', () {
      final p = buildPerformance(
          student: st(),
          groupName: 'ش',
          month: oct,
          attendance: const [],
          homework: const [],
          exams: [ex(oct, 70, 100)]);
      final e = p.indicator(PerfKind.exams)!;
      expect(e.previous, isNull);
      expect(e.trend, PerfTrend.none);
      expect(p.overallDelta, isNull);
      expect(p.overallTrend, PerfTrend.none);
    });
    test('طالب بلا بيانات', () {
      final p = buildPerformance(
          student: st(),
          groupName: 'ش',
          month: oct,
          attendance: const [],
          homework: const [],
          exams: const []);
      expect(p.hasData, false);
      expect(p.hasAnyData, false);
      expect(p.overall, isNull);
    });
  });

  group('rankPerformances', () {
    StudentPerformance mk(String name, List<StudentExamRecord> e) =>
        buildPerformance(
            student: Student(id: name.hashCode, name: name, code: name, groupId: 1, price: 1),
            groupName: 'ش',
            month: oct,
            attendance: const [],
            homework: const [],
            exams: e,
            enabled: {PerfKind.exams});
    test('ترتيب تنازلي، بلا بيانات في الآخر، وفلتر المتراجعين', () {
      final a = mk('أ', [ex(sep, 60, 100), ex(oct, 90, 100)]); // 90 ↑
      final b = mk('ب', [ex(sep, 80, 100), ex(oct, 70, 100)]); // 70 ↓
      final c = mk('ج', const []); // بلا بيانات
      final d = mk('د', [ex(sep, 50, 100), ex(oct, 80, 100)]); // 80 ↑
      final ranked = rankPerformances([c, b, a, d]);
      expect(ranked.map((p) => p.name), ['أ', 'د', 'ب', 'ج']);
      final declining = rankPerformances([a, b, c, d], onlyDeclining: true);
      expect(declining.map((p) => p.name), ['ب']);
    });
  });

  group('المخرجات', () {
    final p = buildPerformance(
        student: st(),
        groupName: 'السادس',
        month: oct,
        attendance: [
          att(DateTime(2026, 9, 5), ATTENDANCE_PRESENT),
          att(DateTime(2026, 10, 5), ATTENDANCE_PRESENT),
        ],
        homework: const [],
        exams: [ex(sep, 60, 100), ex(oct, 70, 100)]);

    test('رسالة نصية: أرقام وأسهم وتوقيع، بلا مبالغ', () {
      final m = performanceMessage(p,
          teacherName: 'أ. سامي', teacherSpecialization: 'رياضيات');
      expect(m, contains('تقرير مستوى الطالب'));
      expect(m, contains('الامتحانات: 70%'));
      expect(m, contains('↑ تحسّن (+10 عن الشهر السابق 60%)'));
      expect(m, contains('أ. سامي'));
      expect(m, contains('رياضيات'));
      expect(m, isNot(contains('جنيه')));
      expect(m, isNot(contains('المتبقي')));
    });
    test('بوابة: مؤشرات فيها بيانات فقط وسلسلة', () {
      final f = performancePortalFields(p)!;
      final inds = f['indicators'] as List;
      expect(inds.map((e) => (e as Map)['kind']),
          containsAll(['exams', 'attendance']));
      expect(inds.any((e) => (e as Map)['kind'] == 'homework'), false);
      expect((f['series'] as Map)['exams'], hasLength(6));
      expect(f['month'], '2026-10-01');
    });
    test('بوابة: بلا بيانات → null', () {
      final empty = buildPerformance(
          student: st(),
          groupName: 'ش',
          month: oct,
          attendance: const [],
          homework: const [],
          exams: const []);
      expect(performancePortalFields(empty), isNull);
    });
  });

  group('ملاحظات شهر التقرير', () {
    StudentExamRecord exRm(DateTime date, DateTime rm, double g) =>
        StudentExamRecord(
          examId: 1, examName: 'شهري', examDate: date, reportMonth: rm,
          maxGrade: 20, passingGrade: 10, grade: g, groupName: 'g');
    test('امتحان 5 أكتوبر محسوب على سبتمبر', () {
      final e = [exRm(DateTime(2026, 10, 5), sep, 14)];
      final pOct = buildPerformance(
          student: st(), groupName: 'ش', month: oct,
          attendance: const [], homework: const [], exams: e);
      expect(pOct.indicator(PerfKind.exams)!.current, isNull);
      expect(pOct.notes.single, contains('محسوب على شهر'));
      final pSep = buildPerformance(
          student: st(), groupName: 'ش', month: sep,
          attendance: const [], homework: const [], exams: e);
      expect(pSep.indicator(PerfKind.exams)!.current, 70.0);
      expect(pSep.notes.single, contains('محسوب على هذا الشهر'));
    });
    test('نفس الشهر → بلا ملاحظة', () {
      final p = buildPerformance(
          student: st(), groupName: 'ش', month: oct,
          attendance: const [], homework: const [],
          exams: [exRm(DateTime(2026, 10, 5), oct, 14)]);
      expect(p.notes, isEmpty);
    });
  });
}
