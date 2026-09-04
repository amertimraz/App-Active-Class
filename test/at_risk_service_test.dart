// test/at_risk_service_test.dart
//
// اختبار وحدة لـ AtRiskService.computeAtRiskStudents — منطق Dart نقي
// (spec 021). بيغطّي كل إشارة على حدة + التهدئة بعد "تمّت المتابعة".
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/at_risk_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/student_follow_up_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/at_risk_service.dart';
import 'package:active_class/config/constants.dart';

Student _student(int id, {bool archived = false, double exemptPercent = 0}) =>
    Student(
      id: id,
      name: 'طالب $id',
      code: 'S$id',
      groupId: 1,
      price: 100,
      isArchived: archived,
      exemptPercent: exemptPercent,
      // PricingHelper.totalDueThrough محتاجة attendanceStart أو createdAt
      // عشان تحسب أي مديونية أصلاً — لأي طالب حقيقي دايمًا متسجّل.
      createdAt: DateTime(2026, 1, 1),
    );

final _group = Group(id: 1, name: 'مجموعة تجريبية', price: 100);

// معطّلة تأخّر الدفع افتراضيًا في اختبارات الإشارات التانية — الطالب
// التجريبي عنده createdAt وسعر مجموعة وصفر دفعات، فبيبقى "متأخر" دايمًا
// لو الإشارة دي شغّالة، وده هيلوّث اختبارات مش قاصدة تغطّي الدفع.
const _defaultSettings = AtRiskSettings(paymentEnabled: false);

