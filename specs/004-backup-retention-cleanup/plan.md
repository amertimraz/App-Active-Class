# Implementation Plan: تنظيف تلقائي للنسخ الاحتياطية الداخلية

**Branch**: `004-backup-retention-cleanup` | **Date**: 2026-08-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-backup-retention-cleanup/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

النسخ الاحتياطية الداخلية (`Documents/backups/*.db`) بتتراكم من غير حد أقصى لأن `BackupService.cleanOldBackups(keepCount: 5)` — الدالة اللي بتنضفها وموجودة بالفعل — مش بتتنادى إلا من زرار يدوي في شاشة الإعدادات. الحل: نادي نفس الدالة تلقائيًا من `AutoBackupService._runBackup()` (نفس المسار اللي بيستدعي بالفعل تنظيف نسخ Downloads الخارجية عبر `_cleanOldExternalBackups`)، مباشرة بعد نجاح `createBackup()`، وقبل أو بعد حفظ نسخة Downloads (ترتيب لا يهم لأنهما مسارين منفصلين). لا حاجة لأي بنية بيانات أو خدمة جديدة — الميزة بالكامل هي "وصلة" مفقودة بين كود موجود بالفعل.

## Technical Context

**Language/Version**: Dart 3 / Flutter (نفس إصدار المشروع الحالي)

**Primary Dependencies**: `dart:io` (File/Directory)، لا مكتبات جديدة — إعادة استخدام `BackupService.cleanOldBackups()` الموجودة بالفعل في `lib/services/backup_service.dart`

**Storage**: ملفات `.db` خام داخل `ApplicationDocumentsDirectory/backups/` (تخزين محلي على الجهاز فقط، لا خوادم)

**Testing**: لا يوجد إطار اختبارات آلي مُفعَّل حاليًا لهذا الجزء من المشروع (تحقق يدوي/على الجهاز، اتساقًا مع بقية مزايا هذا المستودع)

**Target Platform**: Android (تطبيق Flutter، فلافورز `play`/`direct`)

**Project Type**: mobile-app (Flutter/GetX، تعديل داخل خدمتين قائمتين — لا مشروع جديد ولا هيكل جديد)

**Performance Goals**: عملية التنظيف يجب أن تنفَّذ بشكل غير محسوس للمستخدم (بالفعل تعمل داخل نفس دالة الخلفية `_runBackup` التي لا تُظهر أي مؤشر تحميل)

**Constraints**: يجب ألا تحذف نسخة قيد الاستعادة حاليًا؛ فشل حذف ملف واحد يجب ألا يوقف التنظيف أو ينشر استثناء غير مُمسوك (نفس نمط الفشل الصامت المستخدم بالفعل في `_runBackup`/`_cleanOldExternalBackups`)

**Scale/Scope**: تعديل بسيط في مكان استدعاء واحد (`auto_backup_service.dart`) — لا تغييرات في واجهة المستخدم، لا تغييرات في `backup_service.dart` نفسه (الدالة المطلوبة موجودة وجاهزة كما هي)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد ملف دستور (`constitution.md`) مُعبَّأ لهذا المشروع — لا توجد بوابات حوكمة إضافية واجبة التطبيق. تم الاعتماد على أفضل الممارسات القائمة فعليًا في الكود المجاور (النمط المستخدم في تنظيف النسخ الخارجية) كمرجع اتساق.

## Project Structure

### Documentation (this feature)

```text
specs/004-backup-retention-cleanup/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

لا يوجد `contracts/` لهذه الميزة — لا واجهة خارجية (API/CLI) مُعرَّضة؛ التعديل بالكامل داخلي بين خدمتين موجودتين في نفس التطبيق.

### Source Code (repository root)

```text
lib/
├── services/
│   ├── auto_backup_service.dart   # التعديل الوحيد: استدعاء BackupService().cleanOldBackups()
│   │                               # داخل _runBackup() بعد نجاح createBackup()
│   └── backup_service.dart        # بدون تعديل — cleanOldBackups(keepCount: 5) موجودة وجاهزة
└── views/
    └── settings/
        └── settings_page.dart     # بدون تعديل — الزرار اليدوي "حذف النسخ القديمة" يبقى كما هو
```

**Structure Decision**: مشروع Flutter موحّد واحد (mobile-app) — لا توجد خيارات هيكل بديلة مطروحة. التعديل محصور في `lib/services/auto_backup_service.dart` فقط؛ لا ملفات جديدة، لا نقل كود.

## Complexity Tracking

> لا توجد انتهاكات لبوابة الدستور تستوجب تبريرًا — لا يوجد ملف دستور مُعبَّأ، والتغيير المقترح هو أبسط حل ممكن (استدعاء دالة قائمة من مكان إضافي واحد).
