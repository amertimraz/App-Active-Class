// lib/utils/exams_report.dart
//
// حسابات صرفة (بلا DB/GetX) لتبويب «الامتحانات» في التقارير. الامتحان بيتحسب
// في الشهر بتاعه حسب Exam.effectiveReportMonth (نفس باقي التطبيق).
// الغايب مش بيدخل في المتوسط ولا النجاح — بيتعدّ لوحده.
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/exam_model.dart';

/// نتيجة امتحان واحد.
class ExamResult {
  final Exam exam;
  final int graded; // اتسجّلت له درجة
  final int absent;
  final int passed;
  final int expected; // طلاب المجموعات المرتبطة (بعد الفلتر)
  final double? avgPct; // متوسط النسبة المئوية للي اتصحّح لهم
  final double? maxPct;
  final double? minPct;

  const ExamResult({
    required this.exam,
    required this.graded,
    required this.absent,
    required this.passed,
    required this.expected,
    required this.avgPct,
    required this.maxPct,
    required this.minPct,
  });

  /// نجاح ÷ اللي اتصحّح لهم. null لو لسه مفيش درجات.
  double? get passRate => graded == 0 ? null : passed / graded;

  /// لسه ما اتسجلش لهم (لا درجة ولا غياب).
  int get pending => (expected - graded - absent).clamp(0, expected);
}

/// طالب + متوسطه في امتحانات الشهر.
class StudentAvg {
  final int studentId;
  final double avgPct;
  final int exams;
  const StudentAvg(this.studentId, this.avgPct, this.exams);
}

class ExamsReport {
  final List<ExamResult> exams; // الأحدث أولًا
  final int graded;
  final int absent;
  final int passed;
  final double? avgPct;
  final Map<GradeCategory, int> distribution;
  final List<StudentAvg> top;
  final List<StudentAvg> bottom;
  final int studentsCount; // طلاب ليهم درجة في الشهر

  const ExamsReport({
    required this.exams,
    required this.graded,
    required this.absent,
    required this.passed,
    required this.avgPct,
    required this.distribution,
    required this.top,
    required this.bottom,
    required this.studentsCount,
  });

  double? get passRate => graded == 0 ? null : passed / graded;
}

/// تقرير امتحانات [month]. [groupOfStudent]: studentId → groupId (لطلاب
/// الدرجات). [studentsPerGroup]: groupId → عدد طلابه (للمتوقع). لو [groupId]
/// اتحدد، الدرجات والمتوقع لطلاب المجموعة دي بس، والامتحانات المرتبطة بيها.
ExamsReport computeExamsReport({
  required DateTime month,
  required Iterable<Exam> exams,
  required Iterable<ExamGrade> grades,
  required Map<int, int> groupOfStudent,
  required Map<int, int> studentsPerGroup,
  int? groupId,
  int top = 5,
}) {
  final byExam = <int, List<ExamGrade>>{};
  for (final g in grades) {
    if (groupId != null && groupOfStudent[g.studentId] != groupId) continue;
    byExam.putIfAbsent(g.examId, () => []).add(g);
  }

  final inMonth = exams.where((e) {
    if (e.id == null) return false;
    final m = e.effectiveReportMonth;
    if (m.year != month.year || m.month != month.month) return false;
    if (groupId != null && e.groupIds.isNotEmpty && !e.groupIds.contains(groupId)) {
      return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  var graded = 0, absent = 0, passed = 0;
  var sumPct = 0.0;
  final dist = <GradeCategory, int>{};
  final perStudent = <int, List<double>>{};
  final results = <ExamResult>[];

  for (final e in inMonth) {
    final rows = byExam[e.id] ?? const <ExamGrade>[];
    var g = 0, a = 0, p = 0;
    var sum = 0.0;
    double? mx, mn;
    for (final r in rows) {
      if (r.isAbsent) {
        a++;
        continue;
      }
      if (r.grade == null) continue;
      g++;
      final pct = e.maxGrade <= 0 ? 0.0 : r.grade! / e.maxGrade * 100;
      sum += pct;
      mx = mx == null || pct > mx ? pct : mx;
      mn = mn == null || pct < mn ? pct : mn;
      if (r.grade! >= e.passingGrade) p++;
      perStudent.putIfAbsent(r.studentId, () => []).add(pct);
      final passingPct = e.maxGrade <= 0 ? 60.0 : e.passingGrade / e.maxGrade * 100;
      final c = GradeCategoryExt.fromPercentage(pct, passingPct: passingPct);
      dist.update(c, (v) => v + 1, ifAbsent: () => 1);
    }
    final expected = e.groupIds
        .where((id) => groupId == null || id == groupId)
        .fold<int>(0, (s, id) => s + (studentsPerGroup[id] ?? 0));
    results.add(ExamResult(
      exam: e,
      graded: g,
      absent: a,
      passed: p,
      expected: expected,
      avgPct: g == 0 ? null : sum / g,
      maxPct: mx,
      minPct: mn,
    ));
    graded += g;
    absent += a;
    passed += p;
    sumPct += sum;
  }

  final avgs = [
    for (final en in perStudent.entries)
      StudentAvg(en.key, en.value.reduce((a, b) => a + b) / en.value.length,
          en.value.length)
  ];
  int byAvg(StudentAvg x, StudentAvg y) {
    final c = y.avgPct.compareTo(x.avgPct);
    return c != 0 ? c : x.studentId.compareTo(y.studentId);
  }

  final best = [...avgs]..sort(byAvg);
  final worst = [...avgs]..sort((x, y) => byAvg(y, x));

  return ExamsReport(
    exams: results,
    graded: graded,
    absent: absent,
    passed: passed,
    avgPct: graded == 0 ? null : sumPct / graded,
    distribution: dist,
    top: best.take(top).toList(),
    bottom: worst.take(top).toList(),
    studentsCount: avgs.length,
  );
}
