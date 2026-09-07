# Implementation Plan: تنبيه "عليه متأخر في الدفع" في شاشة الحضور — ذكي حسب نوع التسعير

**Branch**: `029-attendance-overdue-warning` | **Date**: 2026-09-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/029-attendance-overdue-warning/spec.md`

## Summary

إضافة دالة قرار واحدة في `PricingHelper` تحدّد "هل يظهر تنبيه المتأخر لهذا الطالب في شاشة الحضور؟":
- معفى بالكامل → لا.
- مجموعة شهرية / بدون مجموعة → `PricingHelper.isOverdue(...)` القائمة (بمهلة السماح).
- مجموعة بالحصة → `accumulatedDebt − (حصص اليوم × effectivePrice) > 0.01`.

ودجت تنبيه مشترك (`OverdueWarningBadge`) يُعرَض في: بانل نتيجة المسح وكروت البحث بشاشة `QRScannerAttendancePage`، وقوائم `attendance_page.dart`. مفتاح إعداد محلي `attendanceOverdueWarning` (افتراضي on). شاشة الـQR للحضور تحمّل الدفعات عند الفتح (زي ما `attendance_page.dart` بيعمل عبر `PaymentController` بالفعل). صفر تغيير DB/مزامنة، صفر مكتبات جديدة.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX. `PricingHelper` القائم (`isOverdue`, `accumulatedDebt`, `monthlyDue`, `sessionsAttended`). `PaymentController.payments` (RxList قائم). لا مكتبات جديدة.

**Storage**: مخزن الإعدادات المحلي القائم (`SettingsController._dbSet`). DB version يبقى **28**. لا جداول/أعمدة.

**Testing**: `flutter test` — وحدة لدالة `PricingHelper` الجديدة.

**Target Platform**: Android (وأي منصة — لا كود منصّي).

**Project Type**: تطبيق موبايل Flutter (هيكل `lib/` مفرد).

**Performance Goals**: حساب القرار لكل طالب O(دفعاته + حضوره) — يتم مرة عند بناء الودجت. تحميل الدفعات في شاشة الـQR مرة واحدة عند الفتح (مثل باقي البيانات). لا حساب في مسار المسح نفسه.

**Constraints**: تحذير بصري فقط (FR-012). لا تغيير DB/مزامنة/تسعير. عند تعطيل المفتاح: المستمع/الحساب لا يُنفَّذ → صفر أثر (SC-005). إعادة استخدام أقصى ما يمكن من `PricingHelper`.

**Scale/Scope**: 1 دالة `PricingHelper` جديدة + 1 helper صغير (حصص اليوم) · 1 ودجت مشترك · 1 إعداد + سطر UI · تعديل 2–3 مواضع عرض في شاشتين · 1 ملف اختبار.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

الدستور `.specify/memory/constitution.md` قالب فارغ (placeholders). نطبّق أعراف المشروع:

| عرف | الحالة |
|---|---|
| صفر تغيير DB إلا بترقية صريحة | ✅ PASS |
| صفر تغيير مزامنة إلا بحاجة | ✅ PASS — الإعداد محلي |
| لا مكتبات جديدة | ✅ PASS |
| إعادة استخدام منطق التسعير القائم، لا تكرار | ✅ PASS — دالة قرار تبني على `isOverdue`/`accumulatedDebt` |
| اختبارات + `flutter analyze` نظيف | ✅ مخطّط |
| git push بإذن صريح؛ commit على `main` | ✅ ملحوظ |

**النتيجة: PASS** — لا انتهاكات، لا Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/029-attendance-overdue-warning/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — قرارات محسومة
├── data-model.md        # Phase 1 — إعداد + قرار مشتقّ، لا سكيمة
├── quickstart.md        # Phase 1 — سيناريوهات تحقّق
├── contracts/
│   ├── pricing-helper-overdue-warning.md   # عقد الدالة الجديدة
│   └── overdue-warning-widget.md            # عقد الودجت المشترك + مواضع الدمج
└── tasks.md             # Phase 2 — /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── utils/
│   └── pricing_helper.dart        # + showsAttendanceOverdueWarning(...) + sessionsAttendedOn(date) داخلي
├── controllers/
│   └── settings_controller.dart   # + attendanceOverdueWarning (RxBool) + setter + تحميل
├── config/
│   └── constants.dart             # + SETTING_ATTENDANCE_OVERDUE_WARNING
├── widgets/
│   └── overdue_warning_badge.dart # جديد — ودجت مشترك (شريط/شارة "متأخر — مديونية N ج")
├── views/
│   ├── qr_scanner/
│   │   └── qr_scanner_attendance_page.dart   # تحميل الدفعات عند الفتح + عرض الودجت في _AttendancePanel و _StudentSearchCard
│   └── attendance/
│       └── attendance_page.dart              # عرض الودجت بجوار اسم الطالب في القوائم (PaymentController متاح بالفعل)
└── views/settings/
    └── settings_page.dart          # + سطر Switch "تنبيه المتأخر في شاشة الحضور"

test/
└── attendance_overdue_warning_test.dart      # جديد — وحدة PricingHelper.showsAttendanceOverdueWarning
```

**Structure Decision**: هيكل Flutter المفرد القائم. كل المنطق القابل للاختبار في دالة `PricingHelper` واحدة (نفس مكان `isOverdue`). الودجت المشترك في `lib/widgets/` (نمط `hardware_reader_widgets.dart` من spec 027). شاشة الـQR للحضور تكتسب `PaymentController` مثل `attendance_page.dart`.

## Complexity Tracking

> لا انتهاكات — لا شيء يُبرَّر.
