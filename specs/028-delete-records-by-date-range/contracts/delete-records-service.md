# Contract: دوال `DatabaseService` للحذف بمدى

تُضاف إلى `lib/services/database_service.dart` بجوار `deleteAllData` و`deleteExam`.

## `countDeletableRecordsInRange`

```dart
Future<Map<DeletableRecordType, int>> countDeletableRecordsInRange({
  required DateTime from,   // يُطبَّع لبداية اليوم
  required DateTime to,     // يُحوَّل داخليًا لـ (to + 1 يوم) حصريًا
  required Set<DeletableRecordType> types,
});
```

- لكل نوع مختار: `SELECT COUNT(*) FROM <mainTable> WHERE <dateExpr> >= ? AND <dateExpr> < ?`.
- `examGrades`: `SELECT COUNT(*) FROM exam_grades WHERE exam_id IN (SELECT id FROM exams WHERE date >= ? AND date < ?)`.
- `exams`: عدد صفوف `exams` ضمن المدى (التوابع لا تُعدّ في المعاينة — أو تُعرَض كسطر "+ درجاتها").
- يرجع Map بكل نوع مختار وعدده (حتى لو 0).
- قراءة فقط — صفر كتابة.

## `deleteRecordsInRange`

```dart
Future<Map<DeletableRecordType, int>> deleteRecordsInRange({
  required DateTime from,
  required DateTime to,
  required Set<DeletableRecordType> types,
});
```

**الخطوات**:
1. `final fromIso = DateTime(from.year, from.month, from.day).toIso8601String();`
   `final toIso = DateTime(to.year, to.month, to.day).add(Duration(days: 1)).toIso8601String();`
2. اجمع قوائم `(table, pkCol, id, remoteId)` للصفوف اللي هتتحذف — **قبل** الحذف (لـ`_queueDelete`):
   - لكل نوع مُزامَن مختار: `db.query(mainTable, columns: [pkCol, COL_SYNC_REMOTE_ID], where: dateRange)`.
   - `exams`: بالإضافة، اقرأ صفوف التوابع المرتبطة بامتحانات المدى (`exam_grades`, `exam_groups`, `exam_questions`, `exam_submissions`) مع `remote_id`.
   - `examGrades` المنفصلة: صفوف `exam_grades` بـ`exam_id IN (امتحانات المدى)`.
3. `await db.transaction((txn) async { ... })`:
   - لكل نوع: `txn.delete(mainTable, where: dateRange)` (أو للدرجات/التوابع: `where: exam_id IN (...)` / حسب امتحانات المدى).
   - رتّب: التوابع قبل `exams` نفسها.
   - `report_logs`: `txn.delete(TABLE_REPORT_LOGS, where: 'sent_at >= ? AND sent_at < ?')` — بلا أي queue.
   - احسب `changes` لكل نوع للإرجاع.
4. بعد الـcommit: `_notifyChanged()` + لكل صف مُزامَن جُمِع في خطوة 2: `await _queueDelete(table, id, remoteId)`.
5. رجّع Map الأعداد الفعلية.

**ثوابت لا تُكسر**:
- لا يُحذف صف تاريخه خارج `[fromIso, toIso)` أو نوعه غير مختار.
- **لا** لمس `students` أو `groups` أبدًا.
- الحذف كله في transaction واحدة — خطأ في أي `txn.delete` يرمي ويُلغي الكل (rethrow).
- `_queueDelete` **لا** يُستدعى لـ`report_logs` (يرمي `ArgumentError` في `_pkCol`).
- `_queueDelete` يُستدعى بـ`db` handle بعد الـtransaction لا داخلها.
- في الوضع الفردي، `_queueDelete` → `_queueSync` → `return` فورًا (صفر تكلفة).

## اختبارات (`test/delete_records_range_test.dart`)

بقاعدة sqflite in-memory (`databaseFactoryFfi` أو نمط الاختبارات القائم):

| # | السيناريو | المتوقّع |
|---|---|---|
| 1 | حضور عبر 3 شهور، حذف شهر واحد، نوع "حضور" فقط | صفوف الشهر المختار فقط تُحذف؛ الباقي + الدفعات سليمة |
| 2 | معاينة تطابق عدد الحذف الفعلي | `count(...) == delete(...)` لنفس المدى/النوع |
| 3 | حذف "امتحانات" ضمن مدى | الامتحانات + درجاتها + ربطها بالمجموعات تُحذف |
| 4 | حذف "درجات امتحانات" كنوع منفصل | الدرجات فقط، الامتحانات تبقى |
| 5 | مدى بلا صفوف لأي نوع | Map كله أصفار، لا حذف |
| 6 | تاريخ "من" بعد "إلى" | الاستدعاء يُرفض على مستوى الشاشة قبل الوصول للدالة (منطق `rangeValid`) |
| 7 | حدود المدى شاملة (صف بتاريخ = from 23:00 و صف = to 01:00) | كلاهما يُحذف |
| 8 | `report_logs` ضمن المدى | يُحذف، بلا صف في `sync_outbox` حتى مع `teamModeEnabled` |
