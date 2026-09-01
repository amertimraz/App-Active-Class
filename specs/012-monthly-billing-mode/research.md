# Research: نظام تحصيل الاشتراك الشهري

**Feature**: 012-monthly-billing-mode | **Date**: 2026-09-01

## جرد الوضع الحالي

### `lib/utils/pricing_helper.dart` — نقطة الحقيقة الوحيدة

كل حسابات المستحق/المديونية بتمرّ من هنا:

| دالة | بتعمل إيه | المتصلين |
|------|-----------|----------|
| `monthlyDue(student, group, month, ...)` | مستحق شهر واحد. شهري → `student.price × (1-exempt)`؛ إخوة → `siblingsTotal/count`؛ بالحصة → `price × حصص محضورة` | `totalDueThrough`، `qr_controller`، `report_controller` |
| `totalDueThrough(student, group, month, ...)` | يلفّ من شهر `attendanceStart ?? createdAt` لحد `month` (شامل)، يجمع `monthlyDue` لكل شهر | `_remainingThrough`، `report_controller`، `qr_controller` |
| `_remainingThrough(..., lastMonth)` | `totalDueThrough(lastMonth) − Σ(كل الدفعات)`، ≥ 0 | `accumulatedDebtThrough`، `isOverdue` |
| `accumulatedDebt` / `accumulatedDebtThrough` | `_remainingThrough` لشهر النهاردة / لشهر محدد | ~13 ملف |
| `isOverdue(..., graceDays)` | `_remainingThrough(lastMonth)` > 0، مع استثناء الشهر الحالي لو `graceDays>0 && now.day<=graceDays` | `notification_service`، `student_sort_helper`، شارات UI |

**الخلاصة**: تعديل **حدّ آخر شهر** (لـ"مؤخّر") في `totalDueThrough`/`_remainingThrough`،
وتعديل **قيمة شهر الانضمام** (للنسبي) جوّه `monthlyDue` — بيغطّي كل الـ13 ملف تلقائيًا.

### المتصلون بـ`PricingHelper` (13 ملف lib)
`qr_controller`, `qr_scanner_payment_page`, `database_service`, `export_service`,
`student_details_page`, `group_details_page`, `report_controller`, `student_sort_helper`,
`dashboard_controller`, `notification_service`, `payments_report_page`, `payments_page`.
**مافيش داعي نلمس أي واحد فيهم** لو الإعدادات وصلت لـ`PricingHelper` بطريقة عامة.

### الإعدادات — `lib/controllers/settings_controller.dart`
- `payment_grace_days` (`_keyPaymentGraceDays`) — نمط الإعداد الرقمي المخزّن في `app_settings`.
- الإعدادات كلها في جدول `app_settings` key/value.

### وضع الفريق — `lib/services/sync_engine.dart`
- `_tables` = groups/students/attendance/payments/homework/exams/exam_groups/exam_grades.
- **`app_settings` مش موجود** → الإعدادات **مش بتتزامن** بين أجهزة الفريق. `payment_grace_days`
  نفسه لكل جهاز على حدة.
- نمط ثابت موجود: `DatabaseService.teamModeEnabled` — `static bool` بيتظبط من `TeamModeService`.

### شاشة الدفع — `lib/controllers/qr_controller.dart`
- `_oldestUnpaidMonth(student, group, payments)` (spec 011/v1.2.33) — بيلفّ `monthlyDue`
  ويجمّع لحد ما يتعدّى `Σ payments`. **لو `monthlyDue` بقى نسبي، ده بياخده تلقائيًا.**
- `_buildUpcomingMonths` + `autoSelect = start.isBefore(nowMonth)` — الشهر الحالي مش
  بيتختار تلقائيًا أصلاً (v1.2.33)، فـ"مؤخّر" بيتوافق معاه.

### بوابة أولياء الأمور
- `booking_site/track/index.html`: `remaining = max(0, effectivePrice − totalPaid)` —
  **حساب مبسّط خاص بالصفحة**، مش `accumulatedDebt`. لو عايزين "المتبقّي" في البوابة يبقى
  دقيق حسب الإعدادين، لازم التطبيق يبعت `accumulatedDebt` كحقل جاهز.

## القرارات

### قرار 1: الإعدادات توصل `PricingHelper` عبر `static` config (نمط `teamModeEnabled`)
- `PricingHelper.billingArrears` (`static bool`, افتراضي `false`).
- `PricingHelper.prorateFirstMonth` (`static bool`, افتراضي `false`).
- `SettingsController` بيظبطهم عند تحميل الإعدادات وعند أي تغيير.
- **السبب**: 13 ملف بينادوا `PricingHelper` بتوقيعات مختلفة — إضافة param لكل نداء = churn
  كبير وخطر. الـstatic config نمط موجود بالفعل في المشروع (`DatabaseService.teamModeEnabled`).
