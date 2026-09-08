---
description: "Task list for feature 032 — إلغاء حصة اليوم وتعويضها"
---

# Tasks: إلغاء حصة اليوم وتعويضها

**Input**: Design documents from `/specs/032-cancel-makeup-session/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة فقط للدوال النقية (`resolveHasSession` / `expectedCountDelta`) و`SessionOverride.toMap/fromMap`. الباقي تحقّق يدوي (quickstart + جهازين).

**Organization**: US1 (إلغاء) + US2 (تعويض) كلاهما P1 ويتشاركان نفس الأساس (الجدول + النموذج + الجدولة override-aware). US3 (سجل الطالب) + US4 (مزامنة) P2.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

تطبيق Flutter مفرد + خادم Supabase على VPS. المسارات من جذر المستودع.

---

## Phase 1: Setup

- [X] T001 في [lib/config/constants.dart](../../lib/config/constants.dart): أضف `const String TABLE_SESSION_OVERRIDES = 'session_overrides';` وغيّر `DATABASE_VERSION` من 28 إلى 29.

---

## Phase 2: Foundational (يَحجُب كل قصص المستخدم)

### النموذج + الدوال النقية

- [X] T002 [P] أنشئ [lib/models/session_override_model.dart](../../lib/models/session_override_model.dart) وفق [contracts/session-override-model-db.md](./contracts/session-override-model-db.md): `enum SessionOverrideType { cancelled, makeup, extra }` + class `SessionOverride` (`id?, groupId, date, type, compensatesDate?, note?, createdAt?`) + `toMap`/`fromMap` (تاريخ ↔ `YYYY-MM-DD`، type ↔ `.name`، نوع غير معروف → `cancelled` + `debugPrint`) + `copyWith`.
- [X] T003 [P] أنشئ [lib/utils/session_schedule_resolver.dart](../../lib/utils/session_schedule_resolver.dart) وفق [contracts/schedule-override-aware.md](./contracts/schedule-override-aware.md): `bool resolveHasSession({required bool scheduleSays, SessionOverrideType? overrideType})` + `int expectedCountDelta({required Iterable<SessionOverride> overridesInRange, required bool Function(DateTime) scheduleHasDay})`.
- [X] T004 [P] أنشئ [test/session_override_model_test.dart](../../test/session_override_model_test.dart): round-trip `toMap`/`fromMap` لكل نوع، تاريخ منزوع الوقت، `compensatesDate` null/قيمة، نوع غير معروف → `cancelled`.
- [X] T005 [P] أنشئ [test/session_schedule_override_test.dart](../../test/session_schedule_override_test.dart): `resolveHasSession` (cancelled→false، makeup/extra→true، null+true→true، null+false→false)؛ `expectedCountDelta` (cancelled على يوم جدول→-1، cancelled على غيره→0، makeup على غير يوم جدول→+1، makeup على يوم جدول→0، مزيج→المجموع، فارغ→0).

### قاعدة البيانات المحلية

- [X] T006 في [lib/services/database_service.dart](../../lib/services/database_service.dart): أضف ثابتَي SQL (`_sessionOverridesTableSql` مع FK `ON DELETE CASCADE` + `_sessionOverridesIndexSql` = `UNIQUE INDEX ... (group_id, date)`). نادِهما في `_createTables`، وفي `_onUpgrade` أضف `if (oldVersion < 29) { try { ... } catch (_) {} }`. استورد `session_override_model.dart`.
- [X] T007 في [lib/services/database_service.dart](../../lib/services/database_service.dart): أضف CRUD وفق [contracts/session-override-model-db.md](./contracts/session-override-model-db.md): `getAllSessionOverrides()`، `getSessionOverride(groupId, day)`، `insertSessionOverride(o)` (+ `_queueSync`)، `deleteSessionOverride(id)` (جلب remote_id قبل الحذف + `_queueDelete`).
- [X] T008 في [lib/services/database_service.dart](../../lib/services/database_service.dart): أضف `countAttendanceForGroupOnDay(groupId, day)`، `attendanceForGroupOnDay(groupId, day)` (`date LIKE 'YYYY-MM-DD%'`)، و`deleteAttendanceForGroupOnDay(groupId, day)` (داخل `transaction` + `_queueDelete` لكل صف بعد الـcommit).

### المزامنة

- [X] T009 في [lib/services/sync_engine.dart](../../lib/services/sync_engine.dart): سجّل `TABLE_SESSION_OVERRIDES` في `_tables` + `_coreTables` + `_pkCol` (`'id'`) + `_buildRemoteRow` (يحوّل `group_id` المحلي → `group_remote_id` uuid زي ربط الحضور بالطالب؛ يمرّر `date`/`type`/`compensates_date`/`note`) + `_toLocalMap` (عكسي) + `_applyRemoteRow` + تحديث UI (`_refreshUiForTable`).
- [X] T010 في [lib/services/sync_engine.dart](../../lib/services/sync_engine.dart): في `_applyRemoteRow` لـ`TABLE_SESSION_OVERRIDES` أضف كتلة dup على المفتاح المنطقي `(group_id, date)` تستدعي `_reconcileDuplicate(db, table, pkCol, dup.first, remote, localMap)` (spec 031) بدل الإدراج الأعمى.

### حالة runtime

- [X] T011 أنشئ [lib/controllers/session_override_controller.dart](../../lib/controllers/session_override_controller.dart) وفق [contracts/schedule-override-aware.md](./contracts/schedule-override-aware.md): `RxList<SessionOverride> overrides` + `RxBool loadedOnce` + `load()` + `overrideFor(groupId, day)` + `overridesForGroupInRange(...)` + `cancelledForGroup(groupId)` + طفرات `cancelToday`/`addMakeup`/`addExtra`/`removeOverride` (ترجع `String?` رسالة خطأ أو null؛ تطبّق قواعد قرار 7).
- [X] T012 في [lib/main.dart](../../lib/main.dart) (أو bindings الأساسية): `Get.put(SessionOverrideController(), permanent: true)`.

### migration الخادم

- [X] T013 [P] أنشئ [supabase/migration_session_overrides.sql](../../supabase/migration_session_overrides.sql) وفق [research.md](./research.md) قرار 3: `CREATE TABLE public.session_overrides (...)` + `enable row level security` + 3 سياسات (`select`/`insert`/`update` = `is_team_member(team_id) AND is_team_license_active(team_id)`) + `replica identity full` + `alter publication supabase_realtime add table session_overrides` + `trg_set_updated_at`.
- [X] T014 طبّق الـmigration عبر SSH: `ssh -i ~/.ssh/ovh_key root@active-class.online "docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1" < supabase/migration_session_overrides.sql`. تحقّق: الجدول موجود، ضمن `supabase_realtime`، وله `trg_set_updated_at`.

**Checkpoint**: النموذج + الجدول (محلي + خادم) + الـcontroller + المزامنة جاهزة. القصص تقدر تبدأ.

---

## Phase 3: User Story 1 — إلغاء حصة اليوم (Priority: P1)

**Goal**: المدرّس يلغي حصة النهارده لمجموعة؛ تختفي من المتوقّع ومن قائمة اليوم، والحضور المسجّل يُمسح بتأكيد.

**Independent Test**: quickstart سيناريوهات 1 + 2 + 3.

- [X] T015 [US1] في [lib/controllers/attendance_controller.dart](../../lib/controllers/attendance_controller.dart): اكتسب `SessionOverrideController` عبر `Get.find` (مع `Get.isRegistered` guard). عدّل `groupHasSessionOnDay(group, day)` لتصير override-aware عبر `resolveHasSession(scheduleSays: <القديم>, overrideType: so?.overrideFor(group.id!, day)?.type)`.
- [X] T016 [US1] في [lib/controllers/attendance_controller.dart](../../lib/controllers/attendance_controller.dart): عدّل `_countExpectedForGroup(group, range)` لإضافة `expectedCountDelta(...)` بعد العدّ القديم ثم `clamp(0, ...)`. تحقّق أن `getExpectedSessionsPerGroup` و`groupsForDay` يمرّان عبر الدوال المعدّلة.
- [X] T017 [US1] في [lib/views/attendance/attendance_page.dart](../../lib/views/attendance/attendance_page.dart): أضف عنصر "إلغاء حصة اليوم" في قائمة "⋮" (يظهر لو الجدول يقول فيه حصة و لا يوجد `cancelled`). حوار تأكيد؛ لو `countAttendanceForGroupOnDay > 0` → حوار "هيتمسح N"؛ عند التأكيد `deleteAttendanceForGroupOnDay` ثم `soCtrl.cancelToday(...)` ثم تحديث `AttendanceController`.
- [X] T018 [US1] في [lib/views/attendance/attendance_page.dart](../../lib/views/attendance/attendance_page.dart): لو يوجد `cancelled` لليوم المحدّد → استبدل قائمة الطلاب ببانر "الحصة اتلغت النهارده" + زر "تراجع عن الإلغاء" (→ `soCtrl.removeOverride`).
- [X] T019 [US1] في [lib/views/attendance/attendance_page.dart](../../lib/views/attendance/attendance_page.dart): `soCtrl.load()` عند فتح الشاشة (نمط spec 029). طبّق قيد الإذن (نفس منطق تعديل الحضور القائم في الشاشة).

**Checkpoint**: الإلغاء + التراجع يعملان؛ الأعداد المتوقّعة صحيحة.

---

## Phase 4: User Story 2 — حصة تعويضية / إضافية (Priority: P1)

**Goal**: المدرّس يضيف حصة في يوم (تعويضًا عن حصة أُلغيت، أو إضافية)، فتظهر شاشة حضور كاملة لذلك اليوم وتُحتسب في الفوترة كحصة عادية.

**Independent Test**: quickstart سيناريوهات 4 + 5.

- [X] T020 [US2] في [lib/views/attendance/attendance_page.dart](../../lib/views/attendance/attendance_page.dart): عنصر "إضافة حصة تعويضية / إضافية" في "⋮" → حوار: اختيار النوع (`makeup`/`extra`)؛ لو `makeup` → منتقي تاريخ "تعويض عن" + تحقّق (قرار 7: يُرفض لو التاريخ عليه `cancelled` مختلف المجموعة؟ لا — يُرفض لو التاريخ الحالي عليه استثناء). يستدعي `soCtrl.addMakeup`/`addExtra`.
- [X] T021 [US2] في [lib/views/attendance/attendance_page.dart](../../lib/views/attendance/attendance_page.dart): في يوم عليه `makeup`/`extra` اعرض قائمة طلاب المجموعة كاملة (عبر `groupHasSessionOnDay` = true) مع لِيبل أعلى القائمة «حصة معوّضة عن {تاريخ}» / «حصة إضافية».
- [ ] T022 [US2] تحقّق يدويًا أن الفوترة per-session صحيحة بلا تغيير كود (`PricingHelper` سليم): حضور في حصة تعويضية = `monthlyDue` يعدّه؛ حذف حضور حصة ملغاة = المستحق ينزل. (لا كود — فحص فقط.)

**Checkpoint**: التعويض/الإضافي يعمل؛ الفوترة صحيحة تلقائيًا.

---

## Phase 5: User Story 3 — سجل الطالب (Priority: P2)

**Goal**: تفاصيل الطالب وبوابة الأهل تعرضان الإلغاء والتعويض كعناصر عرض دون احتسابها في نِسب الحضور.

**Independent Test**: quickstart سيناريو 6.

- [X] T023 [US3] في [lib/views/students/student_details_page.dart](../../lib/views/students/student_details_page.dart): ادمج `soCtrl.cancelledForGroup(student.currentGroupId)` كعناصر عرض "الحصة اتلغت — {تاريخ}" في قسم سجل الحضور، مرتّبة تنازليًا بالتاريخ، غير محتسَبة في النِسب. أضف لِيبل «• حصة معوّضة»/«• حصة إضافية» على صفوف الحضور المطابقة تاريخيًا لاستثناء مجموعة الطالب.
- [ ] T024 [US3] في [lib/services/parent_portal_service.dart](../../lib/services/parent_portal_service.dart): في بناء `attendanceHistory` (المدفوعة) أضف عناصر `cancelled` لمجموعة الطالب كـ«تم إلغاء الحصة» + لِيبل «حصة تعويضية» على الصفوف المطابقة. لا تغيير في حسابات المبالغ.

**Checkpoint**: السجل يعرض الإلغاء/التعويض بوضوح دون تشويه الإحصاء.

---

## Phase 6: User Story 4 — مزامنة الفريق (Priority: P2)

**Goal**: الاستثناءات تتزامن مدرّس↔مساعد خلال دورة catch-up، والتكرار على `(group, date)` يُحلّ بـLWW.

**Independent Test**: quickstart سيناريو 7 (جهازان).

- [X] T025 [US4] `flutter analyze` على `sync_engine.dart` + `session_override_controller.dart` + `session_override_model.dart` + `session_schedule_resolver.dart` — نظيف فوق baseline (34).
- [ ] T026 [US4] نفّذ quickstart سيناريو 7 على جهازين: إلغاء من المدرّس يظهر عند المساعد؛ إنشاء مزدوج لنفس `(group, date)` → لا تكرار، LWW يفوز.

---

## Phase 7: Polish & Cross-Cutting

- [X] T027 [P] `flutter test` كاملًا — كل الاختبارات خضراء (baseline 97 + الجديدة).
- [X] T028 [P] `flutter analyze` كامل — صفر مشاكل جديدة فوق baseline 34.
- [ ] T029 نفّذ quickstart سيناريو 8 (عدم الانحدار): مجموعة بلا استثناءات → كل الأعداد والقوائم مطابقة لما قبل spec 032.
- [X] T030 [P] حدّث [HANDOFF.md](../../HANDOFF.md) و`memory/spec-032-cancel-makeup-session.md` (من "SPEC ONLY" إلى "IMPLEMENTED — device test pending"): الجدول الجديد، DB v29، الـmigration مطبّق عبر SSH، الدوال النقية، الجدولة override-aware، سجل الطالب دمج عرض، الفوترة صفر كود.
- [ ] T031 [US1] device test T019-equivalent: قارئ فعلي غير مطلوب — اختبار يدوي على جهاز للإلغاء/التعويض/التراجع + الفوترة.

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 2** (يَحجُب الكل). داخل Phase 2: T002/T003/T004/T005/T013 متوازية؛ T006→T007→T008 تسلسلي (نفس الملف)؛ T009→T010 (نفس الملف)؛ T011 بعد T002/T007؛ T012 بعد T011؛ T014 بعد T013 (يحتاج شبكة).
- **Phase 3 (US1)** و **Phase 4 (US2)**: بعد Phase 2. T015→T016 تسلسلي (نفس الملف)؛ T017–T019 نفس الملف تسلسلي؛ T020–T021 نفس الملف تسلسلي، بعد T015/T016.
- **Phase 5 (US3)**: بعد Phase 2؛ T023 و T024 ملفّان مختلفان → متوازيان.
- **Phase 6 (US4)**: بعد Phase 3/4.
- **Phase 7**: بعد الكل.

### Parallel Opportunities

- T002 + T003 + T004 + T005 + T013 معًا.
- T023 + T024 معًا.
- T027 + T028 + T030 معًا.

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 3 + 4)

الجدول + النموذج + الجدولة override-aware + شاشة الحضور (إلغاء + تعويض) = القيمة الكاملة للمدرّس. US3/US4 تحسينات عرض/مزامنة.

### Incremental

Setup → Foundational → US1 (إلغاء) → US2 (تعويض) → US3 (سجل) → US4 (مزامنة جهازين) → Polish.
