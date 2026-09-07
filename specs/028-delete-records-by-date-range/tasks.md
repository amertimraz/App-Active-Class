---
description: "Task list for feature 028 — حذف السجلات بمدى تواريخ"
---

# Tasks: حذف السجلات بمدى تواريخ مع تحكّم كامل في نوع السجلات

**Input**: Design documents from `/specs/028-delete-records-by-date-range/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة لدوال `DatabaseService` الجديدة (فلترة المدى/النوع + المعاينة + الذرّية) بقاعدة in-memory. لا اختبارات widget.

**Organization**: مجمّعة حسب user story. US1 (حذف بمدى+نوع) و US2 (أمان) متشابكان في نفس التدفّق فـPhase 3 يغطّيهما. US3 (مزامنة الفريق) شبه مجاني — تحقّق فقط.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ملفات مختلفة، بلا اعتماد متبادل
- **[Story]**: US1 (حذف) / US2 (أمان) / US3 (مزامنة فريق)

## Path Conventions

تطبيق Flutter مفرد: `lib/` و`test/` في جذر المستودع.

---

## Phase 1: Setup (بنية مشتركة)

- [X] T001 [P] أنشئ `lib/models/deletable_record_type.dart` — `enum DeletableRecordType { attendance, payments, examGrades, exams, homework, reportLogs }` مع خصائص (extension أو switch): `label` (عربي)، `mainTable`، `dateColumn` (`'date'` للأربعة، `'sent_at'` لـreportLogs، `null` لـexamGrades = يُفلتَر بالامتحان الأب)، `pkColumn`، `isTeamSynced` (كلها true عدا `reportLogs`). + `const kBulkDeleteThreshold = 100;` + `const kDeleteConfirmWord = 'حذف';`. راجع [data-model.md](./data-model.md) §1/§3.

**Checkpoint**: الـenum متاح لكل الطبقات.

---

## Phase 2: Foundational (شرط حاجز)

**⚠️ CRITICAL**: الشاشة والكونترولر يعتمدان على دوال `DatabaseService`.

- [X] T002 [US1] في `lib/services/database_service.dart` أضف `Future<Map<DeletableRecordType,int>> countDeletableRecordsInRange({required DateTime from, required DateTime to, required Set<DeletableRecordType> types})` وفق [contracts/delete-records-service.md](./contracts/delete-records-service.md): `fromIso = DateTime(from.y,from.m,from.d).toIso8601String()`، `toIso = ذلك + Duration(days:1)`؛ لكل نوع `SELECT COUNT(*) ... WHERE dateExpr >= ? AND dateExpr < ?`؛ `examGrades` → `exam_id IN (SELECT id FROM exams WHERE date >= ? AND date < ?)`. قراءة فقط.
- [X] T003 [US1] نفس الملف أضف `Future<Map<DeletableRecordType,int>> deleteRecordsInRange({required DateTime from, required DateTime to, required Set<DeletableRecordType> types})`:
  1. اقرأ `(table, pkCol, id, remote_id)` لكل صف مُزامَن هيتحذف (قبل الحذف) — يشمل توابع الامتحانات (`exam_groups`/`exam_grades`/`exam_questions`/`exam_submissions` لامتحانات المدى) لو `exams` مختار.
  2. `db.transaction`: `txn.delete` لكل نوع بشرط المدى؛ توابع الامتحان قبل `exams`؛ `report_logs` بشرط `sent_at` بلا queue؛ اجمع `changes`.
  3. بعد الـcommit: `_notifyChanged()` + `_queueDelete(table, id, remoteId)` لكل صف مُزامَن جُمِع في (1) — **ليس** لـ`report_logs`.
  4. رجّع Map الأعداد الفعلية.
- [X] T004 [P] [US1] أنشئ `test/delete_records_range_test.dart` — قاعدة sqflite ffi in-memory (نمط الاختبارات القائمة أو `sqflite_common_ffi`): 8 حالات من جدول العقد — حذف نوع واحد بمدى لا يمسّ غيره؛ `count == delete`؛ الامتحانات تجرّ توابعها؛ درجات منفصلة تسيب الامتحانات؛ مدى فارغ → أصفار؛ حدود المدى شاملة؛ `report_logs` يُحذف بلا صف outbox حتى مع `teamModeEnabled = true`.

**Checkpoint**: `flutter test test/delete_records_range_test.dart` أخضر.

---

## Phase 3: User Story 1 + 2 — الشاشة والتدفّق الآمن (Priority: P1) 🎯 MVP

**Goal**: المدرّس يفتح الشاشة، يحدّد مدى + أنواع، يشوف معاينة، يأكّد، تُنشأ نسخة احتياطية، يتم الحذف الذرّي.

**Independent Test**: quickstart سيناريوهات 1–7.

### Implementation

- [X] T005 [US1] أنشئ `lib/controllers/delete_records_controller.dart` — `GetxController`: `Rxn<DateTime> fromDate/toDate`، `RxSet<DeletableRecordType> selectedTypes`، `Rxn<Map<...,int>> preview`، `RxBool isRunning`؛ مشتقّات `rangeValid`/`previewTotal`/`needsTypeConfirm`/`canPreview`/`canDelete`؛ `setFrom`/`setTo`/`toggleType` (تمسح preview)؛ `Future<void> runPreview()` → `countDeletableRecordsInRange`. راجع [contracts/delete-records-screen.md](./contracts/delete-records-screen.md).
- [X] T006 [US2] نفس الملف — `Future<DeleteOutcome> runDelete()`: حارس `canDelete`؛ `isRunning=true`؛ `BackupService().createBackup()` → لو `!success` رجّع `DeleteOutcome.backupFailed`؛ `deleteRecordsInRange(...)` داخل try/catch → `DeleteOutcome.error` عند استثناء؛ عند النجاح: حدّث `AttendanceController`/`PaymentController`/`ExamController`/`DashboardController` بحارس `Get.isRegistered`، صفّر `preview` و`selectedTypes`، `isRunning=false`، رجّع `DeleteOutcome.success(deleted)`. + عرّف `DeleteOutcome` (sealed/factory: success/backupFailed/error).
- [X] T007 [US1] أنشئ `lib/views/settings/delete_records_page.dart` — رأس تحذيري ثابت؛ صفّا "من/إلى" (`showDatePicker`)؛ `CheckboxListTile` لكل `DeletableRecordType`؛ زر "معاينة" (`canPreview`)؛ بطاقة معاينة `Obx` (سطر لكل نوع + إجمالي، أو "لا سجلّات مطابقة")؛ تحذير مزامنة الفريق لو `DatabaseService.teamModeEnabled && previewTotal > 500`.
- [X] T008 [US2] نفس الملف — زر "حذف نهائيًا" أحمر (`canDelete`) → `_confirmAndDelete()`: `showDialog` بملخّص الأعداد + المدى؛ لو `needsTypeConfirm` → `TextField` + زر "حذف" معطّل حتى `text.trim() == kDeleteConfirmWord`؛ عند التأكيد → `ProgressDialog` أثناء `isRunning` → معالجة `DeleteOutcome` (success → توست بالأعداد الفعلية + تصفير الشاشة؛ backupFailed → توست إلغاء؛ error → توست خطأ).
- [X] T009 [US1] في `lib/views/settings/settings_page.dart` أضف سطر دخول في قسم البيانات/النسخ الاحتياطي، **منفصل بصريًا** عن "حذف كل البيانات": أيقونة `Icons.auto_delete_outlined`، لون `Color(0xFFF59E0B)`، العنوان "حذف سجلّات بمدى تواريخ"، الوصف "احذف حضور/دفعات/امتحانات فترة معيّنة — مع نسخة احتياطية إجبارية"، `onTap: Get.to(() => const DeleteRecordsPage())`.

**Checkpoint**: US1 + US2 يعملان — MVP قابل للتسليم (وضع فردي).

---

## Phase 4: User Story 3 — مزامنة الحذف في الاتجاهين (Priority: P2)

**Goal**: التأكّد أن الحذف الجماعي ينتشر لكل الفريق ولا يرجع.

**Independent Test**: quickstart سيناريو 8.

### Implementation

- [X] T010 [US3] تحقّق من `deleteRecordsInRange` (T003): كل صف مُزامَن يُدخَل في `sync_outbox` كـ`delete` مع `remote_id` (عبر `_queueDelete`)، والاستدعاء يعمل حتى لو الصف أصلاً جه من جهاز تاني (المساعد) — `_remoteIdOf`/`_queueDelete` بيقروا `COL_SYNC_REMOTE_ID` الموجود على الصف بغضّ النظر عن أصله. أضف اختبار في `delete_records_range_test.dart`: مع `teamModeEnabled = true` وصفوف عليها `remote_id` وهمي → بعد `deleteRecordsInRange`، `sync_outbox` فيه صف `delete` بـ`payload.remote_id` صح لكل صف مُزامَن، وصفر لـ`report_logs`.
- [X] T011 [P] [US3] في `delete_records_page.dart` (T007): فعّل نص تحذير مزامنة الفريق فعليًا عند `teamModeEnabled && previewTotal > 500` (كان مُلمَّحًا في T007 — تأكيد التنفيذ).

**Checkpoint**: الحذف يتزامن في الاتجاهين.

---

## Phase 5: Polish & Cross-Cutting

- [X] T012 [P] شغّل `flutter test` كاملًا + `flutter analyze` — صفر مشاكل جديدة فوق baseline (34 info).
- [ ] T013 نفّذ quickstart سيناريوهات 1–9 (يشمل فشل النسخة الاحتياطية، عدم انحدار الروستر، جهازين للمزامنة).
- [X] T014 [P] حدّث `HANDOFF.md` و`memory/` بملخّص spec 028 (دالتا `DatabaseService`، `DeletableRecordType`، `DeleteRecordsPage`/`Controller`، النسخة الاحتياطية الإجبارية، مزامنة الحذف اتجاهين مجانية، `report_logs` محلي، صفر تغيير schema).

---

## Dependencies & Execution Order

- **Phase 1**: T001 (الـenum) — أساس كل شيء.
- **Phase 2**: T002 → T003 (نفس الملف، T003 يعتمد فهم T002)؛ T004 بعد T002/T003.
- **Phase 3**: بعد Phase 2. T005 → T006 (نفس الملف)؛ T007 → T008 (نفس الملف)؛ T009 مستقل (يعتمد وجود `DeleteRecordsPage` من T007). T005/T006 و T007/T008 يمكن لمطوّرَين.
- **Phase 4**: بعد T003. T010 (اختبار) + T011 (نص واجهة).
- **Phase 5**: بعد كل القصص.

### Parallel Opportunities

- T001 مستقل.
- T004 (اختبار) موازٍ لبناء الشاشة.
- الكونترولر (T005/T006) و الشاشة (T007/T008) لمطوّرَين بعد Phase 2.

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 3)

الـenum + دالتا الخدمة + الشاشة + التدفّق الآمن + سطر الدخول. يغطّي US1 + US2 في الوضع الفردي. مزامنة الفريق (US3) تعمل تلقائيًا عبر `_queueDelete` — Phase 4 تحقّق فقط.

### Incremental

Setup+Foundational → الشاشة والأمان (MVP) → تحقّق مزامنة الفريق → صقل.
