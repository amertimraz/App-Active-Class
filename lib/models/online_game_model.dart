// lib/models/online_game_model.dart
//
// الألعاب الإلكترونية (داخل الامتحان الإلكتروني): أسئلة من بنك الأسئلة أو
// من امتحان إلكتروني تتنشر كلعبة بالرابط، والطلاب يلعبوا من الموبايل
// بكودهم، وأفضل نتيجة لكل طالب بتظهر للمدرس في لوحة ترتيب.
//
// ⚠️ عكس الامتحان: مفتاح الإجابة (correctIndex) **بيترفع** مع مستند
// اللعبة — عشان الرد فوري («صح ✓» + الشرح) من غير انتظار سيرفر بين كل
// سؤال. ده مقبول لأن اللعبة للمراجعة والتحفيز مش للتقييم، ومفيش درجة
// بتتسجّل في سجل الطالب. مستندات الألعاب منفصلة تمامًا عن الامتحانات
// (online_exams/{slug}/games/**) فمفيش أي مفتاح إجابة امتحان بيتأثر.
import 'package:active_class/models/bank_question_model.dart';
import 'package:active_class/models/exam_question_model.dart';

/// نوع اللعبة: بيحدد شكل العرض في صفحة الطالب (نفس الأسئلة).
enum OnlineGameType { race, trueFalse, balloons, ladder }

extension OnlineGameTypeX on OnlineGameType {
  /// القيمة المخزّنة في Firestore وبتقراها صفحة الويب.
  String get cloudValue => switch (this) {
        OnlineGameType.race => 'race',
        OnlineGameType.trueFalse => 'true_false',
        OnlineGameType.balloons => 'balloons',
        OnlineGameType.ladder => 'ladder',
      };

  static OnlineGameType fromCloud(String? raw) => switch (raw) {
        'true_false' => OnlineGameType.trueFalse,
        'balloons' => OnlineGameType.balloons,
        'ladder' => OnlineGameType.ladder,
        _ => OnlineGameType.race,
      };

  String get title => switch (this) {
        OnlineGameType.race => 'سباق الأسئلة',
        OnlineGameType.trueFalse => 'صح ولا غلط',
        OnlineGameType.balloons => 'فرقع البالونة',
        OnlineGameType.ladder => 'سلم المليون',
      };

  String get description => switch (this) {
        OnlineGameType.race =>
          'اختيار من متعدد بعدّاد وقت — الأسرع والأدق يكسب نقاط أكتر',
        OnlineGameType.trueFalse => 'جملة وزرّين كبار مع شرح بعد كل سؤال',
        OnlineGameType.balloons =>
          'الإجابات على بالونات طايرة — فرقع البالونة الصح',
        OnlineGameType.ladder =>
          'سؤال بسؤال والنقاط بتزيد — غلطة واحدة وتقف، ومعاك ٥٠:٥٠ وتخطّي',
      };

  /// الوقت الافتراضي للسؤال بالثواني.
  int get defaultSeconds => switch (this) {
        OnlineGameType.race => 20,
        OnlineGameType.trueFalse => 10,
        OnlineGameType.balloons => 15,
        OnlineGameType.ladder => 30,
      };
}

/// حدود وقت السؤال اللي المدرس يقدر يضبطه (ثواني).
const int kGameMinSeconds = 5;
const int kGameMaxSeconds = 120;

/// سؤال داخل لعبة (نسخة مسطّحة من ExamQuestion/BankQuestion).
class GameQuestion {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String? imageUrl;
  final String? explanation;
  final String? explanationImageUrl;
  final List<String?> optionImageUrls;

  const GameQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.imageUrl,
    this.explanation,
    this.explanationImageUrl,
    this.optionImageUrls = const [],
  });

  bool get isValid =>
      text.trim().isNotEmpty &&
      options.length >= 2 &&
      options.length <= 6 &&
      options.every((o) => o.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length;

  factory GameQuestion.fromExam(ExamQuestion q) => GameQuestion(
        text: q.text,
        options: List<String>.of(q.options),
        correctIndex: q.correctIndex,
        imageUrl: q.imageUrl,
        explanation: q.explanation,
        explanationImageUrl: q.explanationImageUrl,
        optionImageUrls: List<String?>.of(q.optionImageUrls),
      );

  factory GameQuestion.fromBank(BankQuestion q) => GameQuestion(
        text: q.text,
        options: List<String>.of(q.options),
        correctIndex: q.correctIndex,
        imageUrl: q.imageUrl,
        explanation: q.explanation,
        explanationImageUrl: q.explanationImageUrl,
        optionImageUrls: List<String?>.of(q.optionImageUrls),
      );

  bool _hasImages(List<String?> l) => l.any((u) => u != null && u.isNotEmpty);

  /// فيه صورة للسؤال أو لأي اختيار (صورة الشرح مش محسوبة) — علامة في المحرّر.
  bool get hasImages =>
      (imageUrl != null && imageUrl!.isNotEmpty) || _hasImages(optionImageUrls);

  Map<String, dynamic> toCloudMap() => {
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        if (explanation != null && explanation!.isNotEmpty)
          'explanation': explanation,
        if (explanationImageUrl != null && explanationImageUrl!.isNotEmpty)
          'explanationImageUrl': explanationImageUrl,
        if (_hasImages(optionImageUrls)) 'optionImageUrls': optionImageUrls,
      };

  factory GameQuestion.fromCloudMap(Map<String, dynamic> m) => GameQuestion(
        text: (m['text'] as String?) ?? '',
        options:
            ((m['options'] as List?) ?? const []).map((e) => '$e').toList(),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
        imageUrl: m['imageUrl'] as String?,
        explanation: m['explanation'] as String?,
        explanationImageUrl: m['explanationImageUrl'] as String?,
        optionImageUrls: ((m['optionImageUrls'] as List?) ?? const [])
            .map((e) => e == null ? null : '$e')
            .toList(),
      );
}

