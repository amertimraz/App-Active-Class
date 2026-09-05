---
description: "Task list — تطويرات الامتحانات: معاينة، شرح، حذف، تحليل، تصدير (023-exam-preview-analytics-export)"
---

# Tasks: تطويرات الامتحانات — معاينة، تحليل، تصدير، شرح الإجابة، حذف

**Input**: Design documents from `specs/023-exam-preview-analytics-export/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: تحقّق يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات. مهمة اختبار واحدة إلزامية (`ExamAnalyticsService` — منطق حساب نقي، نمط `test/at_risk_service_test.dart`). باقي القصص تحقّق يدوي.

**Organization**: ٥ قصص مستقلة. US1 (معاينة) P1 — MVP. US2 (شرح) P2. US5 (حذف) P2. US3 (تحليل) P3. US4 (تصدير) P3.

## Path Conventions

Mobile single-project — `lib/` + ملف ويب ثابت `booking_site/exam/index.html`. المرجع: [plan.md](plan.md) Source Code و[data-model.md](data-model.md) و[contracts/](contracts/).

---

## Phase 1: Setup

- [X] T001 [P] في `lib/services/export_service.dart`: أضف `enum ExportFormat { xlsx, pdf }` (أعلى الملف، خارج الصنف) — يُستخدم في US4.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: T002–T003 تحجب US2 فقط (ترقية DB). باقي القصص تقدر تبدأ بدونها.

- [X] T002 في `lib/config/constants.dart`: `DATABASE_VERSION` من `25` إلى `26`؛ أضف `const String COL_EQ_EXPLANATION = 'explanation';` بجانب باقي `COL_EQ_*`.
- [X] T003 في `lib/services/database_service.dart`: (أ) أضف سطر `$COL_EQ_EXPLANATION    TEXT,` في `_examQuestionsTableSql` قبل `$COL_EQ_CREATED_AT`. (ب) في `_onUpgrade` بعد بلوك `if (oldVersion < 25)`، أضف:
  ```dart
  if (oldVersion < 26) {
    try {
      await db.execute(
          'ALTER TABLE $TABLE_EXAM_QUESTIONS ADD COLUMN $COL_EQ_EXPLANATION TEXT');
    } catch (_) {}
  }
  ```

**Checkpoint**: قاعدة البيانات جاهزة للشرح — كل القصص تقدر تبدأ.

---

## Phase 3: User Story 1 - معاينة الامتحان قبل النشر (Priority: P1) 🎯 MVP

**Goal**: شاشة عرض للقراءة فقط تُظهر الامتحان كما يراه الطالب — بلا إجابة/شرح/تسليم.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 1–4.

- [X] T004 [US1] أنشئ `lib/views/exams/online_exam_preview_page.dart`: `StatelessWidget` `OnlineExamPreviewPage({required Exam exam, required List<ExamQuestion> questions})`. `Scaffold` + `AppBar('معاينة الامتحان')`، `Directionality(rtl)`. ترويسة: اسم الامتحان، `${questions.length} سؤال`، `الدرجة الكلية: ${questions.fold<double>(0,(s,q)=>s+q.points)}`، `المدة: ${exam.durationMin ?? '—'} دقيقة`. لافتة تنبيه: "معاينة — لو الخلط مفعّل، ترتيب الأسئلة/الاختيارات عند الطالب ممكن يختلف". ثم `ListView.builder` كارت لكل سؤال: رقم + نص، `Image.network(q.imageUrl!)` لو موجود مع `loadingBuilder`/`errorBuilder`، ثم الاختيارات كصفوف محايدة (`Text` + نقطة، **بلا** راديو/تحديد/تمييز صحيح). صفر أزرار تفاعل. لا تعرض `correctIndex` ولا `explanation`.
- [X] T005 [US1] في `lib/views/exams/online_exam_editor_page.dart`: زر "معاينة" (`IconButton` أيقونة `Icons.visibility_outlined`) في `AppBar.actions`. عند الضغط: اجمع الأسئلة الحالية من الحالة (نفس مصدر الحفظ/النشر). لو مفيش أسئلة صالحة (`questions.where((q)=>q.isValid).isEmpty`) → `_blockingMsg`/`ToastHelper` "الامتحان محتاج أسئلة صالحة قبل المعاينة". غير كده → `Get.to(() => OnlineExamPreviewPage(exam: <exam الحالي>, questions: <الصالحة>))`. متاح سواء `_isPublished` أو مسودّة.

**Checkpoint**: US1 كامل ومستقل — المدرس يعاين قبل النشر.

---

## Phase 4: User Story 2 - شرح الإجابة الصحيحة (Priority: P2)

**Goal**: حقل شرح اختياري لكل سؤال، يظهر للطالب في المراجعة بعد الاعتماد، ولا يُرفع أبدًا في المستند العام.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 5–11. **Prereq**: Phase 2 (T002–T003).

- [X] T006 [US2] في `lib/models/exam_question_model.dart`: أضف `final String? explanation;` للحقول والباني. `toMap()`: `COL_EQ_EXPLANATION: explanation`. `fromMap()`: `explanation: (m[COL_EQ_EXPLANATION] as String?)?.isNotEmpty == true ? m[COL_EQ_EXPLANATION] as String : null`. `copyWith`: `Object? explanation = _unset` + منطق نمط `imageUrl`. **`isValid` دون تغيير. `toCloudMap()` دون تغيير إطلاقًا** (لا يضيف `explanation`).
- [X] T007 [P] [US2] في `test/exam_question_cloud_map_test.dart` (جديد): اختبار وحدة يفرض `ExamQuestion(..., explanation: 'س', correctIndex: 1, points: 3).toCloudMap().keys` ⊆ `{'id','type','text','options','imageUrl'}` — لا `explanation`/`correctIndex`/`points`.
- [X] T008 [US2] في `lib/views/exams/online_exam_editor_page.dart` `_questionCard(i)`: بعد صف الدرجة، `TextField` "شرح الإجابة (اختياري)" — `maxLength: 500`, `maxLines: 2`, يربط بـ`q.explanation` (controller أو `onChanged` → `copyWith(explanation: ...)`), نص مساعد "يظهر للطالب في مراجعة إجاباته بعد اعتماد الدرجة". تأكّد إن `toModel()`/بناء `ExamQuestion` عند الحفظ (مسودّة/نشر/حفظ مباشر spec 022) يمرّر `explanation`.
- [X] T009 [US2] في `lib/models/exam_submission_model.dart` `QuestionResult`: أضف `final String? explanation;` للحقول والباني (اختياري، بعد `imageUrl`).
- [X] T010 [US2] في `lib/controllers/exam_controller.dart` `questionResults(sub)`: عند بناء كل `QuestionResult` أضف `explanation: q.explanation`.
- [X] T011 [US2] في `lib/services/online_exam_service.dart` `publishReview`: داخل `results.map((r) => {...})`، أضف `if (r.explanation != null && r.explanation!.isNotEmpty) 'explanation': r.explanation,`.
- [X] T012 [US2] في `booking_site/exam/index.html` `renderReview(questions)`: بعد سلسلة `opts` وقبل `<div class="rfoot">`، أضف `${q.explanation ? `<div class="rexpl"><span class="rexpl-i">💡</span><span>${escapeHtml(q.explanation)}</span></div>` : ''}`. أضف CSS `.rexpl` (خلفية خفيفة، `border-right:3px solid var(--accent)`، padding، `border-radius`، خط 12.5px، `margin-top:8px`) و`.rexpl-i`.
- [ ] T013 [US2] انشر `booking_site/exam/index.html` إلى VPS: `scp -i ~/.ssh/ovh_key booking_site/exam/index.html root@active-class.online:/var/www/active-class.online/exam/index.html` ثم تحقّق `curl -s https://active-class.online/exam/ | grep -c "rexpl"` (≥ 2).

