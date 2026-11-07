import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/student_points.dart';

void main() {
  final student = Student(id: 1, name: 'أحمد', code: 'S1', groupId: 1, price: 100);
  final other = Student(id: 2, name: 'بسمة', code: 'S2', groupId: 2, price: 100);

  Attendance att(DateTime d, String status,
          {String? interaction, int? rec, int? recMax}) =>
      Attendance(
          studentId: 1,
          date: d,
          status: status,
          interaction: interaction,
          recitation: rec,
          recitationMax: recMax);

  StudentExamRecord exam(double grade, double max, DateTime month,
          {bool absent = false}) =>
      StudentExamRecord(
          examId: 1,
          examName: 'امتحان',
          examDate: month,
          reportMonth: DateTime(month.year, month.month, 1),
          maxGrade: max,
          passingGrade: max * 0.5,
          grade: absent ? null : grade,
          isAbsent: absent,
          groupName: 'أ');

  const rules = PointsRules.defaults;

  StudentPoints calc(
          {List<Attendance> a = const [],
          List<Homework> h = const [],
          List<StudentExamRecord> e = const [],
          DateTime? month,
          PointsRules r = rules}) =>
      computeStudentPoints(
          student: student,
          attendance: a,
          homework: h,
          exams: e,
          rules: r,
          month: month);

  group('الحضور والانتظام', () {
    test('حاضر 10 ومتأخر 5 والغياب 0', () {
      final p = calc(a: [
        att(DateTime(2026, 11, 1), ATTENDANCE_PRESENT),
        att(DateTime(2026, 11, 2), ATTENDANCE_LATE),
        att(DateTime(2026, 11, 3), ATTENDANCE_ABSENT),
      ]);
      expect(p.breakdown.attendance, 15);
      expect(p.points, 15);
    });

    test('مكافأة الانتظام كل 5 حصص متتالية والغياب بيكسر السلسلة', () {
      final days = [
        for (var i = 1; i <= 5; i++)
          att(DateTime(2026, 11, i), ATTENDANCE_PRESENT),
        att(DateTime(2026, 11, 6), ATTENDANCE_ABSENT),
        for (var i = 7; i <= 11; i++)
          att(DateTime(2026, 11, i), ATTENDANCE_PRESENT),
      ];
      final p = calc(a: days);
      expect(p.breakdown.attendance, 100); // 10 حصص × 10
      expect(p.breakdown.streak, 30); // مكافأتين × 15
      expect(p.bestStreak, 5);
      expect(p.currentStreak, 5);
    });

    test('السجلات من غير حالة بتتجاهل', () {
      final p = calc(a: [att(DateTime(2026, 11, 1), 'x')]);
      expect(p.points, 0);
    });
  });

  group('الامتحانات', () {
    test('النقاط بنسبة الدرجة + مكافأة التفوّق من 90%', () {
      final p = calc(e: [
        exam(45, 50, DateTime(2026, 11, 5)), // 90% → 45 + 20
        exam(25, 50, DateTime(2026, 11, 6)), // 50% → 25
      ]);
      expect(p.breakdown.exams, 70);
      expect(p.breakdown.excellence, 20);
    });

    test('الغياب عن الامتحان بلا نقاط', () {
      final p = calc(e: [exam(0, 50, DateTime(2026, 11, 5), absent: true)]);
      expect(p.points, 0);
    });
  });

  group('الواجب والتسميع والتفاعل', () {
    test('واجب كامل 5 وناقص 2 ولم يعمل 0', () {
      final p = calc(h: [
        Homework(studentId: 1, date: DateTime(2026, 11, 1), status: HOMEWORK_DONE),
        Homework(studentId: 1, date: DateTime(2026, 11, 2), status: HOMEWORK_PARTIAL),
        Homework(studentId: 1, date: DateTime(2026, 11, 3), status: HOMEWORK_NOT_DONE),
      ]);
      expect(p.breakdown.homework, 7);
    });

    test('التسميع نسبي والتفاعل النشيط', () {
      final p = calc(a: [
        att(DateTime(2026, 11, 1), ATTENDANCE_PRESENT,
            rec: 8, recMax: 10, interaction: STUDENT_INTERACTION_ACTIVE),
      ]);
      expect(p.breakdown.recitation, 8);
      expect(p.breakdown.interaction, 3);
    });
  });

  group('الفترة والمستوى', () {
    test('الشهر بيحدد نقاط الفترة، والالتزام من كل الحصص', () {
      final a = [
        att(DateTime(2026, 10, 1), ATTENDANCE_PRESENT),
        att(DateTime(2026, 11, 1), ATTENDANCE_ABSENT),
        att(DateTime(2026, 11, 2), ATTENDANCE_LATE),
      ];
      final nov = calc(a: a, month: DateTime(2026, 11, 1));
      expect(nov.points, 5); // متأخر بس في نوفمبر
      expect(nov.sessions, 3); // الالتزام على مدى الوقت مش الشهر
      expect(nov.attended, 2);
      expect(nov.commitment, closeTo(66.67, 0.01));
      expect(calc(a: a).points, 15);
    });

    test('المستوى بنسبة الالتزام مع حد أدنى للحصص', () {
      PointsLevel lv(double r, int n) => pointsLevelFor(rate: r, sessions: n);
      expect(pointsLevelFor(rate: null, sessions: 0), PointsLevel.starter);
      expect(lv(100, 1), PointsLevel.starter); // 1 من 1 مش ماسي
      expect(lv(100, 3), PointsLevel.starter);
      expect(lv(100, 4), PointsLevel.bronze);
      expect(lv(100, 6), PointsLevel.silver);
      expect(lv(100, 8), PointsLevel.gold);
      expect(lv(100, 12), PointsLevel.diamond);
      expect(lv(95, 12), PointsLevel.diamond);
      expect(lv(94, 12), PointsLevel.gold);
      expect(lv(85, 20), PointsLevel.gold);
      expect(lv(75, 20), PointsLevel.silver);
      expect(lv(60, 20), PointsLevel.bronze);
      expect(lv(59, 20), PointsLevel.starter);
    });

    test('طالب جديد ما غابش يوصل زي القديم', () {
      final fresh = calc(a: [
        for (var i = 1; i <= 12; i++)
          att(DateTime(2026, 11, i), ATTENDANCE_PRESENT)
      ]);
      expect(fresh.commitment, 100);
      expect(fresh.level, PointsLevel.diamond);
      // قديم بنقاط كتير بس بيغيب كتير
      final old = calc(a: [
        for (var i = 1; i <= 100; i++)
          att(DateTime(2026, 1, 1).add(Duration(days: i)),
              i % 2 == 0 ? ATTENDANCE_PRESENT : ATTENDANCE_ABSENT)
      ]);
      expect(old.points, greaterThan(fresh.points));
      expect(old.level, PointsLevel.starter);
    });

    test('التقدّم ورسالة الناقص للمستوى التالي', () {
      expect(levelProgress(rate: 100, sessions: 2), closeTo(0.5, 1e-9));
      expect(levelProgress(rate: 30, sessions: 20), closeTo(0.5, 1e-9));
      expect(levelProgress(rate: 100, sessions: 50), 1.0);
      expect(levelHint(rate: 100, sessions: 2), contains('لسه 2 حصة'));
      expect(levelHint(rate: 50, sessions: 20), contains('60%'));
      expect(levelHint(rate: 100, sessions: 50), isNull);
    });

    test('الأوسمة: منتظم / متفوّق / نشيط', () {
      final a = [
        for (var i = 1; i <= 10; i++)
          att(DateTime(2026, 11, i), ATTENDANCE_PRESENT,
              interaction: i <= 5 ? STUDENT_INTERACTION_ACTIVE : null),
      ];
      final e = [
        for (var i = 1; i <= 3; i++) exam(48, 50, DateTime(2026, 11, i)),
      ];
      final p = calc(a: a, e: e);
      expect(p.badges, {
        PointsBadge.regular,
        PointsBadge.excellent,
        PointsBadge.active,
      });
    });
  });

  group('الترتيب والقواعد', () {
    test('نفس النقاط = نفس المركز، والترتيب بالاسم عند التعادل', () {
      final list = computeLeaderboardPoints(
        students: [student, other],
        attendanceByStudent: {
          1: [att(DateTime(2026, 11, 1), ATTENDANCE_PRESENT)],
          2: [
            Attendance(
                studentId: 2,
                date: DateTime(2026, 11, 1),
                status: ATTENDANCE_PRESENT)
          ],
        },
        homeworkByStudent: const {},
        examsByStudent: const {},
      );
      expect(list.map((r) => r.rank), [1, 1]);
      expect(list.first.entry.student.name, 'أحمد');
    });

    test('بيستثني اللي نقاطه صفر، ويفلتر بالمجموعة', () {
      final list = computeLeaderboardPoints(
        students: [student, other],
        attendanceByStudent: {
          1: [att(DateTime(2026, 11, 1), ATTENDANCE_PRESENT)],
        },
        homeworkByStudent: const {},
        examsByStudent: const {},
      );
      expect(list.length, 1);
      final g2 = computeLeaderboardPoints(
        students: [student, other],
        attendanceByStudent: {
          1: [att(DateTime(2026, 11, 1), ATTENDANCE_PRESENT)],
        },
        homeworkByStudent: const {},
        examsByStudent: const {},
        groupId: 2,
      );
      expect(g2, isEmpty);
    });

    test('تعديل القواعد بيغيّر النقاط', () {
      final p = calc(
          a: [att(DateTime(2026, 11, 1), ATTENDANCE_PRESENT)],
          r: rules.copyWith(present: 20));
      expect(p.points, 20);
    });

    test('تشفير وفك القواعد، والقيم الغلط ترجع للافتراضي', () {
      final r = rules.copyWith(present: 7, streakEvery: 4);
      expect(PointsRules.decode(r.encode()).present, 7);
      expect(PointsRules.decode(r.encode()).streakEvery, 4);
      expect(PointsRules.decode('مش json').present, 10);
      expect(PointsRules.decode(null).examFull, 50);
      expect(PointsRules.decode('{"present":-5,"streakEvery":1}').present, 10);
      expect(PointsRules.decode('{"present":-5,"streakEvery":1}').streakEvery, 5);
    });
  });

  group('رسالة واتساب', () {
    test('بتشرح الحساب وتعرض الالتزام', () {
      final list = computeLeaderboardPoints(
        students: [student],
        attendanceByStudent: {
          1: [
            for (var i = 1; i <= 4; i++)
              att(DateTime(2026, 11, i), ATTENDANCE_PRESENT)
          ],
        },
        homeworkByStudent: const {},
        examsByStudent: const {},
      );
      final text = buildPointsShareText(list, periodLabel: 'كل الوقت');
      expect(text, contains('التزام 100%'));
      expect(text, contains('📌 طريقة حساب النقاط: حضور 10 • متأخر 5'));
      expect(text, contains('كل 5 حصص متتالية +15'));
      expect(text, contains('🏅 المستوى بنسبة الالتزام'));
      expect(text, contains('برونزي 60% • فضي 75% • ذهبي 85% • ماسي 95%'));
    });

    test('القواعد المعدّلة بتظهر والبنود الصفرية بتتخطّى', () {
      final lines = pointsExplainerLines(
          rules.copyWith(present: 20, late: 0, interactionActive: 0));
      expect(lines.first, contains('حضور 20'));
      expect(lines.first, isNot(contains('متأخر')));
      expect(lines.first, isNot(contains('نشيط')));
    });
  });
}
