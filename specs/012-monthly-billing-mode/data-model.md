# Data Model: نظام تحصيل الاشتراك الشهري

**Feature**: 012-monthly-billing-mode | **Date**: 2026-09-01

## 1. إعدادان جديدان في `app_settings` (لا migration)

| المفتاح | النوع المنطقي | افتراضي | القيم | الأثر |
|---------|--------------|---------|------|-------|
| `billing_arrears` | bool (`'1'`/`'0'`) | `false` (مقدّم) | مقدّم / مؤخّر | في "مؤخّر" الشهر الجاري مستثنى من المستحق لحد ما يخلص |
| `prorate_first_month` | bool (`'1'`/`'0'`) | `false` | مفعّل / مطفي | شهر الانضمام يُحسب نسبيًا |

ثوابت المفاتيح في `constants.dart`:
```
const String SETTING_BILLING_ARREARS = 'billing_arrears';
const String SETTING_PRORATE_FIRST_MONTH = 'prorate_first_month';
```

## 2. `SettingsController`

```
final RxBool billingArrears = false.obs;
final RxBool prorateFirstMonth = false.obs;

// في reloadFromDatabase() → Future.wait([... _loadBillingSettings()])
Future<void> _loadBillingSettings() async {
  billingArrears.value = await _migrateBool(SETTING_BILLING_ARREARS) ?? false;
  prorateFirstMonth.value = await _migrateBool(SETTING_PRORATE_FIRST_MONTH) ?? false;
  _applyToPricingHelper();
}

void _applyToPricingHelper() {
  PricingHelper.billingArrears = billingArrears.value;
  PricingHelper.prorateFirstMonth = prorateFirstMonth.value;
}

Future<void> setBillingArrears(bool v) async {
  billingArrears.value = v;
  _applyToPricingHelper();
  await _dbSet(SETTING_BILLING_ARREARS, v ? '1' : '0');
}
// نفس الشيء لـ setProrateFirstMonth
```

> `_applyToPricingHelper()` يُستدعى كمان مرة واحدة عند إقلاع التطبيق (main.dart بعد تحميل
> الإعدادات) — تأمين لو `PricingHelper` اتنادى قبل ما الإعدادات تتحمّل (يفضل بالافتراضي `false`).

## 3. `PricingHelper` — الحقول والمعادلات

### حقول static (نمط `DatabaseService.teamModeEnabled`)
```
static bool billingArrears = false;
static bool prorateFirstMonth = false;
```

### أ) الحساب النسبي — جوّه `monthlyDue`

بعد حساب `base` العادي، **قبل** `return base * (1 - exempt/100)`، وبس للطلاب الشهري
(مش `group.isPerSession`، مش `isFullyExempt` — دول بيرجعوا قبل الفرع):

```
if (prorateFirstMonth) {
  final start = student.attendanceStart ?? student.createdAt;
  if (start != null &&
      start.year == month.year && start.month == month.month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day; // 28..31
    final daysCovered = daysInMonth - start.day + 1;
    final ratio = (daysCovered / 30).clamp(0.0, 1.0);
    base = _roundTo5(base * ratio);
  }
}

static double _roundTo5(double x) => (x / 5).round() * 5.0;
```

مثال: start 15/8، base 100 → daysInMonth 31 → daysCovered 17 → ratio 17/30=0.567
→ 56.7 → `_roundTo5` → **55**.

### ب) "مؤخّر" — تقييد آخر شهر

helper:
```
static DateTime _effectiveLastMonth(DateTime requested) {
  if (!billingArrears) return DateTime(requested.year, requested.month, 1);
  final now = DateTime.now();
  final lastComplete = DateTime(now.year, now.month - 1, 1); // آخر شهر مكتمل
  final req = DateTime(requested.year, requested.month, 1);
  return req.isBefore(lastComplete) ? req : lastComplete;
}
```

- `totalDueThrough`: `final lastMonth = _effectiveLastMonth(month);` (بدل `DateTime(month.year, month.month, 1)`).
  - لو `cursor.isAfter(lastMonth)` → `return 0` (طالب انضم الشهر ده في "مؤخّر" → صفر).
- `_remainingThrough`: بيمرّر `lastMonth` لـ`totalDueThrough` — يستخدم `_effectiveLastMonth(lastMonth)`
  كمان (تقييد مزدوج آمن؛ `_effectiveLastMonth` idempotent).
- `isOverdue`: **مفيش تغيير مطلوب** — بينادي `_remainingThrough` → `totalDueThrough` اللي
  بيطبّق `_effectiveLastMonth` وبيقيّد لـ`الشهر الحالي − 1` في "مؤخّر" تلقائيًا (سواء
  `withinGrace` أو لأ). في وضع "مقدّم" السلوك زي ما هو.

### التوليفات الأربع (طالب انضم 15/8، شهر 100، اليوم 1/9، مدفوع 0)

| مقدّم/مؤخّر | نسبي | مستحق أغسطس | مستحق سبتمبر | الإجمالي |
|------------|------|-------------|--------------|----------|
| مقدّم | مطفي | 100 | 100 | **200** (السلوك الحالي) |
| مؤخّر | مطفي | 100 | — (لسه مخلصش) | **100** |
| مقدّم | مفعّل | 55 | 100 | **155** |
| مؤخّر | مفعّل | 55 | — | **55** |

## 4. شاشة الدفع — `qr_controller._oldestUnpaidMonth`

**مفيش تغيير مطلوب.**
- الحلقة بتجمّع `monthlyDue` → بقت نسبية تلقائيًا (مستحق شهر الانضمام = القيمة المخفّضة).
- `autoSelect = start.isBefore(nowMonth)` (v1.2.33) → الشهر الحالي **مش** بيتختار تلقائيًا
  أصلاً، فسلوك "مؤخّر" (المدرس يقرر يحصّل الشهر الحالي) متحقّق بالفعل.
- "المتبقّي عليه" المعروض في الشاشة بييجي من `PricingHelper.accumulatedDebt` (بقى arrears-aware)
  → الرقم والاختيار الافتراضي متطابقين.

**مهمة تحقّق فقط**: تأكيد إن شاشة الدفع بتعرض نفس رقم "المتبقّي" مع التوليفات الأربع.

## 5. بوابة أولياء الأمور

- `parent_portal_service._buildSummaryData`: أضف
  ```
  'remaining': PricingHelper.accumulatedDebt(
      student: student, group: group,
      allAttendance: attendance, payments: payments,
      siblingGroupMembers: <كل الطلاب>),
  ```
  (بياخد الإعدادين من الحقول static تلقائيًا).
- `booking_site/track/index.html`: `const remaining = (typeof d.remaining === 'number')
  ? Math.max(0, d.remaining) : Math.max(0, effectivePrice - totalPaid);` — توافق خلفي.

## 6. وضع الفريق

`app_settings` مش بيتزامن → الإعدادين لكل جهاز. جهاز المساعد يظبطهم يدويًا زي المالك
(نفس وضع `payment_grace_days`). **مفيش شغل — توثيق بس.**
