// spec 023 — وحدات ExamAnalyticsService (حساب نقي).
import 'package:active_class/models/exam_analytics_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/models/exam_submission_model.dart';
import 'package:active_class/services/exam_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExamQuestion _q(int id, {int correct = 0, int opts = 3}) => ExamQuestion(
      id: id,
      examId: 1,
      position: id,
      type: ExamQuestionType.mcq,
      text: 'سؤال $id',
      options: List.generate(opts, (i) => 'خيار $i'),
      correctIndex: correct,
      points: 1,
    );

ExamSubmission _sub(int id, Map<int, int> answers,
        {SubmissionStatus status = SubmissionStatus.pending}) =>
    ExamSubmission(
      id: id,
      examId: 1,
      studentId: id,
      answers: answers,
      status: status,
    );

void main() {
  test('حساب أساسي: نسبة الصح + توزيع الاختيارات + عدد غير المجيبين', () {
    final questions = [_q(1, correct: 1), _q(2, correct: 0), _q(3, correct: 2)];
    // 5 تسليمات
    final subs = [
      _sub(1, {1: 1, 2: 0, 3: 2}), // كله صح
      _sub(2, {1: 1, 2: 1, 3: 0}), // س1 صح، س2 غلط، س3 غلط
      _sub(3, {1: 0, 2: 0}), // س1 غلط، س2 صح، س3 لم يجب
      _sub(4, {1: 1, 2: 2, 3: 2}), // س1 صح، س2 غلط، س3 صح
      _sub(5, {1: 2, 2: 0, 3: 1}), // س1 غلط، س2 صح، س3 غلط
    ];

    final a = ExamAnalyticsService.compute(questions: questions, submissions: subs);
    expect(a.length, 3);

    // س1: correct=1 → اختاره {1:3, 0:1, 2:1} ، الكل أجاب
    expect(a[0].optionCounts, [1, 3, 1]);
    expect(a[0].correctCount, 3);
    expect(a[0].notAnsweredCount, 0);
    expect(a[0].totalRespondents, 5);
    expect(a[0].correctRate, closeTo(0.6, 1e-9));

    // س2: correct=0 → {0:3, 1:1, 2:1}
    expect(a[1].optionCounts, [3, 1, 1]);
    expect(a[1].correctCount, 3);

    // س3: correct=2 → أجاب 4 (تسليم 3 لم يجب)، {0:1, 1:1, 2:2}
    expect(a[2].optionCounts, [1, 1, 2]);
    expect(a[2].correctCount, 2);
    expect(a[2].answeredCount, 4);
    expect(a[2].notAnsweredCount, 1);
    expect(a[2].totalRespondents, 5);
  });

  test('التسليم المُبطَل مستبعد تمامًا', () {
    final questions = [_q(1, correct: 0)];
    final subs = [
      _sub(1, {1: 0}),
      _sub(2, {1: 1}, status: SubmissionStatus.voided),
    ];
    final a = ExamAnalyticsService.compute(questions: questions, submissions: subs);
    expect(a[0].totalRespondents, 1);
    expect(a[0].optionCounts, [1, 0, 0]);
  });

  test('كل الإجابات صح → topDistractorIndex = null', () {
    final questions = [_q(1, correct: 1)];
    final subs = [_sub(1, {1: 1}), _sub(2, {1: 1}), _sub(3, {1: 1})];
    final a = ExamAnalyticsService.compute(questions: questions, submissions: subs);
    expect(a[0].topDistractorIndex, isNull);
    expect(a[0].correctRate, 1.0);
  });

  test('كلهم تركوا السؤال', () {
    final questions = [_q(1, correct: 0)];
    final subs = [_sub(1, {}), _sub(2, {})];
    final a = ExamAnalyticsService.compute(questions: questions, submissions: subs);
    expect(a[0].notAnsweredCount, 2);
    expect(a[0].correctRate, 0);
    expect(a[0].topDistractorIndex, isNull);
  });

  test('التجميع بهوية السؤال لا بترتيب العرض', () {
    // مفاتيح answers = q.id مهما كان ترتيب العرض المخلوط
    final questions = [_q(10, correct: 0), _q(20, correct: 1)];
    final subs = [_sub(1, {20: 1, 10: 0})];
    final a = ExamAnalyticsService.compute(questions: questions, submissions: subs);
    expect(a[0].questionId, 10);
    expect(a[0].correctCount, 1);
    expect(a[1].questionId, 20);
    expect(a[1].correctCount, 1);
  });

  test('submissions فارغة → قائمة بكل الأسئلة totalRespondents=0', () {
    final questions = [_q(1), _q(2)];
    final a = ExamAnalyticsService.compute(questions: questions, submissions: []);
    expect(a.length, 2);
    expect(a.every((x) => x.totalRespondents == 0), isTrue);
    expect(a[0].correctRate, 0);
  });

  test('أبرز distractor', () {
    final questions = [_q(1, correct: 0, opts: 4)];
    final subs = [
      _sub(1, {1: 2}), _sub(2, {1: 2}), _sub(3, {1: 3}), _sub(4, {1: 0}),
    ];
    final a = ExamAnalyticsService.compute(questions: questions, submissions: subs);
    expect(a[0].topDistractorIndex, 2); // الخيار 2 اتاختار مرتين
  });
}
