---

description: "Task list for exam WhatsApp result notifications"
---

# Tasks: إرسال نتيجة الامتحان لولي الأمر عبر واتساب

**Input**: Design documents from `/specs/008-exam-whatsapp-results/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md)

**Tests**: لم تُطلَب اختبارات آلية — التحقق عبر [quickstart.md](quickstart.md) اليدوي/على الجهاز.

**Organization**: US1 (فردي) وUS2 (جماعي) كلاهما P1 وبيشتركوا في نفس البنية التحتية (دالة بناء الرسالة + خريطة أرقام أولياء الأمور) — Foundational بيبلوك الاتنين، وبعدها بيقدروا يتنفّذوا مع بعض فعليًا لأنهم بيشتركوا في نفس الملفات.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

مشروع Flutter موحّد واحد — المسارات نسبةً لجذر `C:\repo\active_class`.

---

## Phase 1: Foundational (بناء الرسالة + بيانات أولياء الأمور)

**Purpose**: دالة توليد نص رسالة النتيجة/الغياب + تحميل رقم ولي أمر كل طالب في الشاشة — كل القصص بتعتمد عليها.

**⚠️ CRITICAL**: لا تبدأ US1/US2 قبل اكتمال هذه المرحلة.

- [X] T001 في [lib/controllers/exam_controller.dart](../../lib/controllers/exam_controller.dart): أضف دالة `String buildGuardianExamResultMessage({required ExamGrade grade, required Exam exam, required String teacherName})` — لو `grade.isAbsent` رجّع رسالة غياب مستقلة (اسم الطالب + اسم الامتحان + "لم يحضر الامتحان")، غير كده (لو `grade.grade != null`) رجّع رسالة فيها الاسم، اسم الامتحان، "الدرجة: X من Y"، حالة النجاح/الرسوب (استخدم `grade.category`/قارن `grade.grade` بـ`exam.passingGrade` مباشرة — لا نسبة ثابتة)، والملاحظات (`grade.notes`) لو موجودة وغير فارغة.
- [X] T002 في [lib/views/exams/exam_grades_page.dart](../../lib/views/exams/exam_grades_page.dart)، داخل `_load()`: حمّل `List<Student>` طلاب المجموعة (`widget.groupId`) وابنِ `Map<int, Student> _studentsById` (state جديد في `_ExamGradesPageState`) — تُستخدَم لجلب `guardianPhone` بدون استعلام DB منفصل لكل زر إرسال.
- [X] T003 في نفس الملف: أضف دالة مساعدة خاصة (private top-level function أو static method) `String _normalizePhone(String input, String defaultDial)` — انسخ نفس منطق `normalizePhone` الموجود في `attendance_page.dart` (`_showSendReportConfirm`) حرفيًا (تنضيف الرموز، معالجة `+`/`00`/كود الدولة).

**Checkpoint**: بعد T001-T003، الشاشة عندها كل ما يلزم لبناء رسالة وتطبيع رقم — جاهزة لأي زر إرسال.

---

## Phase 2: User Story 1 - إرسال نتيجة طالب واحد (Priority: P1) 🎯 MVP

**Goal**: زر إرسال جنب كل صف طالب، يفتح واتساب برسالة نتيجته (أو غيابه) لولي أمره.

**Independent Test**: سيناريوهات 1-5 من quickstart.md.

### Implementation for User Story 1

- [X] T004 [US1] في [lib/views/exams/exam_grades_page.dart](../../lib/views/exams/exam_grades_page.dart): أضف باراميتر جديد لـ`_GradeRow` — `final Student? student;` (أو `String? guardianPhone` مباشرة) و`final Future<void> Function() onSendWhatsapp;` — مرِّرهم من `_ExamGradesPageState` عند بناء كل `_GradeRow` في `ListView.builder` باستخدام `_studentsById[g.studentId]`.
- [X] T005 [US1] في `_GradeRow`/`_GradeRowState`: أضف أيقونة/زر "إرسال واتساب" (أيقونة `Icons.whatsapp`-مكافئ أو أقرب أيقونة متاحة في المشروع — راجع الأيقونة المستخدمة في `_sendWhatsapp` بـ`attendance_page.dart`) يظهر فقط لو `widget.grade.isEntered == true` (درجة أو غياب مسجّل)، وإلا يكون مخفي.
- [X] T006 [US1] في `_ExamGradesPageState`: أضف دالة `Future<void> _sendResultToGuardian(ExamGrade grade)` — تجيب `Student?` من `_studentsById`، لو `null` أو `guardianPhone` فاضي/غير صالح بعد التطبيع تعرض تنبيه (`ScaffoldMessenger`/toast الموجود بالمشروع) وترجع من غير فتح واتساب؛ غير كده تبني الرسالة عبر `ExamController.buildGuardianExamResultMessage(...)`، تطبّع الرقم، وتفتح `wa.me` عبر `launchUrl(mode: LaunchMode.externalApplication)` (نفس نمط `attendance_page.dart`).
- [X] T007 [US1] اربط `onSendWhatsapp` في كل `_GradeRow` بـ`() => _sendResultToGuardian(g)`.

**Checkpoint**: US1 شغالة ومختبَرة — نفّذ سيناريوهات 1-5 من quickstart.md.

---

## Phase 3: User Story 2 - إرسال جماعي لكل أولياء أمور المجموعة (Priority: P1)

**Goal**: زر "إرسال للكل" بالـAppBar، يبعت رسالة نتيجة لكل طالب مستوفٍ (درجة/غياب مسجّل + رقم ولي أمر)، بتأكيد واحد وتخطي تلقائي.

**Independent Test**: سيناريوهات 6، 7 من quickstart.md.

### Implementation for User Story 2

- [X] T008 [US2] في [lib/views/exams/exam_grades_page.dart](../../lib/views/exams/exam_grades_page.dart): أضف `IconButton` جديد في `AppBar.actions` (جنب زرار المشاركة/PDF الموجودين) بأيقونة واتساب، `onPressed: _confirmSendAllResults`.
- [X] T009 [US2] أضف دالة `Future<void> _confirmSendAllResults()` — تبني قائمتين من `_grades` (بعد استبعاد غير المُدخَلين `!g.isEntered`): `withPhone` (لهم `guardianPhone` صالح بعد التطبيع عبر `_studentsById`) و`skipped` (البقية). لو `withPhone` فاضية، اعرض تنبيه "مفيش أي طالب مستوفٍ حاليًا" وارجع. غير كده اعرض `AlertDialog` تأكيد واحد يوضّح عدد `withPhone` وعدد/أسماء `skipped` (نفس نمط `_showSendReportConfirm` في `attendance_page.dart`).
- [X] T010 [US2] بعد الموافقة: حلقة `for` على `withPhone` تبني الرسالة لكل طالب عبر `buildGuardianExamResultMessage`، تفتح `wa.me`، وتنتظر رجوع التطبيق من الخلفية قبل الرسالة التالية — أعد استخدام أو انسخ نفس آلية `_atWaitForResume`/`_ATResumeObserver` من `attendance_page.dart` (أو استخرجها في ملف مشترك لو الوقت يسمح؛ النسخ المباشر مقبول لو استخراجها هيغيّر ملفات مش متعلقة بالميزة).
- [X] T011 [US2] بعد انتهاء الحلقة: اعرض رسالة نجاح نهائية (toast/SnackBar) توضّح عدد المُرسَل (`withPhone.length`) وعدد المُتخطَّى (`skipped.length`).

**Checkpoint**: US2 شغالة ومختبَرة — نفّذ سيناريوهات 6، 7 من quickstart.md.

---

## Phase 4: Polish & Verification

- [X] T012 راجع (grep) أي استخدام مكرر لمنطق `normalizePhone`/بناء رابط `wa.me` بين `attendance_page.dart` و`exam_grades_page.dart` وتأكد إن السلوك متطابق (نفس معالجة كود الدولة). (نسخ حرفي مطابق تمامًا — تم التأكيد.)
- [X] T013 اختبر الميزة حيًّا على الجهاز المتصل حسب سيناريوهات quickstart.md كاملة (1-7)، شامل حالة الدرجة 0 بالظبط وحالة الغياب. (اتنفّذ فعليًا على الجهاز: زر الإرسال الفردي فتح واتساب برسالة صحيحة كاملة (الاسم + اسم الامتحان + الدرجة + الحالة + اسم/تخصص المدرّس)، زر "إرسال للكل" أظهر تأكيد صحيح بعدد المُرسَل والمُتخطَّى، وسيناريوهات إخفاء/إظهار الزر حسب `isEntered` تحققت. بيانات الاختبار (درجة + غياب تجريبي) اتشالت من قاعدة البيانات الحقيقية بعد التحقق — الامتحان رجع لحالته الأصلية 0/19.)
- [X] T014 شغّل `flutter analyze` للتأكد من عدم وجود أخطاء/تحذيرات جديدة. (نظيف.)

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: يبلوك US1 وUS2 — لازم يكتمل الأول.
- **US1 (Phase 2)**: يعتمد على Phase 1 فقط.
- **US2 (Phase 3)**: يعتمد على Phase 1، وبيشارك T001 (دالة بناء الرسالة) مع US1 — يفضّل تنفيذه بعد US1 مباشرة لتفادي تعارض تعديلات على نفس الملف، لكنه مستقل وظيفيًا.
- **Polish (Phase 4)**: يعتمد على اكتمال US1 وUS2.

## Implementation Strategy

### MVP First

1. Foundational (T001-T003).
2. US1 (T004-T007) → تحقق سيناريوهات 1-5.
3. US2 (T008-T011) → تحقق سيناريوهات 6، 7.
4. Polish (T012-T014).

## Notes

- الميزة بالكامل إعادة استخدام لنمط موجود بالفعل (تقرير حضور واتساب) — الخطر الرئيسي هو نسخ منطق تطبيع الرقم/فتح `wa.me` بشكل غير متسق؛ T012 مخصصة للتأكد من هذا الاتساق.
- لا تغييرات على قاعدة البيانات أو الموديلات — كل التعديلات في `exam_controller.dart` و`exam_grades_page.dart` فقط.
