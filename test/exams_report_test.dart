// test/exams_report_test.dart — حسابات تبويب الامتحانات في التقارير.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/utils/exams_report.dart';

Exam _e(int id, {String? rm, List<int> groups = const [10], double max = 100,
        double pass = 50, DateTime? date}) =>
    Exam(
        id: id,
        name: 'ex$id',
        date: date ?? DateTime(2026, 10, id),
        maxGrade: max,
        passingGrade: pass,
        reportMonth: rm,
        groupIds: groups);

ExamGrade _g(int exam, int student, double? grade, {bool absent = false}) =>
    ExamGrade(
        examId: exam, studentId: student, grade: grade, isAbsent: absent);

void main() {
  final month = DateTime(2026, 10, 1);
  final groupOf = {1: 10, 2: 10, 3: 20};
  const perGroup = {10: 2, 20: 1};

  ExamsReport run(List<Exam> exams, List<ExamGrade> grades, {int? gid}) =>
      computeExamsReport(
          month: month,
          exams: exams,
          grades: grades,
          groupOfStudent: groupOf,
          studentsPerGroup: perGroup,
          groupId: gid);

  test('متوسط ونجاح وغياب، والغايب برّه المتوسط', () {
    final r = run([
      _e(1)
    ], [
      _g(1, 1, 80),
      _g(1, 2, 40),
      _g(1, 3, null, absent: true),
    ]);
    expect(r.graded, 2);
    expect(r.absent, 1);
    expect(r.passed, 1);
    expect(r.avgPct, closeTo(60, 1e-9));
    expect(r.passRate, 0.5);
    expect(r.exams.single.maxPct, 80);
    expect(r.exams.single.minPct, 40);
  });

  test('الشهر حسب reportMonth مش تاريخ الامتحان', () {
    final r = run([
      _e(1, rm: '2026-11'), // تاريخه أكتوبر بس محسوب نوفمبر
      _e(2, rm: '2026-10', date: DateTime(2026, 9, 28)), // العكس
    ], [
      _g(1, 1, 90),
      _g(2, 1, 70),
    ]);
    expect(r.exams.map((e) => e.exam.id), [2]);
    expect(r.avgPct, 70);
  });

  test('المتوقع والمتبقي (لسه ما اتسجلش)', () {
    final r = run([
      _e(1, groups: [10, 20])
    ], [
      _g(1, 1, 60),
      _g(1, 2, null, absent: true),
    ]);
    final x = r.exams.single;
    expect(x.expected, 3);
    expect(x.pending, 1);
  });

  test('فلتر المجموعة: طلابها وامتحاناتها بس', () {
    final r = run([
      _e(1, groups: [10]),
      _e(2, groups: [20]),
    ], [
      _g(1, 1, 100),
      _g(2, 3, 20),
    ], gid: 20);
    expect(r.exams.map((e) => e.exam.id), [2]);
    expect(r.avgPct, 20);
    expect(r.passed, 0);
  });

  test('الأفضل والأضعف مرتّبين بمتوسط الشهر', () {
    final r = run([
      _e(1),
      _e(2)
    ], [
      _g(1, 1, 100),
      _g(2, 1, 80), // طالب 1 = 90
      _g(1, 2, 50),
      _g(2, 2, 30), // طالب 2 = 40
    ]);
    expect(r.top.first.studentId, 1);
    expect(r.top.first.avgPct, 90);
    expect(r.bottom.first.studentId, 2);
    expect(r.studentsCount, 2);
  });

  test('درجة عظمى مختلفة: النسبة مش الدرجة الخام', () {
    final r = run([
      _e(1, max: 20, pass: 10)
    ], [
      _g(1, 1, 15),
    ]);
    expect(r.avgPct, 75);
    expect(r.passed, 1);
    expect(r.distribution[GradeCategory.good], 1);
  });

  test('مفيش درجات → null مش 0', () {
    final r = run([_e(1)], const []);
    expect(r.avgPct, isNull);
    expect(r.passRate, isNull);
    expect(r.exams.single.passRate, isNull);
  });
}
