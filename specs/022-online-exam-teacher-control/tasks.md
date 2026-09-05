---
description: "Task list — تحكّم أوسع للمدرس في الامتحان الإلكتروني (022-online-exam-teacher-control)"
---

# Tasks: تحكّم أوسع للمدرس في الامتحان الإلكتروني

**Input**: Design documents from `specs/022-online-exam-teacher-control/`
**Prerequisites**: plan.md, spec.md, data-model.md, quickstart.md

**Tests**: تحقّق يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات. مفيش مهام اختبار إلزامية (نفس نمط باقي المشروع).

**Organization**: 3 قصص. US1 (إلغاء الاعتماد) P1 — MVP. US2 (إبطال التسليم) P2. US3 (تعديل سؤال بعد النشر) P3. صفر جدول/عمود DB جديد، صفر تعديل Firestore rules.

## Path Conventions

Mobile single-project — `lib/`. المرجع: [plan.md](plan.md) Source Changes و[data-model.md](data-model.md).

---

## Phase 1: Setup

- [X] T001 في `lib/models/exam_submission_model.dart`: أضف `SubmissionStatus.voided` للـenum؛ `dbValue` يرجّع `'voided'`؛ `fromDb('voided')` يرجّع `SubmissionStatus.voided`؛ `label` يرجّع `'مُبطَل'`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: لا قصة تبدأ قبل ما الفيز دي تخلص.

- [X] T002 [P] في `lib/services/database_service.dart`: `Future<void> deleteGrade(int examId, int studentId)` — `db.delete(TABLE_EXAM_GRADES, where: '$COL_GRADE_EXAM_ID = ? AND $COL_GRADE_STUDENT_ID = ?', whereArgs: [examId, studentId])` + `_notifyChanged()`.
- [X] T003 [P] في `lib/services/database_service.dart`: `Future<void> voidSubmissionLocally(int examId, int studentId)` — `db.update(TABLE_EXAM_SUBMISSIONS, {COL_ES_STATUS: 'voided'}, where: '$COL_ES_EXAM_ID = ? AND $COL_ES_STUDENT_ID = ?', whereArgs: [examId, studentId])` + `_notifyChanged()`.
- [X] T004 [P] في `lib/services/online_exam_service.dart`: `Future<void> deleteSubmission(int examId, String attemptKey)` — `_examDoc(slug, examId).collection('submissions').doc(attemptKey).delete()`، best-effort (try/catch + `debugPrint`، زي `publishReview`).
- [X] T005 [P] في `lib/services/online_exam_service.dart`: `Future<void> deleteReview(int examId, String attemptKey)` — نفس الشكل لـ`.collection('results').doc(attemptKey).delete()`.
- [X] T006 في `lib/services/online_exam_service.dart`: `Future<void> republishQuestions(int examId, List<ExamQuestion> questions)` — `_examDoc(slug, examId).update({'questions': questions.map((q) => q.toCloudMap()).toList(), 'questionCount': questions.length, 'totalPoints': questions.fold(0.0,(s,q)=>s+q.points), 'updatedAt': FieldValue.serverTimestamp()})` — `update()` جزئي (مش `set()`) عشان يسيب `status`/`opensAt`/`closesAt`/`allowedCodes` زي ما هم. best-effort.

**Checkpoint**: كل الدوال الأساسية جاهزة — أي قصة تقدر تبدأ.

---

## Phase 3: User Story 1 - إلغاء اعتماد درجة بالغلط (Priority: P1) 🎯 MVP

**Goal**: زر يرجّع تسليم "معتمَد" لحالة "بانتظار الاعتماد" ويشيل كل أثر الدرجة عند الطالب وعلى الويب.

**Independent Test**: quickstart سيناريو 1–2.

