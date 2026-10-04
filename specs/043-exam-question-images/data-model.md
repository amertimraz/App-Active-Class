# Phase 1 Data Model: صور أسئلة الامتحان

## SQLite (محلي، DB v36)

### `exam_questions` (تعديل — عمودان جديدان)
| العمود | النوع | ملاحظة |
|---|---|---|
| `explanation_image_url` | TEXT NULL | محلي فقط — **لا** يدخل `toCloudMap`؛ يصل الطالب عبر `publishReview` بعد الاعتماد بس (زي `explanation`) |
| `option_image_urls` | TEXT NULL | JSON لقائمة `String?` بنفس طول وترتيب `options` (`jsonEncode`/`jsonDecode` زي `options` نفسها) |

### `bank_questions` (تعديل — نفس العمودين)
نفس التعريف بالظبط، لنفس السبب (FR-012 — سؤال من البنك يحتفظ بكل صوره).

## Postgres (Supabase)
`exam_questions` و`bank_questions`: نفس العمودين (`explanation_image_url text`, `option_image_urls text`) — إضافة idempotent عبر `alter table ... add column if not exists`، بلا أي تغيير في RLS/triggers الحالية (الأعمدة الجديدة تتبع نفس صلاحيات الصف).

## الكيانات في Dart

### `ExamQuestion` / `BankQuestion` (كلاهما بنفس الإضافة)
```dart
final String? explanationImageUrl;   // محلي فقط (زي explanation)
final List<String?> optionImageUrls; // نفس طول options، عنصر null = بلا صورة
```
- `toMap()`: `COL_EQ_EXPLANATION_IMAGE_URL`, `COL_EQ_OPTION_IMAGE_URLS: jsonEncode(optionImageUrls)`.
- `fromMap()`: فك JSON، ولو العمود فاضي/قديم (صف قبل الترقية) → قائمة بطول `options.length` كلها null.
- `copyWith`: نفس نمط `_unset` sentinel المستخدم لـ`imageUrl`/`explanation` حاليًا.
- `isValid`: لا تغيير (الصور دايمًا اختيارية).
- `toCloudMap()`: يضيف `optionImageUrls` (القائمة كاملة، أو تُحذف المفتاح لو كل العناصر null) — **لا** يضيف `explanationImageUrl`.

### `QuestionResult` (`lib/models/exam_submission_model.dart`)
```dart
final String? explanationImageUrl;
final List<String?> optionImageUrls;
```
يُمرَّران من `ExamController.questionResults()` (من `ExamQuestion` المحلي) إلى `OnlineExamService.publishReview()` → مستند `results/{attemptKey}` (المفتاحان الجديدان `optionImageUrls`/`explanationImageUrl`، نفس شرط "لو مش فاضي" المستخدَم حاليًا لـ`imageUrl`/`explanation`).

## قواعد التزامن بين `options` و`optionImageUrls`
- إضافة اختيار جديد في المحرّر → `optionImageUrls.add(null)` في نفس اللحظة.
- حذف اختيار بالـindex `k` → `optionImageUrls.removeAt(k)` في نفس اللحظة (FR-007).
- تحميل سؤال قديم (قبل الترقية، `option_image_urls` فاضي) → تُبنى قائمة null بطول `options.length` تلقائيًا عند القراءة، فمفيش IndexOutOfRange أبدًا.
