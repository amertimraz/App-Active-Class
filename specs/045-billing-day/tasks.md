# Tasks: يوم نزول المديونية

**Tests**: اختبار وحدة للدوال الصرفة + اختبار تكاملي لـPricingHelper + تحقق يدوي.
**No DB / sync / migration.**

## Phase 1: المنطق الصرف
- [x] T001 [P] إنشاء `lib/utils/billing_day.dart`: `clampBillingDay`, `effectiveLastMonthFor`, `withinGraceWindow`, `isEarlyInMonthForCollection`, `monthHasLanded` حسب `contracts/billing-day.md`
- [x] T002 [P] إنشاء `test/billing_day_test.dart`: جدول السلوك، التطابق عند 1 (نفس نتائج الدوال القديمة)، المؤخّر يتجاهل اليوم، شهر مستقبلي، `monthHasLanded`
- [x] T003 في `lib/config/constants.dart`: `SETTING_BILLING_DAY = 'billing_day'`
- [x] T004 في `lib/utils/pricing_helper.dart`: `static int billingDay = 1`؛ `_effectiveLastMonth` و`isOverdue` يستخدمان `effectiveLastMonthFor`/`withinGraceWindow` (مع `DateTime.now()` والـstatics)
- [x] T005 في `lib/utils/billing_period.dart`: `defaultCollectionMonth` تستخدم `isEarlyInMonthForCollection`
- [x] T006 اختبار تكاملي في `test/billing_day_test.dart` لـ`PricingHelper.totalDueThrough/isOverdue` بتغيير `PricingHelper.billingDay` (طالب بسعر 100 ومديونية شهر سابق + جاري) مع `tearDown` يعيد القيمة 1
- [x] T007 **CHECKPOINT**: `flutter analyze` + `flutter test` صفر تراجع (اختبارات PricingHelper القديمة تثبت تطابق 1)

## Phase 2: US1 — الإعداد والواجهة
- [x] T008 `SettingsController`: `billingDay` (`RxInt`)، تحميله في `_loadBillingSettings` (clamp)، نسخه في `_applyBillingToPricingHelper`، و`setBillingDay(int)` يحفظ ويطبّق
- [x] T009 `SettingsController`: دالة مشتركة `_onBillingChanged()` — `DashboardController.loadDashboardData()` + `NotificationService.scheduleLatePaymentReminder()` + `ParentPortalService().publishAllStudents()` لو البوابة شغّالة؛ تُنادى من `setBillingDay` و`setBillingArrears` و`setProrateFirstMonth`
- [x] T010 `settings_page.dart`: بند "يوم نزول المديونية" بعد مفتاح المؤخّر — القيمة الحالية، منتقي 1..28، معاينة سطر، ومعطّل برسالة لو المؤخّر مفعّل، وتنبيه صغير لو وضع الفريق مفعّل
- [x] T011 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart بنود 1–4)

## Phase 3: US2 — اتساق الشاشات
- [x] T012 `computeMonthlyBreakdown` (الداشبورد): معامل `monthLanded` (افتراضي true)؛ لو false لا تُملأ قوائم/أعداد "لم يدفع/متأخرين"؛ و`_computePaymentCardBody` يمرّره بـ`monthHasLanded`
- [x] T013 مراجعة باقي المستهلكين (grep) للتأكد إنهم بيمروا بـPricingHelper فقط: المدفوعات، التقارير، الطباعة، تفاصيل الطالب، QR، علامة المتأخر، التنبيه، ملخصات الأهالي — وإصلاح أي حساب شهر جاري مستقل
- [x] T014 اختبار وحدة لـ`computeMonthlyBreakdown` مع `monthLanded: false`
- [x] T015 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart بنود 2، 3، 5–9)

## Phase 4: Polish
- [x] T016 [P] `flutter analyze` + `flutter test` كاملين
- [x] T017 بناء release وتثبيته والتحقق النهائي، وتحديث `HANDOFF.md` بملخص spec 045

## Dependencies
T001/T002/T003 بالتوازي ← T004/T005 ← T006 ← T007. T008 ← T009 ← T010. T012 بعد T001. US1 قبل US2.

## MVP
T001–T011 (المنطق + الإعداد والواجهة). US2 (T012–T015) لاكتمال الاتساق.
