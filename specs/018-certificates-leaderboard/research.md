# Phase 0 — Research: شهادات تقدير + المراكز

قرارات النطاق محسومة مع المستخدم. تفاصيل تقنية محلولة تحت.

## R1 — بناء الشهادة PDF

**Decision**: خدمة جديدة `CertificateService` على نمط `ExportService` بالظبط — `_loadFonts()` (Cairo من `assets/fonts/`)، `pw.Document()`, `PdfColor.fromInt(...)`, `pw.Page(pageFormat: PdfPageFormat.a4, textDirection: TextDirection.rtl)`. صفحة `pw.Widget` واحدة لكل شهادة. الإخراج `Uint8List` → `Printing.sharePdf(bytes: ..., filename: ...)`.

**Rationale**: `ExportService` بيثبت النمط (تحميل خطوط، ألوان، RTL، مشاركة). `printing.sharePdf` مستخدم في `exam_grades_page:540` و`group_details_page:1981`. صفر حزم جديدة.

**Alternatives considered**: توليد صورة (canvas/widget → image) — مرفوض: PDF أنسب للطباعة، والبنية موجودة.

## R2 — القوالب (2–3)

**Decision**: 3 دوال قالب في `CertificateService`، كلها بتاخد `CertificateData` وبترجّع `pw.Widget` (محتوى صفحة A4):
- **كلاسيكي**: إطار مزدوج، خط زخرفي علوي، ألوان ذهبي/كحلي، ترويسة "شهادة تقدير".
- **حديث**: شريط لوني متدرّج علوي/سفلي، تخطيط عصري، ألوان إنديجو/بنفسجي (متناسق مع التطبيق).
- **بسيط**: إطار رفيع، نص مركزي نظيف، أبيض/رمادي — مناسب للطباعة الاقتصادية.

`enum CertTemplate { classic, modern, simple }`. المدرس يختار من منتقي في `certificates_sheet`. آخر اختيار → `app_settings['cert_template']` (نفس `getSetting`/`setSetting` الموجودين).

**Rationale**: FR-005. 3 خيارات تغطّي الأذواق بدون تعقيد تخصيص (مؤجّل).

## R3 — CertificateData ومصادر البيانات

**Decision**: `class CertificateData { String studentName; String achievementText; String gradeText; String dateText; String? teacherName; String? teacherSpecialization; String teacherTitle; }`

- `achievementText`: من السياق — "تقديرًا لتفوّقه في امتحان [X]" (نتائج امتحان / صفحة طالب) · "حصوله على المركز الأول/الثاني/الثالث" (صفحة المراكز).
- `gradeText`: "الدرجة: 92 من 100 (92%)" — من `ExamGrade`.
- `dateText`: `FormatHelper.formatFullDate(exam.date)` أو اليوم.
- `teacherName`/`Specialization`/`Title`: من `SettingsController` (`teacherFullName`, `teacherSpecialization`, `teacherTitle`). لو فاضي → السطر يتحذف (FR-006).

**لا كيان بيانات مخزّن** — يُبنى وقت التوليد ويُرمى.

## R4 — قائمة الطلاب المؤهّلين للشهادة

**Decision**: `ExamController.certifiableStudents(int examId)` → يجيب `getGradesForExamGroup` لكل مجموعات الامتحان (أو استعلام موحّد)، يفلتر `grade != null && !isAbsent && grade > passingGrade`. يرجّع `List<({int studentId, String name, double grade, double maxGrade})>`.

**Rationale**: FR-002. `>` مش `>=` (المتفوّق مش اللي على الحد بالظبط) — موثّق في Assumptions. المدرس يقدر يضيف/يشيل يدويًا في `certificates_sheet`.

## R5 — توسيع getLeaderboard

**Decision**: توسيع `getLeaderboard({int? examId, int? groupId, String? monthKey})`:
- **استبعاد المؤرشفين**: `AND s.$COL_STUDENT_IS_ARCHIVED = 0` في الـWHERE (FR-016) — إصلاح نقص حالي.
- **فلتر الشهر**: `monthKey` صيغة "YYYY-M". الفلترة بـ`effectiveReportMonth` للامتحان (سبيك 013 — `report_month` أو شهر `date`). SQL: `AND (COALESCE(e.report_month, strftime('%Y-', e.date) || CAST(strftime('%m', e.date) AS INTEGER)) = ?)` — أو أبسط: نجيب كل الامتحانات ونفلتر `examId`s الشهر ده في Dart ثم نمرّرهم كـ`IN (...)`.
- **tie-break ثابت**: `ORDER BY pct DESC, s.$COL_STUDENT_NAME ASC` (FR-017/SC-005).

**Rationale**: `getLeaderboard` حاليًا: مايستبعدش المؤرشفين، مفيش شهر، الترتيب بـpct بس (تعادل غير محدد). الثلاثة تُصلَّح مع الميزة.

**Alternatives considered**: فلتر الشهر بالكامل في Dart فوق `getAllExams` — أنظف من SQL معقّد. **مُعتمَد**: الكنترولر يجيب امتحانات الشهر (`exams.where((e) => e.effectiveReportMonth == month)`)، ولو فيه أكتر من امتحان يستدعي `getLeaderboard` مرة لكل واحد ويجمّع — أو نضيف `examIds` param. القرار النهائي في التخطيط؛ الأبسط: `getLeaderboard` تاخد `List<int>? examIds`.

## R6 — مشاركة قائمة الأوائل

**Decision**: `leaderboard_share.dart` → `String buildLeaderboardShareText(List<LeaderboardEntry> top, String teacherLine, String filterLabel)`:
```
🏆 قائمة الأوائل — [filterLabel]
🥇 [اسم] — 95%
🥈 [اسم] — 91%
🥉 [اسم] — 88%
4. [اسم] — 85%
...
— [مستر س، تخصص]
```
`Share.share(text)` (نفس `share_plus` المستخدم). صورة مؤجّلة (Assumptions).

## R7 — زر مشاركة نتائج الامتحان الإلكتروني (US3)

**Decision**: في `OnlineExamResultsPage` زر "إرسال النتائج واتساب" → لكل تسليم حالته `approved` (وله درجة في `exam_grades`): يبني `ExamGrade` + `Exam` ويستدعي `_ec.buildGuardianExamResultMessage(...)` ثم `launchUrl(wa.me link)` — نفس مسار `exam_grades_page._sendWhatsapp` (سطر ~277/349). لو أكتر من طالب: قائمة اختيار أو إرسال متتابع بتأكيد.

**Rationale**: FR-020..022. `buildGuardianExamResultMessage` موجودة في `ExamController` (سبيك 008). الدرجات المعتمَدة في `exam_grades` بعد سبيك 016.

## R8 — نقاط دخول أزرار الشهادات

**Decision**:
- `ExamGradesPage` (`actions:` سطر ~333/590) — زر أيقونة "شهادات تقدير".
- `OnlineExamResultsPage` — زر في الأكشنز.
- `student_details_page` — زر في تبويب الامتحانات أو أكشنز الـappbar → يفتح `certificates_sheet` بمود "طالب واحد" (يختار امتحان ناجح فيه).
- `LeaderboardPage` — زر "شهادات المراكز" → يولّد لأول 3 في الفلتر الحالي بنوع إنجاز "المركز".

كلها بتفتح `certificates_sheet` (شاشة موحّدة: قائمة + قالب + توليد) أو مباشرة لـ`CertificateService` للحالة المفردة.
