---
description: "Task list for feature 030 — تقوية مزامنة وضع الفريق"
---

# Tasks: تقوية مزامنة وضع الفريق — منع فقدان البيانات وتسجيل الخروج الخاطئ

**Input**: Design documents from `/specs/030-team-sync-hardening/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة للدوال النقية في `sync_retry_policy.dart` فقط (عتبات/عدّادات قابلة للعزل). المنطق المدموج في `SyncEngine` (شبكة/Supabase حي) يُتحقَّق يدويًا عبر quickstart.

**Organization**: 3 إصلاحات مستقلة (US1 طابور، US2 سحب دوري، US3 حارس الخروج) — كلها P1، كلها في `sync_engine.dart` فـتُنفَّذ تسلسليًا في نفس الملف لكن بلا اعتماد منطقي بينها.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ملفات مختلفة، بلا اعتماد متبادل
- **[Story]**: US1 (طابور) / US2 (سحب دوري) / US3 (حارس الخروج)

## Path Conventions

تطبيق Flutter مفرد: `lib/` و`test/` في جذر المستودع.

---

## Phase 1: Foundational — الدوال النقية + الاختبار

**⚠️ CRITICAL**: `SyncEngine` هيستدعي دوال `sync_retry_policy.dart`.

- [X] T001 [P] أنشئ `lib/utils/sync_retry_policy.dart` — `bool shouldAttemptOutboxRow(int fails, int round, {int maxFails = 5, int poisonRetryEvery = 20})` = `fails < maxFails || round % poisonRetryEvery == 0`؛ `bool shouldFireTeamExit({required bool sessionUsable, required int emptyStreak, int threshold = 3})` = `sessionUsable && emptyStreak >= threshold`. راجع [contracts/outbox-retry-policy.md](./contracts/outbox-retry-policy.md) و[contracts/membership-check-guard.md](./contracts/membership-check-guard.md).
- [X] T002 [P] أنشئ `test/sync_retry_policy_test.dart` — 12 حالة: `shouldAttemptOutboxRow` (fails=0/round=7→true؛ fails=4→true؛ fails=5/round=7→false؛ fails=5/round=20→true؛ fails=99/round=40→true؛ fails=5/round=0→true)؛ `shouldFireTeamExit` (sessionUsable=false/streak=9→false؛ true/streak=2→false؛ true/streak=3→true؛ true/streak=5→true؛ false/streak=0→false؛ threshold مخصّص).

**Checkpoint**: `flutter test test/sync_retry_policy_test.dart` أخضر.

---

## Phase 2: User Story 1 — تقوية طابور الإرسال (Priority: P1)

**Goal**: صف outbox فاشل واحد لا يوقف الطابور؛ يُتخطّى بعد 5 محاولات؛ يُعاد المحاولة عليه كل 20 جولة؛ لوج واحد.

**Independent Test**: quickstart سيناريو 1.

### Implementation (كلها في `lib/services/sync_engine.dart`)

- [X] T003 [US1] أضف حقول الحالة: `final Map<int,int> _outboxFails = {};`، `final Map<int,String> _lastOutboxErr = {};`، `final Set<int> _loggedPoison = {};`، `int _drainRound = 0;`. + ثوابت `_kMaxOutboxFails = 5`, `_kPoisonRetryEvery = 20` (أو استيرادها من `sync_retry_policy.dart`).
- [X] T004 [US1] أضف `void _recordOutboxFail(int id, String table, int rowId, String err)` و`void _forgetOutbox(int id)` وفق [contracts/outbox-retry-policy.md](./contracts/outbox-retry-policy.md): `_recordOutboxFail` يزيد العدّاد، يخزّن آخر خطأ، ولو بلغ العتبة و`_loggedPoison.add(id)` رجع true → `debugPrint('⚠️ صف عالق بعد N محاولات — table/rowId — آخر خطأ: err')`. `_forgetOutbox` يمسح المفتاح من الخرائط الثلاث.
- [X] T005 [US1] عدّل `drainOutbox`: `_drainRound++` أول السطر؛ احسب `poison = _outboxFails` بقيمة `>= _kMaxOutboxFails`؛ `retryPoison = _drainRound % _kPoisonRetryEvery == 0`؛ ابنِ `where` = `synced=0` + (لو `poison.isNotEmpty && !retryPoison`) `AND id NOT IN (poison.join(','))`؛ استعلم بـ`where.toString()`. في الحلقة: نجاح → `db.delete` + `_forgetOutbox`؛ `done == false` → `_recordOutboxFail(id, table, rowId, 'الأب لسه بلا remote_id')`؛ `catch` → `_recordOutboxFail(..., e.toString())` + `debugPrint` الموجود؛ جدول مشال (`!_tables.contains`) → `db.delete` + `_forgetOutbox`.

**Checkpoint**: US1 يعمل — الطابور مقاوم للصفوف المسمومة.

---

## Phase 3: User Story 2 — سحب دوري + عند الرجوع من الخلفية (Priority: P1)

**Goal**: `catchUpPull` كل 50s + فورًا عند `resumed`؛ يتوقف مع `stop()`.

**Independent Test**: quickstart سيناريوهات 2 + 3.

### Implementation (`lib/services/sync_engine.dart`)

- [X] T006 [US2] اجعل `class SyncEngine` يستخدم `with WidgetsBindingObserver` (استيراد `package:flutter/widgets.dart`). أضف `Timer? _catchUpTimer;`.
- [X] T007 [US2] في `start()`: `_catchUpTimer = Timer.periodic(const Duration(seconds: 50), (_) => unawaited(catchUpPull()));` + `WidgetsBinding.instance.addObserver(this);`.
- [X] T008 [US2] أضف `@override void didChangeAppLifecycleState(AppLifecycleState state)` → `if (state == AppLifecycleState.resumed) unawaited(catchUpPull());`.
- [X] T009 [US2] في `stop()`: `_catchUpTimer?.cancel(); _catchUpTimer = null; WidgetsBinding.instance.removeObserver(this);` + تصفير كل حقول الحالة من T003 و(لاحقًا) T010 (`_outboxFails/_lastOutboxErr/_loggedPoison.clear()`، `_emptyMembershipStreak = _deviceUnboundStreak = 0`).

**Checkpoint**: US2 يعمل — الاستقبال لا يتوقف لو Realtime وقع.

---

## Phase 4: User Story 3 — حارس فحص الخروج من الفريق (Priority: P1)

**Goal**: هبّة شبكة/توكن متأخّر لا تسجّل خروج المساعد؛ الإزالة الفعلية لسه تسجّله خلال ~45–90s.

**Independent Test**: quickstart سيناريوهات 4 + 5 + 6 + 9.

### Implementation (`lib/services/sync_engine.dart`)

- [X] T010 [US3] أضف `int _emptyMembershipStreak = 0;`، `int _deviceUnboundStreak = 0;` + `bool _sessionUsable()` وفق [contracts/membership-check-guard.md](./contracts/membership-check-guard.md): `final s = client.auth.currentSession; if (s == null || s.isExpired) { unawaited(client.auth.refreshSession().catchError((_) {})); debugPrint('...جلسة غير صالحة'); return false; } return true;`.
- [X] T011 [US3] عدّل `_wasRemovedFromTeam`: `if (!_sessionUsable()) return false;` بعد فحص `uid`؛ عند `rows.isEmpty` → `_emptyMembershipStreak++`؛ لو `shouldFireTeamExit(sessionUsable: true, emptyStreak: _emptyMembershipStreak)` → `debugPrint` تأكيد + `onRemovedFromTeam?.call()` + `return true`؛ غير كده `debugPrint('عضوية فاضية (N/3)')` + `return false`؛ نتيجة غير فاضية → `_emptyMembershipStreak = 0`.
- [X] T012 [US3] عدّل `_wasDeviceUnbound`: `if (!_sessionUsable()) return false;` أولًا؛ `!stillBound` → `_deviceUnboundStreak++`، `onDeviceUnbound?.call()` فقط عند `_deviceUnboundStreak >= 3`؛ `stillBound` → `_deviceUnboundStreak = 0`.
- [X] T013 [US3] عدّل `_wasLicenseDeactivated`: أضف `if (!_sessionUsable()) return false;` في البداية فقط (لا streak).

**Checkpoint**: US3 يعمل — لا تسجيل خروج خاطئ.

---

## Phase 5: Polish & Cross-Cutting

- [X] T014 [P] شغّل `flutter test` كاملًا + `flutter analyze` — صفر مشاكل جديدة فوق baseline (34 info).
- [ ] T015 نفّذ quickstart: سيناريوهات المحاكاة 1–3 (بتعديل مؤقّت لحقن فشل/عطل Realtime)، وسيناريوهات جهازين 4–9 (خصوصًا: هبّة شبكة لا تسجّل خروج، إزالة فعلية تسجّله، مزامنة ثنائية كاملة، عدم انحدار جهاز المدرّس).
- [X] T016 [P] حدّث `HANDOFF.md` و`memory/` بملخّص spec 030 (`sync_retry_policy.dart`، الإصلاحات الثلاثة في `sync_engine.dart`، `_catchUpTimer` 50s + resume، `_sessionUsable` + streak ≥ 3، صفر تغيير DB/خادم).

---

## Dependencies & Execution Order

- **Phase 1**: T001 قبل/مع T002. T001 يسبق كل الاستدعاءات في `sync_engine.dart`.
- **Phase 2/3/4**: كلها في `sync_engine.dart` → تسلسلية في الملف، لكن مستقلة منطقيًا. الترتيب المقترح: T003→T004→T005 (US1)، ثم T006→T009 (US2)، ثم T010→T013 (US3). T009 يلمس تصفير حقول US3 فنفّذه بعد T010 أو ارجع له.
- **Phase 5**: بعد كل شيء.

### ملاحظة تنفيذ

T009 (تصفير الحالة في `stop()`) يشير لحقول من T003 و T010 — أنجز T003+T010 قبل إتمام T009، أو اكتب `stop()` مرة واحدة بعد كل الحقول.

### Parallel Opportunities

- T001 + T002 (منطق + اختباره).
- بعد Phase 1، الإصلاحات الثلاثة منطقيًا مستقلة — لو مطوّر واحد، نفّذها بالترتيب؛ لو أكتر، لازم دمج يدوي لنفس الملف.

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 4)

الدوال النقية + تقوية الطابور (US1) + حارس الخروج (US3) = يعالج "بيانات مش بتوصل" (جزئيًا) و"تسجيل خروج خاطئ" (كليًا). US2 (السحب الدوري) يكمّل "بيانات مش بتوصل/بتتأخّر".

### Incremental

Phase 1 → US1 (طابور) → US2 (سحب) → US3 (حارس) → صقل + تحقّق جهازين.
