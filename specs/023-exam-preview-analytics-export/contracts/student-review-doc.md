# Contract: مستند مراجعة الطالب — توسّع + قيد المستند العام

## المستند العام (يقرأه الطالب أثناء الحل) — ثابت

`online_exams/{slug}/exams/{examId}` — حقل `questions[]` مبني من `ExamQuestion.toCloudMap()`:

```
{ id: "q{localId}", type, text, options, imageUrl? }
```

**قيد صارم (لا يتغيّر)**: بلا `correctIndex`، بلا `points`، بلا `explanation`. يسري على:
- النشر الأول (`publish` / `set`)
- إعادة نشر سؤال بعد التعديل (`republishQuestions` / partial `update`, spec 022)

اختبار وحدة يفرض: `toCloudMap().keys` ⊆ `{id, type, text, options, imageUrl}`.

## مستند مراجعة الطالب — بعد الاعتماد فقط

`online_exams/{slug}/exams/{examId}/results/{attemptKey}` — يكتبه `publishReview` عند اعتماد المدرس:

```
{
  grade, maxGrade, approvedAt,
  questions: [
    {
      text, options,
      correctIndex, chosenIndex, points, earned,
      imageUrl?,        // إن وُجد
      explanation?      // جديد — يُضاف فقط إن غير فارغ
    }
  ]
}
```

- `attemptKey = {studentCode}_{last4(guardianPhone)}` — غير قابل للتخمين.
- `firestore.rules`: `results/{docId}` → `allow read: if true; allow write: if _oeOwner(slug);` — **بلا تغيير**.

## تدفّق الحقل

```
محرّر السؤال → ExamQuestion.explanation → SQLite (COL_EQ_EXPLANATION)
  → ExamController.questionResults() → QuestionResult.explanation
  → OnlineExamService.publishReview() → results/{attemptKey}.questions[].explanation
  → booking_site/exam/index.html renderReview() → <div class="rexpl">
```

## الويب — عرض

- `renderReview(questions)` يعرض `q.explanation` (إن وُجد) بعد صفوف الاختيارات، قبل `rfoot`.
- الأسئلة بلا شرح: لا عنصر في DOM.
- بعد التعديل: نشر `booking_site/exam/index.html` إلى VPS + تحقّق `curl` (بحث عن `rexpl` و`q.explanation`).

## معايير القبول

- FR-010, FR-011, FR-012, FR-013.
- SC-002: صفر تسريب للشرح/الإجابة في المستند العام (فحص عيّنة).
- SC-003: ١٠٠٪ من الأسئلة ذات الشرح تُظهره بعد الاعتماد.
