# Implementation Plan: نظام تحصيل الاشتراك الشهري

**Branch**: `012-monthly-billing-mode` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/012-monthly-billing-mode/spec.md`

## Summary

إضافة إعدادين عامّين يتحكموا في حساب المستحق الشهري للطلاب "الشهري":
1. **نظام التحصيل** (مقدّم/مؤخّر) — في "مؤخّر" الشهر الجاري ما يتحسبش لحد ما يخلص.
2. **حساب نسبي للشهر الأول** — شهر انضمام الطالب يُحسب `min(أيام مشمولة ÷ 30، 1.0) × السعر`
   مقرّبًا لأقرب 5 ج.

كله يمرّ من `PricingHelper` عبر حقلين `static` (نمط `DatabaseService.teamModeEnabled`)،
فكل الـ13 ملف اللي بتنادي `PricingHelper` تاخد التغيير تلقائيًا. الافتراضي = السلوك الحالي
بالظبط (صفر مفاجأة). مفيش migration — كله حساب مشتقّ.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter

**Primary Dependencies**: GetX، sqflite (`app_settings`)، pdf/printing، cloud_firestore (البوابة)

**Storage**: `app_settings` key/value — مفتاحين نصّيين جديدين

**Testing**: يدوي عبر [quickstart.md](quickstart.md) (نفس نهج specs 009–011) + `flutter analyze`

**Target Platform**: Android (arm64 + v7a، split-per-abi)

**Project Type**: تطبيق موبايل single-project

**Performance Goals**: حساب المديونية فوري زي دلوقتي (`monthlyDue` بينادى في حلقة — الإضافة حساب تاريخ رخيص)

**Constraints**: الافتراضي لازم يطابق السلوك الحالي 100%؛ مفيش migration؛ المجموعات بالحصة والمُعفيين مستثنيين

**Scale/Scope**: ملف `PricingHelper` (جوهر) + `SettingsController` + `settings_page` + `qr_controller` (شاشة الدفع) + `parent_portal_service` + `booking_site/track` (نشر يدوي)

## Constitution Check

`.specify/memory/constitution.md` = template placeholders، **مفيش مبادئ ملزمة**. المشروع يتبع
نمط specs 009–011:
- مصدر حقيقة واحد (`PricingHelper`).
- إعدادات بنمط `payment_grace_days`.
- تحقّق يدوي عبر quickstart.
- الافتراضي يحافظ على التوافق الخلفي (زي `use24hFormat` في 009).

**النتيجة**: PASS — لا انتهاكات، لا تعقيد يحتاج تبرير.

## Project Structure

### Documentation (this feature)

```text
specs/012-monthly-billing-mode/
├── plan.md              # هذا الملف
├── research.md          # مكتمل — 6 قرارات
├── data-model.md        # الإعدادين + معادلات الحساب
├── quickstart.md        # سيناريوهات تحقّق يدوي
├── checklists/
│   └── requirements.md   # مكتمل
└── tasks.md             # ينشئه /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                 # + SETTING_BILLING_ARREARS, SETTING_PRORATE_FIRST_MONTH
├── utils/
│   └── pricing_helper.dart            # جوهر التغيير:
│                                      #  - static bool billingArrears / prorateFirstMonth
│                                      #  - monthlyDue: فرع نسبي لشهر الانضمام
│                                      #  - totalDueThrough/_remainingThrough: تقييد آخر شهر في "مؤخّر"
│                                      #  - helpers: _proratedBase، _arrearsLastMonth، _roundTo5
├── controllers/
│   └── settings_controller.dart       # RxBool billingArrears / prorateFirstMonth + load/set +
│                                      # يظبط PricingHelper.* عند التحميل وعند التغيير
│                                      # (qr_controller: تحقّق فقط — الحساب بيمر من PricingHelper)
├── services/
│   └── parent_portal_service.dart     # _buildSummaryData: + حقل remaining من PricingHelper.accumulatedDebt
└── views/
    └── settings/
        └── settings_page.dart         # segmented "نظام التحصيل" (مقدّم/مؤخّر) + switch "حساب نسبي للشهر الأول"
                                       #  + نص شرح لكل واحد

booking_site/track/index.html          # يستخدم d.remaining لو موجود (fallback للحساب الحالي) — نشر VPS يدوي
```

**Structure Decision**: single-project. التغيير مركّز في `pricing_helper.dart` + توصيل
الإعدادات. مفيش وحدات جديدة، مفيش migration.

## Complexity Tracking

> لا انتهاكات — القسم فاضي.
