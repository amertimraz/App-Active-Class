// lib/services/exam_analytics_service.dart
//
// spec 023 — محرك تحليل أسئلة الامتحان الإلكتروني. Dart نقي (بلا Flutter
// ولا DB) — قابل للاختبار مباشرة، نفس فلسفة AtRiskService.
import 'package:active_class/models/exam_analytics_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/models/exam_submission_model.dart';

class ExamAnalyticsService {
  /// لكل سؤال: نسبة الصح، توزيع الاختيارات، وعدد من لم يجب — محسوبة من
  /// التسليمات **غير المُبطَلة** فقط. التجميع بهوية السؤال (q.id) لا
  /// بترتيب العرض. أسئلة بلا id تُتخطّى.
  static List<QuestionAnalytics> compute({
    required List<ExamQuestion> questions,
    required List<ExamSubmission> submissions,
  }) {
    final valid = submissions
        .where((s) => s.status != SubmissionStatus.voided)
        .toList();

    final out = <QuestionAnalytics>[];
    for (final q in questions) {
      final qid = q.id;
      if (qid == null) continue;

      final counts = List<int>.filled(q.options.length, 0);
      var answered = 0;
      var notAnswered = 0;

      for (final s in valid) {
        final idx = s.answers[qid];
        if (idx == null || idx < 0 || idx >= counts.length) {
          notAnswered++;
        } else {
          counts[idx]++;
          answered++;
        }
      }

      final ci = q.correctIndex;
      final correctCount =
          (ci >= 0 && ci < counts.length) ? counts[ci] : 0;

      out.add(QuestionAnalytics(
        questionId: qid,
        questionText: q.text,
        options: q.options,
        correctIndex: ci,
        optionCounts: counts,
        answeredCount: answered,
        notAnsweredCount: notAnswered,
        correctCount: correctCount,
        totalRespondents: answered + notAnswered,
      ));
    }
    return out;
  }
}
