---

description: "Task list for backup retention cleanup feature"
---

# Tasks: تنظيف تلقائي للنسخ الاحتياطية الداخلية

**Input**: Design documents from `/specs/004-backup-retention-cleanup/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md)

**Tests**: لم تُطلَب اختبارات آلية صراحةً في `spec.md` — لا يوجد إطار اختبارات مُفعَّل حاليًا في هذا الجزء من المستودع، فالتحقق عبر [quickstart.md](quickstart.md) اليدوي/على الجهاز.

**Organization**: الميزة صغيرة بما يكفي لتُنفَّذ كقصة واحدة (US1) مع خطوة تحقق مباشرة لـ US2 — لا توجد مرحلة Setup أو Foundational منفصلة لأن كل البنية التحتية (سقف الاحتفاظ، دالة الحذف، الحماية من الاستثناءات) موجودة بالفعل في `backup_service.dart`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: يمكن تنفيذها بالتوازي (ملفات مختلفة، لا اعتمادية)
- **[Story]**: US1 أو US2 حسب قصة المستخدم في spec.md

## Path Conventions

مشروع Flutter موحّد واحد — المسارات نسبةً لجذر `C:\repo\active_class`.

---

## Phase 1: User Story 1 - النسخ الداخلية بتتنظف تلقائيًا زي الخارجية (Priority: P1) 🎯 MVP

**Goal**: بعد كل نسخة احتياطية داخلية تلقائية جديدة، يتم تلقائيًا حذف أي نسخ زائدة عن سقف الاحتفاظ (5)، من غير تدخل يدوي من المدرس.

**Independent Test**: محاكاة أكتر من 5 تغييرات بيانات متتالية (بفاصل debounce 20 ثانية بين كل واحدة)، ثم فتح شاشة "إدارة النسخ الاحتياطية" والتأكد أن العدد المعروض لا يتجاوز 5 — طبقًا لسيناريو 1 في [quickstart.md](quickstart.md).

### Implementation for User Story 1

- [X] T001 [US1] في [lib/services/auto_backup_service.dart](../../lib/services/auto_backup_service.dart)، داخل الدالة `_runBackup()`: بعد نجاح `BackupService().createBackup()` (نفس الكتلة `if (result.success) { ... }`)، أضف استدعاء `await BackupService().cleanOldBackups();` لتنظيف النسخ الداخلية الزائدة عن السقف الافتراضي (5) — بنفس الأسلوب المستخدم بالفعل لتنظيف نسخ Downloads الخارجية عبر `_cleanOldExternalBackups` في نفس الكتلة.
- [X] T002 [US1] تأكد أن الاستدعاء الجديد ملفوف ضمن `try/catch` الموجودة بالفعل في `_runBackup()` (الفشل الصامت الحالي) بحيث فشل التنظيف لا يوقف بقية تدفق `_runBackup()` أو يظهر كخطأ للمستخدم — لا حاجة لتعديل بنية `try/catch` الحالية، فقط تأكيد أن مكان الاستدعاء الجديد داخلها.

**Checkpoint**: النسخ الداخلية تتنظف تلقائيًا الآن؛ نفّذ سيناريو 1 من quickstart.md للتحقق على جهاز حقيقي.

---

## Phase 2: User Story 2 - التنظيف التلقائي ميأثرش على قدرة المدرس على الاستعادة (Priority: P2)

**Goal**: التأكد أن أحدث نسخة تفضل دائمًا متاحة للاستعادة، وأن التنظيف لا يعطّل أي مسار موجود (الزر اليدوي، الاستعادة، فشل حذف ملف واحد).

**Independent Test**: بعد تنفيذ US1 وتجاوز السقف، افتح شاشة "إدارة النسخ الاحتياطية"، تأكد أن أحدث نسخة موجودة، واستعِدها بنجاح — طبقًا لسيناريو 2 و3 في [quickstart.md](quickstart.md).

### Verification for User Story 2

هذه القصة لا تتطلب أي تعديل كود إضافي — `cleanOldBackups()` الموجودة بالفعل تحافظ على الأحدث وتحذف الأقدم فقط (مرتبة حسب `date` تنازليًا)، و`deleteBackup()` بها بالفعل معالجة صامتة للفشل (راجع [research.md](research.md) القرار 3 و4). المطلوب هنا تحقق يدوي فقط:

- [ ] T003 [US2] نفّذ سيناريو 2 من [quickstart.md](quickstart.md) على جهاز/محاكي: تأكد أن أحدث نسخة موجودة في القائمة بعد تجاوز السقف، وأن استعادتها تنجح بشكل طبيعي.
- [ ] T004 [US2] نفّذ سيناريو 3 من [quickstart.md](quickstart.md): تأكد أن الزرار اليدوي "حذف النسخ القديمة" في شاشة الإعدادات ما زال يعمل بشكل طبيعي بعد إضافة T001 (لا تعارض بين الاستدعاءين لأنهما يستدعيان نفس الدالة الموجودة).

**Checkpoint**: كل القصص (US1 + US2) شغالة ومتحقق منها.

---

## Phase 3: Polish

- [X] T005 [P] راجع التعليق التوضيحي أعلى `_cleanOldExternalBackups` في [lib/services/auto_backup_service.dart](../../lib/services/auto_backup_service.dart) (السطور 95-100) وأضف سطرًا موازيًا يوضح أن النسخ الداخلية تُنظَّف الآن أيضًا تلقائيًا عبر `BackupService().cleanOldBackups()`، حفاظًا على نفس مستوى التوثيق الداخلي في الملف.
- [X] T006 شغّل `flutter analyze` للتأكد من عدم وجود أخطاء/تحذيرات جديدة ناتجة عن التعديل.

---

## Dependencies & Execution Order

- **US1 (Phase 1)**: لا اعتماديات — التغيير الأساسي والوحيد في الكود.
- **US2 (Phase 2)**: يعتمد على اكتمال US1 (تحقق فقط، لا كود جديد).
- **Polish (Phase 3)**: يعتمد على اكتمال US1.

### Parallel Opportunities

- T005 يمكن تنفيذها بالتوازي مع T003/T004 (ملفات/أنشطة مختلفة).
- T001 و T002 في نفس الملف ونفس الكتلة البرمجية — تُنفَّذان معًا كتعديل واحد فعليًا، وليس بالتوازي.

## Implementation Strategy

### MVP First (User Story 1 فقط)

1. نفّذ T001 وT002 (تعديل سطر واحد فعليًا في `auto_backup_service.dart`).
2. تحقق يدويًا عبر سيناريو 1 في quickstart.md.
3. هذا وحده يحل المشكلة الأساسية (تراكم النسخ الداخلية بلا حد).

### Incremental Delivery

1. US1 → يحل جوهر المشكلة.
2. US2 → تحقق أن لا شيء انكسر (الاستعادة، الزر اليدوي، مقاومة الفشل).
3. Polish → توثيق + `flutter analyze`.

## Notes

- الميزة بالكامل تتلخص في **سطر كود واحد جديد** + تحقق يدوي — لا نماذج بيانات جديدة، لا شاشات جديدة، لا اعتماديات جديدة.
- كل الحماية المطلوبة (فشل حذف صامت، ترتيب الأحدث أولاً) موجودة بالفعل في `BackupService.cleanOldBackups()`/`deleteBackup()` ولا تحتاج تعديلاً.
