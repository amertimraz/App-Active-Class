---

description: "Task list for feature implementation"
---

# Tasks: نسخ احتياطي سحابي (Google Drive شخصي لكل مدرّس)

**Input**: Design documents from `/specs/037-cloud-backup/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cloud-backup-operations.md, quickstart.md

**Tests**: اختبار وحدة إلزامي واحد لمنطق قرار إعادة المحاولة الصرف (بلا شبكة فعلية). عمليات Drive API الفعلية (رفع/تحميل/حذف) بتحتاج حساب Google حقيقي — تحقّق يدوي عبر quickstart.md بس، مش اختبار آلي (بنفس منطق الاختبارات اليدوية لكل مزامنة/Supabase في المشروع).

**Organization**: Tasks مجمّعة حسب قصة المستخدم من spec.md.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: قابلة للتنفيذ بالتوازي (ملفات مختلفة، بلا اعتماديات)
- **[Story]**: US1/US2/US3/US4 من spec.md
- كل Task فيها مسار الملف بالظبط

## Path Conventions

مشروع Flutter واحد — `lib/` في جذر `active_class/`، اختبارات في `test/`.

---

## Phase 1: Setup

**⚠️ إجباري وبيحصل مرة واحدة — قبل أي كود، وخارج نطاق `flutter`/الكود تمامًا (راجع research.md #3).**

- [X] T001 أنشئ/استخدم مشروع Google Cloud، فعّل **Google Drive API**، واضبط **OAuth consent screen** (اسم التطبيق، إيميل دعم، نطاق `drive.file` مُضاف).
- [X] T002 استخرج بصمة **SHA-1** (مش SHA-256) لنفس كيستور الـrelease الحالي (`android/key.properties`) عبر `keytool -list -v -keystore <keystore> -alias <alias>`، وأنشئ **Android OAuth client ID** في Google Cloud Console بـ`com.amertimraz.activeclass` + الـSHA-1 ده.
- [X] T003 [P] أضف تبعية `google_sign_in` لـ`pubspec.yaml` (بلا `googleapis`/`googleapis_auth` — راجع research.md #2)، شغّل `flutter pub get`.

**Checkpoint**: `google_sign_in` جاهزة للاستخدام في الكود — بلا الخطوتين T001/T002، أي محاولة تسجيل دخول هتفشل بـ`DEVELOPER_ERROR` على الـrelease.

---

## Phase 2: Foundational (Blocking Prerequisites)

**الهدف**: هيكل الخدمة الأساسي + تخزين حالة الربط محليًا — كل الـuser stories بتعتمد عليه.

**⚠️ CRITICAL**: لازم يخلص قبل أي عمل في أي user story.

- [X] T004 عرّف ثوابت الإعدادات الجديدة (`cloud_backup_linked_email`, `cloud_backup_last_attempt_at`, `cloud_backup_pending_retries`) في `lib/config/constants.dart` (نفس نمط `SETTING_*` الموجود).
- [X] T005 أنشئ `lib/services/google_drive_backup_service.dart` — كلاس singleton (نفس نمط `AuthService`/`BackupService`) فيه `GoogleSignIn` مهيّأ بنطاق `drive.file` بس، ودوال هيكلية فاضية بس (`isLinked`, `linkedEmail`) بتقرا من `DatabaseService.getSetting` (T004) — التنفيذ الفعلي لباقي الدوال في المراحل الجاية.
- [X] T006 [P] أنشئ `lib/controllers/google_drive_backup_controller.dart` — GetX controller بـ`RxBool isLinked`, `RxString? linkedEmail`, `RxList` لقائمة النسخ السحابية (فاضية مبدئيًا) — بيقرا الحالة من `GoogleDriveBackupService` (T005) وقت `onInit`.

**Checkpoint**: الهيكل الأساسي موجود ومُسجَّل في GetX — التنفيذ الفعلي لعمليات Drive يبدأ من US1.

---

## Phase 3: User Story 1 - ربط حساب Google Drive الشخصي (Priority: P1) 🎯 MVP جزئي

**الهدف**: المدرّس يقدر يربط/يلغي ربط حساب Google، ويشوف حالة الربط بوضوح.

**اختبار مستقل**: من شاشة الإعدادات، فعّل النسخ السحابي واختر حساب Google، وتأكد إن الحالة بقت "مفعّل" مع إيميل الحساب ظاهر.

### Implementation for User Story 1

- [X] T007 [US1] نفّذ `GoogleDriveBackupService.linkAccount()` (`lib/services/google_drive_backup_service.dart`) — `GoogleSignIn.signIn()`، عند النجاح خزّن `cloud_backup_linked_email` (T004)، رجّع `true`/`false` (عقد #1 في contracts/cloud-backup-operations.md).
- [X] T008 [US1] نفّذ `GoogleDriveBackupService.unlinkAccount()` — `GoogleSignIn.signOut()` + مسح `cloud_backup_linked_email` محليًا بس (بلا لمس أي ملف على Drive — عقد #2).
- [X] T009 [US1] اربط `linkAccount`/`unlinkAccount` بـ`GoogleDriveBackupController` (T006) — تحديث `isLinked`/`linkedEmail` فور النجاح.
- [X] T010 [US1] أضف قسم "النسخ السحابية (Google Drive)" في شاشة إدارة النسخ الاحتياطي (`lib/views/settings/settings_page.dart`، بجانب قسم النسخ المحلي الموجود) — يعرض حالة الربط (مفعّل + الإيميل / غير مفعّل)، وزرار "تفعيل"/"إلغاء الربط" حسب الحالة.

**Checkpoint**: US1 شغالة ومستقلة — الربط/إلغاء الربط بيشتغلوا ويعكسوا حالتهم في الواجهة فورًا.

---

## Phase 4: User Story 2 - رفع تلقائي بلا تدخّل (Priority: P1)

**الهدف**: نسخة احتياطية محلية دورية جديدة تترفع تلقائيًا للحساب المربوط، مع إعادة محاولة محدودة عند الفشل.

**اختبار مستقل**: بعد ربط الحساب، سيب نسخة محلية دورية تتعمل، وتأكد إنها اترفعت للدرايف بلا أي ضغطة زرار.

### Tests for User Story 2

- [X] T011 [P] [US2] اكتب `test/cloud_backup_retry_policy_test.dart` — دالة صرفة `shouldAttemptCloudUpload({required int pendingRetries, required int maxRetries})` (أو مشابه): تحت الحد → `true`، عند/فوق الحد → `false`؛ حالات حدّية (0، الحد بالظبط، فوقه). الاختبار المفروض يفشل قبل T012.

### Implementation for User Story 2

- [X] T012 [P] [US2] عرّف دالة `shouldAttemptCloudUpload(...)` الصرفة (من T011) في `lib/services/google_drive_backup_service.dart` أو ملف `lib/utils/cloud_backup_retry_policy.dart` جديد (بنفس نمط `sync_retry_policy.dart`).
- [X] T013 [US2] نفّذ `GoogleDriveBackupService.uploadBackup({required bool isAutomatic})` (عقد #3): لو مش مربوط → فشل فوري بلا شبكة؛ `signInSilently()`؛ `BackupService().createBackup()` لبناء الملف؛ رفع بطلب واحد كامل (`files.create` multipart) لـGoogle Drive API v3 عبر `dio`؛ عند النجاح صفّر `cloud_backup_pending_retries` ونظّف الأقدم لو تجاوز 5 (T014)؛ عند الفشل زوّد `cloud_backup_pending_retries` (محكوم بـT012).
- [X] T014 [US2] نفّذ منطق "تنظيف الأقدم عند تجاوز 5 نسخ" داخل `uploadBackup` (بعد نجاح الرفع) — `listCloudBackups()` (تُبنى فعليًا في US3، ممكن نسخة مبدئية هنا) + حذف الأقدم لو العدد > 5.
- [X] T015 [US2] في `lib/services/auto_backup_service.dart`، بعد نجاح `createBackup()` المحلي، نادِ `GoogleDriveBackupService().uploadBackup(isAutomatic: true)` بشكل **fire-and-forget** (بلا `await` يعطّل تسلسل النسخ المحلي، بلا رفع استثناء لأعلى — عقد #3 معيار القبول).

**Checkpoint**: US1 + US2 شغالين مع بعض — رفع تلقائي حقيقي بعد كل نسخة محلية دورية، بحد إعادة محاولة معقول.

---

## Phase 5: User Story 3 - استرجاع كامل على جهاز جديد (Priority: P1)

**الهدف**: المدرّس يقدر يسجّل دخول بنفس حساب Google على جهاز جديد ويسترجع أي نسخة سحابية.

**اختبار مستقل**: اعمل نسخة سحابية، امسح بيانات التطبيق (أو جهاز تاني)، سجّل دخول بنفس الحساب، استرجع — تأكد إن كل البيانات رجعت.

### Implementation for User Story 3

- [X] T016 [US3] نفّذ `GoogleDriveBackupService.listCloudBackups()` (عقد #4) — `files.list` (Drive API v3) مفلترة على ملفات التطبيق، مرتبة تنازليًا حسب `createdTime`؛ رجّع `List<CloudBackupEntry>` (id/name/createdTime/size — راجع data-model.md).
- [X] T017 [US3] نفّذ `GoogleDriveBackupService.restoreFromCloud(String fileId)` (عقد #5) — تحميل الملف (`files.get?alt=media`) لمسار مؤقت (`getTemporaryDirectory()`)؛ عند نجاح التحميل بس، نادِ `BackupService().restoreBackup(tempPath)` الموجودة بالفعل؛ احذف الملف المؤقت بعد كده (نجح أو فشل الاسترجاع).
- [X] T018 [US3] في `GoogleDriveBackupController` (T006)، اربط `listCloudBackups`/`restoreFromCloud` + حالة تحميل (`RxBool restoring`).
- [X] T019 [US3] في `settings_page.dart` (قسم US1 من T010)، أضف "استرجاع من السحابة" — قائمة النسخ (تاريخ + حجم) + حوار تحذير صريح قبل التنفيذ (تاريخ النسخة + "هيستبدل بياناتك الحالية") + استدعاء `_reloadAllControllers()` الموجودة بعد نجاح الاستعادة (نفس تسلسل الاستعادة المحلية الحالي).
- [X] T020 [US3] تعامل مع حالة "حساب مختلف/مفيش نسخ" (سيناريو 4 في quickstart.md) — رسالة واضحة لو `listCloudBackups()` رجعت قائمة فاضية، بدل شاشة فاضية بلا تفسير.

**Checkpoint**: US1 + US2 + US3 شغالين — دورة الحماية الأساسية كاملة (ربط → رفع تلقائي → استرجاع على جهاز جديد).

---

## Phase 6: User Story 4 - رفع/استرجاع يدوي وإدارة النسخ (Priority: P2)

**الهدف**: رفع يدوي فوري + حذف نسخة سحابية معيّنة.

**اختبار مستقل**: من شاشة النسخ الاحتياطي، دوس "رفع للسحابة الآن" وتأكد إنها ظهرت في القائمة، واحذف نسخة وتأكد إنها اختفت.

### Implementation for User Story 4

- [X] T021 [US4] أضف زرار "رفع نسخة للسحابة الآن" في `settings_page.dart` (قسم US1) — بينادي `uploadBackup(isAutomatic: false)` مباشرة (T013) ويعرض نجاح/فشل واضح، ويحدّث القائمة فورًا.
- [X] T022 [US4] نفّذ `GoogleDriveBackupService.deleteCloudBackup(String fileId)` (عقد #6) — `files.delete`، بعد تأكيد صريح في الواجهة (حوار مشابه لحذف النسخة المحلية الموجود بالفعل).
- [X] T023 [US4] أضف زرار حذف لكل صف في قائمة النسخ السحابية (T019) — بينادي `deleteCloudBackup` (T022) ويحدّث القائمة فورًا بعد النجاح.

**Checkpoint**: كل الـuser stories الأربعة شغالة مع بعض.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T024 [P] شغّل `flutter analyze` وتأكد إن كل الملفات الجديدة/المعدَّلة بلا مشاكل جديدة (نفس الـbaseline القديم).
- [X] T025 [P] شغّل `flutter test test/cloud_backup_retry_policy_test.dart` وباقي `flutter test` للتأكد من عدم وجود انحدار.
- [ ] T026 نفّذ سيناريوهات `quickstart.md` (1–7) يدويًا على جهاز حقيقي بحساب Google حقيقي — **لازم APK release موقّع بنفس الكيستور** (راجع research.md #3 — تسجيل الدخول بيفشل على توقيع مختلف).
- [X] T027 حدّث `HANDOFF.md` بملخص الميزة بعد التنفيذ والتحقق (نفس نمط باقي الـspecs)، مع توثيق واضح إن الميزة دي **مش** محتاجة أي migration.sql أو لمسة VPS (استثناء عن كل الـspecs السابقة).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: إجباري ويدوي بالكامل (T001/T002) — يمنع أي اختبار حقيقي لـ`google_sign_in` على الـrelease، لكن **مش بيمنع كتابة الكود نفسه** (T003 فصاعدًا ممكن تتكتب بالتوازي مع انتظار موافقة/إعداد Google Cloud).
- **Foundational (Phase 2)**: يعتمد على T003 (التبعية مضافة) — **يمنع** كل الـuser stories.
- **User Story 1 (Phase 3)**: يعتمد على Phase 2. أول جزء قابل للتجربة الفعلية (يحتاج T001/T002 مكتملين للاختبار الحقيقي).
- **User Story 2 (Phase 4)**: يعتمد على US1 (محتاج `isLinked`/`linkAccount` شغّالين).
- **User Story 3 (Phase 5)**: يعتمد على US1 (نفس الحساب) — مستقلة عن US2 منطقيًا (ممكن تتنفّذ بالتوازي) لكن الاختبار الفعلي محتاج نسخة مرفوعة بالفعل (من US2 أو رفع يدوي من US4).
- **User Story 4 (Phase 6)**: يعتمد على US2 (`uploadBackup`) وUS3 (`listCloudBackups`/قائمة العرض) — أضعف استقلالية، عمليًا آخر واحدة تتنفّذ.
- **Polish (Phase 7)**: بعد خلاص كل الـstories.

### Parallel Opportunities

- T001/T002 (Google Cloud Console، يدوي) ممكن يحصل بالتوازي مع T003 (كود) — بلا اعتماد فعلي بينهم لحد أول اختبار حقيقي.
- T005 وT006 (Phase 2) قابلين للتوازي (ملفات مختلفة).
- T011 (اختبار الوحدة) بالتوازي مع T012 (لو اتكتب أول، TDD).
- T024 وT025 (Polish) بالتوازي.

---

## Implementation Strategy

### MVP First (User Story 1 + 2 فقط)

1. Phase 1 (Setup، يدوي) — T001–T003.
2. Phase 2 (Foundational) — T004–T006.
3. Phase 3 (US1) — T007–T010.
4. Phase 4 (US2) — T011–T015.
5. **قف وتحقّق**: سيناريو ٢ من quickstart.md (رفع تلقائي حقيقي).
6. دي أصلًا نص القيمة — المدرّس بقى عنده نسخ سحابي تلقائي، حتى لو الاستعادة (US3) لسه معمولاش.

### Incremental Delivery

1. Foundational → US1 (ربط الحساب) → US2 (رفع تلقائي) = **حماية فعلية بدون واجهة استرجاع بعد** (نسخ موجودة على Drive، جاهزة للاستخدام لاحقًا حتى لو US3 اتأخّرت).
2. + US3 (استرجاع كامل) = **الميزة كاملة القيمة** (MVP الحقيقي حسب الـspec).
3. + US4 (إدارة يدوية) = تحسين تحكّم إضافي.
4. Polish.
