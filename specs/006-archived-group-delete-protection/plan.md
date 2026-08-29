# Implementation Plan: حماية الطلاب المؤرشفين من حذف المجموعة

**Branch**: `006-archived-group-delete-protection` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-archived-group-delete-protection/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

منع حذف أي مجموعة بها طالب مؤرشف واحد على الأقل، عبر فحص واحد مركزي في [GroupController.deleteGroup()](../../lib/controllers/group_controller.dart) — نقطة الاستدعاء الوحيدة لحذف المجموعات من كل شاشات التطبيق (شاشة المجموعات الرئيسية وشاشة تفاصيل المجموعة، مؤكَّد بالفعل عبر grep). لو فيه طلاب مؤرشفون بالمجموعة، الحذف يترفض فورًا (قبل أي استدعاء لقاعدة البيانات) وتظهر رسالة توضح العدد وتوجّه المدرس لشاشة الأرشيف. لا تغيير في مخطط قاعدة البيانات ولا في قيد `ON DELETE CASCADE` الحالي — الحماية على مستوى منطق التطبيق فقط.

## Technical Context

**Language/Version**: Dart 3 / Flutter (نفس إصدار المشروع الحالي)

**Primary Dependencies**: لا مكتبات جديدة — إضافة دالة واحدة في [database_service.dart](../../lib/services/database_service.dart) (استعلام `COUNT` بسيط) واستخدام `ToastHelper` الموجود بالفعل لعرض رسالة الرفض.

**Storage**: قراءة فقط (استعلام `SELECT COUNT(*)` جديد على `TABLE_STUDENTS` بشرط `group_id = ? AND is_archived = 1`) — لا تغيير في المخطط (schema) ولا migration جديد.

**Testing**: لا يوجد إطار اختبارات آلي مُفعَّل حاليًا لهذا الجزء من المشروع — تحقق يدوي/على الجهاز، اتساقًا مع بقية المستودع.

**Target Platform**: Android (تطبيق Flutter، فلافورز `play`/`direct`)

**Project Type**: mobile-app (Flutter/GetX) — تعديل داخل كنترولر وخدمة موجودين، لا شاشات جديدة

**Performance Goals**: الفحص استعلام `COUNT` واحد خفيف قبل الحذف مباشرة — بلا أثر ملحوظ على زمن استجابة عملية الحذف الحالية.

**Constraints**: عدم كسر حذف المجموعات اللي مفيهاش مؤرشفين (FR-004)؛ المنع يجب أن يطبَّق من نقطة مركزية واحدة (`GroupController.deleteGroup`) بدل تكرار الفحص في كل شاشة، لضمان FR-003 (الاتساق) تلقائيًا بلا احتمال نسيان شاشة.

**Scale/Scope**: تعديل 3 نقاط: (1) دالة جديدة `getArchivedStudentCountForGroup(groupId)` في `database_service.dart`، (2) فحص في `GroupController.deleteGroup()` قبل استدعاء الحذف الفعلي، (3) لا حاجة لتعديل الشاشات نفسها — رسالة الخطأ تظهر عبر `ToastHelper.error` الموجود بالفعل في `deleteGroup()` لحالات الفشل الأخرى.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد ملف دستور (`constitution.md`) مُعبَّأ لهذا المشروع — لا توجد بوابات حوكمة إضافية واجبة التطبيق. المرجع الوحيد للاتساق هو نمط "فحص قبل التنفيذ + رسالة واضحة" الموجود بالفعل في هذا الكونترولر نفسه (`ToastHelper.error` عند فشل الحذف) وفي أماكن أخرى بالتطبيق (مثل `LicenseController.checkCanAddStudent`).

## Project Structure

### Documentation (this feature)

```text
specs/006-archived-group-delete-protection/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

لا يوجد `contracts/` لهذه الميزة — لا واجهة خارجية (API/CLI)، منطق داخلي بحت.

### Source Code (repository root)

```text
lib/
├── services/
│   └── database_service.dart      # إضافة getArchivedStudentCountForGroup(groupId)
├── controllers/
│   └── group_controller.dart      # deleteGroup(): فحص العدد قبل الحذف، رفض + رسالة لو >0
└── views/groups/
    ├── groups_page.dart           # بدون تعديل — الرفض يظهر تلقائيًا عبر ToastHelper.error
    │                               # الموجودة بالفعل في deleteGroup() لحالات الفشل
    └── group_details_page.dart    # بدون تعديل — نفس السبب
```

**Structure Decision**: مشروع Flutter موحّد واحد (mobile-app) — لا خيارات هيكل بديلة. التعديل الحقيقي في مكانين فقط (`database_service.dart`, `group_controller.dart`)؛ الشاشتان تستفيدان تلقائيًا من الحماية بدون أي تعديل فيهما، لأن الاثنتين بينادوا نفس `GroupController.deleteGroup()`.

## Complexity Tracking

> لا توجد انتهاكات لبوابة الدستور تستوجب تبريرًا — لا يوجد ملف دستور مُعبَّأ. أبسط حل ممكن: فحص مركزي واحد في نقطة الاستدعاء المشتركة الوحيدة، بدل تكرار المنطق في كل شاشة.
