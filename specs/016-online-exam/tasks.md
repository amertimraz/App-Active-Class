---
description: "Task list — امتحان إلكتروني (016-online-exam)"
---

# Tasks: امتحان إلكتروني (اختبار أونلاين)

**Input**: Design documents from `specs/016-online-exam/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: لا توجد بنية اختبار آلي — التحقّق يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات. لا مهام اختبار.

**Organization**: 4 قصص (US1/US2/US3 = P1 مترابطة كسلسلة تأليف→حل→تصحيح؛ US4 = P2). كل plumbing قاعدة البيانات + الموديلات + خدمة السحابة + قواعد Firestore في المرحلة الأساسية.

## Path Conventions

Mobile single-project: كل الكود تحت `lib/`. صفحة الطالب تحت `booking_site/`. قواعد الأمان في `firestore.rules` بجذر الريبو.

**قرارات مرجعية**: [data-model.md](data-model.md) للأعمدة/الجداول، [contracts/firestore-online-exams.md](contracts/firestore-online-exams.md) للسحابة، [contracts/student-exam-page.md](contracts/student-exam-page.md) لصفحة الطالب.

---

## Phase 1: Setup

- [x] T001 في `lib/config/constants.dart`: ارفع `DATABASE_VERSION` من `22` إلى `23`. أضف ثوابت الجداول: `const String TABLE_EXAM_QUESTIONS = 'exam_questions';` و`const String TABLE_EXAM_SUBMISSIONS = 'exam_submissions';` جنب `TABLE_EXAM_GRADES`. أضف ثوابت أعمدة `exams` الجديدة: `COL_EXAM_IS_ONLINE = 'is_online'`, `COL_EXAM_ONLINE_STATUS = 'online_status'`, `COL_EXAM_OPENS_AT = 'opens_at'`, `COL_EXAM_CLOSES_AT = 'closes_at'`, `COL_EXAM_DURATION_MIN = 'duration_minutes'`. أضف ثوابت أعمدة الجدولين الجديدين (`COL_EQ_*` لـ exam_questions: exam_id/position/type/text/options/correct_index/points/created_at؛ `COL_ES_*` لـ exam_submissions: exam_id/student_id/started_at/submitted_at/answers_json/auto_score/final_grade/status/auto_submitted/pulled_at).

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: مفيش شغل user story يبدأ قبل اكتمال المرحلة دي.

### 2أ — قاعدة البيانات (schema + migration)

- [x] T002 في `lib/services/database_service.dart` `_createTables` (جدول `$TABLE_EXAMS` سطر ~178): أضف الأعمدة الخمسة الجديدة (`$COL_EXAM_IS_ONLINE INTEGER NOT NULL DEFAULT 0`, `$COL_EXAM_ONLINE_STATUS TEXT`, `$COL_EXAM_OPENS_AT TEXT`, `$COL_EXAM_CLOSES_AT TEXT`, `$COL_EXAM_DURATION_MIN INTEGER`) قبل أعمدة الـsync.
- [x] T003 في `lib/services/database_service.dart` `_createTables`: أضف `CREATE TABLE IF NOT EXISTS $TABLE_EXAM_QUESTIONS (...)` و`CREATE TABLE IF NOT EXISTS $TABLE_EXAM_SUBMISSIONS (...)` بالأعمدة من [data-model.md](data-model.md#2-جدول-جديد-exam_questions). أضف فهرس `idx_exam_questions_exam_id (exam_id, position)` وفهرس فريد `idx_exam_submissions_unique (exam_id, student_id)` في `_createIndexes`.
- [x] T004 في `lib/services/database_service.dart` `_onUpgrade` (بعد guard `oldVersion < 22` سطر ~562): أضف `if (oldVersion < 23) { ... }` — خمس `ALTER TABLE $TABLE_EXAMS ADD COLUMN ...` داخل `try/catch` لكل عمود، ثم `CREATE TABLE IF NOT EXISTS` للجدولين، ثم إنشاء الفهارس. نمط v20/v21.

### 2ب — الموديلات

- [x] T005 [P] في `lib/models/exam_question_model.dart` (جديد): `enum ExamQuestionType { trueFalse, mcq }` (+ extension `dbValue`/`fromDb` → `'true_false'`/`'mcq'`). كلاس `ExamQuestion` — `id`, `examId`, `position`, `type`, `text`, `List<String> options`, `int correctIndex`, `double points`, `createdAt`. `toMap()` (options → `jsonEncode`)، `fromMap()` (options → `jsonDecode`)، `copyWith()`. `Map<String,dynamic> toCloudMap()` — يرجّع `{'id': 'q$id', 'type': type.dbValue, 'text': text, 'options': options}` **بدون correctIndex/points** (FR-034).
- [x] T006 [P] في `lib/models/exam_submission_model.dart` (جديد): `enum SubmissionStatus { pending, approved, notSubmitted }` (+ dbValue/fromDb). كلاس `ExamSubmission` — `id`, `examId`, `studentId`, `startedAt`, `submittedAt`, `Map<int,int> answers` (questionId→chosenIndex؛ يُخزَّن `answers_json`)، `double autoScore`, `double finalGrade`, `SubmissionStatus status`, `bool autoSubmitted`, `pulledAt`, + بيانات JOIN `String? studentName`. toMap/fromMap/copyWith. getters مساعدة يستخدمها UI النتائج لاحقًا: احسبها في الكنترولر مش هنا (الموديل ما يعرفش الإجابات الصحيحة).
- [x] T007 في `lib/models/exam_model.dart`: أضف `final bool isOnline`, `final OnlineExamStatus? onlineStatus`, `final DateTime? opensAt`, `final DateTime? closesAt`, `final int? durationMinutes` + `enum OnlineExamStatus { draft, published, stopped, removed }` (في نفس الملف أو `exam_question_model.dart`). حدّث الكونستركتور (defaults: `isOnline = false`، الباقي null) + `toMap` (لاحظ toMap يستخدم string literals — استخدم `'is_online': isOnline ? 1 : 0` إلخ؛ التواريخ `?.toIso8601String()`) + `fromMap` + `copyWith` (sentinel `_unset` لكل nullable زي `reportMonth` الموجود).

### 2ج — DB CRUD

- [x] T008 في `lib/services/database_service.dart`: أضف دوال الأسئلة — `getQuestionsForExam(int examId)` (ORDER BY position)، `insertQuestion(ExamQuestion)`، `updateQuestion(ExamQuestion)`، `deleteQuestion(int id)`، `reorderQuestions(int examId, List<int> orderedIds)`. **لا `_queueSync`** — خارج المزامنة (R7).
- [x] T009 في `lib/services/database_service.dart`: أضف `setExamOnlineFields(int examId, {required bool isOnline, OnlineExamStatus? status, DateTime? opensAt, DateTime? closesAt, int? durationMinutes})` — `UPDATE $TABLE_EXAMS SET ...`. وأضف `setExamOnlineStatus(int examId, OnlineExamStatus status)` مختصرة. مرّرها عبر `_queueSync(TABLE_EXAMS, examId, 'update', ...)` **بدون** الأعمدة الجديدة في الـpayload (تفضل محلية — R7).
- [x] T010 في `lib/services/database_service.dart`: أضف `upsertSubmission(ExamSubmission)` — INSERT ... ON CONFLICT(exam_id, student_id) DO UPDATE (يحافظ على `final_grade`/`status` لو `status == 'approved'`؛ راجع R9)، و`getSubmissionsForExam(int examId)` (JOIN students للاسم)، و`getSubmissionForStudent(int examId, int studentId)`.
- [x] T011 في `lib/services/database_service.dart`: أضف `Future<({Map<String,bool> allowed, int excludedCount})> allowedStudentCodesForGroups(List<int> groupIds)` — SELECT `code, guardian_phone` من `students` WHERE `group_id IN (...)` AND `is_archived = 0`. لكل طالب: نظّف الأرقام من `guardian_phone`؛ لو < 4 أرقام → `excludedCount++`؛ غير كده `allowed[code.toUpperCase()] = true`. `allowed` تُرفع كـ `allowedCodes` (FR-008)؛ `excludedCount` لتحذير النشر (edge case "طالب بلا رقم ولي أمر").
- [x] T012 في `lib/services/database_service.dart` `deleteExam` (~1766): تأكّد إن الحذف بيمسح `exam_questions` و`exam_submissions` التابعة (أضف `txn.delete` لكل منهما جنب `exam_grades`).

### 2د — خدمة السحابة + قواعد Firestore

- [x] T013 في `lib/services/parent_portal_service.dart`: تأكّد إن `ensureSlug()` عامة وقابلة للاستدعاء من خدمة تانية (هي كده `Future<String>` public). لا تغيير سلوك — تعليق سطر يوضّح إنها مصدر الـslug المشترك لسبيك 016.
- [x] T014 في `lib/services/online_exam_service.dart` (جديد): كلاس `OnlineExamService` singleton على غرار `ParentPortalService` — `FirebaseFirestore get _db`, `FirebaseAuth get _auth`, `_ensureAuth()` (نسخة من parent_portal), `_slug()` → `ParentPortalService().ensureSlug()`. دوال فارغة توقيعها فقط (implementation في US1/US3/US4): `Future<void> publish(Exam exam, List<ExamQuestion> qs, Map<String,String> allowedCodes)`, `Future<void> unpublish(int examId)`, `Future<void> stopNow(int examId, DateTime closesAtUtc)`, `Future<void> deleteRemote(int examId)`, `Future<List<CloudSubmission>> fetchSubmissions(int examId)`. عرّف `class CloudSubmission { final String code; final Map<String,int> answers; final DateTime? startedAt, submittedAt; final bool autoSubmitted; }`.
- [x] T015 في `firestore.rules`: أضف بلوك `match /online_exams/{slug} { ... }` كامل قبل قوس الإغلاق الأخير — انسخ حرفيًا من [contracts/firestore-online-exams.md](contracts/firestore-online-exams.md#قواعد-الأمان-تُضاف-إلى-firestorerules-قبل-قوس-الإغلاق-الأخير)، مع استثناء الحذف لصاحب الرابط على `attempts`/`submissions` (المذكور في نهاية العقد). **شغل يدوي على المستخدم**: `firebase deploy --only firestore:rules`.

### 2هـ — هيكل الواجهة + بوابة الترخيص

- [x] T016 في `lib/views/exams/exams_page.dart`: لفّ الـ`Scaffold` body في `DefaultTabController(length: 2)` مع `TabBar` (تبويبان: "ورقي" — المحتوى الحالي كما هو؛ "إلكتروني" — `_OnlineExamsTab` جديد). تبويب "إلكتروني" يظهر فقط لو `LicenseController.to.parentPortalActiveNow` (Obx)؛ غير كده يعرض حالة مقفولة "الامتحانات الإلكترونية ضمن إضافة بوابة الأهالي". FAB "امتحان جديد" يتفرّع حسب التبويب النشط (ورقي → `_showExamSheet`؛ إلكتروني → `Get.to(OnlineExamEditorPage())`).
- [x] T017 [P] في `lib/views/exams/online_exams_tab.dart` (جديد، أو widget داخل exams_page): قائمة الامتحانات الإلكترونية (`_ec.exams.where((e) => e.isOnline)`), كل كارت يعرض: الاسم، الحالة (`onlineStatus`)، النافذة الزمنية، عدد التسليمات (لو منشور/موقوف)، وأزرار سياقية (تعديل/نشر لمسودّة؛ نتائج/إيقاف/حذف لمنشور). Placeholder onPressed لحد US1/US3/US4.

**Checkpoint**: DB v23 جاهزة، الموديلات + CRUD + هيكل الخدمة + القواعد + التبويب موجودين. مفيش سلوك مستخدم كامل بعد.

---

## Phase 3: User Story 1 - المدرس يؤلّف امتحانًا وينشره (Priority: P1) 🎯 MVP

**Goal**: المدرس ينشئ امتحان أسئلة موضوعية، يضبط النافذة/المدة/المجموعات، وينشره للسحابة بدون مفتاح إجابة.

**Independent Test**: quickstart سيناريو 1 — إنشاء امتحان 3 أسئلة، نشر، والتأكد من مستند Firestore بلا `correct`.

- [x] T018 [US1] في `lib/views/exams/online_exam_editor_page.dart` (جديد): شاشة تأليف — حقل الاسم، قائمة أسئلة قابلة لإعادة الترتيب (`ReorderableListView`)، كل سؤال محرّر inline (نوع: صح/خطأ أو اختياري؛ نص؛ اختيارات 2–6 للاختياري؛ تحديد الإجابة الصحيحة؛ درجة). زر "إضافة سؤال". قسم الإعدادات: اختيار المجموعات (multi-select من `GroupController`)، `opensAt`/`closesAt` (date+time pickers)، `durationMinutes`. يعرض إجمالي الدرجة المحسوب. أزرار "حفظ كمسودّة" و"نشر".
- [x] T019 [US1] في `lib/controllers/exam_controller.dart`: أضف `createOnlineExamDraft({required String name})` → ينشئ صف `exams` بـ `isOnline=1, onlineStatus=draft`، يرجّع `examId`. و`saveOnlineExamDraft(Exam exam, List<ExamQuestion> questions, List<int> groupIds)` → يحفظ الامتحان + upsert الأسئلة (حذف المحذوف) + ربط المجموعات (نفس `editExam` junction).
- [x] T020 [US1] في `lib/controllers/exam_controller.dart`: أضف `Future<String?> publishOnlineExam(int examId)` — (1) تحقّق `LicenseController.to.parentPortalActiveNow` وإلا رجّع رسالة الإضافة؛ (2) تحقّق القيود: ≥1 سؤال، ≥1 مجموعة، `opensAt < closesAt`، `durationMinutes > 0`، `durationMinutes*60 ≤ closesAt-opensAt` (FR-007/009) — رجّع رسالة مناسبة لكل فشل؛ (3) `final r = await db.allowedStudentCodesForGroups(groupIds)`؛ لو `r.allowed.isEmpty` → رجّع "مفيش طلاب لهم رقم ولي أمر صالح في المجموعات المختارة"؛ لو `r.excludedCount > 0` اعرض تحذير غير حاجب؛ (4) `await OnlineExamService().publish(exam, questions, r.allowed)`؛ (5) `db.setExamOnlineStatus(examId, published)`؛ (6) `loadExams()`. أي استثناء (شبكة) → رجّع "تحقق من اتصالك بالإنترنت" والحالة تفضل `draft`.
- [x] T021 [US1] في `lib/services/online_exam_service.dart`: نفّذ `publish()` — راجع [تسلسل النشر في العقد](contracts/firestore-online-exams.md#تسلسل-النشر-onlineexamservicepublish). `ensureSlug` → `_ensureAuth` → `ParentPortalService().publishProfile()` (مستند الأب) → **ضمان ملخصات الطلاب**: لكل كود في `allowedCodes`، تحقّق وجود `parent_portal/{slug}/students/{code}_{last4}` (فحص هوية T025 يعتمد عليها)؛ لو أي واحد ناقص → `await ParentPortalService().publishAllStudents()` مرة واحدة (best-effort، داخل try/catch — لا تفشل النشر بسببه) → `set` على `online_exams/{slug}` (`ownerUid`/`deviceId`/`active:true`/`updatedAt` — merge) → `set` على `online_exams/{slug}/exams/$examId` بالمستند من [data-model](data-model.md#online_examsslugexamsexamid-امتحان-منشور--examid--id-المحلي-كنص): `title`, `questionCount`, `totalPoints`, `opensAt`/`closesAt` (`.toUtc().toIso8601String()`), `durationMinutes`, `allowedGroupNames`, `allowedCodes` (خريطة code→true), `questions` (`qs.map((q) => q.toCloudMap())`), `status:'published'`, `publishedAt`/`updatedAt` serverTimestamp. **تأكيد: مفيش أي مفتاح إجابة**.
- [x] T022 [US1] في `lib/services/online_exam_service.dart`: نفّذ `unpublish(examId)` — `delete` على `online_exams/{slug}/exams/$examId` (بدون لمس التسليمات المحلية). يُستدعى من زر "إلغاء النشر" في التبويب (FR-018) — أضف الزر + استدعاء `db.setExamOnlineStatus(examId, draft)` بعده.
- [x] T023 [US1] في `lib/views/exams/online_exams_tab.dart` + `online_exam_editor_page.dart`: اربط أزرار "نشر"/"حفظ كمسودّة"/"تعديل" (تعديل ممنوع وهو `published` → يطلب "إلغاء النشر أولًا"، FR-018). بعد نشر ناجح: اعرض `active-class.online/exam/{slug}` في bottom sheet مع زر نسخ (`Clipboard.setData`).

**Checkpoint**: US1 كامل — يقدر يؤلّف وينشر ويلغي نشر. مستند السحابة صحيح وبلا حل.

---

## Phase 4: User Story 2 - الطالب يدخل بكوده ويحلّ الامتحان (Priority: P1)

**Goal**: صفحة `active-class.online/exam/{slug}` — هوية `{code}_{last4}`، حل بمؤقّت، أسئلة مخلوطة، تسليم واحد، استئناف.

**Independent Test**: quickstart سيناريو 2 — بامتحان منشور من US1، دخول وحل وتسليم، ومحاولة إعادة الدخول تُرفض.

- [x] T024 [US2] في `booking_site/exam/index.html` (جديد): انسخ هيكل `booking_site/track/index.html` (CSS، Cairo، RTL، `firebaseConfig` نفسه، `getSlug()`، `escapeHtml`، `signInAnonymously`، شاشات الحالة/المغزل). نموذج هوية: حقل كود + حقل آخر 4 أرقام (نفس `track`).
- [x] T025 [US2] في `booking_site/exam/index.html`: `init()` — اقرأ `online_exams/{slug}` (وجود) و`parent_portal/{slug}` (`active === true` وإلا "غير متاح"، FR-030). عند إرسال الهوية: `getDoc(parent_portal/{slug}/students/{code}_{last4})` — مش موجود → خطأ عام "الكود أو الأرقام غير صحيحة" (FR-012). موجود → خزّن `groupName` وانتقل لاختيار الامتحان.
- [x] T026 [US2] في `booking_site/exam/index.html`: اقرأ `online_exams/{slug}/exams` (collection)، فلتر: `status==='published'` (أو `stopped` لعرض "انتهى")، `allowedCodes[code]===true` وإلا "غير متاح لمجموعتك" (FR-013). للمتاح: قارن `Date.now()` بـ `opensAt`/`closesAt` → "يبدأ الساعة …" / "انتهى وقت هذا الامتحان" / متاح. > 1 → قائمة اختيار.
- [x] T027 [US2] في `booking_site/exam/index.html`: فتح امتحان — `getDoc(submissions/{code}_{last4})` موجود → "لقد سلّمت هذا الامتحان بالفعل" (نهائي، FR-016/019). غير موجود: `getDoc(attempts/{code}_{last4})`؛ لو مفقود `setDoc` بـ `{code, startedAt: serverTimestamp()}` ثم **`getDocFromServer`** لأخذ الطابع المثبَّت (القراءة الفورية العادية ممكن ترجع `startedAt` = null قبل تثبيت الخادم — لا تعتمد عليها؛ fallback: `Date.now()` وقت الكتابة). احسب `remainingMs = min(startedAtMs + durationMinutes*60000 - now, closesAtMs - now)` (FR-015).
- [x] T028 [US2] في `booking_site/exam/index.html`: عرض الامتحان — خلط الأسئلة والاختيارات بـ seed حتمي من `code` (دالة PRNG بسيطة، mulberry32)، خزّن خريطة `shuffled→original`. مؤقّت تنازلي من `remainingMs`. راديو لكل سؤال. حفظ كل اختيار في `localStorage["exam_{slug}_{examId}_{code}"]` (FR-020) وقراءته عند التحميل/الاستئناف.
- [x] T029 [US2] في `booking_site/exam/index.html`: التسليم (زر أو انتهاء المؤقّت → `autoSubmitted=true`, FR-017) — ابنِ `answers = {"q<id>": originalIndex}` للمُجاب فقط، `setDoc(submissions/{code}_{last4}, {code, answers, submittedAt: serverTimestamp(), autoSubmitted, startedAtClient})`. نجاح → امسح localStorage، شاشة "تم إرسال إجاباتك" (بلا درجة، FR-019). فشل شبكة → "لم يُرسَل بعد — لا تغلق الصفحة" + إعادة محاولة كل 5ث وعند حدث `online` (SC-007). فشل permission-denied (موجود بالفعل) → "لقد سلّمت هذا الامتحان بالفعل".
- [ ] T030 [US2] **شغل يدوي على المستخدم**: نشر `booking_site/exam/` على الـVPS مع توجيه `/exam/*` → `index.html` (زي `/track` و`/book`). موثّق في quickstart.

**Checkpoint**: US2 كامل — دورة الطالب تعمل end-to-end مع US1.

---

## Phase 5: User Story 3 - المدرس يصحّح النتائج ويعتمدها (Priority: P1)

**Goal**: سحب التسليمات، تصحيح تلقائي محلي، مراجعة، تعديل يدوي، اعتماد → `exam_grades` → خط النتائج الحالي.

**Independent Test**: quickstart سيناريو 3 — تسليمان، "تحديث النتائج"، "اعتماد الكل"، والتحقق من ظهور الدرجات في الشاشات القائمة.

- [x] T031 [US3] في `lib/services/online_exam_service.dart`: نفّذ `fetchSubmissions(examId)` — `ensureSlug` → `_ensureAuth` → `get` على `online_exams/{slug}/exams/$examId/submissions` → لكل مستند ابنِ `CloudSubmission` (فك `answers` map<String,int>، `startedAt` من مستند `attempts` المناظر أو من الحقل، `submittedAt` من الحقل). ارجع القائمة.
- [x] T032 [US3] في `lib/controllers/exam_controller.dart`: أضف `Future<String?> pullAndGradeOnlineExam(int examId)` — (1) `subs = await OnlineExamService().fetchSubmissions(examId)`؛ (2) `questions = db.getQuestionsForExam(examId)` (map `'q${q.id}'` → question)؛ (3) لكل `CloudSubmission`: طابق `code` بطالب محلي (`db.getStudentByCode` — موجود، `database_service.dart:896`)؛ احسب `autoScore = Σ over questions: (answers['q${q.id}'] == q.correctIndex) ? q.points : 0` — **السؤال غير المُجاب (مفتاح غائب من `answers`) = 0، لا يُحتسب صح**؛ `db.upsertSubmission(ExamSubmission(status: pending, autoScore, finalGrade: autoScore, ...))`؛ (4) الطلاب المسموح لهم بلا تسليم و`now > closesAt` → `upsertSubmission(status: notSubmitted)` (FR-026)؛ (5) رجّع null أو رسالة خطأ.
- [x] T033 [US3] في `lib/controllers/exam_controller.dart`: أضف `perQuestionResults(ExamSubmission sub, List<ExamQuestion> qs)` → لكل سؤال: `{question, chosenIndex, correct: chosen == q.correctIndex}` (للـUI تفاصيل التسليم، FR-024/US3-AS6). وأضف `Future<void> approveOnlineGrade(int examId, int studentId, {double? overrideGrade})` — يحدّث `exam_submissions.status = approved` و`final_grade`، ثم `db.upsertGrade(examId, studentId, grade: finalGrade, notes: 'امتحان إلكتروني — تصحيح تلقائي', isAbsent: status == notSubmitted && markedAbsent)` — نفس مسار `saveGrade` عشان `pushStudentSummary` يتنفّذ. و`approveAll(examId)`.
- [x] T034 [US3] في `lib/controllers/exam_controller.dart` `approveOnlineGrade`: idempotency (FR-027/R9) — لو الصف `approved` بالفعل و`overrideGrade == null`، ما تعملش شيء؛ إعادة `pullAndGrade` ما تدهسش `final_grade` لصف `approved` (مضمون في `upsertSubmission` T010، تأكيد هنا).
- [x] T035 [US3] في `lib/views/exams/online_exam_results_page.dart` (جديد): زر "تحديث النتائج" (يستدعي `pullAndGradeOnlineExam` + spinner)؛ قائمة الطلاب (اسم، درجة محسوبة/كلية، شارة الحالة pending/approved/not_submitted)؛ لكل صف: حقل تعديل درجة + زر "اعتماد"؛ زر "اعتماد الكل"؛ للـ not_submitted زر "تعليم غائب"؛ نقر الصف → bottom sheet تفاصيل إجابات الطالب (من `perQuestionResults`) مع علامات صح/غلط (FR-024).
- [x] T036 [US3] في `lib/views/exams/online_exams_tab.dart`: اربط زر "النتائج" على كارت الامتحان المنشور/الموقوف → `Get.to(OnlineExamResultsPage(examId))`. اعرض عدّاد "N تسليم" على الكارت (من `db.getSubmissionsForExam`).
- [x] T037 [US3] تحقّق تكامل (لا كود جديد متوقّع): بعد الاعتماد، افتح `exam_grades_page.dart` وسجل الطالب و`buildGuardianExamResultMessage` (سبيك 008) و`/track` — الدرجات تظهر زي أي درجة يدوية (FR-028/SC-005). أصلح أي افتراض يكسر (مثلاً شاشة تفترض وجود درجات مُدخلة يدويًا فقط).

**Checkpoint**: US3 كامل — الدائرة مقفولة، الدرجات في `exam_grades`.

---

## Phase 6: User Story 4 - المدرس يوقف/يقفل امتحانًا منشورًا (Priority: P2)

**Goal**: "إيقاف الآن" و"حذف من الويب" مع بقاء البيانات المحلية.

**Independent Test**: quickstart سيناريو 4.

- [x] T038 [US4] في `lib/services/online_exam_service.dart`: نفّذ `stopNow(examId, closesAtUtc)` — `update` على `online_exams/{slug}/exams/$examId` بـ `{status:'stopped', closesAt: closesAtUtc.toIso8601String()}`. ونفّذ `deleteRemote(examId)` — batched delete لكل `submissions` + `attempts` (query ثم `batch.delete`)، ثم `delete` مستند `exams/$examId`. best-effort: أي فشل → `debugPrint` فقط (نمط `removeStudentSummary`).
- [x] T039 [US4] في `lib/controllers/exam_controller.dart`: أضف `stopOnlineExam(int examId)` → `OnlineExamService().stopNow(examId, DateTime.now().toUtc())` + `db.setExamOnlineStatus(examId, stopped)`. و`removeOnlineExamFromWeb(int examId)` → `deleteRemote` + `setExamOnlineStatus(removed)`. كلاهما مع تأكيد حواري (الأخير يوضّح إن الدرجات المعتمَدة تفضل).
- [x] T040 [US4] في `lib/views/exams/online_exams_tab.dart`: اربط أزرار "إيقاف الآن" و"حذف من الويب" على كارت الامتحان المنشور/الموقوف مع `Get.dialog` تأكيد.
- [x] T041 [US4] في `lib/services/parent_portal_service.dart` `_watchLicenseChanges` / `publishPortalClosed`: عند قفل البوابة، لا حاجة لكتابة إضافية على `online_exams/{slug}` — صفحة الطالب تقرأ `parent_portal/{slug}.active` مباشرةً (T025). تأكيد فقط إن `publishPortalClosed` بيكتب `active:false` على `parent_portal/{slug}` (هو كده — سطر ~199). أضف تعليق يربط بسبيك 016.

**Checkpoint**: كل القصص شغّالة.

---

## Phase 7: Polish & Cross-Cutting

- [x] T042 `flutter analyze` — صفر أخطاء/تحذيرات. أصلح أي import غير مستخدم / null-safety.
- [x] T043 [P] راجع كل مسارات عرض الامتحانات (`exams_page` فلاتر، `leaderboard`, `student_exam_history_page`, `export_service` تصدير امتحانات) — تأكّد إن الامتحانات الإلكترونية (`isOnline`) تظهر/تُستبعد بشكل مقصود (الدرجات المعتمَدة جزء من الإحصائيات؛ الامتحان المسودّة غير المنشور ما يظهرش في تقارير الطلاب).
- [ ] T044 [P] تحقّق الميجريشن: ثبّت فوق DB v22 فيها امتحانات ورقية + درجات، افتح التطبيق، تأكّد `online_status = NULL` لكلها وكل الشاشات تشتغل (SC-006).
- [ ] T045 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–5 كاملة على جهاز/محاكي. سجّل أي انحراف.
- [ ] T046 تأكيد أمني نهائي: افتح Firestore console بعد نشر امتحان — **لا `correct`/`correctIndex`/`answer`/`points` في أي `questions[*]`**؛ حاول `getDoc` على تسليم طالب آخر من متصفح الطالب (لازم permission-denied)؛ حاول تسليم مرتين (لازم يُرفض).
- [x] T047 [P] حدّث `HANDOFF` القادم / ملاحظات الجلسة: DB v23، الملفات الجديدة، الشغل اليدوي المتبقّي (نشر `booking_site/exam/` + `firebase deploy --only firestore:rules`).

---

## Dependencies & Execution Order

- **Phase 1 (Setup)**: فورًا.
- **Phase 2 (Foundational)**: بعد Setup — **يحجب كل القصص**. الترتيب داخله: 2أ (DB) → 2ب/2ج (موديلات + CRUD، 2ب متوازي) → 2د (خدمة + قواعد) → 2هـ (UI shell).
- **US1 (Phase 3)**: بعد Foundational. **MVP**.
- **US2 (Phase 4)**: بعد Foundational؛ يُختبر عمليًا مع US1 (محتاج امتحان منشور).
- **US3 (Phase 5)**: بعد Foundational؛ يُختبر مع US1+US2 (محتاج تسليمات).
- **US4 (Phase 6)**: بعد US1 (محتاج امتحان منشور).
- **Polish (Phase 7)**: بعد القصص المطلوبة.

### تسلسل القصص

القصص الثلاث P1 **سلسلة تشغيلية** (تأليف → حل → تصحيح) — تُبنى بالترتيب، لكن كل واحدة قابلة للاختبار المستقل بمدخلات يدوية. US4 مستقلة بعد US1.

### فرص التوازي

- T005/T006 (موديلان جديدان) متوازيان.
- T017 (تبويب UI) متوازي مع 2ج/2د.
- T024–T029 (صفحة الطالب) ملف واحد — تسلسلي، لكن متوازي تمامًا مع US3 (ملفات lib).
- T043/T044/T047 متوازية في Polish.

---

## Implementation Strategy

### MVP (US1 فقط)

Phase 1 → Phase 2 → Phase 3. عند اكتمال US1: المدرس يقدر يؤلّف وينشر امتحان، والمستند السحابي صحيح. **قف وتحقّق** (سيناريو 1) قبل US2.

### تسليم تدريجي

1. Setup + Foundational → الأساس جاهز (DB v23، قواعد منشورة).
2. US1 → تحقّق سيناريو 1 → المدرس ينشر.
3. US2 → نشر `booking_site/exam/` → تحقّق سيناريو 2 → الطالب يحل.
4. US3 → تحقّق سيناريو 3 → الدرجات في النظام. **الميزة كاملة الوظيفة هنا.**
5. US4 → تحكّم تشغيلي.
6. Polish.

---

## Notes

- `[P]` = ملفات مختلفة، بلا تبعية.
- كل الأعمدة/الجداول الجديدة **خارج `sync_engine`** في v1 (R7) — مراجعة v2.
- الإجابات الصحيحة **لا تغادر الجهاز أبدًا** — تحقّق T021 و T046.
- التوقيت UTC في كل مكان (R5).
- commit بعد كل مهمة أو مجموعة منطقية.
- شغل يدوي على المستخدم: T015 (deploy rules)، T030 (deploy booking_site/exam).
