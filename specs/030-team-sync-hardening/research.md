# Research: تقوية مزامنة وضع الفريق

## قرار 1 — عدّاد فشل عناصر الطابور: في الذاكرة، لا عمود DB

**القرار**: `final Map<int, int> _outboxFails = {};` (`outboxId → عدد الفشل`) + `final Set<int> _loggedPoison = {};` داخل `SyncEngine`. لا `ALTER TABLE sync_outbox`.

**السبب**: عمود جديد = ترقية نسخة قاعدة (v29) + migration + مزامنة — كل ده لباج تشغيلي. عدّاد الذاكرة يكفي: عنصر مسموم يُعاد تشغيله بضع مرات بعد إعادة فتح التطبيق ثم يُتخطّى ثانيةً — كلفة تافهة، صفر خطر.

**البدائل المرفوضة**: عمود `attempts` مثابر — تعقيد غير مبرّر؛ حذف العنصر بعد N — يفقد بيانات المدرّس نهائيًا لو الفشل مؤقت طويل (FR-006 يمنعه).

---

## قرار 2 — تخطّي العنصر المسموم دون احتكار نافذة الـ50

**القرار**: `drainOutbox` يبني قائمة المعرّفات المتخطّاة `skip = {id : fails >= 5}` ويضيفها للاستعلام: `WHERE synced=0 AND id NOT IN (skip) ORDER BY id ASC LIMIT 50`. كل جولة عدّادها `_drainRound++`؛ كل 20 جولة (≈ دقيقة) يُدرَج المتخطّى في الاستعلام لمحاولة واحدة (`retryPoisonThisRound = _drainRound % 20 == 0`).

**السبب**: `NOT IN` يمنع الصفوف المسمومة من ملء نافذة الـ50، فالصفوف الأحدث تُختار وتُرسَل دائمًا (FR-005). محاولة كل 20 جولة تغطّي حالة "العنصر بقى قابلًا للإرسال" دون إغراق.

**تفصيل**: عند `retryPoisonThisRound`، لا نضيف `NOT IN` أصلًا (نجرّب الكل). عنصر مسموم نجح فجأة → يُحذف ويُنسى.

**البدائل المرفوضة**: رفع `LIMIT` فقط — يؤجّل المشكلة لا يحلّها؛ `ORDER BY fails ASC, id ASC` — `fails` في الذاكرة مش في DB فمينفعش في `ORDER BY`.

---

## قرار 3 — اللوج مرة واحدة

**القرار**: عند وصول عنصر للعتبة (`_outboxFails[id] == 5` بالضبط، أو `>= 5 && !_loggedPoison.contains(id)`) → `debugPrint('SyncEngine: صف عالق بعد 5 محاولات — $table/$rowId — آخر خطأ: $lastErr')` + `_loggedPoison.add(id)`. آخر خطأ يُحفظ في `Map<int,String> _lastOutboxErr` عند الـcatch.

**السبب**: FR-004 / SC-006 — بدون `_loggedPoison`، السطر يتكرر كل 3 ثوانٍ للأبد ويغرق اللوج.

---

## قرار 4 — السحب الدوري: `Timer.periodic` + lifecycle

**القرار**:
- في `start()`: `_catchUpTimer = Timer.periodic(const Duration(seconds: 50), (_) => catchUpPull());`
- `SyncEngine implements WidgetsBindingObserver`؛ في `start()`: `WidgetsBinding.instance.addObserver(this);`؛ `didChangeAppLifecycleState`: `if (state == AppLifecycleState.resumed) unawaited(catchUpPull());`
- في `stop()`: `_catchUpTimer?.cancel(); _catchUpTimer = null; WidgetsBinding.instance.removeObserver(this);`

**السبب**: `catchUpPull` عنده `_lastCatchUp` guard (≥3s) و`_pulling` guard — فالنداءات من (التايمر + Realtime `subscribed` + resume) لا تتكرر. 50s فترة معقولة (SC-002 يطلب ≤60s). يطابق نمط `_pushTimer`/`_membershipTimer`.

