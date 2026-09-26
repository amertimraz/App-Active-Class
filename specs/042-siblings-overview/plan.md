# Implementation Plan: شاشة الإخوة — عرض العيلات وتفاصيلها

**Branch**: `042-siblings-overview` | **Date**: 2026-09-26 | **Spec**: [spec.md](spec.md)

## Summary

شاشة عرض فقط تجمّع الطلاب النشطين حسب `siblingGroupId` (≥ 2 أعضاء) وتعرض لكل عيلة: الأعضاء ومجموعاتهم، الإجمالي المشترك، مستحق/مدفوع/متبقي كل أخ وإجمالي العيلة، الحضور الشهري، أرقام ولي الأمر، وزر رسالة واتساب واحدة. **لا جداول ولا مزامنة ولا migration** — كل الأرقام تُحسب من كنترولرز موجودة بنفس دوال `PricingHelper` المستخدمة في تفاصيل الطالب (SC-002).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1
**Primary Dependencies**: GetX (كنترولرز موجودة: `StudentController`, `PaymentController`, `AttendanceController`, `GroupController`), `PricingHelper`, `launchGuardianWhatsapp`, `TeamModeService.canSeeFinancials`
**Storage**: لا تغيير (قراءة من الكنترولرز المحمَّلة في الذاكرة)
**Testing**: `flutter test` — اختبار وحدة للمنطق الصرف `siblings_overview.dart` + تحقق يدوي على جهاز
**Target Platform**: Android (release APK)
**Project Type**: mobile app (Flutter)
**Constraints**: أرقام مطابقة 100% لتفاصيل الطالب؛ إخفاء مالي كامل بدون `canSeeFinancials`؛ CurrencyText `stacked` للأرقام الكبيرة؛ يتحدّث تلقائيًا (Obx) بما فيه تغييرات المزامنة
**Scale/Scope**: حتى ~100 عيلة (≈ 300 طالب) — الحساب O(طلاب + دفعات + حضور) لمرة لكل rebuild

## Constitution Check

`.specify/memory/constitution.md` قالب فقط (بدون مبادئ مُفعَّلة) — لا قيود إضافية. ملتزم بأعراف المشروع: منطق صرف + اختبار وحدة، لا تعديل في ملفات التسعير (نقرأ منها فقط)، استبعاد إسقاط المديونية من "المدفوع" (spec 038)، إخفاء مالي بـ`canSeeFinancials`.

## Project Structure

### Documentation
```text
specs/042-siblings-overview/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/siblings-math.md
└── checklists/requirements.md
```

### Source Code
```text
lib/utils/siblings_overview.dart        # منطق صرف: تجميع العيلات + الأرقام + رسالة العيلة
lib/views/students/siblings_page.dart   # الشاشة + الكروت + بحث/فلتر + إرسال واتساب
lib/views/students/students_page.dart   # + زر في AppBar
lib/config/constants.dart               # + ROUTE_SIBLINGS
lib/main.dart                           # + GetPage
test/siblings_overview_test.dart
```

**Structure Decision**: منطق صرف في `utils` (قابل للاختبار بلا GetX)، والشاشة تستدعيه داخل `Obx` على الكنترولرز. ما فيش كنترولر جديد.