- **البديل المرفوض**: تمرير `SettingsController` لكل `PricingHelper` call — churn 13 ملف.

### قرار 2: "مؤخّر" = تقييد آخر شهر مستحق بـ`الشهر الحالي − 1`
- في `totalDueThrough` و`_remainingThrough`: لو `billingArrears`، الحدّ الفعّال =
  `_earliestOf(requestedMonth, DateTime(now.year, now.month - 1, 1))`.
- يعني: لو المدرس بيتصفّح تقرير "لحد سبتمبر" وإحنا في سبتمبر → يُحسب لحد أغسطس. لو إحنا في
  أكتوبر → سبتمبر خلص → يُحسب لحد سبتمبر عادي.
- الشهر يُعتبر "خلص" أول ما يبدأ الشهر اللي بعده (طول شهر سبتمبر، آخر شهر مكتمل = أغسطس).
- **`isOverdue`**: `graceDays` الموجود بيعمل نفس الاستثناء للشهر الحالي — لو `billingArrears`،
  الاستثناء بيبقى دايم (بغض النظر عن `now.day`/`graceDays`).

### قرار 3: "نسبي" = تعديل `base` لشهر الانضمام فقط جوّه `monthlyDue`
- في `monthlyDue`، بعد حساب `base` العادي (شهري/إخوة — مش بالحصة، مش مُعفى):
  - لو `prorateFirstMonth` و`month` == شهر (`attendanceStart ?? createdAt`):
    - `daysCovered = daysInMonth(month) − enrollmentDay + 1`
    - `ratio = min(daysCovered / 30, 1.0)`
    - `base = roundToNearest5(base × ratio)`
- `daysInMonth` = `DateTime(month.year, month.month + 1, 0).day` (28–31).
- المقام **ثابت 30** (Q2). التقريب **لأقرب 5** (Q1): `(x / 5).round() * 5`.
- بالحصة والمُعفى: `return` بيحصل قبل الفرع ده → مايتأثروش (FR-012/FR-013).

### قرار 4: شاشة الدفع — تعديل بسيط لـ`_oldestUnpaidMonth` في وضع "مؤخّر"
- الحلقة بتجمّع `monthlyDue` (بقت نسبية تلقائيًا). لكن في "مؤخّر" الشهر الحالي مش مديونية
  → الحلقة تتوقّف عند `الشهر الحالي − 1` (متعملش walk للشهر الحالي كـ"مستحق").
- `autoSelect` (v1.2.33) شغّال صح مع الاتنين بدون تغيير.

### قرار 5: بوابة أولياء الأمور — التطبيق يبعت `accumulatedDebt` جاهز
- في `parent_portal_service._buildSummaryData`: أضف حقل `remaining` (أو `accumulatedDebt`)
  محسوب من `PricingHelper.accumulatedDebt` (بياخد الإعدادين تلقائيًا).
- `booking_site/track/index.html`: يستخدم `d.remaining` لو موجود، وإلا يرجع للحساب المبسّط
  الحالي (توافق خلفي).

### قرار 6: الإعدادات في وضع الفريق
- `app_settings` مش بيتزامن حاليًا → الإعدادين هيبقوا **لكل جهاز**. جهاز المساعد لازم
  يظبطهم زي المالك.
- **مقبول لـv1** — نفس وضع `payment_grace_days`. توثيق بس، مش شغل.
- (تزامن `app_settings` تحسين مستقبلي منفصل، خارج نطاق spec 012.)

## المخاطر

- **13 موضع بينادوا `PricingHelper`**: الـstatic config بيغطّيهم بدون لمس — بس لازم مهمة
  تحقّق تتأكد إن الإعدادين بيوصلوا صح (تُحمَّل عند الإقلاع + تتحدّث عند التغيير).
- **الأثر الرجعي**: تفعيل "نسبي" بيغيّر مديونيات تاريخية — ده مقصود (FR-011)، بس المدرس
  لازم يفهم من نص الشرح. مفيش فقدان بيانات (حساب مشتقّ).
- **`monthlyDue` بينادى في حلقة `totalDueThrough`** لكل شهر — إضافة حساب النسبة لكل نداء
  رخيصة (حساب تاريخ بسيط)، بس الشرط "هل ده شهر الانضمام؟" لازم يكون سريع.
- **بوابة الـVPS**: أي تغيير في `track/index.html` محتاج نشر يدوي (زي كل المرات).