**البدائل المرفوضة**: hook من `main.dart` — `main.dart` ملوش مرجع مباشر لـ`_engine` (داخل `TeamModeService` private)؛ إضافة تمرير = تسريب تعقيد. `SyncEngine` يراقب نفسه أنظف.

**ملاحظة**: `catchUpPull` ينادي `_wasRemovedFromTeam` وإخوته — فمع السحب الدوري، الفحص يجري كل 50s كمان (بالإضافة لـ`_membershipTimer` كل 15s). مقبول — نفس منطق الحارس/الـstreak يحميه.

---

## قرار 5 — حارس صلاحية الجلسة + عتبة الـstreak

**القرار**: دالة `bool _sessionUsable()`:
```
final s = client.auth.currentSession;
if (s == null || s.isExpired) {
  unawaited(client.auth.refreshSession().catchError((_) {}));
  return false;
}
return true;
```
`_wasRemovedFromTeam`:
```
if (!_sessionUsable()) { debugPrint('...تخطّي فحص العضوية — جلسة غير صالحة'); return false; }
try {
  final rows = await client.from('team_members').select('user_id')
      .eq('team_id', teamId).eq('user_id', uid).limit(1);
  if ((rows as List).isEmpty) {
    _emptyMembershipStreak++;
    if (_emptyMembershipStreak >= 3) { onRemovedFromTeam?.call(); return true; }
    debugPrint('SyncEngine: عضوية فاضية ($_emptyMembershipStreak/3) — بانتظار تأكيد');
    return false;
  }
  _emptyMembershipStreak = 0;
  return false;
} catch (e) { debugPrint('...فشل التحقق من العضوية — $e'); return false; }
```
نفس النمط لـ`_wasDeviceUnbound` بعدّاد `_deviceUnboundStreak` (عتبة 3). `_wasLicenseDeactivated`: يضيف `if (!_sessionUsable()) return false;` فقط (لا streak — `.single()` يرمي عند الفشل، وحالة "غير نشط" صريحة من الخادم).

**السبب**: FR-011/012/013/014. عتبة 3 على فترة 15s = ~45s (SC-005 يسمح 90s). streak يُصفَّر على أول نتيجة صحيحة → إزالة فعلية (فاضٍ دائم) تُطلَق خلال ~45s.

**البدائل المرفوضة**: عتبة زمنية بدل عدد — أعقد؛ الاعتماد على `refreshSession` المتزامن قبل كل فحص — بطء + احتمال حلقة.

---

## قرار 6 — استخراج المنطق النقي للاختبار

**القرار**: `lib/utils/sync_retry_policy.dart`:
```dart
/// هل نحاول إرسال عنصر عدّاد فشله [fails] في جولة [round]؟
bool shouldAttemptOutboxRow(int fails, int round,
    {int maxFails = 5, int poisonRetryEvery = 20}) =>
  fails < maxFails || round % poisonRetryEvery == 0;

/// هل نطلق إجراء الإزالة/فك-الجهاز؟
bool shouldFireTeamExit({required bool sessionUsable, required int emptyStreak,
    int threshold = 3}) => sessionUsable && emptyStreak >= threshold;
```
`SyncEngine` يستدعيها ويحمل الحالة (الخرائط/العدّادات).

**السبب**: يخلي الجوهر (العتبات) قابلًا للاختبار بلا محاكاة شبكة/Supabase. `SyncEngine` نفسه صعب اختباره (يحتاج `SupabaseClient` حي).

---

## ملخّص الحسم

| # | الموضوع | القرار |
|---|---|---|
| 1 | عدّاد الفشل | `Map` في الذاكرة، لا عمود DB |
| 2 | التخطّي | `WHERE id NOT IN (poison)` + retry كل 20 جولة |
| 3 | اللوج | `Set _loggedPoison` — سطر واحد لكل عنصر |
| 4 | السحب الدوري | `Timer.periodic(50s)` + `WidgetsBindingObserver` في `SyncEngine`، يُلغى في `stop()` |
| 5 | حارس الخروج | `_sessionUsable()` + streak ≥ 3 قبل `onRemovedFromTeam`/`onDeviceUnbound` |
| 6 | الاختبار | دوال نقية في `sync_retry_policy.dart` |
