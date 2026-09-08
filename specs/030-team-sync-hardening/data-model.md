# Data Model: تقوية مزامنة وضع الفريق

لا كيانات قاعدة بيانات جديدة. DB version يبقى **28**. لا عمود في `sync_outbox`. لا تغيير خادم/RLS/بروتوكول.

## حالة runtime جديدة داخل `SyncEngine` (كلها في الذاكرة، تُصفَّر بإعادة تشغيل التطبيق)

| الحقل | النوع | الغرض | دورة الحياة |
|---|---|---|---|
| `_outboxFails` | `Map<int, int>` | `outboxId → عدد محاولات الإرسال الفاشلة المتتالية` | يزيد عند فشل `_pushOne`؛ يُحذف المفتاح عند نجاح الإرسال أو حذف صف الطابور |
| `_lastOutboxErr` | `Map<int, String>` | آخر نص خطأ لكل عنصر عالق — للّوج التشخيصي | يُكتَب عند الـcatch؛ يُحذف مع `_outboxFails` |
| `_loggedPoison` | `Set<int>` | معرّفات العناصر اللي اتسجّلت في اللوج كـ"عالقة" — لمنع تكرار السطر | تُضاف عند بلوغ العتبة؛ تُحذف عند نجاح/حذف العنصر |
| `_drainRound` | `int` | عدّاد جولات `drainOutbox` — لتحديد جولة إعادة محاولة العناصر المتخطّاة (كل 20) | `++` كل جولة |
| `_catchUpTimer` | `Timer?` | مؤقّت السحب الدوري كل 50 ثانية | يُنشأ في `start()`، يُلغى في `stop()` |
| `_emptyMembershipStreak` | `int` | عدد نتائج استعلام `team_members` الفاضية المتتالية | `++` على فاضٍ؛ `= 0` على نتيجة صحيحة؛ عند `>= 3` (وجلسة صالحة) → إطلاق الإزالة |
| `_deviceUnboundStreak` | `int` | عدد نتائج "الجهاز غير مرتبط" المتتالية | نفس منطق `_emptyMembershipStreak` لفكّ الجهاز |

## ثوابت (في `sync_retry_policy.dart` أو أعلى `SyncEngine`)

| الثابت | القيمة | المعنى |
|---|---|---|
| `_kMaxOutboxFails` | `5` | بعدها العنصر "متخطّى" في الجولات العادية |
| `_kPoisonRetryEvery` | `20` جولة (≈ 60s عند 3s/جولة) | تواتر محاولة العناصر المتخطّاة |
| `_kCatchUpInterval` | `50s` | فترة السحب الدوري |
| `_kTeamExitStreak` | `3` | نتائج فاضية متتالية قبل تسجيل الخروج (≈ 45s عند فحص كل 15s) |

## دوال نقية (`lib/utils/sync_retry_policy.dart`)

```dart
bool shouldAttemptOutboxRow(int fails, int round,
    {int maxFails = 5, int poisonRetryEvery = 20});

bool shouldFireTeamExit({required bool sessionUsable, required int emptyStreak,
    int threshold = 3});
```

## بدون تأثير

- `sync_outbox` schema/محتوى: يُقرأ ويُحذف كما اليوم — لا صف جديد ولا عمود.
- `_membershipTimer` (15s) و`_pushTimer` (3s): فترتهما بلا تغيير — يتغيّر فقط شرط إطلاق الإجراء داخل الفحوصات.
- جهاز المدرّس (المالك): الكولباكات `null` → `_checkStillAllowed` لا يُشغَّل أصلًا (`if (onRemovedFromTeam != null ...)` عند إنشاء `_membershipTimer`) → عدّادات الـstreak لا تُستخدم عنده. `_catchUpTimer` وتقوية الطابور تعمل عنده.