- [X] T007 [US1] في `lib/controllers/exam_controller.dart`: `Future<void> unapproveOnlineGrade(int examId, int studentId)` — `_db.updateSubmissionApproval(examId, studentId, 0, SubmissionStatus.pending)` + `_db.deleteGrade(examId, studentId)` + `unawaited(ParentPortalService().pushStudentSummary(studentId))` + (best-effort) `_db.getStudent(studentId)` → `ParentPortalService().attemptKeyFor(student)` → `_online.deleteReview(examId, attemptKey)`.
- [X] T008 [US1] في `lib/views/exams/online_exam_results_page.dart` `_row(s)`: زر جديد "إلغاء الاعتماد" (أيقونة `Icons.undo_rounded` أو مشابه) يظهر بس لو `s.status == SubmissionStatus.approved` — بجانب زر القلم الموجود. `onPressed` → `showDialog` تأكيد (نص يوضّح إن الطالب لو شايف الدرجة بالفعل هتختفي) → عند التأكيد `_ec.unapproveOnlineGrade(_examId, s.studentId)` ثم `_load()`.

**Checkpoint**: US1 كامل ومستقل — المدرس يقدر يصحّح أي اعتماد غلط.

---

## Phase 4: User Story 2 - إبطال تسليم طالب (Priority: P2)

**Goal**: زر يمسح تسليم الطالب بالكامل (محليًا يتعلّم "مُبطَل"، وعلى الويب يتشال) عشان يقدر يسلّم تاني.

**Independent Test**: quickstart سيناريو 3–5.

- [X] T009 [US2] في `lib/controllers/exam_controller.dart`: `Future<void> voidSubmission(int examId, int studentId)` — نفس تسلسل `unapproveOnlineGrade` (حذف الدرجة + `pushStudentSummary` + حذف المراجعة) + `_db.voidSubmissionLocally(examId, studentId)` + (best-effort) `_online.deleteSubmission(examId, attemptKey)`. بيشتغل بغضّ النظر عن كون الحالة الحالية `pending` أو `approved` (زر واحد يعمل الاتنين — FR-014).
- [X] T010 [US2] في `online_exam_results_page.dart` `_row(s)`: زر جديد "إبطال التسليم" (أيقونة `Icons.block_rounded` أو مشابه، لون تحذيري) يظهر لو `s.status != SubmissionStatus.notSubmitted && s.status != SubmissionStatus.voided`. تأكيد صريح ("هيتمسح إجاباته الحالية نهائيًا ويقدر يسلّم من الأول") → `_ec.voidSubmission(_examId, s.studentId)` → `_load()`.
- [X] T011 [US2] في `online_exam_results_page.dart`: التسليمات `status == voided` تتعرض في قسم/تبويب منفصل (مش مختلطة مع قائمة "بانتظار الاعتماد" العادية) — تصميم مشابه لفصل `notSubmitted` الحالي لو موجود، وإلا فلتر بسيط فوق القائمة. `_summaryHeader` (متوسط الدرجات، عدد المعتمَد/الكل) MUST يستبعد `voided` من الحساب.

**Checkpoint**: US1+US2 يشتغلوا مع بعض.

---

## Phase 5: User Story 3 - تعديل سؤال في امتحان منشور (Priority: P3)

**Goal**: تعديل نص/اختيارات/إجابة صحيحة/درجة سؤال واحد بدون إلغاء نشر الامتحان، مع تحذير لو فيه تسليمات متأثرة.

**Independent Test**: quickstart سيناريو 6–8.

