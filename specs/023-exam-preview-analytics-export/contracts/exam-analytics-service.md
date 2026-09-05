# Contract: ExamAnalyticsService (تحليل الأسئلة)

## الخدمة — `lib/services/exam_analytics_service.dart` (جديد، Dart نقي)

```
class ExamAnalyticsService {
  static List<QuestionAnalytics> compute({
    required List<ExamQuestion> questions,
    required List<ExamSubmission> submissions,
  });
}
```

### السلوك

1. `valid = submissions.where((s) => s.status != SubmissionStatus.voided)`.
   - (يُستبعد أيضًا `notSubmitted` — لا `answers`.)
2. لكل `q` في `questions` (بترتيبها):
   - `counts = List.filled(q.options.length, 0)`
   - `answered = 0`, `notAnswered = 0`
   - لكل `s` في `valid`:
     - `idx = s.answers[q.id]`
     - `idx == null || idx < 0 || idx >= counts.length` → `notAnswered++`
     - وإلا → `counts[idx]++`, `answered++`
   - `correctCount = counts[q.correctIndex]` (بحدود آمنة)
   - يُنشئ `QuestionAnalytics(questionId: q.id!, questionText: q.text, options: q.options, correctIndex: q.correctIndex, optionCounts: counts, answeredCount: answered, notAnsweredCount: notAnswered, correctCount: correctCount, totalRespondents: answered + notAnswered)`
3. يُرجع القائمة بنفس ترتيب `questions`.

### حواف

- `valid` فارغة → تُرجع قائمة بكل الأسئلة بـ`totalRespondents = 0` (الشاشة تعرض رسالة "لا توجد تسليمات كافية").
- سؤال بلا `id` → يُتخطّى (لا يُفترض حدوثه لأسئلة منشورة).
- `q.correctIndex` خارج المدى → `correctCount = 0` (لا رمي استثناء).

## الشاشة — `lib/views/exams/exam_analytics_page.dart` (جديد)

- تُفتح عبر `Get.to(() => ExamAnalyticsPage(exam: exam))` من أيقونة `Icons.insights_rounded` في AppBar لـ`OnlineExamResultsPage`.
- تحمّل: `_db.getQuestionsForExam(examId)` + `_db.getSubmissionsForExam(examId)` → `ExamAnalyticsService.compute(...)`.
- لكل `QuestionAnalytics` كارت:
  - رقم + نص السؤال
  - شريط/نسبة: `${(correctRate*100).round()}% صح (${correctCount}/${totalRespondents})`
  - صفوف الاختيارات: نص الخيار + عدد؛ الصحيح بخلفية خضراء + ✓؛ `topDistractorIndex` بحدّ أحمر/تحذيري
  - سطر ختامي: `لم يجب: ${notAnsweredCount}`
- ترويسة الصفحة: عدد التسليمات المُحلَّلة، أضعف سؤال (أقل `correctRate`).
- `totalRespondents == 0` لكل الأسئلة → رسالة فارغة موحّدة.

## الاختبار — `test/exam_analytics_service_test.dart` (جديد)

- ٥ تسليمات على ٣ أسئلة، حساب يدوي معروف → يطابق `optionCounts`/`correctCount`/`notAnsweredCount`.
- تسليم واحد `voided` → مستبعد من كل الأعداد.
- سؤال كل الإجابات صحيحة → `topDistractorIndex == null`, `correctRate == 1.0`.
- سؤال بلا إجابات (كلهم تركوه) → `notAnsweredCount == valid.length`, `correctRate == 0`.
- إجابات بترتيب مختلط محفوظة بـ`questionId` → التجميع صحيح (المفاتيح هي id لا الموضع).
- `submissions` فارغة → قائمة بكل الأسئلة، `totalRespondents == 0`.

## معايير القبول

- SC-004: تحديد أضعف ٣ أسئلة من الشاشة < دقيقة.
- SC-005: مطابقة الحساب اليدوي على ٥ تسليمات مع استبعاد المُبطَل.
