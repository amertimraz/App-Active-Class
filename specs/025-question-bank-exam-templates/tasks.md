---
description: "Task list — بنك الأسئلة + نسخ/قوالب الامتحان (025-question-bank-exam-templates)"
---

# Tasks: بنك الأسئلة + نسخ/قوالب الامتحان

**Input**: Design documents from `specs/025-question-bank-exam-templates/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: `flutter analyze` صفر تحذيرات + تحقّق يدوي عبر [quickstart.md](quickstart.md). مهمتان اختبار وحدة إلزاميتان: `pickRandom` و`duplicateExam` (منطق ما يُنسخ)، + استمرار اختبار `exam_question_cloud_map_test` (spec 023).

**Organization**: ٣ قصص. US1 (بنك) P1 — MVP. US2 (تكامل المحرّر) P1. US3 (تكرار) P2.

## Path Conventions

Mobile single-project — `lib/` + `supabase/*.sql`. المرجع: [plan.md](plan.md)، [data-model.md](data-model.md)، [contracts/](contracts/).

---

## Phase 1: Setup

- [X] T001 في `lib/config/constants.dart`: `DATABASE_VERSION` 27 → 28؛ أضف `TABLE_BANK_QUESTIONS = 'bank_questions'` + ثوابت `COL_BQ_*` ([data-model.md](data-model.md) §1) + `ROUTE_QUESTION_BANK = '/question_bank'`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: DB + الموديل + هيكل المزامنة قبل أي قصة.

- [X] T002 في `lib/services/database_service.dart`: `_bankQuestionsTableSql` + `_bankQuestionsIndexSql` ([data-model.md](data-model.md) §1، أعمدة المزامنة من الإنشاء)؛ `await db.execute(...)` في `_createTables`/`_onCreate`؛ بلوك `if (oldVersion < 28) { try { await db.execute(_bankQuestionsTableSql); await db.execute(_bankQuestionsIndexSql); } catch (_) {} }` في `_onUpgrade`.
- [X] T003 [P] أنشئ `lib/models/bank_question_model.dart`: `class BankQuestion` ([contracts/bank-question-model-db.md](contracts/bank-question-model-db.md)) — الحقول، `isValid` (بلا شرط subject)، `toMap`/`fromMap` (`options`/`tags` عبر jsonEncode)، `copyWith` (نمط `_unset`)، `toExamQuestion({examId, position})`، `factory fromExamQuestion(ExamQuestion, {subject, tags})`. يستورد `ExamQuestionType` من `exam_question_model.dart`.
- [X] T004 [P] أنشئ `supabase/migration_question_bank.sql` ([contracts/bank-sync.md](contracts/bank-sync.md)): جدول `bank_questions` ([data-model.md](data-model.md) §3)، RLS (3 policies، `is_team_member` + `is_team_license_active`)، trigger `trg_check_delete_bank_questions` (يعيد استخدام `public.check_delete_exams()`)، إضافة للـ`supabase_realtime` publication. ترويسة تعليق فيها أمر SSH للتطبيق.
- [X] T005 في `lib/services/sync_engine.dart`: `TABLE_BANK_QUESTIONS` في `_tables` (بعد `TABLE_EXAMS`) و`_extendedTables`؛ `_pkCol` → `COL_BQ_ID`.
- [X] T006 في `lib/services/sync_engine.dart`: `_buildRemoteRow` `case TABLE_BANK_QUESTIONS` + `_toLocalMap` `case TABLE_BANK_QUESTIONS` ([contracts/bank-sync.md](contracts/bank-sync.md) — كل الحقول، `subject` بديله `''`، بلا `*_remote_id`/`return null`).
- [X] T007 في `lib/services/sync_engine.dart` `_refreshUiForTable`: `case TABLE_BANK_QUESTIONS:` → `if (Get.isRegistered<QuestionBankController>()) Get.find<QuestionBankController>().refresh();` (يحتاج import — يُضاف بعد إنشاء الكنترولر في T009، أو import مبدئي).

**Checkpoint**: DB + الموديل + المزامنة جاهزين.

---

## Phase 3: User Story 1 - بنك الأسئلة (Priority: P1) 🎯 MVP

**Goal**: مخزن أسئلة منظّم بمادة/وسوم، CRUD + بحث/فلترة، متزامن عبر الفريق.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 1–9.

- [X] T008 [US1] في `lib/services/database_service.dart`: دوال البنك ([contracts/bank-question-model-db.md](contracts/bank-question-model-db.md)) — `getBankQuestions()`، `insertBankQuestion(q)` (+`created_at`/`sync_updated_at` = now + `_queueRowUpsert(TABLE_BANK_QUESTIONS, COL_BQ_ID, id)`)، `updateBankQuestion(q)` (+`sync_updated_at`، بلا لمس `remote_id`/`created_at` + `_queueRowUpsert`)، `deleteBankQuestion(id)` (جلب `remote_id` → delete → `_queueDelete`)، `distinctSubjects()`.
- [X] T009 [US1] أنشئ `lib/controllers/question_bank_controller.dart`: `QuestionBankController extends GetxController` ([contracts/bank-question-model-db.md](contracts/bank-question-model-db.md)) — `RxList<BankQuestion> _all`، `RxnString subjectFilter/tagFilter`، `RxString query`، `items` getter (فلترة في الذاكرة: subject + tag `q.tags.contains` + بحث نصّي)، `subjects`/`tags` getters، `@override Future<void> refresh()`، `add`/`save`/`remove`.
- [X] T010 [US1] أنشئ `lib/views/exams/question_draft.dart`: انقل صنف `_QDraft` من `online_exam_editor_page.dart` باسم عام `QuestionDraft` (controllers النص/الاختيارات/الشرح، type/correctIndex/points/imageUrl/uploadingImage، `dispose()`، `toModel(examId, position)` → `ExamQuestion`). أضف `factory QuestionDraft.fromBankQuestion(BankQuestion)` و`factory QuestionDraft.fromExamQuestion(ExamQuestion)`.
- [X] T011 [US1] أنشئ `lib/views/exams/question_editor.dart`: `QuestionEditor` StatefulWidget يعرض كارت تحرير سؤال واحد من `QuestionDraft` — النص، رفع صورة + مصغّرة (`_pickQuestionImage` يُنقل جواه)، الاختيارات + راديو، إضافة/حذف اختيار (mcq)، الدرجة، الشرح (spec 023). المدخلات: `QuestionEditor({required QuestionDraft draft, VoidCallback? onChanged, VoidCallback? onDelete, Widget? trailing})`. **احتياط R2**: لو استخراج المنطق من `online_exam_editor_page` طلع خطر، اكتب `QuestionEditor` نظيف من الصفر وسجّل الانحراف هنا (محرّر الامتحان يتوحّد في T016 أو يُؤجَّل).
- [X] T012 [US1] أنشئ `lib/views/question_bank/question_bank_page.dart`: `QuestionBankPage` — `Scaffold`+`AppBar('بنك الأسئلة')`+RTL. شريط بحث + chips/dropdown للمادة والوسم (من `controller.subjects`/`tags`). `Obx` → `ListView` كروت مختصرة (نص/نوع/مادة/عدد اختيارات/درجة). ضغط الكارت → bottom sheet فيه `QuestionEditor` + حقل مادة (autocomplete من `distinctSubjects`) + حقل وسوم → حفظ يستدعي `controller.save`. زر `+` عائم → sheet سؤال جديد → `controller.add`. حذف بزر + تأكيد. بنك فارغ → رسالة + دعوة.
- [X] T013 [US1] في `lib/main.dart`: `GetPage(name: ROUTE_QUESTION_BANK, page: () => const QuestionBankPage())`. في `lib/views/home_page.dart` `_buildDrawer`: `_DrawerItem(icon: Icons.quiz_rounded, title: 'بنك الأسئلة', onTap: () { Navigator.pop(context); Get.toNamed(ROUTE_QUESTION_BANK); })` بعد "الحجوزات".
- [X] T014 [US1] أكمل `_refreshUiForTable` import في `sync_engine.dart` (T007) — `import 'package:active_class/controllers/question_bank_controller.dart';`.

**Checkpoint**: البنك يشتغل مستقلًا — CRUD + بحث/فلترة + مزامنة.

---

## Phase 4: User Story 2 - تكامل البنك مع المحرّر (Priority: P1)

**Goal**: "أضف من البنك" (فردي أو N عشوائي) + "احفظ في البنك"، نسخ مستقلة.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 10–15. **Prereq**: US1 (البنك + `QuestionEditor`).

- [X] T015 [P] [US2] أنشئ `lib/services/question_bank_picker.dart` + `test/question_bank_random_test.dart`: `List<BankQuestion> pickRandom(List<BankQuestion> pool, int n, {Random? rng})` ([contracts/editor-integration.md](contracts/editor-integration.md)) — فارغ/`n<=0` → []، `n >= pool.length` → كل pool مخلوط، وإلا `take(n)` بلا تكرار. اختبار: 5 من pool فيه 3 → 3، rng محقون للتكرارية، pool فارغ → [].
- [X] T016 [US2] في `lib/views/exams/online_exam_editor_page.dart`: أعِد كتابة `_questionCard(i)` ليستخدم `QuestionEditor` + `QuestionDraft` (المنقول في T010). `trailing` = زر "حفظ هذا السؤال" (spec 022، لو `_isPublished && q.id != null`). `flutter analyze` بعدها. (لو T011 اختار النسخة النظيفة، وحّد هنا أو أجّل مع تسجيل الانحراف.)
- [X] T017 [US2] أنشئ `lib/views/question_bank/question_bank_picker_page.dart`: `QuestionBankPickerPage` تُفتح بـ`Get.to<List<BankQuestion>>` وترجّع المختار. وضعان: (أ) اختيار فردي — قائمة بفلاتر + `Checkbox` + عدّاد + "أضف". (ب) N عشوائي — نطاق (الكل/مادة/وسم) + حقل N + "متاح: M" → `pickRandom`. بنك فارغ → رسالة + زر يفتح `QuestionBankPage`.
- [X] T018 [US2] في `online_exam_editor_page.dart`: زر "أضف من البنك" (`Icons.library_add_rounded`) في `AppBar.actions` → `QuestionBankPickerPage` → لكل `BankQuestion` مرتجع: `setState(() => _questions.add(QuestionDraft.fromBankQuestion(bq)))` (id = null، نسخة قيمة). رسالة "تمت إضافة N".
- [X] T019 [US2] في `online_exam_editor_page.dart`: في `QuestionEditor.trailing` أضف زر "احفظ في البنك" (`Icons.bookmark_add_outlined`) — لو `!draft.isValid` → `_blockingMsg`؛ وإلا `BankQuestion.fromExamQuestion(draft.toModel(0,0))`، لو `subject` فارغ → `showDialog` يطلب المادة (حقل + autocomplete من `distinctSubjects`، إلغاء = لا حفظ) → `Get.find<QuestionBankController>().add(bq)` → `ToastHelper.success`. + عنصر overflow "احفظ كل الأسئلة في البنك" (يطلب مادة واحدة، يطبّق على الصالحة).
- [X] T020 [US2] تحقّق: بعد "أضف من البنك"، `saveOnlineExamDraft` → `replaceExamQuestions` يخزّن الأسئلة الجديدة كصفوف `exam_questions` عادية، والنشر يمرّ بـ`toCloudMap` (بلا مفاتيح تصحيح). صفر تغيير في مسار النشر — بس تأكيد بـ`exam_question_cloud_map_test` + خطوة quickstart 15.

**Checkpoint**: US1+US2 — المدرس يبني امتحان من البنك بسرعة، ويدفع أسئلته للبنك.

---

## Phase 5: User Story 3 - نسخة جديدة من امتحان (Priority: P2)

**Goal**: زر "نسخة جديدة" → مسودّة كاملة بنفس الأسئلة/الدرجات، بلا مجموعات/مواعيد/تسليمات/نشر.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 16–19. مستقل عن US1/US2.

- [X] T021 [P] [US3] أنشئ `test/exam_duplicate_test.dart`: منطق ما يُنسخ / ما لا يُنسخ. لو `duplicateExam` صعب اختباره بلا DB، اختبر دالة نقية مساعدة `Exam duplicatedExamMeta(Exam src)` (تبني `Exam` النسخة: الاسم+"(نسخة)"، الدرجات، بلا groupIds/opensAt/closesAt، status draft) — واستخدمها في T022.
- [X] T022 [US3] في `lib/controllers/exam_controller.dart`: `Future<int?> duplicateExam(int examId)` ([contracts/exam-duplicate.md](contracts/exam-duplicate.md)) — `src` لازم `isOnline`؛ `insertExam(Exam(name+' (نسخة)', maxGrade/passingGrade/reportMonth من src), const [], skipSync: true)`؛ `setExamOnlineFields(newId, isOnline: true, status: draft, durationMinutes: src.durationMinutes)` (بلا مواعيد)؛ `getQuestionsForExam(examId)` → `replaceExamQuestions(newId, qs.map((q) => q.copyWith(id: null, examId: newId)))`؛ `loadExams()`؛ يرجّع `newId`.
- [X] T023 [US3] في `lib/views/exams/online_exams_tab.dart` `_actions`: زر `_btn('نسخة جديدة', Icons.copy_all_rounded, () async { final id = await _ec.duplicateExam(exam.id!); if (id != null && context.mounted) { await onChanged(); final e = _ec.exams.firstWhereOrNull((x) => x.id == id); if (e != null) Get.to(() => OnlineExamEditorPage(existing: e)); } })` — في كل الحالات (draft/published/stopped/removed).

**Checkpoint**: كل القصص شغّالة.

---

## Phase 6: Polish

- [X] T024 `flutter analyze` — صفر أخطاء/تحذيرات.
- [X] T025 `flutter test` — كل الاختبارات تنجح (يشمل `question_bank_random_test`، `exam_duplicate_test`، `exam_question_cloud_map_test`).
- [X] T026 نشر `supabase/migration_question_bank.sql` على Supabase الإنتاج عبر SSH ([quickstart.md](quickstart.md) خطوة 0) + تحقّق (publication، RLS، 3 policies، idempotent).
- [ ] T027 [P] تحقّق بصري (فاتح/ليلي): شاشة البنك، sheet تحرير السؤال، شاشة الاختيار من البنك، زر "نسخة جديدة".
- [ ] T028 نفّذ [quickstart.md](quickstart.md) خطوات 1–19 (خصوصًا 7–9 مزامنة بجهازين، 15 فحص Firestore).
- [X] T029 [P] حدّث ملاحظات الجلسة: سبيك 025 — `bank_questions` (DB v28، القناة الممتدة، migration عبر SSH)، `BankQuestion`، `QuestionEditor` widget مشترك، `duplicateExam`، `pickRandom`.

---

## Dependencies & Execution Order

- **Phase 1 (T001)**: ثوابت.
- **Phase 2 (T002–T007)**: أساس، يحجب كل القصص. T002 (DB)؛ T003/T004 [P]؛ T005→T006→T007 (نفس `sync_engine`، تسلسلي).
- **US1 (T008–T014)**: بعد Phase 2. T008 (DB)؛ T009 (كنترولر، بعد T003/T008)؛ T010→T011 (استخراج المحرّر، تسلسلي، حسّاس)؛ T012 (بعد T009/T011)؛ T013؛ T014 (يكمّل T007).
- **US2 (T015–T020)**: بعد US1. T015 [P]؛ T016 (بعد T010/T011 — يلمس محرّر الامتحان)؛ T017 (بعد T015/T012)؛ T018/T019 (بعد T016/T017، نفس الملف)؛ T020 تحقّق.
- **US3 (T021–T023)**: بعد Phase 2. T021 [P]؛ T022→T023.
- **Polish (T024–T029)**: بعد الكل. T026 (نشر) قبل T028.

### فرص التوازي
- T003 (موديل) / T004 (SQL) [P].
- T015 (pickRandom) / T021 (duplicate test) [P] مع بعض ومع بداية US1.
- US3 مستقل عن US1/US2 — ممكن بالتوازي.
- T027/T029 [P].

---

## Implementation Strategy

**MVP**: Phase 1+2 + US1 → البنك يشتغل (CRUD + بحث + مزامنة). قف وتحقّق (quickstart 1–9).
**تدريجي**: US1 → US2 (تكامل المحرّر) → US3 (تكرار) → Polish (نشر migration + تحقّق).
**حسّاس**: T010/T011 (استخراج `QuestionEditor` من `online_exam_editor_page`) — `flutter analyze` بعد كل خطوة، والاحتياط (نسخة نظيفة) جاهز لو الاستخراج خطر.
**أمني**: أسئلة البنك في تخزين الفريq (RLS)؛ النسخ لامتحان يمرّ بـ`toCloudMap` — `exam_question_cloud_map_test` يظل يفرض.

## Notes

- نمط مزامنة `bank_questions` = `exam_questions` (spec 024) بالحرف، لكن أبسط (ملوش أب، لا dedup).
- `_queueRowUpsert` / `_queueDelete` موجودة من spec 024 — إعادة استخدام.
- migration عبر SSH لحاوية `active-class-auth-db-1` (spec 024 T029) — مش لوحة تحكم.
- "نسخة جديدة" للإلكتروني فقط في v1 (R6). "تكرار" فقط، لا قسم قوالب (R7).
- commit بعد كل قصة.
