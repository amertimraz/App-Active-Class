# Phase 1 Data Model: تطويرات الامتحانات 023

## 1. ExamQuestion — حقل `explanation` (US2)

**ملف**: `lib/models/exam_question_model.dart`

| الحقل | النوع | ملاحظات |
|---|---|---|
| `explanation` | `String?` | جديد. شرح اختياري للإجابة الصحيحة. ≤ 500 حرف. NULL/فارغ = لا شرح. |

- `toMap()`: يضيف `COL_EQ_EXPLANATION: explanation`.
- `fromMap()`: `explanation: (m[COL_EQ_EXPLANATION] as String?)?.isNotEmpty == true ? ... : null`.
- `copyWith()`: يضيف `Object? explanation = _unset` (نمط `imageUrl` للتفريق بين "لم يتغيّر" و"صار null").
- `isValid`: **لا يتغيّر** (الشرح اختياري).
- **`toCloudMap()`: لا يتغيّر إطلاقًا** — لا `explanation` ولا `correctIndex` ولا `points`. قيد أمني (FR-010، spec 016 FR-034).

### ترقية قاعدة البيانات (v25 → v26)

**ملف**: `lib/config/constants.dart` + `lib/services/database_service.dart`

```
DATABASE_VERSION: 25 → 26
COL_EQ_EXPLANATION = 'explanation'   // جديد
```

- `_examQuestionsTableSql`: سطر جديد `$COL_EQ_EXPLANATION TEXT,` قبل `created_at`.
- `_onUpgrade`: بلوك جديد
  ```
  if (oldVersion < 26) {
    try {
      await db.execute('ALTER TABLE $TABLE_EXAM_QUESTIONS ADD COLUMN $COL_EQ_EXPLANATION TEXT');
    } catch (_) {}
  }
  ```
- غير مدمّر: أسئلة قديمة → `explanation = NULL`.
- `exam_questions` خارج مزامنة الفريق → صفر Supabase migration، صفر `_queueSync`.

## 2. QuestionResult — حقل `explanation` (US2)

**ملف**: `lib/models/exam_submission_model.dart`

| الحقل | النوع | ملاحظات |
|---|---|---|
| `explanation` | `String?` | جديد. يُنسخ من `ExamQuestion.explanation` وقت بناء نتائج المراجعة. |

- كيان في الذاكرة فقط (يُبنى في `ExamController.questionResults`)، لا يُخزَّن في SQLite.
- ينتقل إلى مستند مراجعة الطالب عبر `publishReview`.

## 3. QuestionAnalytics — كيان محسوب جديد (US3)

**ملف**: `lib/models/exam_analytics_model.dart` (جديد)

| الحقل | النوع | الوصف |
|---|---|---|
| `questionId` | `int` | هوية السؤال المحلية |
| `questionText` | `String` | نص السؤال (للعرض) |
| `options` | `List<String>` | نصوص الاختيارات |
| `correctIndex` | `int` | فهرس الإجابة الصحيحة |
| `optionCounts` | `List<int>` | عدد الطلاب لكل فهرس خيار (طول = options.length) |
| `answeredCount` | `int` | عدد من أجابوا (أي خيار) |
| `notAnsweredCount` | `int` | عدد من تركوا السؤال |
| `correctCount` | `int` | `optionCounts[correctIndex]` |
| `totalRespondents` | `int` | `answeredCount + notAnsweredCount` (تسليمات غير مُبطَلة) |

**مشتقّات (getters)**:
- `double get correctRate` → `totalRespondents == 0 ? 0 : correctCount / totalRespondents`
- `int? get topDistractorIndex` → فهرس أعلى `optionCounts` بين الفهارس ≠ correctIndex وقيمته > 0، وإلا `null`
- كيان غير قابل للتغيير، غير مخزَّن، يُبنى وقت العرض فقط.

## 4. ResultExportRow — تمثيل صف تصدير (US4)