- [X] T012 [US3] في `lib/controllers/exam_controller.dart`: `Future<int> updateQuestionAfterPublish(ExamQuestion updated) async` — `await _db.updateQuestion(updated)`؛ `final subs = await _db.getSubmissionsForExam(updated.examId); final affected = subs.where((s) => s.status != SubmissionStatus.voided && s.answers.containsKey(updated.id)).length;`؛ `final questions = await _db.getQuestionsForExam(updated.examId); unawaited(_online.republishQuestions(updated.examId, questions));`؛ يرجّع `affected`.
- [X] T013 [US3] في `lib/views/exams/online_exam_editor_page.dart` `_questionCard(i)`: **تعديل عن الخطة** — حقول السؤال في الكارت قابلة للتعديل أصلاً (مفيش قفل فعلي، بس بانر تحذيري)، فبدل `showDialog` منفصل (تكرار كل الحقول)، اتضاف زر `FilledButton` "حفظ هذا السؤال" أسفل كل كارت — يظهر بس لو `_isPublished && q.id != null`. أبسط وأقل كود. البانر التحذيري اتحدّث يوضّح الإمكانية دي.
- [X] T014 [US3] في `online_exam_editor_page.dart` `_saveQuestionLive(int i)`: يتحقق `model.isValid` → `_ec.updateQuestionAfterPublish(model)` → لو `affected > 0`، `_blockingMsg` تحذير بعدد التسليمات + توجيه لـ"تحديث النتائج" (بدون أكشن تلقائي)؛ لو 0، `ToastHelper.success` عادي.
- [X] T015 [US3] تأكيد: إضافة/حذف سؤال في امتحان منشور يفضلوا معطّلين/يطلبوا إلغاء النشر زي دلوقتي (صفر تغيير في المنطق ده) — التعديل الجديد للسؤال الموجود بس.

**Checkpoint**: كل القصص شغّالة.

---

## Phase 6: Polish

- [X] T016 `flutter analyze` — صفر أخطاء/تحذيرات.
- [ ] T017 [P] تحقّق بصري (فاتح/ليلي): أزرار الاعتماد/الإبطال الجديدة في `online_exam_results_page`، دايلوج التعديل السريع ودايلوج التحذير في `online_exam_editor_page`.
- [ ] T018 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–10 كاملة على جهاز حقيقي (خصوصًا 1 و3 اللي بتلمس Firestore فعليًا).
- [X] T019 [P] حدّث ملاحظات الجلسة: سبيك 022، `SubmissionStatus.voided`، `unapproveOnlineGrade`/`voidSubmission` بيستخدموا نفس مسار حذف الدرجة، `republishQuestions` (update جزئي مش set كامل).

---

## Dependencies & Execution Order

- **Phase 1–2**: أساس — يحجب كل القصص. T002-T006 مستقلين عن بعض ([P]) إلا T006 (لوحده، بيُستخدم في US3 بس).
- **US1 (T007–T008)**: بعد Foundational. **MVP**.
- **US2 (T009–T011)**: بعد Foundational (T009 بيشبه T007 لكن مستقل — ممكن يتنفّذوا بالتوازي لو حابب). T010→T011 (نفس الملف، تسلسلي).
- **US3 (T012–T015)**: بعد Foundational (T006 تحديدًا). مستقل تمامًا عن US1/US2.
- **Polish**: بعد الكل.

### فرص التوازي
- T002/T003/T004/T005 [P] — ملفات/دوال مختلفة.
- US1 وUS2 وUS3 الثلاثة مستقلين عن بعض بعد Foundational — ممكن التنفيذ بالتوازي لو فريق أكتر من شخص.
- Polish: T017/T019 [P].

---

## Implementation Strategy

**MVP**: Phase 1+2 + US1 → إلغاء الاعتماد شغّال. قف وتحقّق (quickstart 1–2).
**تدريجي**: US1 → US2 (الإبطال) → US3 (تعديل السؤال) → Polish.

## Notes

- **صفر جدول/عمود DB جديد** — `voided` قيمة enum بس (العمود بلا CHECK constraint).
- **صفر تعديل Firestore rules** — القواعد الموجودة (`_oeOwner`) بتغطّي كل الحذف/التحديث المطلوب هنا.
- **`exam_questions` محلي بالكامل** (خارج مزامنة الفريق) — تعديل السؤال بعد النشر ميحتاجش أي تعامل مع `SyncEngine`.
- كل الحذف على Firestore (submissions/results) best-effort — فشل الشبكة ميمنعش الحفظ المحلي.
- commit بعد كل قصة.
