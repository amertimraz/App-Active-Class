# Contract: `lib/utils/billing_day.dart` (دوال صرفة)

```dart
const int kBillingDayMin = 1;
const int kBillingDayMax = 28;

int clampBillingDay(int? v);   // null/خارج النطاق → 1

DateTime effectiveLastMonthFor({
  required DateTime requested, required DateTime now,
  required bool arrears, required int billingDay,
});

bool withinGraceWindow({
  required DateTime now, required int graceDays,
  required bool arrears, required int billingDay,
});

bool isEarlyInMonthForCollection({
  required DateTime now, required int graceDays,
  required bool arrears, required int billingDay,
});

/// الشهر (اليوم 1) هل "نزل" اشتراكه فعليًا دلوقتي؟ (للكارت)
bool monthHasLanded({
  required DateTime month, required DateTime now,
  required bool arrears, required int billingDay,
});
```

## جدول السلوك (billingDay = 10، grace = 3، مقدّم، أكتوبر)
| اليوم | آخر شهر مستحق | داخل مهلة؟ | الشهر الافتراضي للتحصيل |
|---|---|---|---|
| 5 | سبتمبر | — (الشهر الجاري أصلاً مستبعد) | سبتمبر |
| 10 | أكتوبر | نعم | سبتمبر |
| 12 | أكتوبر | نعم | سبتمبر |
| 13 | أكتوبر | لا (متأخر) | سبتمبر |
| 14 | أكتوبر | لا | سبتمبر |
| 15 | أكتوبر | لا | أكتوبر |

## عند billingDay = 1
مطابق للسلوك الحالي في كل الدوال (يُختبر مباشرة).

## المؤخّر مفعّل
`billingDay` متجاهَل في كل الدوال.
