# Contract: تصدير نتائج الامتحان

## التعداد

```
enum ExportFormat { xlsx, pdf }
```

## ExportService — طرق جديدة (`lib/services/export_service.dart`)

### 1) امتحان إلكتروني

```
Future<ExportResult> exportOnlineExamResults({
  required Exam exam,
  required List<ExamSubmission> submissions,   // مع studentName
  required List<Student> students,             // لتغطية من لم يسلّم
  required ExportFormat format,
});
```

- صف لكل طالب مسجّل في مجموعات `exam.groupIds`:
  - الاسم، الكود، المكتسب (`finalGrade ?? autoScore`)، الكلية (`exam.maxGrade`)، النسبة، الحالة.
  - الحالة من `SubmissionStatus`: `approved`→"معتمَد"، `pending`→"بانتظار الاعتماد"، `voided`→"مُبطَل"، لا تسليم→"لم يسلّم".
- المُبطَل/لم يسلّم: خلية درجة فارغة، لا يُحتسبان في صف "المتوسط".
- صف تذييل: عدد المعتمَد، المتوسط (للمعتمَد فقط)، أعلى.

### 2) امتحان ورقي (كل المجموعات)

```
Future<ExportResult> exportExamGradesSheet({
  required Exam exam,
  required ExportFormat format,
  int? onlyGroupId,     // null = كل مجموعات exam.groupIds
});
```

- يقرأ عبر `DatabaseService.getExamGradesForExport(examId, groupId?)`.
- عمود "المجموعة" يظهر فقط حين `onlyGroupId == null` وعدد المجموعات > 1.
- الغائب → حالة "غائب"، خلية فارغة. لم يُدخل → "لم يُدخل".

## DatabaseService — استعلام جديد

```
Future<List<ResultExportRow>> getExamGradesForExport(int examId, {int? groupId});
```

- JOIN `exam_grades` × `students` × `groups` على الامتحان (وربما LEFT JOIN لإظهار طلاب بلا درجة).
- مرتّب: اسم المجموعة ثم اسم الطالب.
- قراءة فقط، لا مزامنة.

## الملف والمشاركة

- **xlsx**: `excel` package — `Excel.createExcel()`, ورقة واحدة، صف ترويسة عربي، `Share.shareXFiles`.
- **pdf**: نمط `pw.Table` من `exam_grades_page._exportPdf` الحالي (خطوط Cairo، `TextDirection.rtl`).
- اسم الملف: `نتائج_${exam.name}_${yyyy-MM-dd}.{xlsx|pdf}` (تنظيف المحارف غير الصالحة).
- كلاهما يمرّ عبر `ExportResult` (نمط الطرق الحالية) ثم `Share.shareXFiles([XFile(path)])`.

## UI

- **`online_exam_results_page.dart`**: زر `Icons.download_rounded` في AppBar → `showModalBottomSheet` باختيار الصيغة (Excel / PDF) → استدعاء + مشاركة.
- **`exam_grades_page.dart`**: بجانب `_exportPdf` الحالي، عنصر قائمة/زر "تصدير" → اختيار النطاق (هذه المجموعة / كل المجموعات) ثم الصيغة.

## معايير القبول

- FR-023..FR-028، SC-006، SC-007.
- امتحان ٦ طلاب → ٦ صفوف + ترويسة + تذييل؛ من لم يسلّم ظاهر.
- ورقي متعدد المجموعات → كل الطلاب، عمود مجموعة.
- أسماء عربية سليمة في Excel (ترميز UTF-8، لا mojibake).
- المُبطَل غير محتسب في متوسط الملف.
