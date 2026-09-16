# Implementation Plan: ملخص تفصيلي لكارت دفعات الشهر (تفصيل حسب المجموعة)

**Branch**: `036-payment-month-summary` | **Date**: 2026-09-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/036-payment-month-summary/spec.md`

## Summary

كارت "دفعات [الشهر]" في الصفحة الرئيسية بيعرض رقم إجمالي واحد بس (مستحق/محصّل/باقي/نسبة) للشهر المختار، وضغطة "N لم يدفع" بتفتح قائمة مسطحة بكل الطلاب المتأخرين مخلوطين من كل المجموعات. المطلوب: ضغطة على جسم الكارت نفسه (منفصلة عن السحب لتبديل الشهر، ومنفصلة عن شريحة "N لم يدفع" الموجودة) تفتح شيت جديد يعرض نفس الإجمالي فوق تفصيل لكل مجموعة (مستحق/محصّل/باقي/عدد المتأخرين)، مرتّب تنازليًا حسب الباقي. الحل: دالة تجميع جديدة في `DashboardController` بتعيد استخدام نفس منطق `_computePaymentCardBody` الموجود (نفس `monthlyDue`/`totalDueThrough` من `PricingHelper`) لكن مجمّعة بـ`groupId` بدل مجموع واحد — بلا صيغة حساب جديدة وبلا تغيير في القاعدة.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1 — بلا تغيير.

**Primary Dependencies**: بلا تبعيات جديدة — تعديل داخل `dashboard_controller.dart` + `home_page.dart` الحاليين + widget شيت جديد.

**Storage**: N/A — الميزة كلها عرض/تجميع لحظي فوق بيانات موجودة بالفعل (`students`, `payments`, `groups`, `attendance`). بلا عمود/جدول جديد، بلا migration.

**Testing**: `flutter test` لدالة التجميع الصرفة الجديدة (بلا Flutter widgets) في `dashboard_controller.dart` أو ملف منطق منفصل — بنفس نمط الاختبارات الحالية لـ`PricingHelper`.

**Target Platform**: Android (بلا تغيير).

**Project Type**: تطبيق موبايل واحد — بلا تغيير في البنية.

**Performance Goals**: التجميع بيحصل على بيانات محمَّلة بالفعل في الذاكرة (نفس مصادر `_computePaymentCardBody`) — بلا استعلام DB إضافي وقت فتح الشيت؛ الحساب نفسه بسيط (حلقة واحدة على الطلاب + تجميع بـ`groupId`) فمتوقع أقل من مللي ثانية لـ١٥٠+ طالب.

**Constraints**: لازم مجموع "الباقي" لكل المجموعات (+ "بلا مجموعة") يساوي بالظبط رقم "الباقي" الإجمالي الحالي في الكارت (SC-002) — يعني لازم إعادة استخدام نفس فلترة/نفس شروط `_computePaymentCardBody` سطرًا بسطر (استبعاد المعفيين، `start == null`، `dueThisMonth <= 0`) بدل صياغة شرط جديد يمكن يختلف بالغلط.

**Scale/Scope**: تعديل في `dashboard_controller.dart` (دالة تجميع جديدة + حقل RxList جديد) + `home_page.dart` (onTap جديد على الكارت + widget شيت جديد) — بلا تغيير في أي شاشة تانية.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد `constitution.md` مُفعّل في المشروع (لسه على شكل القالب الافتراضي). الاعتبارات العملية المكافئة (من نمط المشروع الفعلي):
- ✅ بلا تغيير في قاعدة البيانات أو المزامنة (`sync_engine.dart` غير ملموس).
- ✅ إعادة استخدام منطق حساب موجود وموثوق (`PricingHelper.monthlyDue`/`totalDueThrough`) بدل صيغة جديدة — يقلّل خطر تناقض بين الكارت والشيت الجديد (نفس الباج اللي اتصلّح في `overdue_warning_badge.dart` كان سببه بالظبط استخدام مصدر بيانات غير مفلتر صح — الدرس هنا: لازم نمرّر نفس البيانات المفلترة اللي بيستخدمها الكارت، مش نعيد كتابة الفلترة).
- ✅ لا حذف/تعديل بيانات — قراءة وعرض فقط.

## Project Structure

### Documentation (this feature)

```text
specs/036-payment-month-summary/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — قرارات تقنية
├── data-model.md        # Phase 1 — الكيانات المحسوبة
├── contracts/            # Phase 1 — عقد الشيت الجديد
│   └── group-payment-summary-sheet.md
├── quickstart.md         # Phase 1 — سيناريوهات تحقق
└── tasks.md              # Phase 2 (/speckit-tasks — لسه مش منشأ)
```

### Source Code (repository root)

```text
active_class/
├── lib/
│   ├── controllers/
│   │   └── dashboard_controller.dart   # + GroupPaymentSummaryEntry (كلاس بيانات)
│   │                                    # + RxList<GroupPaymentSummaryEntry> paymentCardGroupBreakdown
│   │                                    # + _computeGroupBreakdown() تُستدعى من _computePaymentCardBody
│   │                                    #   (بيانات مجمَّعة أثناء نفس الحلقة الموجودة — بلا حلقة إضافية منفصلة)
│   └── views/
│       └── home_page.dart              # + onTap جديد على جسم _PaymentProgressCard (منفصل عن السحب
│                                        #   وعن onTapUnpaid الحالي) → _showPaymentMonthSummarySheet(context)
│                                        # + _showPaymentMonthSummarySheet: شيت جديد (ملخص عام + قائمة
│                                        #   مجموعات) — الضغط على مجموعة يفتح _showUnpaidSheet نفسه
│                                        #   لكن مفلتر بـgroupId (باراميتر اختياري جديد)
└── test/
    └── dashboard_group_payment_breakdown_test.dart   # [جديد] اختبار الدالة الصرفة
```

**Structure Decision**: تعديل داخل نفس بنية التطبيق الحالية — بلا مشروع/طبقة جديدة. الشيت الجديد widget إضافي في `home_page.dart` بنفس نمط `_showUnpaidSheet`/`_showTodayPaymentsSheet` الموجودين بالفعل، وبيانات التجميع تُحسب داخل `DashboardController` (مش داخل الـwidget) عشان تفضل قابلة للاختبار بمعزل عن الواجهة.

## Complexity Tracking

> لا توجد انتهاكات دستورية تحتاج تبرير.