**Checkpoint**: US2 كامل — الشرح يوصل للطالب بعد الاعتماد فقط، والمستند العام نظيف.

---

## Phase 5: User Story 5 - حذف الامتحان الإلكتروني نهائيًا (Priority: P2)

**Goal**: حذف كامل (محلي + سحابي بكل المجموعات الفرعية) لأي امتحان إلكتروني في أي حالة.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 20–25. مستقل تمامًا عن باقي القصص.

- [X] T014 [US5] في `lib/services/online_exam_service.dart` `deleteRemote(examId)`: غيّر `for (final sub in ['submissions', 'attempts'])` إلى `for (final sub in ['submissions', 'attempts', 'results'])`. باقي الدالة (batch حد 400، `examRef.delete()`، try/catch) كما هي.
- [X] T015 [US5] في `lib/controllers/exam_controller.dart`: `Future<String?> deleteOnlineExam(int examId)` — `String? warn; try { await _online.deleteRemote(examId); } catch (_) { warn = 'تم الحذف من التطبيق — لكن تنظيف السحابة قد لا يكون اكتمل'; } await _db.deleteExam(examId); await loadExams(); return warn;` (نمط `removeOnlineExamFromWeb`).
- [X] T016 [US5] في `lib/views/exams/online_exams_tab.dart` `_actions(context, status, c)`: أضف في **كل** فروع `switch` (draft, published, stopped, removed) عنصر `_btn('حذف نهائي', Icons.delete_forever_outlined, () { _confirm(context, title: 'حذف الامتحان نهائيًا', color: const Color(0xFFDC2626), icon: Icons.delete_forever_rounded, body: 'مفيش رجوع. هيتمسح الامتحان وكل أسئلته، وكل التسليمات والدرجات المعتمَدة، وصفحات مراجعة الطلاب على الويب.', onYes: () => _run(() => _ec.deleteOnlineExam(exam.id!), 'اتحذف الامتحان')); })`. **لا تلمس** زر "حذف من الويب" الحالي في published/stopped.

