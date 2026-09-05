# Contract: مرونة Realtime + تنظيف الطابور (US3)

## المشكلة

`_subscribeRealtime()` بيسجّل كل `_tables` على قناة واحدة `team-$teamId`. binding لجدول غير موجود على الخادم / مش في `supabase_realtime` publication → `CHANNEL_ERROR` للقناة كلها → **كل** البثّ اللحظي يقع + `catchUpPull()` (المربوط بـ`subscribed`) ما يتنادىش. (حصل مع `student_follow_ups`، 2026-09-05.)

## الحل: قناتان

```
static const _coreTables = [
  TABLE_GROUPS, TABLE_STUDENTS, TABLE_ATTENDANCE, TABLE_PAYMENTS,
  TABLE_HOMEWORK, TABLE_EXAMS, TABLE_EXAM_GROUPS, TABLE_EXAM_GRADES,
];
static const _extendedTables = [
  TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS,
];
static const _tables = [..._coreTables_ordered_with_questions_inserted...];
// ملاحظة: _tables (للـpull/push) يفضل بالترتيب الصحيح للتبعية
// (exam_questions بعد exams). _coreTables/_extendedTables للـRealtime فقط.
```

`_subscribeRealtime()`:
```
RealtimeChannel? _channel;    // أساسية
RealtimeChannel? _channelX;   // ممتدة

void _subscribeRealtime() {
  _channel = _makeChannel('team-$teamId', _coreTables, driveCatchUp: true);
  _channelX = _makeChannel('team-$teamId-x', _extendedTables, driveCatchUp: true);
}

RealtimeChannel _makeChannel(String name, List<String> tables, {required bool driveCatchUp}) {
  final ch = client.channel(name);
  for (final table in tables) {
    ch.onPostgresChanges(event: ..., schema: 'public', table: table,
        filter: PostgresChangeFilter(type: eq, column: 'team_id', value: teamId),
        callback: (payload) { /* نفس المنطق الحالي */ });
  }
  ch.subscribe((status, error) {
    if (status == RealtimeSubscribeStatus.subscribed && driveCatchUp) {
      unawaited(catchUpPull());
    }
    // CHANNEL_ERROR على _channelX ما بيلمسش _channel — كل قناة معزولة
  });
  return ch;
}
```

- `stop()`: يقفل الاتنين (`_channel?.unsubscribe()` + `_channelX?.unsubscribe()`).
- `catchUpPull()` عنده `_pulling` guard → النداء من القناتين آمن (idempotent).
- لو الخادم ماعندوش `exam_questions`/`exam_submissions` → `_channelX` تدخل `CHANNEL_ERROR`، `_channel` تفضل شغّالة 100%، والواجب/الدرجات بثّهم لحظي طبيعي.

## `_fullPull` — تخطّي جدول ناقص (موجود جزئيًا)

السطور 561–575: كل جدول في `Future.wait` عنده try/catch يرجّع `null` عند الخطأ. **موجود بالفعل** — الجدول الناقص بيرجّع `null` وبيتخطّى في حلقة التطبيق (السطر 580 `if (rows == null ...) continue`). ✅ صفر تغيير مطلوب هنا، بس تأكيد بالاختبار.

## FR-016 — تنظيف طابور الدفع (اتعمل عاجل — يتثبّت)

`_drainOutbox` (commit `3c3e0b2`):
```
if (!_tables.contains(table)) {
  await db.delete(TABLE_SYNC_OUTBOX, where: '$COL_OUTBOX_ID = ?', whereArgs: [outboxId]);
  continue;
}
```
- يتثبّت كجزء من الميزة.
- سيناريو quickstart: صف `student_follow_ups` عالق في الطابور (من نسخة قديمة) → بعد التحديث يُمسح في أول دورة، ما يسدّش رأس الطابور قدّام الواجب/الدرجات.

## معايير القبول

- FR-012..FR-016، SC-005.
- محاكاة: احذف `exam_questions` من الخادم (أو ماتشغّلش migration) → فعّل الفريq → مزامنة الواجب/الحضور/الدرجات (بثّ + تحميل + دفع) تعمل 100%.
- شغّل migration بعدها → `exam_questions`/`exam_submissions` يبدأوا يتزامنوا تلقائيًا (إعادة اتصال القناة الممتدة).
