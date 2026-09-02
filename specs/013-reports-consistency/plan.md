# Implementation Plan: تناسق التقارير

**Branch**: `013-reports-consistency` | **Date**: 2026-09-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-reports-consistency/spec.md`

## Summary

6 إصلاحات تناسق:
1. **US1**: `report_controller` يستبعد الطلاب المؤرشفين (سطر واحد).
2. **US2**: **كل** شاشة فيها منتقي شهر (التقارير، المدفوعات، تقرير المدفوعات، تفاصيل الرسوم) تفتح على "شهر التحصيل الافتراضي" (آخر شهر مكتمل لو أول الشهر أو التحصيل المؤخّر).
3. **US3**: موديلات تقرير الواتساب (المجموعة/الإعدادات/الطالب) تبدأ بمنتقي شهر (شهور مكتملة فقط)؛ الرسالة كلها للشهر المختار؛ **نص الرسالة من دالة واحدة موحّدة** `buildMonthlyReportMessage`.
4. **US4**: كارت الدفعات في الداشبورد يعرض شهر التحصيل + سهمين تنقّل، أرقامه مشتقّة من `PricingHelper` (المديونية المتراكمة).
5. **US5**: جدول الحضور/الواجب في PDF يعرض أعمدة الأيام اللي فيها تسجيل فقط.
6. **US6**: حقل جديد "شهر التقرير" للامتحان (`report_month`, nullable → بديله شهر التاريخ) + migration v22 + منتقي في شاشة الامتحان + كل فلترة امتحانات بالشهر تتبعه.

helper مشترك `defaultCollectionMonth()` يخدم US2/US3/US4 (مصدر واحد لتعريف "شهر التحصيل الافتراضي").

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter

**Primary Dependencies**: GetX، sqflite، pdf/printing، cloud_firestore (sync)، url_launcher (واتساب)

**Storage**: `exams` table — عمود `report_month TEXT` جديد (nullable). لا تغيير آخر في القاعدة.

**Testing**: يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` (نهج specs 009–012)

**Target Platform**: Android (arm64 + v7a، split-per-abi)

**Project Type**: تطبيق موبايل single-project

**Performance Goals**: حساب التقارير/الداشبورد فوري زي دلوقتي

**Constraints**: الافتراضيات محفوظة (امتحانات قديمة بتاريخها؛ شهور بعد المهلة زي دلوقتي)؛ migration بسيط `ALTER TABLE` (نمط specs 010/011)

**Scale/Scope**: ~10 ملفات lib + migration واحدة + sync_engine

## Constitution Check

`.specify/memory/constitution.md` = template placeholders، مفيش مبادئ ملزمة. المشروع يتبع نمط
specs 009–012: مصدر حقيقة واحد للحساب، migration محافظة بـguard، تحقّق يدوي، توافق خلفي.

**النتيجة**: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/013-reports-consistency/
├── plan.md · research.md · data-model.md · quickstart.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                 # + COL_EXAM_REPORT_MONTH؛ DATABASE_VERSION 21 → 22
├── utils/
│   └── pricing_helper.dart            # (أو helper منفصل) defaultCollectionMonth() — مشترك US2/3/4
├── models/
│   └── exam_model.dart                # + String? reportMonth + effectiveReportMonth + toMap/fromMap/copyWith
├── services/
│   ├── database_service.dart          # _onCreate عمود report_month؛ migration v22 (ALTER TABLE)؛
│   │                                  # insertExam/updateExam؛ getStudentExamHistory/getAllStudentExamHistories SELECT
│   └── sync_engine.dart               # push (case TABLE_EXAMS ~327) + pull (~963): report_month
├── utils/
│   └── monthly_report_message.dart    # US3/FR-007b: buildMonthlyReportMessage(student, month, ...) موحّدة
├── controllers/
│   ├── report_controller.dart         # US1: فلترة !isArchived (سطر ~46)؛ US2: selectedMonth الأولي = defaultCollectionMonth()
│   ├── payment_controller.dart        # US2: selectedMonth الأولي (عبر الـviews) = defaultCollectionMonth()
│   ├── dashboard_controller.dart      # US4: Rx paymentCardMonth + setPaymentCardMonth؛ أرقام مشتقّة لـ M
│   └── exam_controller.dart           # addExam/editExam: تمرير reportMonth
└── views/
    ├── reports/reports_page.dart      # US2: (يشتغل تلقائيًا من selectedMonth) — تحقّق فقط
    ├── payments/payments_page.dart    # US2: selectedMonth ??= defaultCollectionMonth()
    ├── reports/payments_report_page.dart # US2: selectedMonth ??= defaultCollectionMonth()
    ├── groups/group_details_page.dart # US2: موديل "تفاصيل الرسوم" الشهر الأولي؛ US3: _pickAndSend منتقي شهر + buildMonthlyReportMessage؛ فلترة الامتحانات بـeffectiveReportMonth
    ├── settings/settings_page.dart    # US3: _startWhatsappBatchSend منتقي شهر + buildMonthlyReportMessage
    ├── students/student_details_page.dart # US3: _shareMonthlyReport منتقي شهر + buildMonthlyReportMessage؛ تبويب الامتحانات يفلتر بـreportMonth
    ├── exams/exams_page.dart          # US6: _ExamFormSheet منتقي "شهر التقرير"
    ├── home/ (dashboard widget)       # US4: كارت الدفعات → سهمين + عنوان الشهر
    └── ... (export_service.dart)      # US5: _attendanceGrid/_homeworkTable أعمدة من السجلات

lib/services/export_service.dart       # US5 (مذكور فوق) + US6: أي تصدير امتحانات يفلتر بـreportMonth
```

**Structure Decision**: single-project. أكبر جزء: US6 (model + DB + sync + UI). الباقي تعديلات موضعية + helper مشترك.

## Complexity Tracking

> لا انتهاكات — القسم فاضي.
