# Contract: نسخة جديدة من امتحان (US3)

## `ExamController.duplicateExam(int examId)` — جديد

```
Future<int?> duplicateExam(int examId) async {
  final src = exams.firstWhereOrNull((e) => e.id == examId);
  if (src == null || !src.isOnline) return null;   // v1: إلكتروني فقط
  final newId = await _db.insertExam(
    Exam(
      name: '${src.name} (نسخة)',
      date: DateTime.now(),
      maxGrade: src.maxGrade,
      passingGrade: src.passingGrade,
      reportMonth: src.reportMonth,
    ),
    const [],                // بلا مجموعات
    skipSync: true,
  );
  await _db.setExamOnlineFields(
    newId,
    isOnline: true,
    status: OnlineExamStatus.draft,
    durationMinutes: src.durationMinutes,
    // بلا opensAt/closesAt
  );
  final qs = await _db.getQuestionsForExam(examId);
  await _db.replaceExamQuestions(
    newId,
    qs.map((q) => q.copyWith(id: null, examId: newId)).toList(),
  );
  await loadExams();
  return newId;
}
```

| يُنسخ | لا يُنسخ |
|---|---|
| الاسم + " (نسخة)" | المجموعات (`groupIds = []`) |
| كل الأسئلة (id = null → صفوف جديدة) | `opensAt` / `closesAt` |
| المدة، الدرجة الكلية، درجة النجاح، الشهر | التسليمات، الدرجات، حالة النشر (تبدأ `draft`) |

- `ExamQuestion.copyWith` عنده `id`/`examId` — نمرّر `id: null` و`examId: newId`. `replaceExamQuestions` يعامل `id == null` كـinsert جديد.
- الأسئلة الجديدة تتزامن عبر spec 024 (`replaceExamQuestions` يطابور upsert).

## UI — `online_exams_tab.dart` `_actions(context, status, c)`

- زر `_btn('نسخة جديدة', Icons.copy_all_rounded, () async { final id = await _ec.duplicateExam(exam.id!); if (id != null) { await onChanged(); Get.to(() => OnlineExamEditorPage(existing: <الامتحان الجديد بعد loadExams>)); } })` — في **كل** الحالات (draft/published/stopped/removed).
- يفضّل جلب الامتحان الجديد من `_ec.exams.firstWhere(id == newId)` بعد `loadExams` وتمريره للمحرّر.

## Edge

- امتحان بصفر أسئلة → نسخة بصفر أسئلة، بلا خطأ.
- امتحان بأسئلة كتيرة → النسخ في `replaceExamQuestions` transaction واحدة.
- `src.reportMonth` null → يفضل null في النسخة (بديله شهر التاريخ).

## معايير القبول

- FR-016..FR-021، SC-006.
- نسخة امتحان بـ٥ أسئلة → مسودّة صالحة < ٥ ثوانٍ، تفتح في المحرّر.
- تعديل النسخة لا يمسّ الأصل (عيّنة تعديلات).
- النسخة بلا مجموعات/مواعيد/تسليمات/درجات، حالتها `draft`.
