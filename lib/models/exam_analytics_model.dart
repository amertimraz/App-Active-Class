// lib/models/exam_analytics_model.dart
//
// spec 023 — تحليل سؤال واحد في امتحان إلكتروني. كيان محسوب وقت العرض
// (غير مخزَّن) من التسليمات + الأسئلة. التسليمات المُبطَلة مستبعدة قبل
// الحساب (راجع ExamAnalyticsService).
class QuestionAnalytics {
  final int questionId;
  final String questionText;
  final List<String> options;
  final int correctIndex;

  /// عدد الطلاب لكل فهرس خيار (الطول = options.length).
  final List<int> optionCounts;

  /// عدد من أجابوا بأي خيار.
  final int answeredCount;

  /// عدد من تركوا السؤال.
  final int notAnsweredCount;

  /// عدد من أجابوا صح = optionCounts[correctIndex].
  final int correctCount;

  /// إجمالي المستجيبين (تسليمات غير مُبطَلة) = answeredCount + notAnsweredCount.
  final int totalRespondents;

  const QuestionAnalytics({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.optionCounts,
    required this.answeredCount,
    required this.notAnsweredCount,
    required this.correctCount,
    required this.totalRespondents,
  });

  double get correctRate =>
      totalRespondents == 0 ? 0 : correctCount / totalRespondents;

  /// فهرس أكثر اختيار خاطئ شيوعًا (distractor الأبرز)، أو null لو مفيش
  /// أي إجابة خاطئة.
  int? get topDistractorIndex {
    int? best;
    var bestCount = 0;
    for (var i = 0; i < optionCounts.length; i++) {
      if (i == correctIndex) continue;
      if (optionCounts[i] > bestCount) {
        bestCount = optionCounts[i];
        best = i;
      }
    }
    return bestCount > 0 ? best : null;
  }
}
