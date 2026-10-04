# Implementation Plan: يوم نزول المديونية

**Branch**: `045-billing-day` | **Date**: 2026-10-04 | **Spec**: [spec.md](spec.md)

## Summary

إعداد محلي عام `billing_day` (1–28، افتراضي 1) يحدد اليوم اللي فيه اشتراك الشهر الجاري "ينزل" مديونية على طلاب المجموعات الشهرية. المنطق كله في `PricingHelper` اللي كل الشاشات بتعتمد عليه، فبنعدّل **ثلاث نقاط فقط**: آخر شهر مستحق (`_effectiveLastMonth`)، نافذة مهلة السماح (`isOverdue`)، وشهر التحصيل الافتراضي (`defaultCollectionMonth`) — كلها عبر دوال صرفة جديدة في `lib/utils/billing_day.dart` بتاخد `now` كمعامل عشان تتختبر. بالإضافة لواجهة اختيار في الإعدادات (مع معاينة وتعطيل لو "المؤخّر" مفعّل)، وإعادة تحديث الداشبورد والتنبيه وملخصات أولياء الأمور عند التغيير.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1
**Primary Dependencies**: GetX (`SettingsController`)، `PricingHelper`، `DatabaseService.getSetting/setSetting`
**Storage**: `app_settings` (مفتاح جديد `billing_day`) — **لا تغيير في جداول ولا مزامنة ولا migration**
**Testing**: `flutter test` — دوال صرفة بمعامل `now` + اختبار تكاملي لـ`PricingHelper` بتحكم في `billingDay`
**Constraints**: القيمة 1 = سلوك مطابق 100% للحالي؛ المؤخّر يتجاهل اليوم؛ بالحصة غير متأثرة؛ الإعداد محلي (لا مزامنة فريق)
**Scale/Scope**: 3 نقاط حساب + إعداد + واجهة؛ ملف جديد صغير

## Constitution Check

لا مبادئ مُفعَّلة. ملتزم بأعراف المشروع: منطق مركزي في `PricingHelper`، دوال صرفة + اختبار وحدة، إعداد محلي بنمط `billing_arrears`، وتحديث الواجهات بعد تغيير الإعداد.

## Project Structure

```text
specs/045-billing-day/{spec,plan,research,data-model,quickstart,tasks}.md + contracts/billing-day.md
lib/utils/billing_day.dart                 # جديد: دوال صرفة بمعامل now
lib/utils/pricing_helper.dart              # static billingDay + استخدام الدوال الصرفة (_effectiveLastMonth, isOverdue)
lib/utils/billing_period.dart              # defaultCollectionMonth تعتمد اليوم
lib/config/constants.dart                  # SETTING_BILLING_DAY
lib/controllers/settings_controller.dart   # billingDay Rx + تحميل/حفظ/setBillingDay + تحديث الواجهات
lib/views/settings/settings_page.dart      # منتقي اليوم + معاينة + تعطيل مع المؤخّر
lib/controllers/dashboard_controller.dart  # computeMonthlyBreakdown: شهر لم ينزل = بلا متأخرين
test/billing_day_test.dart
```
