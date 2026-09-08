# Contract: توفيق الصف المكرّر في `_applyRemoteRow`

## `lib/utils/sync_conflict.dart` (جديد)

```dart
/// هل الصف الوارد (من جهاز آخر) يفوز على صف محلي مكرّر منطقيًا؟
/// - وقت وارد أحدث → true.  - أقدم → false.
/// - تعادل → الصف صاحب remote_id الأصغر معجميًا يفوز (حسم ثابت لكل الأجهزة).
bool syncConflictIncomingWins({
  DateTime? localUpdatedAt,
  DateTime? remoteUpdatedAt,
  required String localRemoteId,
  required String remoteRemoteId,
}) {
  if (remoteUpdatedAt == null) return false;
  if (localUpdatedAt == null) return true;
  final cmp = remoteUpdatedAt.compareTo(localUpdatedAt);
  if (cmp != 0) return cmp > 0;
  return remoteRemoteId.compareTo(localRemoteId) < 0;
}
```

## تعديل `_applyRemoteRow` — استبدال كل كتلة dup

**قبل** (× 5):
```dart
if (dup.isNotEmpty) {
  debugPrint('SyncEngine: تجاهل صف ... مكرر وارد من جهاز تاني');
  return;
}
```

**بعد** — دالة موحّدة:
```dart
/// وُجد صف محلي [dup] يطابق منطقيًا الصف الوارد لكن بمعرّف مزامنة مختلف.
/// نطبّق LWW على البيانات (نحتفظ بـ remote_id المحلي — لا نغيّره).
Future<void> _reconcileDuplicate(
  DatabaseExecutor db,
  String table,
  String pkCol,
  Map<String, Object?> dupRow,
  Map<String, dynamic> remote,
  Map<String, dynamic> localMap,   // من _toLocalMap(remote)
) async {
  final localUpdatedAt = DateTime.tryParse(
      dupRow[COL_SYNC_UPDATED_AT] as String? ?? '');
  final remoteUpdatedAt = DateTime.tryParse(remote['updated_at'] as String? ?? '');
  final localRemoteId = dupRow[COL_SYNC_REMOTE_ID] as String? ?? '';
  final remoteRemoteId = remote['id'] as String;

  final wins = syncConflictIncomingWins(
    localUpdatedAt: localUpdatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
    localRemoteId: localRemoteId,
    remoteRemoteId: remoteRemoteId,
  );
  if (!wins) {
    debugPrint('SyncEngine: صف مكرر وارد أقدم/خاسر — إبقاء المحلي ($table)');
    return;
  }
  // نحدّث حقول البيانات فقط — نحذف remote_id من الماب عشان نحتفظ بمعرّف
  // الصف المحلي (تغييره بيربك دفعات outbox اللاحقة).
  final data = Map<String, Object?>.from(localMap)..remove(COL_SYNC_REMOTE_ID);
  await db.update(table, data,
      where: '$pkCol = ?', whereArgs: [dupRow[pkCol]]);
  debugPrint('SyncEngine: توفيق صف مكرر — طُبِّق الوارد الأحدث ($table)');
}
```

في كل كتلة dup: تُقرأ صفوف الـdup **بكل الأعمدة** (`db.query(table, where: ...)` بلا `columns:` أو مع `[pkCol, COL_SYNC_REMOTE_ID, COL_SYNC_UPDATED_AT]`)، ثم:
```dart
if (dup.isNotEmpty) {
  await _reconcileDuplicate(db, table, pkCol, dup.first, remote, localMap);
  return;
}
```

**الكتل الخمس**: `TABLE_ATTENDANCE`, `TABLE_HOMEWORK`, `TABLE_EXAM_GROUPS`, `TABLE_EXAM_GRADES`, `TABLE_EXAM_SUBMISSIONS`.

## ثوابت لا تُكسر

- **`remote_id` المحلي للصف المكرّر لا يتغيّر أبدًا** — فقط حقول البيانات.
- لو الوارد أقدم → صفر تعديل (المحلي يبقى).
- تعادل الطوابع → نفس القرار على كل الأجهزة (tie-break معجمي).
- لا `return` صامت بدون تطبيق LWW.
- `groups`/`students`/`payments`/`exams` — لا كتل dup لها، غير متأثّرة.
- الصف "الخاسر" على الخادم يظل يعيد البثّ؛ كل بثّة تُعيد التوفيق فتبقى النتيجة ثابتة (لا حلقة، `db.update` idempotent على نفس البيانات).

## اختبارات (`test/sync_conflict_test.dart`)

| # | localUpdatedAt | remoteUpdatedAt | localRemoteId | remoteRemoteId | المتوقّع |
|---|---|---|---|---|---|
| 1 | 12:00 | 12:05 | "b" | "a" | true (وارد أحدث) |
| 2 | 12:05 | 12:00 | "a" | "b" | false (وارد أقدم) |
| 3 | 12:00 | 12:00 | "b" | "a" | true (تعادل، "a" < "b") |
| 4 | 12:00 | 12:00 | "a" | "b" | false (تعادل، محلي أصغر) |
| 5 | null | 12:00 | "x" | "y" | true (محلي بلا وقت) |
| 6 | 12:00 | null | "x" | "y" | false (وارد بلا وقت) |
