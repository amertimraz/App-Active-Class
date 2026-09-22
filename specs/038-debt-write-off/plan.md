# Implementation Plan: إسقاط المديونية المتراكمة — زرار مع تأكيد صريح

**Branch**: `038-debt-write-off` | **Date**: 2026-09-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/038-debt-write-off/spec.md`

## Summary

إضافة زرار "إسقاط المديونية" جنب كارت "مديونية متراكمة" في شاشة تفاصيل الطالب. الزرار يفتح نافذة تأكيد توضّح المبلغ الحالي، وبعد التأكيد يُسجَّل `Payment` جديد بمبلغ يساوي `PricingHelper.accumulatedDebt` المحسوبة **لحظة التأكيد الفعلي** (مش وقت فتح النافذة)، وبملاحظة ثابتة قابلة للتمييز برمجيًا (`kDebtWriteOffNote`). ده بيصفّر `accumulatedDebt` تلقائيًا لأنها قيمة محسوبة (مش عمود مخزَّن)، فمفيش أي تعديل مطلوب في مخطط قاعدة البيانات أو في `PricingHelper` نفسه. العملية بتتسجّل عن طريق `DatabaseService.insertPayment()` الموجودة بالفعل، فبتستفيد أوتوماتيك من `_queueSync` (مزامنة وضع الفريق) بدون أي كود مزامنة إضافي. تقارير وتصدير المدفوعات (`report_controller.dart`, `export_service.dart`, `payments_report_page.dart`) لازم تتعدّل عشان تفصل مبلغ الإسقاط عن "المحصَّل فعليًا" وتوسمه بوضوح.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX (state management)، sqflite (تخزين محلي)، `intl` (تنسيق العملة/التاريخ)، `SyncEngine`/`_queueSync` الموجودة (مزامنة وضع الفريق عبر Supabase self-hosted)

**Storage**: SQLite محلي عبر `DatabaseService` — جدول `payments` الموجود بالفعل (بدون تعديل مخطط/migration)

**Testing**: `flutter test` (unit tests بنمط المشروع — راجع `test/dashboard_group_payment_breakdown_test.dart` و`test/cloud_backup_retry_policy_test.dart` كأمثلة)

**Target Platform**: Android (تطبيق موبايل للمدرّسين)

**Project Type**: mobile-app (Flutter، مشروع واحد `lib/` + `test/`)

**Performance Goals**: العملية فورية على جهاز المدرّس (كتابة سطر واحد في SQLite محلي) — لا قيود أداء خاصة، نفس زمن استجابة أي عملية تسجيل دفعة عادية موجودة بالفعل.

**Constraints**: لازم تشتغل offline-first (وضع عدم الاتصال) زي باقي التطبيق — الإسقاط بيتسجل محليًا فورًا، والمزامنة بتحصل لاحقًا عبر `_queueSync` الموجود؛ صفر تعديل على `PricingHelper.accumulatedDebt` نفسها (لازم تفضل دالة حساب لحظي بحتة، بدون حالة مخزَّنة).

**Scale/Scope**: تعديل محدود على 4-5 ملفات موجودة (شاشة تفاصيل الطالب، ملف الثوابت، تقرير/تصدير المدفوعات) + دالة واحدة جديدة في `PaymentController` أو `DatabaseService` — لا كيانات أو جداول جديدة.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

المشروع مفيهوش دستور مُفعَّل (`.specify/memory/constitution.md` لسه على شكل placeholder مش متعبّى) — تُستخدم بدلًا منه ممارسات المشروع القائمة (المرصودة في `HANDOFF.md` والسبيكات السابقة): إعادة استخدام البنية التحتية الموجودة بدل تكرارها، بدون تعديلات مخطط قاعدة بيانات إلا لو ضروري، واختبارات وحدة لأي منطق حسابي جديد. الخطة دي بتلتزم بكل ده: صفر migration، إعادة استخدام `insertPayment`/`_queueSync`/`accumulatedDebt` بالكامل. **لا مخالفات.**

## Project Structure

### Documentation (this feature)

```text
specs/038-debt-write-off/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                          # [MODIFY] إضافة kDebtWriteOffNote
├── controllers/
│   ├── payment_controller.dart                  # [MODIFY] دالة writeOffDebt(student, group, ...)
│   └── report_controller.dart                   # [MODIFY] استبعاد الإسقاط من "المحصَّل فعليًا"
├── services/
│   └── export_service.dart                      # [MODIFY] وسم الإسقاط في تصدير PDF/Excel
├── utils/
│   └── pricing_helper.dart                       # [NO CHANGE] accumulatedDebt تُستخدم كما هي
├── views/
│   ├── students/
│   │   └── student_details_page.dart            # [MODIFY] تفعيل الزرار + نافذة التأكيد
│   └── reports/
│       └── payments_report_page.dart             # [MODIFY] وسم الإسقاط في عرض القائمة

test/
└── debt_write_off_test.dart                       # [NEW] اختبارات وحدة لمنطق الإسقاط
```

**Structure Decision**: مشروع Flutter واحد (mobile-app) بالفعل — الميزة بتضيف/تعدّل ملفات داخل نفس هيكل `lib/` الموجود، بدون أي مشروع أو طبقة جديدة. لا حاجة لـ`contracts/` API خارجية (التطبيق موبايل offline-first بدون واجهة عامة)، لكن هيتوثّق "عقد" داخلي لدالة `writeOffDebt` كواجهة بين الشاشة والـcontroller.

## Complexity Tracking

*لا مخالفات على الدستور/الممارسات القائمة — القسم ده فاضي بالتصميم.*