/// لعبة منشورة (كما تُقرأ من Firestore).
class OnlineGame {
  final String id;
  final String title;
  final OnlineGameType type;
  final int secondsPerQuestion;

  /// فاضية = كل الطلاب. غير كده: صفحة اللعبة بتسمح لطلاب المجموعات دي بس
  /// (فحص من جهة الصفحة — لعبة مش امتحان رسمي).
  final List<String> allowedGroupNames;
  final bool open;
  final List<GameQuestion> questions;
  final DateTime? createdAt;

  const OnlineGame({
    required this.id,
    required this.title,
    required this.type,
    required this.secondsPerQuestion,
    required this.allowedGroupNames,
    required this.open,
    required this.questions,
    this.createdAt,
  });

  /// المحتوى اللي بيتكتب في Firestore عند النشر (بدون status/createdAt —
  /// بيضيفهم الـservice).
  static Map<String, dynamic> cloudContent({
    required String title,
    required OnlineGameType type,
    required int secondsPerQuestion,
    required List<String> allowedGroupNames,
    required List<GameQuestion> questions,
  }) =>
      {
        'title': title,
        'gameType': type.cloudValue,
        'secondsPerQuestion': secondsPerQuestion,
        'allowedGroupNames': allowedGroupNames,
        'questionCount': questions.length,
        'questions': questions.map((q) => q.toCloudMap()).toList(),
      };

  factory OnlineGame.fromCloud(String id, Map<String, dynamic> m,
      {DateTime? createdAt}) {
    final type = OnlineGameTypeX.fromCloud(m['gameType'] as String?);
    return OnlineGame(
      id: id,
      title: (m['title'] as String?) ?? 'لعبة',
      type: type,
      secondsPerQuestion:
          (m['secondsPerQuestion'] as num?)?.toInt() ?? type.defaultSeconds,
      allowedGroupNames: ((m['allowedGroupNames'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      open: (m['status'] as String?) != 'closed',
      questions: ((m['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => GameQuestion.fromCloudMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: createdAt,
    );
  }
}

/// أفضل نتيجة لطالب في لعبة.
class GameScore {
  final String code;
  final String name;
  final int score;
  final int correct;
  final int total;

  /// إجمالي وقت الإجابات بالمللي ثانية (للفصل بين المتساويين).
  final int timeMs;
  final DateTime? updatedAt;

  const GameScore({
    required this.code,
    required this.name,
    required this.score,
    required this.correct,
    required this.total,
    required this.timeMs,
    this.updatedAt,
  });

  factory GameScore.fromCloud(Map<String, dynamic> m, {DateTime? updatedAt}) =>
      GameScore(
        code: ((m['code'] as String?) ?? '').trim().toUpperCase(),
        name: (m['name'] as String?) ?? '',
        score: (m['score'] as num?)?.toInt() ?? 0,
        correct: (m['correct'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        timeMs: (m['timeMs'] as num?)?.toInt() ?? 0,
        updatedAt: updatedAt,
      );

  /// ترتيب لوحة الصدارة: النقاط تنازليًا، وعند التساوي الأسرع أولًا.
  static List<GameScore> ranked(Iterable<GameScore> scores) {
    final list = scores.toList();
    list.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.timeMs.compareTo(b.timeMs);
    });
    return list;
  }
}

/// تقسيم نقاط السؤال — نفس المعادلة اللي في صفحة اللعبة (booking_site/game)،
/// متكرّرة هنا عشان تتختبر. [remainingFraction] نسبة الوقت المتبقي (0..1).
///
/// سباق الأسئلة وفرقع البالونة: 500 أساسية + حتى 500 سرعة (1000 كحد أقصى).
/// صح ولا غلط: 100 أساسية + حتى 50 سرعة (150 كحد أقصى).
/// سلم المليون: 100 × (رقم السؤال) + حتى 50 سرعة — [index] يبدأ من 0.
int gameQuestionPoints({
  required OnlineGameType type,
  required bool correct,
  required double remainingFraction,
  int index = 0,
}) {
  if (!correct) return 0;
  final f = remainingFraction.clamp(0.0, 1.0);
  return switch (type) {
    OnlineGameType.race || OnlineGameType.balloons => 500 + (500 * f).round(),
    OnlineGameType.trueFalse => 100 + (50 * f).round(),
    OnlineGameType.ladder => 100 * (index + 1) + (50 * f).round(),
  };
}
