# Phase 1 Data Model: يوم نزول المديونية

**لا تغيير في SQLite ولا Supabase.**

## Setting (محلي، جدول `app_settings`)
| المفتاح | القيمة | افتراضي |
|---|---|---|
| `billing_day` | نص رقم صحيح 1..28 | غير موجود = 1 |

## State
- `SettingsController.billingDay` (`RxInt`، 1..28).
- `PricingHelper.billingDay` (static int) — بيتنسخ منه عند التحميل والتغيير.

## قواعد
- أي قيمة خارج 1..28 أو غير رقمية تُعامَل 1.
- المؤخّر مفعّل ⇒ القيمة محفوظة لكن لا تُستخدم (ولا تُمسح).
