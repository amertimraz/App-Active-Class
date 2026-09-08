# Contract: سياسة إعادة محاولة طابور الإرسال

## `lib/utils/sync_retry_policy.dart` (جديد)

```dart
/// هل نحاول إرسال عنصر طابور عدّاد فشله [fails] في جولة [round]؟
/// - أقل من [maxFails] → دايمًا نحاول.
/// - بلغ/تجاوز [maxFails] (متخطّى) → نحاول فقط كل [poisonRetryEvery] جولة.
bool shouldAttemptOutboxRow(int fails, int round,
    {int maxFails = 5, int poisonRetryEvery = 20}) {
  if (fails < maxFails) return true;
  return round % poisonRetryEvery == 0;
}
```

## تعديل `SyncEngine.drainOutbox`

```dart
Future<void> drainOutbox() async {
  if (_draining) return;
  _draining = true;
  _drainRound++;
  try {
    final db = await _dbService.database;
    final poison = _outboxFails.entries
        .where((e) => e.value >= _kMaxOutboxFails)
        .map((e) => e.key)
        .toList();
    final retryPoison = _drainRound % _kPoisonRetryEvery == 0;

    final where = StringBuffer('$COL_OUTBOX_SYNCED = 0');
    if (poison.isNotEmpty && !retryPoison) {
      where.write(' AND $COL_OUTBOX_ID NOT IN (${poison.join(',')})');
    }
    final rows = await db.query(TABLE_SYNC_OUTBOX,
        where: where.toString(),
        orderBy: '$COL_OUTBOX_ID ASC', limit: 50);

    for (final row in rows) {
      final outboxId = row[COL_OUTBOX_ID] as int;
      final table = row[COL_OUTBOX_TABLE] as String;
      final rowId = row[COL_OUTBOX_ROW_ID] as int;
      // ... op / payloadStr كما اليوم ...

      if (!_tables.contains(table)) {
        await db.delete(TABLE_SYNC_OUTBOX, where: '$COL_OUTBOX_ID = ?', whereArgs: [outboxId]);
        _forgetOutbox(outboxId);
        continue;
      }
      try {
        final done = await _pushOne(table, rowId, op, payloadStr);
        if (done) {
          await db.delete(TABLE_SYNC_OUTBOX, where: '$COL_OUTBOX_ID = ?', whereArgs: [outboxId]);
          _forgetOutbox(outboxId);
        } else {
          _recordOutboxFail(outboxId, table, rowId, 'الأب لسه بلا remote_id');
        }
      } catch (e) {
        _recordOutboxFail(outboxId, table, rowId, e.toString());
        debugPrint('SyncEngine: فشل push لـ $table/$rowId — $e');
      }
    }
  } finally {
    _draining = false;
  }
}

void _recordOutboxFail(int id, String table, int rowId, String err) {
  final n = (_outboxFails[id] ?? 0) + 1;
  _outboxFails[id] = n;
  _lastOutboxErr[id] = err;
  if (n >= _kMaxOutboxFails && _loggedPoison.add(id)) {
    debugPrint('SyncEngine: ⚠️ صف عالق بعد $n محاولات — $table/$rowId — آخر خطأ: $err');
  }
}

void _forgetOutbox(int id) {
  _outboxFails.remove(id);
  _lastOutboxErr.remove(id);
  _loggedPoison.remove(id);
}
```

## ثوابت لا تُكسر

- عنصر واحد فاشل دائمًا **لا** يمنع أي عنصر أحدث من الوصول (FR-005) — لأنه يُستبعَد من `NOT IN` في الجولات العادية.
- عنصر نجح إرساله → يُحذف من DB **و** من كل خرائط الحالة (لا تسريب ذاكرة).
- العنصر المسموم **لا** يُحذف من `sync_outbox` (FR-006) — يظل للتشخيص وإعادة المحاولة كل 20 جولة.
- اللوج التشخيصي سطر واحد لكل عنصر (FR-004) — `_loggedPoison` يمنع التكرار.
- `_forgetOutbox` يُستدعى أيضًا لعناصر الجداول المشالة (`!_tables.contains`).

## اختبارات (`test/sync_retry_policy_test.dart`)

| # | `shouldAttemptOutboxRow` | المتوقّع |
|---|---|---|
| 1 | `fails=0, round=7` | true |
| 2 | `fails=4, round=7` | true (تحت العتبة) |
| 3 | `fails=5, round=7` | false (متخطّى، مش جولة retry) |
| 4 | `fails=5, round=20` | true (جولة retry) |
| 5 | `fails=99, round=40` | true (كل مضاعف 20) |
| 6 | `fails=5, round=0` | true (0 % 20 == 0) |
