---
description: "Task list — شهادات تقدير + تطوير المراكز (018-certificates-leaderboard)"
---

# Tasks: شهادات تقدير + تطوير صفحة المراكز

**Input**: Design documents from `specs/018-certificates-leaderboard/`
**Prerequisites**: plan.md, spec.md, research.md, contracts/, quickstart.md

**Tests**: تحقّق يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات. لا مهام اختبار.

**Organization**: 3 قصص. US1 (شهادات) و US2 (المراكز) P1؛ US3 (مشاركة نتائج إلكتروني) P2. صفر تغييرات قاعدة بيانات.

## Path Conventions

Mobile single-project — `lib/`. المرجع: [contracts/certificate-templates.md](contracts/certificate-templates.md) و [contracts/leaderboard-filters.md](contracts/leaderboard-filters.md).

---

## Phase 1: Setup

- [x] T001 في `lib/config/constants.dart`: أضف `const String SETTING_CERT_TEMPLATE = 'cert_template';` جنب مفاتيح app_settings.

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T002 في `lib/models/certificate_model.dart` (جديد): `enum CertTemplate { classic, modern, simple }` (+ `label` extension)؛ `enum CertKind { examExcellence, rank1, rank2, rank3, appreciation }`؛ كلاس `CertificateData` بالحقول من [العقد](contracts/certificate-templates.md#certificatedata-libmodelscertificate_modeldart).
- [x] T003 في `lib/services/database_service.dart` `getLeaderboard`: (1) أضف `AND s.$COL_STUDENT_IS_ARCHIVED = 0` للـWHERE (استبعاد المؤرشفين، FR-016)؛ (2) أضف بارامتر `List<int>? examIds` → `AND eg.$COL_GRADE_EXAM_ID IN (...)` لو مش فاضية؛ (3) غيّر `ORDER BY` لـ `(SUM(eg.$COL_GRADE_VALUE)*1.0/SUM(e.$COL_EXAM_MAX_GRADE)) DESC, s.$COL_STUDENT_NAME ASC` (tie-break ثابت، FR-017). `examId`/`groupId` زي ما هما.

**Checkpoint**: الموديل + الاستعلام الموسّع جاهزين.

---

## Phase 3: User Story 1 - شهادات تقدير (Priority: P1) 🎯 MVP

**Goal**: توليد PDF شهادات لكل الناجحين في امتحان (أو طالب واحد، أو أول 3 مراكز)، 3 قوالب.

**Independent Test**: quickstart سيناريو 1–2.

- [x] T004 [US1] في `lib/services/certificate_service.dart` (جديد): singleton زي `ExportService` — `_loadFonts()` (نسخة: Cairo-Regular/Bold من `assets/fonts/`)، `Future<Uint8List> buildCertificatesPdf(List<CertificateData> items, CertTemplate t)` → `pw.Document()`؛ لكل عنصر `pw.Page(pageFormat: PdfPageFormat.a4, textDirection: pw.TextDirection.rtl, build: (_) => _byTemplate(t, item))`.
- [x] T005 [US1] في `certificate_service.dart`: نفّذ `_classic(CertificateData d)` — إطار مزدوج ذهبي/كحلي، "شهادة تقدير"، اسم الطالب (auto-fit لو طويل)، `achievementText`، `gradeText` (لو موجود)، تذييل (تاريخ + معلّم، تحذف السطور الفارغة — FR-006). راجع [العقد](contracts/certificate-templates.md#كلاسيكي-_classic).
- [x] T006 [US1] [P] في `certificate_service.dart`: نفّذ `_modern(d)` — شريط متدرّج إنديجو→بنفسجي علوي/سفلي، كبسولة درجة ملوّنة.
- [x] T007 [US1] [P] في `certificate_service.dart`: نفّذ `_simple(d)` — إطار رفيع، نص مركزي نظيف، تذييل سطر واحد.
- [x] T008 [US1] في `lib/controllers/exam_controller.dart`: أضف `Future<List<({int studentId, String name, double grade, double maxGrade})>> certifiableStudents(int examId)` — يجمع درجات كل مجموعات الامتحان، يفلتر `grade != null && !isAbsent && grade > passingGrade`. وأضف helper `CertificateData buildExamCert(String studentName, double grade, double max, Exam exam, CertKind kind, {String? scopeLabel})` — يبني النص + بيانات المدرس من `SettingsController`.
- [x] T009 [US1] في `lib/views/exams/certificates_sheet.dart` (جديد): `CertificatesSheet` — StatefulWidget يستقبل `List<CertificateData> initialItems` + `String fileName`. UI: قائمة عناصر checkable (كلها معلَّمة)، `SegmentedButton`/شرائح لاختيار `CertTemplate` (الافتراضي من `db.getSetting(SETTING_CERT_TEMPLATE)`)، زر "توليد ومشاركة". عند التوليد: `db.setSetting(SETTING_CERT_TEMPLATE, ...)` + `CertificateService().buildCertificatesPdf(selected, template)` + `Printing.sharePdf(bytes:..., filename:...)`. لو `initialItems` فاضية → رسالة "مفيش طلاب فوق درجة النجاح" (FR-010).
- [x] T010 [US1] في `lib/views/exams/exam_grades_page.dart` (`actions:` ~333/590): أضف `IconButton(icon: Icons.workspace_premium_rounded, tooltip: 'شهادات تقدير')` → `certifiableStudents(examId)` → يبني `CertificateData` لكل واحد (`CertKind.examExcellence`) → `Get.to(() => CertificatesSheet(...))`.
- [x] T011 [US1] في `lib/views/students/student_details_page.dart`: أضف زر "شهادة تقدير" (تبويب الامتحانات أو أكشنز الـappbar) → حوار اختيار امتحان الطالب ناجح فيه → `CertificatesSheet` بعنصر واحد.

**Checkpoint**: US1 كامل — شهادات من نتائج الامتحان + صفحة الطالب.

---

## Phase 4: User Story 2 - صفحة المراكز المطوّرة (Priority: P1)

**Goal**: `LeaderboardPage` مُعاد تصميمها بفلاتر + ميداليات + مشاركة.

**Independent Test**: quickstart سيناريو 3.

- [x] T012 [US2] في `lib/controllers/exam_controller.dart`: أضف `enum LbScope { all, group, exam, month }` + `Future<List<LeaderboardEntry>> leaderboard({required LbScope scope, int? groupId, int? examId, DateTime? month})` — `all`→`getLeaderboard()`, `group`→`getLeaderboard(groupId:)`, `exam`→`getLeaderboard(examId:)`, `month`→ `examIds = exams.where((e) => e.effectiveReportMonth == DateTime(month.year,month.month,1)).map((e)=>e.id!)` ثم `getLeaderboard(examIds: examIds)` (فاضية → []). تحقّق `groupId`/`examId` لسه موجودين وإلا رجّع `all`.
- [x] T013 [US2] في `lib/utils/leaderboard_share.dart` (جديد): `String buildLeaderboardShareText(List<LeaderboardEntry> top, String teacherLine, String filterLabel)` — راجع [العقد](contracts/leaderboard-filters.md#r6). أول 20، ميداليات 🥇🥈🥉 للـ3، أرقام للباقي.
- [x] T014 [US2] في `lib/views/exams/leaderboard_page.dart`: إعادة تصميم كامل — ترويسة متدرّجة (إنديجو→بنفسجي) بعنوان "المراكز" + عدد المحتسبين + نطاق الفلتر؛ شريط شرائح فلتر (الكل / منتقي مجموعة / منتقي امتحان / منتقي شهر — واحد نشط)؛ صفوف من [العقد](contracts/leaderboard-filters.md#العرض-fr-011015): ميدالية ملوّنة للـ3 الأوائل + رقم للباقي + الاسم + شريحة المجموعة + النسبة الكبيرة + `{totalGrade}/{totalMax}` + `{examCount} امتحان` + شريط نسبة. يستدعي `_ec.leaderboard(filter)` ويعيد التحميل عند تغيير الفلتر.
- [x] T015 [US2] في `leaderboard_page.dart`: زر "مشاركة قائمة الأوائل" (أعلى/actions) → `Share.share(buildLeaderboardShareText(...))` — معطّل لو القائمة فاضية. وزر "شهادات المراكز" → يبني 3 `CertificateData` (`rank1/2/3`, scopeLabel من الفلتر) → `CertificatesSheet`.
- [x] T016 [US2] حالات حافّة: شهر بلا امتحانات → "مفيش امتحانات في [شهر]"؛ فلتر مجموعة/امتحان محذوف → يرجع "الكل".

**Checkpoint**: US2 كامل.

---

## Phase 5: User Story 3 - مشاركة نتائج الامتحان الإلكتروني (Priority: P2)

**Goal**: زر "إرسال النتائج واتساب" في `OnlineExamResultsPage`.

**Independent Test**: quickstart سيناريو 4.

- [x] T017 [US3] في `lib/views/exams/exam_grades_page.dart`: استخرج منطق إرسال واتساب لطالب (`~277`/`349` — بناء `buildGuardianExamResultMessage` + `launchUrl(wa.me)`) لدالة قابلة لإعادة الاستخدام (في `ExamController` أو helper) لو مش كده بالفعل.
- [x] T018 [US3] في `lib/views/exams/online_exam_results_page.dart`: أضف زر "إرسال النتائج واتساب" (actions أو زر أسفل) → قائمة الطلاب `status == approved` فقط → لكل واحد يبني `ExamGrade` + يستدعي مسار الإرسال من T017. الطلاب `pending`/`notSubmitted` مستبعدين (FR-022).
- [x] T019 [US3] في `online_exam_results_page.dart`: نفس زر "شهادات تقدير" (T010) على الشاشة دي — `certifiableStudents(examId)` بيشتغل على `exam_grades` بعد الاعتماد.

**Checkpoint**: كل القصص شغّالة.

---

## Phase 6: Polish

- [x] T020 `flutter analyze` — صفر أخطاء/تحذيرات.
- [x] T021 [P] تحقّق: `getLeaderboard` التغييرات ما كسرتش أي مستدعي حالي (الاستدعاءات الموجودة في `leaderboard_page` القديمة بتتحدّث في T014؛ أي مستدعي تاني؟ grep `getLeaderboard`).
- [ ] T022 [P] تحقّق بصري (فاتح/ليلي): صفحة المراكز، `CertificatesSheet`، وأزرار الشهادات في الشاشات الـ3.
- [ ] T023 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–5. تأكيد: أسماء/درجات الشهادات صحيحة، صفر سطور فارغة، ترتيب الأوائل ثابت، المؤرشفون مستبعدون، صفر migration.
- [x] T024 [P] حدّث ملاحظات الجلسة: سبيك 018، `SETTING_CERT_TEMPLATE`, `CertificateService`, توسيع `getLeaderboard`.

---

## Dependencies & Execution Order

- **Phase 1–2**: أساس — يحجب كل القصص.
- **US1 (T004–T011)**: بعد Foundational. T004→T005/6/7 (نفس ملف، T006/7 [P] منطقيًا). T008 قبل T009–T011. **MVP**.
- **US2 (T012–T016)**: بعد Foundational + T002 (getLeaderboard). مستقل عن US1 إلا T015 (يحتاج `CertificatesSheet` من US1).
- **US3 (T017–T019)**: بعد US1 (T019 يحتاج `CertificatesSheet`).
- **Polish**: بعد الكل.

### فرص التوازي
- T006/T007 (قوالب) — نفس الملف فتسلسلي عمليًا لكن مستقلة منطقيًا.
- T013 (`leaderboard_share.dart`) متوازي مع US1.
- Polish T021/T022/T024 متوازية.

---

## Implementation Strategy

**MVP**: Phase 1+2 + US1 → شهادات من نتائج الامتحان. قف وتحقّق (سيناريو 1).
**تدريجي**: US1 → US2 (المراكز) → US3 (مشاركة إلكتروني) → Polish.

## Notes
- **صفر تغييرات قاعدة بيانات** — `DATABASE_VERSION` يفضل 23. `SETTING_CERT_TEMPLATE` key/value في app_settings الموجود.
- `certifiableStudents`: `grade > passingGrade` (أكبر تمامًا) + غير غائب.
- كل مشاركة/إرسال بضغطة صريحة.
- commit بعد كل قصة.