**Checkpoint**: US5 كامل — تنظيف القائمة ممكن لأي حالة.

---

## Phase 6: User Story 3 - إحصائيات الأسئلة بعد التصحيح (Priority: P3)

**Goal**: لكل سؤال: نسبة الصح، توزيع الاختيارات، عدد غير المجيبين، أبرز distractor — مستبعدًا `voided`.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 12–15 + `flutter test test/exam_analytics_service_test.dart`.

- [ ] T017 [P] [US3] أنشئ `lib/models/exam_analytics_model.dart`: `class QuestionAnalytics` غير قابل للتغيير — الحقول: `questionId`, `questionText`, `options`, `correctIndex`, `optionCounts` (`List<int>`), `answeredCount`, `notAnsweredCount`, `correctCount`, `totalRespondents`. getters: `double get correctRate` (`totalRespondents == 0 ? 0 : correctCount / totalRespondents`)، `int? get topDistractorIndex` (أعلى `optionCounts` بين فهارس ≠ correctIndex وقيمته > 0، وإلا null).
- [ ] T018 [P] [US3] أنشئ `lib/services/exam_analytics_service.dart` (Dart نقي): `static List<QuestionAnalytics> compute({required List<ExamQuestion> questions, required List<ExamSubmission> submissions})` حسب [contracts/exam-analytics-service.md](contracts/exam-analytics-service.md) — `valid = submissions.where((s) => s.status != SubmissionStatus.voided)`؛ لكل سؤال عدّ `s.answers[q.id]` (null/خارج المدى → notAnswered)؛ حدود آمنة على `correctIndex`. يتخطّى سؤالًا بلا `id`.
- [ ] T019 [P] [US3] أنشئ `test/exam_analytics_service_test.dart`: الحالات في العقد — ٥ تسليمات/٣ أسئلة بحساب يدوي معروف، تسليم `voided` مستبعد، كل الإجابات صح → `topDistractorIndex == null`، كلهم تركوا السؤال، إجابات بمفاتيح `questionId` مختلطة، `submissions` فارغة.
- [ ] T020 [US3] أنشئ `lib/views/exams/exam_analytics_page.dart`: `StatefulWidget` `ExamAnalyticsPage({required Exam exam})`. `initState`/`FutureBuilder`: `_db.getQuestionsForExam(exam.id!)` + `_db.getSubmissionsForExam(exam.id!)` → `ExamAnalyticsService.compute(...)`. لو كل `totalRespondents == 0` → رسالة "لا توجد تسليمات كافية للتحليل". غير كده: ترويسة (عدد التسليمات المُحلَّلة، أضعف سؤال = أقل `correctRate`)، ثم `ListView` كارت لكل `QuestionAnalytics`: رقم+نص، سطر `${(correctRate*100).round()}% صح (${correctCount}/${totalRespondents})`، صفوف الاختيارات (نص + عدد؛ الصحيح خلفية خضراء + ✓؛ `topDistractorIndex` حدّ تحذيري)، سطر `لم يجب: ${notAnsweredCount}`.
- [ ] T021 [US3] في `lib/views/exams/online_exam_results_page.dart`: أيقونة `Icons.insights_rounded` في `AppBar.actions` → `Get.to(() => ExamAnalyticsPage(exam: <exam>))`.

