# Contract: BankQuestion + جدول bank_questions

## SQLite (v27 → v28)

- جدول جديد `bank_questions` — [data-model.md](../data-model.md) §1. أعمدة المزامنة (`updated_at`, `remote_id`) من الإنشاء.
- `_onCreate` + `if (oldVersion < 28)` في `_onUpgrade`.
- فهرس على `subject`.

## Model — `lib/models/bank_question_model.dart` (جديد)

```
class BankQuestion {
  final int? id;
  final ExamQuestionType type;        // من exam_question_model.dart
  final String text;
  final List<String> options;
  final int correctIndex;
  final double points;
  final String? imageUrl;
  final String? explanation;
  final String subject;               // '' افتراضي
  final List<String> tags;            // [] افتراضي
  final DateTime? createdAt;
}
```

- `isValid`: text غير فارغ + options 2..6 غير فارغة + correctIndex في المدى + points > 0. **subject ليس شرطًا.**
- `toMap()` → أعمدة `bank_questions` (`options`/`tags` = `jsonEncode`).
- `fromMap()` → عكسها (`tags` فارغ/null → `[]`).
- `copyWith({..., Object? imageUrl = _unset, Object? explanation = _unset})`.
- `ExamQuestion toExamQuestion({required int examId, required int position})`.
- `factory BankQuestion.fromExamQuestion(ExamQuestion q, {String subject = '', List<String> tags = const []})`.

## DatabaseService — دوال جديدة

- `Future<List<BankQuestion>> getBankQuestions()`
- `Future<int> insertBankQuestion(BankQuestion q)` → `created_at`+`updated_at` = now، `_queueRowUpsert(TABLE_BANK_QUESTIONS, COL_BQ_ID, id)`
- `Future<void> updateBankQuestion(BankQuestion q)` → `updated_at` = now (بلا لمس `remote_id`/`created_at`)، `_queueRowUpsert`
- `Future<void> deleteBankQuestion(int id)` → جلب `remote_id` → delete → `_queueDelete(TABLE_BANK_QUESTIONS, id, remoteId)`
- `Future<List<String>> distinctSubjects()`

## QuestionBankController — `lib/controllers/question_bank_controller.dart` (جديد)

```
class QuestionBankController extends GetxController {
  final RxList<BankQuestion> _all = <BankQuestion>[].obs;
  final RxnString subjectFilter = RxnString();
  final RxnString tagFilter = RxnString();
  final RxString query = ''.obs;

  List<BankQuestion> get items => _filtered();   // يطبّق subject + tag + query نصّي
  List<String> get subjects;                     // DISTINCT من _all
  List<String> get tags;                         // اتحاد كل q.tags
  int get count => _all.length;

  @override Future<void> refresh();               // _db.getBankQuestions() → _all
  Future<void> add(BankQuestion q);
  Future<void> save(BankQuestion q);              // update
  Future<void> remove(int id);
}
```
- `refresh()` `@override` (زي `AtRiskController`/`DashboardController`).
- الفلترة والبحث كلها في الذاكرة (R3).

## معايير القبول

- FR-001..FR-008، SC-003، SC-005.
- إضافة/تعديل/حذف يبقى بعد إغلاق التطبيق.
- بحث/فلتر بمادة/وسم → نتائج صحيحة، إزالة الفلتر تُرجع الكل.
- ترقية من v27: قاعدة موجودة تُفتح، الجدول يُنشأ، صفر تأثير على جداول أخرى.