كيان داخلي في `ExportService` (قد يكون `record` أو صنف خاص):

| الحقل | النوع | ملاحظات |
|---|---|---|
| `studentName` | `String` | |
| `studentCode` | `String` | |
| `groupName` | `String?` | للامتحان الورقي متعدد المجموعات فقط |
| `earned` | `double?` | الدرجة المكتسبة؛ null = لم يُدخل/لم يسلّم |
| `maxGrade` | `double` | الدرجة الكلية للامتحان |
| `percent` | `double?` | `earned == null ? null : earned / maxGrade * 100` |
| `status` | `String` | "معتمَد" / "بانتظار الاعتماد" / "لم يسلّم" / "مُبطَل" / "غائب" (ورقي) / "لم يُدخل" |

**قواعد**:
- الطلاب بلا تسليم/درجة يظهرون بصف كامل، خلية درجة فارغة (FR-025).
- المُبطَل يظهر بحالته، لا يُحتسب في أي متوسط/إجمالي داخل الملف (FR-026).

## 5. مستند مراجعة الطالب — توسّع (US2)

**المسار**: `online_exams/{slug}/exams/{examId}/results/{attemptKey}` (Firestore)

بنية `questions[]` الحالية تكسب مفتاحًا:
```
{
  text, options, correctIndex, chosenIndex, points, earned,
  imageUrl?,          // موجود
  explanation?        // جديد — يُضاف فقط لو غير فارغ
}
```

- `allow read: if true` (محمي بـ attemptKey غير القابل للتخمين) — بلا تغيير.
- `allow write: if _oeOwner(slug)` — بلا تغيير.
- **صفر تعديل `firestore.rules`**.

## 6. المستند العام للامتحان — ثابت

`online_exams/{slug}/exams/{examId}` (يقرأه الطالب أثناء الحل): `questions[]` من `toCloudMap()` — **يبقى بلا `correctIndex` ولا `points` ولا `explanation`**. لا تغيير هنا؛ قيد يُتحقَّق في quickstart واختبار.

## الكيانات حسب القصة

| قصة | كيانات |
|---|---|
| US1 معاينة | لا شيء جديد (يقرأ `Exam` + `List<ExamQuestion>` الموجودين) |
| US2 شرح | `ExamQuestion.explanation` + DB v26، `QuestionResult.explanation`, توسّع `results/{attemptKey}` |
| US3 تحليل | `QuestionAnalytics` (محسوب) |
| US4 تصدير | `ResultExportRow` (داخلي)، استعلام `getExamGradesForExport` |
| US5 حذف | لا كيان جديد — يعيد استخدام `deleteExam` (كاسكيد + `_queueDelete`) + توسيع `deleteRemote` بمجموعة `results` |

## 7. حذف الامتحان الإلكتروني (US5)

**لا نموذج/عمود/جدول جديد.** يعتمد على:
- **محليًا**: `DatabaseService.deleteExam(examId)` الموجودة — تحذف `exams` وتترك الكاسكيد (FK `ON DELETE CASCADE`) يمسح `exam_questions` / `exam_submissions` / `exam_grades` / `exam_groups`، ثم `_queueDelete` للصفوف المتزامنة (`exam_grades`, `exam_groups`, `exams`).
- **سحابيًا**: `OnlineExamService.deleteRemote(examId)` — تُوسَّع حلقة المجموعات الفرعية من `['submissions', 'attempts']` إلى `['submissions', 'attempts', 'results']` ثم `examRef.delete()`. best-effort (try/catch + debugPrint).
- **تنسيق**: `ExamController.deleteOnlineExam(examId)` = `deleteRemote` ثم `deleteExam` ثم `loadExams()`.

**Firestore rules**: `submissions`/`attempts`/`results` كلها `allow write/delete: if _oeOwner(slug)` والوثيقة الأم كذلك — **صفر تعديل**.
