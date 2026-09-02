# Implementation Plan: تقارير الفترة المخصصة

**Branch**: `014-custom-period-reports` (العمل فعليًا على `main` زي باقي السبيكات) | **Date**: 2026-09-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/014-custom-period-reports/spec.md`

## Summary

إضافة وضع "فترة مخصصة" (تاريخ من / تاريخ إلى) بجانب الوضع الشهري الحالي، في مكانين فقط:
1. **شيت تصدير PDF في شاشة التقارير** — لتقريري الحضور والواجب فقط.
2. **تقرير واتساب في صفحة الطالب** (`_shareMonthlyReport`).

الوضع الشهري يفضل الافتراضي في كل مكان. الفلترة بالتاريخ فقط — صفر تغييرات قاعدة بيانات. الامتحانات تتفلتر بـ`examDate` الفعلي (Q1=A). ملخص المجموعات PDF مستثنى من وضع الفترة (Q2=A). تقرير واتساب الفترة أكاديمي بحت بدون قسم مالي (Q3=B).

**النهج التقني**: توسيع دوال `ExportService` الحالية بمعامل `periodEnd` اختياري؛ توسيع `buildMonthlyReportMessage` بمعاملات فترة اختيارية؛ حالة الوضع/النطاق محلية للـUI (مش في `ReportController.selectedMonth` اللي بيغذّي شاشة التقارير كلها).

## Technical Context

**Language/Version**: Dart 3 / Flutter (مطابق للمشروع الحالي)

**Primary Dependencies**: GetX (حالة)، `pdf` + `printing` (توليد ومشاركة PDF)، `intl` (`DateFormat`)، `url_launcher` (واتساب) — كلها موجودة، مفيش إضافات.

**Storage**: sqflite — **لا تغييرات**. مفيش migration، `DATABASE_VERSION` ثابت على 22.

**Testing**: مفيش بنية اختبار آلي في المشروع — تحقّق يدوي عبر `quickstart.md`.

**Target Platform**: Android (أساسي)، APK release.

**Project Type**: تطبيق موبايل single-project — كل الكود تحت `lib/`.

**Performance Goals**: توليد PDF لفترة شهرين لمجموعة ~30 طالب في < 30 ثانية على جهاز متوسط (SC-001).

**Constraints**: offline-capable (كل الحساب محلي)، صفر تغيير في سلوك التقارير الشهرية الحالية (SC-005).

**Scale/Scope**: ~4 ملفات تتعدّل (`export_service.dart`، `report_controller.dart`، `reports_page.dart`، `monthly_report_message.dart`، `student_details_page.dart`). مفيش ملفات جديدة.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

ملف `.specify/memory/constitution.md` قالب فاضي (placeholders) — **مفيش بنود حوكمة مفعّلة**. البوابة تُعتبر ناجحة تلقائيًا.

مبادئ ضمنية من نمط المشروع (متّبعة):
- **صفر تغييرات DB** ما لم تكن ضرورية — ✅ (فلترة تواريخ فقط).
- **إضافة اختيارية غير كاسرة** — ✅ (الوضع الشهري الافتراضي، معاملات جديدة كلها اختيارية بقيم افتراضية).
- **إعادة استخدام المنطق الموحّد** — ✅ (توسيع `buildMonthlyReportMessage` و`_attendanceTable`/`_homeworkTable` من سبيك 013 بدل نسخ جديدة).

## Project Structure

### Documentation (this feature)

```text
specs/014-custom-period-reports/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — قرارات تقنية
├── data-model.md        # Phase 1 — لا كيانات DB جديدة (حالة UI فقط)
├── quickstart.md        # Phase 1 — سيناريوهات تحقّق يدوي
├── checklists/
│   └── requirements.md  # جودة المواصفة (مكتمل)
└── tasks.md             # Phase 2 — ناتج /speckit-tasks (مش من هنا)
```

مفيش `contracts/` — تطبيق موبايل داخلي، مفيش واجهات API خارجية.

### Source Code (repository root)

```text
lib/
├── services/
│   └── export_service.dart          # + معامل periodEnd في exportAttendancePDF/exportHomeworkPDF
│                                    #   + ترويسة عمود بتاريخ كامل في وضع الفترة
│                                    #   + تسمية ملف/عنوان صفحة للفترة
├── controllers/
│   └── report_controller.dart       # + تمرير from/to لدوال التصدير، فلترة allAttendance/allHomework بالنطاق
├── utils/
│   └── monthly_report_message.dart  # + periodStart/periodEnd اختياريين → عنوان "تقرير الفترة" + إخفاء القسم المالي
└── views/
    ├── reports/
    │   └── reports_page.dart        # شيت التصدير: مفتاح "شهر / فترة" + منتقيي من/إلى + إخفاء دفعات/ملخص في وضع الفترة
    └── students/
        └── student_details_page.dart # _shareMonthlyReport: اختيار الوضع قبل الإرسال
```

**Structure Decision**: single-project موبايل. التغييرات مركّزة في طبقة الخدمات (`export_service`) وطبقة العرض (`reports_page`, `student_details_page`) والدالة الموحّدة (`monthly_report_message`). حالة الوضع/النطاق **محلية للـUI** — مش في `ReportController` (اللي `selectedMonth` بتاعته تغذّي شاشة التقارير الرئيسية كلها بـKPIs، والفترة مش المفروض تأثّر عليها).

## Complexity Tracking

> لا مخالفات دستورية — القسم غير مطبّق.
