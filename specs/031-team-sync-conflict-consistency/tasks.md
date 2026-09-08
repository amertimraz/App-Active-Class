---
description: "Task list for feature 031 — اتساق تعارضات مزامنة الفريق"
---

# Tasks: اتساق تعارضات مزامنة الفريق — وقت الخادم + توفيق الصفوف المكرّرة

**Input**: Design documents from `/specs/031-team-sync-conflict-consistency/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة للدالة النقية `syncConflictIncomingWins` فقط. الـtrigger والتوفيق المدموج يُتحقَّق يدويًا (SQL + جهازين).

**Organization**: إصلاحان مترابطان — US1 (وقت الخادم) و US2 (توفيق المكرّر). US1 لازم يسبق US2 عمليًا (التوفيق يعتمد طوابع موحّدة). US3/US4 (عدم انحدار + جهازين) تحقّق.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

تطبيق Flutter مفرد + خادم Supabase على VPS.

---

## Phase 1: Foundational — الدالة النقية + اختبارها

- [X] T001 [P] أنشئ `lib/utils/sync_conflict.dart` — `bool syncConflictIncomingWins({DateTime? localUpdatedAt, DateTime? remoteUpdatedAt, required String localRemoteId, required String remoteRemoteId})` وفق [contracts/duplicate-reconcile.md](./contracts/duplicate-reconcile.md): `remoteUpdatedAt == null` → false؛ `localUpdatedAt == null` → true؛ `remoteUpdatedAt.compareTo(localUpdatedAt) != 0` → `> 0`؛ تعادل → `remoteRemoteId.compareTo(localRemoteId) < 0`.
- [X] T002 [P] أنشئ `test/sync_conflict_test.dart` — 6 حالات من جدول العقد: وارد أحدث → true؛ وارد أقدم → false؛ تعادل + محلي أكبر معجميًا → true؛ تعادل + محلي أصغر → false؛ محلي بلا وقت → true؛ وارد بلا وقت → false.

**Checkpoint**: `flutter test test/sync_conflict_test.dart` أخضر.

---

## Phase 2: User Story 1 — وقت خادم موحّد لـ`updated_at` (Priority: P1)

**Goal**: كل الكتابات على الجداول المتزامنة تأخذ `updated_at = now()` من الخادم، فمقارنات LWW متسقة رغم انحراف ساعات الأجهزة.

**Independent Test**: quickstart سيناريو 1 (تعديل لاحق يفوز رغم ساعة منحرفة) + التحقّق SQL (11 trigger).

### Implementation

- [X] T003 [US1] أنشئ `supabase/migration_server_updated_at.sql` وفق [contracts/server-updated-at-trigger.md](./contracts/server-updated-at-trigger.md): دالة `public.set_updated_at()` (`NEW.updated_at := now(); RETURN NEW;`) + كتلة `DO $$` تنشئ `trg_set_updated_at` (`DROP IF EXISTS` ثم `CREATE ... BEFORE INSERT OR UPDATE ... FOR EACH ROW`) على الـ11 جدول: `groups, students, attendance, payments, homework, exams, exam_groups, exam_grades, exam_questions, exam_submissions, bank_questions`.
- [X] T004 [US1] طبّق الـmigration عبر SSH: `ssh -i ~/.ssh/ovh_key root@active-class.online "docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1" < supabase/migration_server_updated_at.sql`. تحقّق: `SELECT count(*) FROM information_schema.triggers WHERE trigger_schema='public' AND trigger_name='trg_set_updated_at'` = **11**؛ واختبار سلوكي (`UPDATE ... SET updated_at='2000-01-01'` ثم `SELECT updated_at` ≈ now()).
- [X] T005 [US1] في `lib/services/sync_engine.dart` عند مقارنة LWW في `_applyRemoteRow` step 1 (`!remoteUpdatedAt.isAfter(localUpdatedAt)`): أضف تعليقًا يوضّح أن الطوابع الآن موحّدة من الخادم (spec 031) — لا تغيير منطقي، توثيق فقط. (اختياريًا: أضف `debugPrint` عند تجاهل وارد لأنه ليس أحدث، لتسهيل التشخيص.)

**Checkpoint**: الـmigration مطبّق ومتحقَّق؛ LWW القائم يعمل بطوابع موحّدة.

---

## Phase 3: User Story 2 — توفيق الصف المكرّر بدل تجاهله (Priority: P1)

**Goal**: صف وارد يطابق منطقيًا صفًا محليًا بمعرّف مختلف → يُطبَّق LWW على البيانات لا يُتجاهَل.

**Independent Test**: quickstart سيناريوهات 2 + 3 + 4 + 5.

### Implementation (`lib/services/sync_engine.dart`)

- [X] T006 [US2] أضف `import 'package:active_class/utils/sync_conflict.dart';` + دالة `Future<void> _reconcileDuplicate(DatabaseExecutor db, String table, String pkCol, Map<String,Object?> dupRow, Map<String,dynamic> remote, Map<String,dynamic> localMap)` وفق [contracts/duplicate-reconcile.md](./contracts/duplicate-reconcile.md): تحسب `localUpdatedAt`/`remoteUpdatedAt`/`localRemoteId`/`remoteRemoteId`، تستدعي `syncConflictIncomingWins`؛ لو false → `debugPrint` + return؛ لو true → `data = Map.from(localMap)..remove(COL_SYNC_REMOTE_ID)` ثم `db.update(table, data, where: '$pkCol = ?', whereArgs: [dupRow[pkCol]])` + `debugPrint`.
- [X] T007 [US2] في كتلة `TABLE_ATTENDANCE` بـ`_applyRemoteRow`: غيّر استعلام الـdup ليجيب أعمدة `[pkCol, COL_SYNC_REMOTE_ID, COL_SYNC_UPDATED_AT]` (بدل `limit:1` فقط)، واستبدل `if (dup.isNotEmpty) { debugPrint(...); return; }` بـ`if (dup.isNotEmpty) { await _reconcileDuplicate(db, table, pkCol, dup.first, remote, localMap); return; }`.
- [X] T008 [US2] نفس التغيير لكتلة `TABLE_HOMEWORK`.
- [X] T009 [US2] نفس التغيير لكتلة `TABLE_EXAM_GROUPS`.
- [X] T010 [US2] نفس التغيير لكتلة `TABLE_EXAM_GRADES`.
- [X] T011 [US2] نفس التغيير لكتلة `TABLE_EXAM_SUBMISSIONS`.

**Checkpoint**: الصفوف المكرّرة الواردة تُوفَّق؛ لا تجاهل صامت.

---

## Phase 4: User Story 3 + 4 — عدم الانحدار + جهازين (Priority: P2)

**Independent Test**: quickstart سيناريوهات 6 + 7 + كل السيناريوهات جهازين.

- [X] T012 [US3] راجع أن `_applyRemoteRow` step 1 (نفس `remote_id`) وباقي المسارات غير المكرّرة بلا تغيير سلوكي — التوفيق يمسّ **فقط** الكتل الخمس ذات الفهرس المنطقي.
- [X] T013 [US4] `flutter analyze` على `sync_engine.dart` + `sync_conflict.dart` — نظيف.

**Checkpoint**: لا انحدار.

---

## Phase 5: Polish & Cross-Cutting

- [X] T014 [P] شغّل `flutter test` كاملًا + `flutter analyze` — صفر مشاكل جديدة فوق baseline (34).
- [ ] T015 نفّذ quickstart جهازين (مدرّس + مساعد): ساعة منحرفة، حضور مزدوج، درجة مزدوجة، ربط مزدوج، عدم انحدار التعديل العادي، التعديل بعد التوفيق.
- [X] T016 [P] حدّث `HANDOFF.md` و`memory/` بملخّص spec 031 (`migration_server_updated_at.sql` مطبّق عبر SSH، `sync_conflict.dart`، `_reconcileDuplicate` بدل 5 كتل تجاهل، `remote_id` المحلي ثابت، الخاسر يعيد البثّ، صفر تغيير schema محلي/RLS).

---

## Dependencies & Execution Order

- **Phase 1**: T001 قبل/مع T002.
- **Phase 2**: T003 → T004 (تطبيق) → T005. T004 (SSH) يحتاج شبكة.
- **Phase 3**: بعد Phase 1 (T001) و **يُفضَّل** بعد Phase 2 (طوابع موحّدة). T006 قبل T007–T011؛ T007–T011 نفس الملف تسلسلي لكن متطابقة النمط.
- **Phase 4/5**: بعد كل شيء.

### Parallel Opportunities

- T001 + T002.
- T003 (كتابة الـSQL) موازٍ لـT001/T002.

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 3)

الدالة + الـtrigger المطبّق + توفيق الكتل الخمس = يحلّ "تعديلاتي مش بتوصل" (وقت الخادم) و"مش متطابقين" (التوفيق) بالكامل.

### Incremental

Phase 1 → US1 (وقت الخادم — migration) → US2 (التوفيق) → تحقّق جهازين.
