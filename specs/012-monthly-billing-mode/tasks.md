---
description: "Task list — نظام تحصيل الاشتراك الشهري (012-monthly-billing-mode)"
---

# Tasks: نظام تحصيل الاشتراك الشهري (مقدّم/مؤخّر + حساب نسبي للشهر الأول)

**Input**: Design documents from `specs/012-monthly-billing-mode/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: لا توجد بنية اختبار آلي في المشروع — التحقّق يدوي عبر [quickstart.md](quickstart.md). لا مهام اختبار.

**Organization**: كل الحساب يمرّ من `lib/utils/pricing_helper.dart` عبر حقلين `static`
(نمط `DatabaseService.teamModeEnabled`). الـ13 ملف اللي بتنادي `PricingHelper` ما بتتلمسش.

## Path Conventions

Mobile single-project: كل الكود تحت `lib/`. الواجهة العامة تحت `booking_site/`.

---

## Phase 1: Setup

- [X] T001 في `lib/config/constants.dart`: أضف `const String SETTING_BILLING_ARREARS = 'billing_arrears';` و`const String SETTING_PRORATE_FIRST_MONTH = 'prorate_first_month';` جنب `SETTING_LATE_GRACE_MINUTES`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: توصيل الإعدادين لـ`PricingHelper` + الـhelpers الحسابية — كله يسبق أي user story

**⚠️ CRITICAL**: مفيش شغل user story يبدأ قبل اكتمال المرحلة دي

- [X] T002 في `lib/utils/pricing_helper.dart`: أضف `static bool billingArrears = false;` و`static bool prorateFirstMonth = false;` في أول الكلاس. أضف `static double _roundTo5(double x) => (x / 5).round() * 5.0;`. أضف `static DateTime _effectiveLastMonth(DateTime requested)` — لو `!billingArrears` يرجّع `DateTime(requested.year, requested.month, 1)`؛ غير كده `min(DateTime(requested.year, requested.month, 1)، DateTime(now.year, now.month - 1, 1))` (آخر شهر مكتمل). idempotent.
- [X] T003 [P] في `lib/controllers/settings_controller.dart`: أضف `RxBool billingArrears = false.obs` + `RxBool prorateFirstMonth = false.obs`. أضف `_loadBillingSettings()` (`_migrateBool(SETTING_BILLING_ARREARS) ?? false` + `_migrateBool(SETTING_PRORATE_FIRST_MONTH) ?? false` ثم `_applyToPricingHelper()`) وضيفها لـ`Future.wait` في `reloadFromDatabase`. أضف `void _applyToPricingHelper()` (يظبط `PricingHelper.billingArrears`/`prorateFirstMonth` من قيم الـRx). أضف `setBillingArrears(bool)` و`setProrateFirstMonth(bool)` — كل واحد يحدّث الـRx + `_applyToPricingHelper()` + `_dbSet`.
- [X] T004 تحقّق فقط: `SettingsController.onInit` بينده `reloadFromDatabase` (اللي هيحتوي `_loadBillingSettings` → `_applyToPricingHelper`) — يعني `PricingHelper.*` بيتظبط تلقائيًا عند الإقلاع. مفيش تعديل على `main.dart` مطلوب. أكّد إن `reloadFromDatabase` فعلًا في `onInit` (سطر ~123).

**Checkpoint**: `PricingHelper.billingArrears`/`prorateFirstMonth` بيتظبطوا من الإعدادات المخزّنة

---

## Phase 3: User Story 1 - نظام تحصيل "مؤخّر" (Priority: P1) 🎯 MVP

**Goal**: في وضع "مؤخّر"، الشهر الجاري ما يتحسبش في المستحق/المديونية/شارة متأخر/التقارير لحد ما يخلص.

**Independent Test**: quickstart سيناريو 2.

- [X] T005 [US1] في `lib/utils/pricing_helper.dart` `totalDueThrough`: بدّل `final lastMonth = DateTime(month.year, month.month, 1);` بـ`final lastMonth = _effectiveLastMonth(month);`. شرط `if (cursor.isAfter(lastMonth)) return 0;` يفضل زي ما هو (طالب انضم الشهر الحالي في "مؤخّر" → 0).
- [X] T006 [US1] في `lib/utils/pricing_helper.dart` `_remainingThrough`: تأكّد إنه بيمرّر `lastMonth` لـ`totalDueThrough` (اللي بقى بيطبّق `_effectiveLastMonth`). مفيش تعديل مطلوب على `_remainingThrough` نفسها — بس علّق إن `isOverdue` بقى arrears-aware تلقائيًا عبرها (مفيش تعديل على `isOverdue`).
- [X] T007 [US1] في `lib/views/settings/settings_page.dart`: في قسم مناسب (جنب "مهلة السماح قبل متأخر")، أضف `Obx(() => _buildSwitchTile(...))` بعنوان "تحصيل مؤخّر (بالمنقضي)" مربوط بـ`settings.billingArrears` / `setBillingArrears`. subtitle حسب الحالة: مفعّل → "الشهر الجاري ما يتحسبش في المديونية لحد ما يخلص"؛ مطفي → "مقدّم — الشهر مستحق من أول يومه (الافتراضي)".

**Checkpoint**: US1 كامل — "مؤخّر" شغّال في كل الشاشات عبر `PricingHelper`

---

## Phase 4: User Story 2 - حساب نسبي للشهر الأول (Priority: P2)

**Goal**: عند التفعيل، شهر انضمام الطالب يُحسب `round5(min(daysCovered/30, 1) × base)`.

**Independent Test**: quickstart سيناريو 3.

- [X] T008 [US2] في `lib/utils/pricing_helper.dart` `monthlyDue`: بعد حساب `base` وقبل `return base * (1 - student.exemptPercent / 100);` — أضف فرع: لو `prorateFirstMonth` و`start = student.attendanceStart ?? student.createdAt` مش null و`start.year == month.year && start.month == month.month`: `final daysInMonth = DateTime(month.year, month.month + 1, 0).day;` `final daysCovered = daysInMonth - start.day + 1;` `final ratio = (daysCovered / 30).clamp(0.0, 1.0);` `base = _roundTo5(base * ratio);`. (الفرع مش بيتنفّذ للـper-session ولا المُعفى — دول بيعملوا `return` قبله.)
- [X] T009 [US2] في `lib/views/settings/settings_page.dart`: أضف `SwitchListTile` "حساب نسبي للشهر الأول" مربوط بـ`settings.prorateFirstMonth` / `setProrateFirstMonth`. نص شرح: "الطالب اللي بينضم نص الشهر يدفع نسبة الأيام اللي حضرها بدل شهر كامل — يتقرّب لأقرب 5 ج".

**Checkpoint**: US2 كامل — النسبي شغّال، مفيش مديونية وهمية

---

## Phase 5: User Story 3 - الانتشار والتوليفات + البوابة (Priority: P3)

**Goal**: كل الواجهات (شامل بوابة أولياء الأمور) تعرض رقمًا متّسقًا مع أي توليفة من الإعدادين.

**Independent Test**: quickstart سيناريوهات 4 و 6.

- [X] T010 [US3] في `lib/services/parent_portal_service.dart` `_buildSummaryData`: أضف حقل `'remaining': PricingHelper.accumulatedDebt(student: student, group: group, allAttendance: attendance, payments: payments, siblingGroupMembers: <قائمة كل الطلاب المتاحة في الدالة>)` للماب المُرجَعة. (لو `_buildSummaryData` مامعهاش كل الطلاب، مرّرها من `pushStudentSummary`/`publishAllStudents` زي ما بيتعمل مع باقي الحسابات.)
- [X] T011 [P] [US3] في `booking_site/track/index.html` (`renderStudent`): بدّل `const remaining = Math.max(0, effectivePrice - totalPaid);` بـ`const remaining = (typeof d.remaining === 'number') ? Math.max(0, d.remaining) : Math.max(0, effectivePrice - totalPaid);`. **نشر VPS يدوي.**
- [X] T012 [US3] جرد تحقّق: افتح الـ13 ملف اللي بتنادي `PricingHelper` (qr_controller, qr_scanner_payment_page, database_service, export_service, student_details_page, group_details_page, report_controller, student_sort_helper, dashboard_controller, notification_service, payments_report_page, payments_page) — تأكّد إن كلها بتاخد الرقم من `PricingHelper` (مش بتعيد حساب مديونية بنفسها). وثّق أي موضع بيحسب لوحده لو لقيت.

**Checkpoint**: US3 كامل — رقم واحد متّسق في كل مكان

---

## Phase 6: Polish & Cross-Cutting

- [X] T013 `flutter analyze` — صفر أخطاء/تحذيرات جديدة.
- [ ] T014 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–7 على جهاز — بالتركيز على سيناريو 1 (الافتراضي = صفر تغيير) وسيناريو 6 (الانتشار).
- [X] T015 ارفع `version` في `pubspec.yaml` (+build) وابنِ `--split-per-abi` release.

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 2** (يحجب كل الـuser stories). T002 و T003 شبه متوازيين (ملفات مختلفة) لكن T003 بيعتمد على `PricingHelper.billingArrears` من T002 (كتعريف). T004 بعد T003.
- **Phase 3 (US1)**: بعد Phase 2. T005→T006 (`pricing_helper.dart`، تسلسلي). T007 مستقل (`settings_page.dart`).
- **Phase 4 (US2)**: بعد Phase 2. T008 (`pricing_helper.dart` — تسلسلي مع T005/T006). T009 (`settings_page.dart` — تسلسلي مع T007).
- **Phase 5 (US3)**: بعد Phase 3+4 (عشان التحقّق يكون على السلوك النهائي). T010→T011. T012 جرد.
- **Phase 6**: بعد كل ما سبق.

### تعارض ملفات
`lib/utils/pricing_helper.dart`: T002, T005, T006, T008 — تسلسلي.
`lib/views/settings/settings_page.dart`: T007, T009 — تسلسلي.

---

## Implementation Strategy

### MVP (US1)
Phase 1 + 2 + 3 → "مؤخّر" شغّال في كل الشاشات. تحقّق (quickstart 1 + 2) → قابل للإصدار.

### تسليم تدريجي
- + US2 (Phase 4) → النسبي. تحقّق (quickstart 3).
- + US3 (Phase 5) → البوابة + جرد الانتشار. نشر `track` على VPS يدويًا.
- Phase 6: analyze + جهاز + بناء.

---

## Notes

- **الافتراضي (مقدّم + بدون نسبي) لازم يطابق النسخة السابقة 100%** — أهم بند تحقّق (SC-002).
- مفيش migration — كله مشتقّ.
- `app_settings` مش بيتزامن في وضع الفريق → الإعدادين لكل جهاز (زي `payment_grace_days`).
- `booking_site/track/index.html` نشره يدوي على VPS.
- المجموعات بالحصة والمُعفيين مستثنيين بحكم `return` المبكر في `monthlyDue`.