**Checkpoint**: US3 كامل ومستقل.

---

## Phase 7: User Story 4 - تصدير نتائج الامتحان (Priority: P3)

**Goal**: تصدير جدول نتائج (إلكتروني + ورقي كل المجموعات) كـExcel أو PDF عبر ورقة المشاركة.

**Independent Test**: [quickstart.md](quickstart.md) خطوات 16–19. **Prereq**: T001 (`ExportFormat`).

- [ ] T022 [P] [US4] في `lib/services/database_service.dart`: `Future<List<Map<String, dynamic>>> getExamGradesForExport(int examId, {int? groupId})` — `rawQuery` يربط `students` × `exam_grades` (LEFT JOIN على examId) × `groups` × `exams` لطلاب مجموعات الامتحان (`exam_groups` أو `students.group_id in exam.groupIds`)، يرجّع: اسم الطالب، الكود، اسم المجموعة، الدرجة (`COL_GRADE_VALUE`)، `is_absent`، `max_grade`، `passing_grade`. مرتّب باسم المجموعة ثم اسم الطالب. `groupId != null` → فلتر لمجموعة واحدة. قراءة فقط.
- [ ] T023 [US4] في `lib/services/export_service.dart`: `Future<ExportResult> exportExamGradesSheet({required Exam exam, required ExportFormat format, int? onlyGroupId})` — يقرأ `getExamGradesForExport(exam.id!, groupId: onlyGroupId)`؛ صف ترويسة عربي + صف لكل طالب (الاسم/الكود/[المجموعة لو onlyGroupId==null و groupIds.length>1]/الدرجة/الكلية/النسبة/الحالة: "غائب"/"لم يُدخل"/رقم)؛ صيغة `xlsx` عبر `excel` package (نمط `excel_import_service.dart`)، صيغة `pdf` عبر `pw.Table` RTL بخطوط Cairo (نمط `exam_grades_page._exportPdf`). اسم الملف `نتائج_${sanitize(exam.name)}_${yyyy-MM-dd}.{ext}`. يرجّع `ExportResult`. **لا** `Share` هنا (المتصل يشارك).
- [ ] T024 [US4] في `lib/services/export_service.dart`: `Future<ExportResult> exportOnlineExamResults({required Exam exam, required List<ExamSubmission> submissions, required List<Student> students, required ExportFormat format})` — صف لكل طالب في مجموعات `exam.groupIds`: الاسم/الكود/المكتسب (`finalGrade ?? autoScore`)/`exam.maxGrade`/النسبة/الحالة (`approved`→"معتمَد"، `pending`→"بانتظار الاعتماد"، `voided`→"مُبطَل"، لا تسليم→"لم يسلّم"). صف تذييل: عدد المعتمَد، متوسط المعتمَد فقط، الأعلى (المُبطَل/لم يسلّم مستبعدان من المتوسط). نفس صيغتي الملف. يرجّع `ExportResult`.
- [ ] T025 [US4] في `lib/views/exams/online_exam_results_page.dart`: أيقونة `Icons.download_rounded` في `AppBar.actions` → `showModalBottomSheet` باختيار Excel/PDF → `_ec`/`_db` يجهّز `submissions` + `students` → `ExportService().exportOnlineExamResults(...)` → `Share.shareXFiles([XFile(result.path)])` (نمط `ExportService` الحالي). عرض تحميل أثناء التوليد.
- [ ] T026 [US4] في `lib/views/exams/exam_grades_page.dart`: بجانب `_exportPdf` الحالي، زر/عنصر قائمة "تصدير" → اختيار النطاق ("هذه المجموعة" / "كل مجموعات الامتحان" — الأخير يظهر لو `widget.exam.groupIds.length > 1`) ثم الصيغة (Excel/PDF) → `ExportService().exportExamGradesSheet(exam: widget.exam, format: ..., onlyGroupId: <this group | null>)` → `Share.shareXFiles`.

