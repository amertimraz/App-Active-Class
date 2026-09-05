---
description: "Task list — مزامنة الامتحانات الإلكترونية عبر وضع الفريق (024-online-exam-team-sync)"
---

# Tasks: مزامنة الامتحانات الإلكترونية عبر وضع الفريق

**Input**: Design documents from `specs/024-online-exam-team-sync/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: تحقّق يدوي عبر [quickstart.md](quickstart.md) **بجهازين** (الأساسي هنا) + `flutter analyze` صفر تحذيرات. مهمة اختبار وحدة واحدة إلزامية: `toCloudMap` يفضل بلا مفاتيح تصحيح.

**Organization**: ٣ قصص. US1 (أسئلة) P1 — MVP. US2 (تسليمات) P1. US3 (مرونة) P2.

## Path Conventions

Mobile single-project — `lib/` + `supabase/*.sql`. المرجع: [plan.md](plan.md)، [data-model.md](data-model.md)، [contracts/](contracts/).

---

## Phase 1: Setup

- [ ] T001 حدّد `DATABASE_VERSION` الحالي في `lib/config/constants.dart` (v25 أو v26 لو spec 023 نزل)، والنسخة الجديدة = الحالي + 1. تحقّق هل عمود `COL_EQ_EXPLANATION` موجود على `exam_questions` محليًا (spec 023) — لو لأ، شيل مفاتيح `explanation` من خرائط المزامنة في T012/T013.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: كل القصص تحتاج أعمدة المزامنة + migration الخادم + تحسين مرونة القناة قبل ما تبدأ.

- [ ] T002 في `lib/config/constants.dart`: `DATABASE_VERSION` → الحالي + 1.
- [ ] T003 في `lib/services/database_service.dart`: (أ) أضف `$COL_SYNC_UPDATED_AT TEXT` + `$COL_SYNC_REMOTE_ID TEXT` لـ`_examQuestionsTableSql` و`_examSubmissionsTableSql`. (ب) في `_onUpgrade` بلوك جديد `if (oldVersion < <النسخة الجديدة>)`:
  ```dart
  for (final sql in [
    'ALTER TABLE $TABLE_EXAM_QUESTIONS   ADD COLUMN $COL_SYNC_UPDATED_AT TEXT',
    'ALTER TABLE $TABLE_EXAM_QUESTIONS   ADD COLUMN $COL_SYNC_REMOTE_ID  TEXT',
    'ALTER TABLE $TABLE_EXAM_SUBMISSIONS ADD COLUMN $COL_SYNC_UPDATED_AT TEXT',
    'ALTER TABLE $TABLE_EXAM_SUBMISSIONS ADD COLUMN $COL_SYNC_REMOTE_ID  TEXT',
  ]) { try { await db.execute(sql); } catch (_) {} }
  ```
- [ ] T004 [P] أنشئ `supabase/migration_online_exam_sync.sql` حسب [contracts/supabase-migration.md](contracts/supabase-migration.md): جدول `exam_questions` ([data-model.md](data-model.md) §2)، جدول `exam_submissions` (§3)، أعمدة أونلاين على `exams` (§4 — `alter table ... add column if not exists`)، RLS + soft-delete trigger (صلاحية `delete_attendance`، نسخ `check_delete_exams` من `migration_exams.sql`)، إضافة للـ`supabase_realtime` publication (§5). ترويسة تعليق النشر إلزامية.
- [ ] T005 في `lib/services/sync_engine.dart`: أعد تنظيم قوائم الجداول:
  - `_tables` (للـpull/push، بالترتيب): `... TABLE_EXAMS, TABLE_EXAM_QUESTIONS, TABLE_EXAM_GROUPS, TABLE_EXAM_GRADES, TABLE_EXAM_SUBMISSIONS`.
  - `_coreTables` (للـRealtime): كل جداول `_tables` عدا `TABLE_EXAM_QUESTIONS` و`TABLE_EXAM_SUBMISSIONS`.
  - `_extendedTables` = `[TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS]`.
- [ ] T006 في `lib/services/sync_engine.dart` `_subscribeRealtime()` + `stop()`: قناتان حسب [contracts/realtime-resilience.md](contracts/realtime-resilience.md) — helper `_makeChannel(name, tables, {driveCatchUp})`؛ `_channel` = `team-$teamId` على `_coreTables`؛ `_channelX` = `team-$teamId-x` على `_extendedTables`؛ الاتنين ينادوا `catchUpPull()` عند `subscribed` (idempotent، `_pulling` guard موجود)؛ `stop()` يقفل الاتنين.
- [ ] T007 في `lib/services/sync_engine.dart` `_pkCol`: أضف `TABLE_EXAM_QUESTIONS => COL_EQ_ID` و`TABLE_EXAM_SUBMISSIONS => COL_ES_ID`.

**Checkpoint**: البنية جاهزة — القصص تقدر تبدأ.

---

## Phase 3: User Story 1 - المساعد يشوف أسئلة الامتحان الإلكتروني (Priority: P1) 🎯 MVP

**Goal**: `exam_questions` + حقول الأونلاين على `exams` تتزامن عبر الفريق.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 1–6.

- [ ] T008 [US1] في `lib/services/database_service.dart`: أضف `_queueSync`/`_queueDelete` + كتابة `COL_SYNC_UPDATED_AT` لدوال أسئلة الامتحان حسب [contracts/sync-exam-questions.md](contracts/sync-exam-questions.md): `insertQuestion` (insert)، `updateQuestion` (update)، `deleteQuestion` (جلب `sync_remote_id` قبل الحذف → `_queueDelete`). حدّث تعليق "كله محلي — لا _queueSync" (سطر ~2101).
- [ ] T009 [US1] في `lib/services/database_service.dart`: `deleteExam` — أضف `_queueDelete(TABLE_EXAM_QUESTIONS, ...)` لكل صف سؤال تابع للامتحان (نفس نمط cascade `exam_grades`/`exam_groups` الموجود في `deleteExam`).
- [ ] T010 [US1] في `lib/services/database_service.dart`: `setExamOnlineFields` و`setExamOnlineStatus` (وأي دالة تلمس `is_online`/`online_status`/`opens_at`/`closes_at`/`duration_minutes`) — بعد `db.update(TABLE_EXAMS, ...)` أضف تحديث `COL_SYNC_UPDATED_AT` + `_queueSync(TABLE_EXAMS, examId, 'update', payload: <صف exams كامل>)`.
- [ ] T011 [US1] في `lib/services/sync_engine.dart` `_buildRemoteRow(TABLE_EXAMS)` و`_toLocalMap(TABLE_EXAMS)`: أضف مفاتيح الأونلاين الخمسة ([data-model.md](data-model.md) §4) — `is_online` boolean (نمط `is_absent`)، الباقي مباشر.
- [ ] T012 [US1] في `lib/services/sync_engine.dart` `_buildRemoteRow`: `case TABLE_EXAM_QUESTIONS` حسب [contracts/sync-exam-questions.md](contracts/sync-exam-questions.md) — يحلّ `exam_remote_id` (`return null` لو الأب لسه ما اتزامنش)، باقي الحقول من `payload[COL_EQ_*]`، `explanation` لو العمود موجود (T001).
- [ ] T013 [US1] في `lib/services/sync_engine.dart` `_toLocalMap`: `case TABLE_EXAM_QUESTIONS` — يحلّ `COL_EQ_EXAM_ID` من `_localIdForRemote(TABLE_EXAMS, ...)` (`return null` لو مفقود)، باقي الحقول + `COL_SYNC_UPDATED_AT`/`COL_SYNC_REMOTE_ID`.
- [ ] T014 [US1] في `lib/services/sync_engine.dart` `_refreshUiForTable`: `case TABLE_EXAM_QUESTIONS:` → `if (Get.isRegistered<ExamController>()) Get.find<ExamController>().loadExams();`.
- [ ] T015 [P] [US1] في `test/exam_question_cloud_map_test.dart` (جديد أو مشترك مع spec 023): اختبار يفرض `ExamQuestion(..., correctIndex: 1, points: 3, explanation: 'س').toCloudMap().keys` ⊆ `{id, type, text, options, imageUrl}` — لا `correct_index`/`points`/`explanation`. (المزامنة في Supabase منفصلة تمامًا عن `toCloudMap`.)

**Checkpoint**: المساعد يشوف الامتحان الإلكتروني بأسئلته وحالته وميعاده.

---

## Phase 4: User Story 2 - مزامنة التسليمات والحالة (Priority: P1)

**Goal**: `exam_submissions` تتزامن؛ حالة موحّدة؛ `voided` محترمة؛ آخر تعديل يفوز.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 7–15. **Prereq**: Phase 2. مستقل عن US1 تقنيًا (بس عمليًا التسليم بلا سؤال أب يتأجّل — راجع dedup/return null).

- [ ] T016 [US2] في `lib/services/database_service.dart`: أضف `_queueSync`/`_queueDelete` + `COL_SYNC_UPDATED_AT` لكل دوال كتابة `exam_submissions` حسب [contracts/sync-exam-submissions.md](contracts/sync-exam-submissions.md): كتابة التسليمات في `pullAndGradeOnlineExam` (insert/upsert لكل تسليم)، `updateSubmissionApproval`، `voidSubmissionLocally` (spec 022)، وأي مسار يغيّر `status`/`final_grade`/`auto_score`. حدّث تعليق "محلي بالكامل" (سطر ~2294).
- [ ] T017 [US2] في `lib/services/database_service.dart`: `deleteExam` — أضف `_queueDelete(TABLE_EXAM_SUBMISSIONS, ...)` لكل صف تسليم تابع (نمط cascade).
- [ ] T018 [US2] في `lib/services/sync_engine.dart` `_buildRemoteRow`: `case TABLE_EXAM_SUBMISSIONS` حسب [contracts/sync-exam-submissions.md](contracts/sync-exam-submissions.md) — يحلّ `exam_remote_id` + `student_remote_id` (الاتنين `return null` لو مفقود)، `auto_submitted` → boolean، **`pulled_at` مستبعد**.
- [ ] T019 [US2] في `lib/services/sync_engine.dart` `_toLocalMap`: `case TABLE_EXAM_SUBMISSIONS` — يحلّ `COL_ES_EXAM_ID` + `COL_ES_STUDENT_ID` من `_localIdForRemote` (`return null` لو أي أب مفقود)، `auto_submitted` → 0/1، **`COL_ES_PULLED_AT` غير متضمّن** (يفضل NULL)، + `COL_SYNC_UPDATED_AT`/`COL_SYNC_REMOTE_ID`.
- [ ] T020 [US2] في `lib/services/sync_engine.dart` `_applyRemoteRow` (قبل `_insertWithCodeRetry`، بعد بلوك `TABLE_EXAM_GRADES`): بلوك dedup لـ`TABLE_EXAM_SUBMISSIONS` — `db.query(WHERE exam_id=? AND student_id=?)` → لو موجود `debugPrint` + `return` ([contracts/sync-exam-submissions.md](contracts/sync-exam-submissions.md)).
- [ ] T021 [US2] في `lib/services/sync_engine.dart` `_refreshUiForTable`: `case TABLE_EXAM_SUBMISSIONS:` → `ExamController.loadExams()`.
- [ ] T022 [US2] تحقّق: `unapproveOnlineGrade`/`voidSubmission`/`updateQuestionAfterPublish` (spec 022، `exam_controller.dart`) بيمرّوا كلهم عبر دوال `_db` اللي اتعدّلت في T016/T008 — صفر تغيير مطلوب في الكنترولر لو الدوال دي هي البوابة الوحيدة للكتابة. لو فيه كتابة مباشرة على الجدول، وجّهها عبر دالة `_db`.

**Checkpoint**: US1+US2 — المساعد يسحب، يصحّح، يعتمد، والحالة موحّدة بين الجهازين.

---

## Phase 5: User Story 3 - المرونة (Priority: P2)

**Goal**: جدول ناقص على الخادم ما يعطّلش باقي المزامنة؛ توثيق النشر؛ تثبيت FR-016.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 16–18.

- [ ] T023 [US3] تأكيد T006 (القناتين) شغّال: على قاعدة اختبار بلا `exam_questions`/`exam_submissions` (أو قبل تشغيل T004)، فعّل الفريq → `_channel` (الأساسية) تدخل `subscribed` وتنادي `catchUpPull`، `_channelX` تدخل `CHANNEL_ERROR` بلا تأثير. وثّق النتيجة في تعليق داخل `_subscribeRealtime`.
- [ ] T024 [US3] تأكيد `_fullPull` (السطور ~561–580) بيتخطّى جدول راجع خطأ "relation does not exist" بهدوء (`try/catch` يرجّع `null` → `continue`) — **موجود بالفعل**، بس أضف تعليق يربطه بالسيناريو ده صراحة.
- [ ] T025 [US3] تثبيت FR-016: تأكيد بلوك `if (!_tables.contains(table))` في `_drainOutbox` (commit `3c3e0b2`) موجود وصحيح بعد إعادة ترتيب `_tables` في T005 — `student_follow_ups` (مش في `_tables`) صفوفه تتمسح، `exam_questions`/`exam_submissions` (في `_tables`) صفوفها تتدفع.
- [ ] T026 [P] [US3] راجع `supabase/README` أو أضف سطر في `migration_online_exam_sync.sql` يوضّح ترتيب النشر بالنسبة لباقي ملفات `migration_*.sql` (بعد `migration_exams.sql`).

**Checkpoint**: كل القصص شغّالة، والمزامنة الأساسية محميّة.

---

## Phase 6: Polish

- [ ] T027 `flutter analyze` — صفر أخطاء/تحذيرات.
- [ ] T028 `flutter test` — كل الاختبارات تنجح (يشمل `exam_question_cloud_map_test.dart`).
- [ ] T029 نشر `migration_online_exam_sync.sql` على Supabase الإنتاج (SQL Editor) + تحقّق: الجداول موجودة، في الـ`supabase_realtime` publication، RLS مفعّل. شغّله تاني → صفر أخطاء (idempotent).
- [ ] T030 نفّذ [quickstart.md](quickstart.md) خطوات 0–18 كاملة **بجهازين حقيقيين** — خصوصًا 9 (سحب على جهاز، ظهور على التاني)، 14 (تعارض اعتماد)، 15 (تعارض voided)، 16 (محاكاة جدول ناقص).
- [ ] T031 [P] حدّث ملاحظات الجلسة: سبيك 024 — `exam_questions`/`exam_submissions` بقوا متزامنين، حقول الأونلاين على `exams` دخلت payload المزامنة، قناتان Realtime (`team-$id` + `team-$id-x`)، `migration_online_exam_sync.sql` محتاج تشغيل يدوي. حدّث [[spec-021-at-risk-students]] (درس CHANNEL_ERROR اتحوّل لحل دائم).

---

## Dependencies & Execution Order

- **Phase 1 (T001)**: استكشاف — يحدّد رقم النسخة ووجود `explanation`.
- **Phase 2 (T002–T007)**: أساس، يحجب كل القصص. T002→T003 (نفس منطقة DB، تسلسلي)؛ T004 [P]؛ T005→T006→T007 (نفس ملف `sync_engine`، تسلسلي).
- **US1 (T008–T015)**: بعد Phase 2. T008/T009/T010 (نفس ملف `database_service`، تسلسلي)؛ T011/T012/T013/T014 (نفس ملف `sync_engine`، تسلسلي)؛ T015 [P].
- **US2 (T016–T022)**: بعد Phase 2. T016/T017 (`database_service`)؛ T018/T019/T020/T021 (`sync_engine`)؛ T022 تحقّق. مستقل عن US1 (ملفات نفسها لكن دوال/حالات مختلفة — لو نفس المطوّر، تسلسلي بعد US1).
- **US3 (T023–T026)**: بعد Phase 2 (خصوصًا T006). أغلبه تأكيد/توثيق. T026 [P].
- **Polish (T027–T031)**: بعد الكل. T029 (نشر) قبل T030 (تحقّق بجهازين).

### فرص التوازي
- T004 (SQL) [P] مع T002/T003 (DART).
- T015 (اختبار) [P].
- US1 وUS2 مستقلين منطقيًا — لكن بيلمسوا نفس ملفين (`database_service`, `sync_engine`)، فبفريق واحد: تسلسلي. بفريقين: ممكن بحذر (حالات switch مختلفة).
- T026/T031 [P].

---

## Implementation Strategy

**MVP**: Phase 1+2 + US1 → المساعد يشوف أسئلة الامتحان الإلكتروني وحالته. قف وتحقّق (quickstart 1–6).
**تدريجي**: US1 → US2 (التسليمات + التعارض) → US3 (تثبيت المرونة) → Polish (نشر migration + تحقّق بجهازين).
**حرج**: T004 (migration) لازم يتنشر (T029) قبل ما الميزة تشتغل فعليًا — لكن T006 (القناتين) بيضمن إن عدم نشره **ما يكسرش** مزامنة الواجب/الدرجات.

## Notes

- نمط مزامنة جدول جديد = `exam_grades` بالحرف (5 نقاط لمس في `sync_engine` + SQL + publication).
- `_queueSync` فيها `if (!teamModeEnabled) return;` — آمنة للنداء دايمًا، صفر تكلفة على غير مستخدمي الفريق.
- `correct_index`/`points`/`explanation` في Supabase (تخزين الفريq، RLS) — **مش** في `toCloudMap` (مستند Firestore العام). T015 يفرض.
- `student_follow_ups` يفضل بره `_tables` (شغل منفصل).
- commit بعد كل قصة.
