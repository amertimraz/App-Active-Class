// lib/models/ai_draft_question.dart
//
// spec 057 — سؤال مقترح من الذكاء الاصطناعي (مسودة). بيتحط في محرر الامتحان
// الإلكتروني للمراجعة قبل النشر. correctIndex = -1 معناها «الإجابة لسه مش
// محددة» (في تحويل الورقة بنسيب الإجابة فاضية لو مش معلّمة فيها).
class AiDraftQuestion {
  final String text;
  final List<String> options;
  final int correctIndex; // -1 = غير محددة
  final String explanation;
  final bool needsReview;
  final bool hasFigure;
  final bool duplicate;
  final int? sourcePage;
  final String type; // mcq | true_false

  const AiDraftQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.needsReview = false,
    this.hasFigure = false,
    this.duplicate = false,
    this.sourcePage,
    this.type = 'mcq',
  });

  /// صح/خطأ: اختيارين بالظبط «صح» و«خطأ/غلط».
  bool get looksTrueFalse =>
      type == 'true_false' ||
      options.length == 2 &&
      options[0].trim() == 'صح' &&
      (options[1].trim() == 'خطأ' || options[1].trim() == 'غلط');

  bool get hasAnswer => correctIndex >= 0 && correctIndex < options.length;

  factory AiDraftQuestion.fromJson(Map<String, dynamic> j) {
    final opts = [
      for (final o in (j['options'] as List? ?? const [])) '$o'.trim(),
    ].where((o) => o.isNotEmpty).toList();
    final ci = j['correct_index'];
    return AiDraftQuestion(
      text: '${j['text'] ?? ''}'.trim(),
      options: opts,
      correctIndex: ci is int && ci >= 0 && ci < opts.length ? ci : -1,
      explanation: '${j['explanation'] ?? ''}'.trim(),
      needsReview: j['needs_review'] == true,
      hasFigure: j['has_figure'] == true,
      duplicate: j['duplicate'] == true,
      sourcePage: j['source_page'] is int ? j['source_page'] as int : null,
      type: j['type'] == 'true_false' ? 'true_false' : 'mcq',
    );
  }
}

/// نتيجة عملية ذكية ناجحة.
class AiExamResult {
  final List<AiDraftQuestion> questions;
  final int skipped;
  final List<String> notes;
  const AiExamResult(this.questions, this.skipped, this.notes);

  int get needsReviewCount => questions.where((q) => q.needsReview).length;

  factory AiExamResult.fromJson(Map<String, dynamic> j) => AiExamResult(
        [
          for (final q in (j['questions'] as List? ?? const []))
            AiDraftQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
        ].where((q) => q.text.isNotEmpty && q.options.length >= 2).toList(),
        (j['skipped'] as num?)?.toInt() ?? 0,
        [for (final n in (j['notes'] as List? ?? const [])) '$n'],
      );
}