**Checkpoint**: كل القصص شغّالة.

---

## Phase 8: Polish

- [ ] T027 `flutter analyze` — صفر أخطاء/تحذيرات.
- [ ] T028 `flutter test` — كل الاختبارات تنجح (تشمل `exam_analytics_service_test.dart` و`exam_question_cloud_map_test.dart`).
- [ ] T029 [P] تحقّق بصري (فاتح/ليلي): شاشة المعاينة، حقل الشرح في المحرّر، صفحة تحليل الأسئلة، أزرار التصدير + زر "حذف نهائي" وحواره.
- [ ] T030 نفّذ [quickstart.md](quickstart.md) خطوات 1–25 على جهاز حقيقي (خصوصًا 7/9/22 اللي بتفحص Firestore فعليًا، و10/13 نشر VPS).
- [ ] T031 [P] حدّث ملاحظات الجلسة: سبيك 023 — `ExamQuestion.explanation` (DB v26، مش في toCloudMap)، `deleteRemote` بقت تشمل `results`، `deleteOnlineExam`، `ExamAnalyticsService`، تصدير Excel/PDF للنتائج.

---

## Dependencies & Execution Order

- **Phase 1 (T001)**: مستقل. **Phase 2 (T002–T003)**: تسلسلي (نفس منطقة constants/DB)، يحجب US2 فقط.
- **US1 (T004–T005)**: بعد Setup. T004→T005 (T005 يستورد T004). **MVP**.
- **US2 (T006–T013)**: بعد Phase 2. T006→T008 (نفس الموديل ثم المحرّر)؛ T007 [P] بعد T006؛ T009→T010؛ T011 بعد T009/T010؛ T012→T013 (نشر بعد التعديل).
- **US5 (T014–T016)**: بعد Setup. T014→T015→T016. مستقل تمامًا.
- **US3 (T017–T021)**: بعد Setup. T017/T018/T019 [P]؛ T020 بعد T017/T018؛ T021 بعد T020.
- **US4 (T022–T026)**: بعد T001. T022 [P]؛ T023 بعد T022؛ T024 [P] مع T023؛ T025 بعد T024؛ T026 بعد T023.
- **Polish (T027–T031)**: بعد الكل.

### فرص التوازي
- US1 / US2 / US5 / US3 / US4 مستقلة بعد Setup+Phase 2 — قابلة للتنفيذ بالتوازي بفريق.
- داخل US2: T007. داخل US3: T017/T018/T019. داخل US4: T022 ثم T023+T024.
- Polish: T029/T031.

---

## Implementation Strategy

**MVP**: Phase 1 + US1 → معاينة الامتحان شغّالة. قف وتحقّق (quickstart 1–4).
**تدريجي**: US1 → US2 (شرح، يشمل نشر VPS) → US5 (حذف) → US3 (تحليل) → US4 (تصدير) → Polish.
**أمني**: T006 + T007 يضمنان إن `toCloudMap` يفضل نظيف؛ T011 هو المكان الوحيد اللي الشرح بيخرج فيه (بعد الاعتماد).

## Notes

- ترقية DB واحدة (v25→v26)، عمود واحد، `exam_questions` محلي بالكامل → صفر Supabase migration، صفر `_queueSync`.
- صفر تعديل `firestore.rules` — قواعد `_oeOwner` + `allow read: if true` الموجودة تغطّي المراجعة والحذف.
- كل كتابات/حذف Firestore best-effort — فشل الشبكة ما يفشّلش العملية المحلية.
- commit بعد كل قصة.