void main() {
  group('غياب متتالي', () {
    test('يتحقق عند الوصول للعتبة', () {
      final s = _student(1);
      final attendance = [
        Attendance(studentId: 1, date: DateTime(2026, 9, 1), status: ATTENDANCE_ABSENT),
        Attendance(studentId: 1, date: DateTime(2026, 9, 2), status: ATTENDANCE_ABSENT),
      ];
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance,
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings, // threshold = 2
      );
      expect(result.length, 1);
      expect(result.first.signals.single.type, RiskSignalType.consecutiveAbsence);
    });

    test('لا يتحقق تحت العتبة أو لو آخر يوم حاضر', () {
      final s = _student(1);
      final attendance = [
        Attendance(studentId: 1, date: DateTime(2026, 9, 1), status: ATTENDANCE_ABSENT),
        Attendance(studentId: 1, date: DateTime(2026, 9, 2), status: ATTENDANCE_PRESENT),
      ];
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance,
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings,
      );
      expect(result, isEmpty);
    });
  });

  group('واجب ناقص متكرر', () {
    test('يحتاج نافذة كاملة (W) قبل ما يتحقق', () {
      final s = _student(1);
      final homework = [
        Homework(studentId: 1, date: DateTime(2026, 9, 1), status: HOMEWORK_NOT_DONE),
        Homework(studentId: 1, date: DateTime(2026, 9, 2), status: HOMEWORK_NOT_DONE),
      ]; // W الافتراضي = 5، عندنا 2 بس
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: homework,
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings,
      );
      expect(result, isEmpty);
    });

    test('يتحقق لو M من آخر W ناقصين', () {
      final s = _student(1);
      final homework = List.generate(
        5,
        (i) => Homework(
          studentId: 1,
          date: DateTime(2026, 9, i + 1),
          status: i < 3 ? HOMEWORK_NOT_DONE : HOMEWORK_DONE,
        ),
      ); // 3 ناقص من 5 — M الافتراضي = 3
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: homework,
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings,
      );
      expect(result.length, 1);
      expect(result.first.signals.single.type, RiskSignalType.missingHomework);
    });
  });

  group('هبوط الدرجات', () {
    test('درجة تحت النجاح تتحقق حتى بدرجة واحدة بس', () {
      final s = _student(1);
      final grades = [
        ExamGrade(
          id: 1, examId: 1, studentId: 1, grade: 40,
          maxGrade: 100, passingGrade: 50,
          createdAt: DateTime(2026, 9, 1),
        ),
      ];
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: const [],
        examGrades: grades,
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings,
      );
      expect(result.length, 1);
      expect(result.first.signals.single.type, RiskSignalType.gradeDrop);
    });

    test('هبوط ≥ العتبة عن متوسط السابق يتحقق', () {
      final s = _student(1);
      final grades = [
        ExamGrade(id: 1, examId: 1, studentId: 1, grade: 85, maxGrade: 100,
            passingGrade: 50, createdAt: DateTime(2026, 8, 1)),
        ExamGrade(id: 2, examId: 2, studentId: 1, grade: 60, maxGrade: 100,
            passingGrade: 50, createdAt: DateTime(2026, 9, 1)), // -25 نقطة
      ];
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: const [],
        examGrades: grades,
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings, // gradeDropPoints = 15
      );
      expect(result.length, 1);
    });

    test('استقرار الدرجات لا يتحقق', () {
      final s = _student(1);
      final grades = [
        ExamGrade(id: 1, examId: 1, studentId: 1, grade: 82, maxGrade: 100,
            passingGrade: 50, createdAt: DateTime(2026, 8, 1)),
        ExamGrade(id: 2, examId: 2, studentId: 1, grade: 80, maxGrade: 100,
            passingGrade: 50, createdAt: DateTime(2026, 9, 1)),
      ];
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: const [],
        examGrades: grades,
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings,
      );
      expect(result, isEmpty);
    });
  });

  group('تأخّر الدفع', () {
    test('طالب معفى بالكامل لا يترصد أبدًا', () {
      final s = _student(1, exemptPercent: 100);
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: const AtRiskSettings(paymentGraceDays: 0),
      );
      expect(result, isEmpty);
    });

    test('طالب بلا دفعات ومديونية موجبة يترصد', () {
      final s = _student(1);
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: const [],
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: const AtRiskSettings(paymentGraceDays: 0),
        now: DateTime(2026, 9, 15),
      );
      expect(result.any((e) => e.signals.any((sig) => sig.type == RiskSignalType.latePayment)),
          isTrue);
    });
  });

  group('استبعادات عامة', () {
    test('الطالب المؤرشف مستبعد حتى مع إشارة واضحة', () {
      final s = _student(1, archived: true);
      final attendance = List.generate(
        3,
        (i) => Attendance(
            studentId: 1, date: DateTime(2026, 9, i + 1), status: ATTENDANCE_ABSENT),
      );
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance,
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: _defaultSettings,
      );
      expect(result, isEmpty);
    });

    test('إشارة معطّلة من الإعدادات لا تُحتسب', () {
      final s = _student(1);
      final attendance = [
        Attendance(studentId: 1, date: DateTime(2026, 9, 1), status: ATTENDANCE_ABSENT),
        Attendance(studentId: 1, date: DateTime(2026, 9, 2), status: ATTENDANCE_ABSENT),
      ];
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance,
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: const [],
        settings: const AtRiskSettings(absenceEnabled: false, paymentEnabled: false),
      );
      expect(result, isEmpty);
    });
  });

  group('الإقرار والتهدئة', () {
    final attendance = [
      Attendance(studentId: 1, date: DateTime(2026, 9, 1), status: ATTENDANCE_ABSENT),
      Attendance(studentId: 1, date: DateTime(2026, 9, 2), status: ATTENDANCE_ABSENT),
    ];

    test('مؤجَّل داخل مدة التهدئة لنفس السبب', () {
      final s = _student(1);
      final followUp = StudentFollowUp(
        studentId: 1,
        reasonTypes: [RiskSignalType.consecutiveAbsence.storageKey],
        acknowledgedAt: DateTime(2026, 9, 2, 12),
      );
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance,
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: [followUp],
        settings: _defaultSettings, // cooldownDays = 7
        now: DateTime(2026, 9, 5),
      );
      expect(result, isEmpty);
    });

    test('يرجع يظهر بعد انتهاء مدة التهدئة', () {
      final s = _student(1);
      final followUp = StudentFollowUp(
        studentId: 1,
        reasonTypes: [RiskSignalType.consecutiveAbsence.storageKey],
        acknowledgedAt: DateTime(2026, 9, 2, 12),
      );
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance,
        homework: const [],
        examGrades: const [],
        payments: const [],
        recentFollowUps: [followUp],
        settings: _defaultSettings,
        now: DateTime(2026, 9, 20), // بعد 18 يوم > cooldown 7
      );
      expect(result.length, 1);
    });

    test('يرجع فورًا لو ظهر سبب من نوع جديد لم يكن مشمولًا بالإقرار', () {
      final s = _student(1);
      final homework = List.generate(
        5,
        (i) => Homework(
          studentId: 1,
          date: DateTime(2026, 9, i + 1),
          status: i < 3 ? HOMEWORK_NOT_DONE : HOMEWORK_DONE,
        ),
      );
      final followUp = StudentFollowUp(
        studentId: 1,
        reasonTypes: [RiskSignalType.consecutiveAbsence.storageKey], // الغياب بس
        acknowledgedAt: DateTime(2026, 9, 2, 12),
      );
      final result = computeAtRiskStudents(
        students: [s],
        groups: [_group],
        attendance: attendance, // لسه غياب
        homework: homework, // + واجب جديد
        examGrades: const [],
        payments: const [],
        recentFollowUps: [followUp],
        settings: _defaultSettings,
        now: DateTime(2026, 9, 5), // لسه داخل التهدئة
      );
      expect(result.length, 1);
      expect(result.first.signals.map((sig) => sig.type),
          containsAll([RiskSignalType.consecutiveAbsence, RiskSignalType.missingHomework]));
    });
  });
}
