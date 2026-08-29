---

description: "Task list for attendance registration UX redesign (v2: cards + modal)"
---

# Tasks: إعادة هيكلة شاشة تسجيل الحضور (بطاقات + موديل)

**Input**: Design documents from `/specs/005-attendance-ux-redesign/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md)

**Tests**: لم تُطلَب اختبارات آلية — التحقق عبر [quickstart.md](quickstart.md) اليدوي/على الجهاز.

**Organization**: هذه إعادة تخطيط (v2) بعد أن رأى المستخدم التنفيذ الأول (v1: بحث + تمييز بصري + شريط قفز، كل حاجة inline) وطلب بنية أعمق (بطاقات + موديل). المهام هنا تُعيد استخدام كود v1 (البحث، `_StudentAttendanceChip`) بدل حذفه وإعادة كتابته.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

مشروع Flutter موحّد واحد — كل التعديلات في [lib/views/attendance/attendance_page.dart](../../lib/views/attendance/attendance_page.dart).

---

## Phase 1: Foundational (تفكيك v1 قبل بناء v2)

**Purpose**: إزالة الكود اللي بقى غير لازم من v1 (شريط القفز بين المجموعات وما يتعلق به) قبل إعادة الهيكلة، وتبسيط `_RegisterTab` رجوعًا لحالة أقرب لدوره الجديد (عرض شبكة بطاقات بس).

- [X] T001 في [attendance_page.dart](../../lib/views/attendance/attendance_page.dart)، من `_RegisterTabState`: احذف `_searchController`/`_searchQuery`/`_scrollController`/`_groupKeys`/`_jumpToGroup` وكتلة شريط الشرائح (`if (todayGroups.length > 1) ...`) وكتلة `CustomSearchBar` من `build()` — دول هيتنقلوا لجوه الموديل الجديد بدل الشاشة الرئيسية (راجع القرار 3 الملغى في research.md).
- [X] T002 تأكد أن `_RegisterTabState.build()` بعد الحذف يرجع بسيط: `Column([_DayNavigator, Expanded(ListView.builder(...))])` — الـ`ListView.builder` هيتغيّر itemBuilder في T004 بدل ما يبني `_GroupAttendanceCard` القديمة.

**Checkpoint**: `_RegisterTab` نضيف ومُجهّز لاستضافة شبكة البطاقات.

---

## Phase 2: User Story 1 - شاشة رئيسية مبسّطة ببطاقات مجموعات (Priority: P1) 🎯 MVP

**Goal**: الشاشة الرئيسية تعرض بطاقة مختصرة واحدة لكل مجموعة ليها حصة اليوم، بدل قائمة الطلاب الكاملة.

**Independent Test**: فتح تبويب "تسجيل" والتأكد إن الشاشة بتعرض بطاقات مختصرة بس (سيناريو 1 في quickstart.md).

### Implementation for User Story 1

- [X] T003 [US1] في [attendance_page.dart](../../lib/views/attendance/attendance_page.dart)، أنشئ ودجت جديدة `_GroupSummaryCard` (`StatelessWidget`) تعرض: أيقونة+اسم المجموعة+ميعاد الحصة (منقول من هيدر `_GroupAttendanceCard` القديمة سطر-بسطر تقريبًا، شامل شارة العداد التنازلي)، شارة نسبة الحضور (`$presentCount/$totalCount`)، شريط تقدّم مختصر، و`onTap` callback. **بدون** أي قائمة طلاب داخلها.
- [X] T004 [US1] في `_RegisterTabState.build()`، غيّر `itemBuilder` في الـ`ListView.builder` ليبني `_GroupSummaryCard` (بدل `_GroupAttendanceCard`) لكل مجموعة في `todayGroups`، بنفس حسابات `gPresent`/`gTotal`/`gRate` الموجودة، مع `onTap: () => _openAttendanceSheet(context, group: group, ...)` (الدالة تُبنى في T007).

**Checkpoint**: الشاشة الرئيسية بقت بطاقات مختصرة — نفّذ سيناريو 1 من quickstart.md.

---

## Phase 3: User Story 2 - تسجيل الحضور داخل موديل مخصص (Priority: P1)

**Goal**: الضغط على كارت مجموعة يفتح موديل فيه كل أدوات تسجيل الحضور لهذه المجموعة بس (منقولة من v1/الكود القديم).

**Independent Test**: الضغط على كارت، التأكد من فتح الموديل بمحتوى المجموعة الصحيح، واستخدام البحث والتحضير الجماعي (سيناريو 2 في quickstart.md).

### Implementation for User Story 2

- [X] T005 [US2] أنشئ دالة `Future<void> _openAttendanceSheet(BuildContext context, {required Group group, required List<Student> students, required Map<int,String> statusMap, required DateTime selectedDay, required AttendanceController controller, required HomeworkController homeworkCtrl, required bool alreadySentReport, required VoidCallback onReportSent})` تستخدم نفس نمط `showDialog`+`Dialog(backgroundColor: transparent, insetPadding: ...)`+`ConstrainedBox(minWidth/maxWidth: size.width*0.92, maxHeight: size.height*0.85)` الموجود بالفعل في [add_student_sheet.dart](../../lib/widgets/add_student_sheet.dart) (راجع القرار 5 في research.md)، وتعرض ودجت جديدة `_AttendanceSheet`.
- [X] T006 [US2] أنشئ `_AttendanceSheet` (`StatefulWidget`) — محتواها منقول تقريبًا حرفيًا من جسم `_GroupAttendanceCard` القديمة (شريط تقدّم، إحصاء المجموعة، أزرار تحضير الكل/واجب الكل، Divider، قائمة الطلاب عبر `_StudentAttendanceChip`، زر إرسال تقرير واتساب)، ملفوفة بـ`Column` تبدأ بهيدر بسيط (اسم المجموعة + زر إغلاق) و`Flexible(child: SingleChildScrollView(...))` للمحتوى (نفس نمط `_AddStudentSheetState` في التعامل مع المحتوى القابل للتمرير جوه `ConstrainedBox`).
- [X] T007 [US2] داخل `_AttendanceSheet`، أضف حالة بحث محلية (`TextEditingController` + `String _searchQuery`) و`CustomSearchBar` (منقولة من v1 — نفس hint ونفس منطق التصفية بالاسم من [attendance_page.dart](../../lib/views/attendance/attendance_page.dart) الحالي)، تُصفّي طلاب **هذه المجموعة فقط** (لا حاجة لباراميتر `searchQuery` يتمرر من الأب، البحث محلي بالكامل داخل الموديل).
- [X] T008 [US2] احذف الحقل `searchQuery` من `_GroupAttendanceCard` القديمة (أو احذف الكلاس بالكامل لو `_AttendanceSheet` غطّت كل استخداماته ولم يعد لها أي استدعاء) بعد التأكد من نقل كل منطقها لـ`_AttendanceSheet`.

**Checkpoint**: الموديل شغال بكامل وظائفه — نفّذ سيناريو 2 من quickstart.md.

---

## Phase 4: User Story 3 - وضوح بصري للاستثناءات جوه الموديل (Priority: P2)

**Goal**: التمييز البصري لـ"غائب" (من v1) يستمر شغالاً داخل الموديل الجديد بلا تغيير.

**Independent Test**: فتح موديل مجموعة بخليط حالات، التأكد من وضوح الغائبين (سيناريو 3 في quickstart.md).

### Implementation for User Story 3

- [X] T009 [US3] تأكد أن `_StudentAttendanceChip` (من v1، بلا أي تعديل جديد مطلوب) لسه بتُستخدم كما هي داخل `_AttendanceSheet` (من T006) — مجرد نقل مكان الاستدعاء، لا تعديل في الودجت نفسها.

**Checkpoint**: US3 محقَّقة تلقائيًا كنتيجة لـ T006 — نفّذ سيناريو 3 من quickstart.md للتأكيد.

---

## Phase 5: Polish & Verification

- [X] T010 راجع كل الملف [attendance_page.dart](../../lib/views/attendance/attendance_page.dart) وتأكد من عدم وجود كود ميت متبقٍ من v1 (imports غير مستخدمة، دوال/كلاسات لم تعد مستدعاة).
- [X] T011 نفّذ سيناريو 4 من [quickstart.md](quickstart.md) بالكامل (تحضير الكل، واجب الكل، شريط التقدّم، إرسال تقرير واتساب، تصدير PDF، ملخص اليوم، التنقل بين الأيام) للتأكد من صفر تراجع وظيفي (FR-007/SC-005).
- [X] T012 نفّذ سيناريو 5 من [quickstart.md](quickstart.md) (مجموعة 40+ طالب و/أو يوم فيه 5+ مجموعات) للتأكد من عدم وجود تهنيج في شبكة البطاقات أو داخل الموديل (FR-008/SC-006).
- [X] T013 [P] شغّل `flutter analyze` للتأكد من عدم وجود أخطاء/تحذيرات جديدة.
- [X] T014 **قبل أي اختبار حي على الجهاز**: نفّذ `flutter clean` ثم أعد التشغيل — تجنبًا لتكرار حادثة البناء القديم (Aug 26) اللي حصلت في الجولة السابقة من هذه الجلسة.

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: يبلوك US1 (لازم `_RegisterTab` يترجع بسيط قبل ما يستضيف البطاقات).
- **US1 (Phase 2)**: يعتمد على Phase 1.
- **US2 (Phase 3)**: يعتمد على US1 (محتاج `onTap` من الكارت لفتح الموديل) — لكن T005/T006/T007 (بناء الموديل نفسه) ممكن تتنفذ بالتوازي مع T003/T004 طالما الربط بينهم (استدعاء `_openAttendanceSheet`) بيتم آخر حاجة.
- **US3 (Phase 4)**: نتيجة مباشرة لـ US2 — لا عمل إضافي حقيقي، تحقق فقط.
- **Polish (Phase 5)**: يعتمد على اكتمال كل القصص.

## Implementation Strategy

### MVP First

1. Foundational (T001-T002) → US1 (T003-T004) → تحقق سيناريو 1.
2. US2 (T005-T008) — هنا فعليًا بيكتمل التدفق الأساسي الكامل (بطاقة + موديل شغال).
3. US3 تلقائية (T009) → تحقق سيناريو 3.
4. Polish (T010-T014)، وعلى رأسها `flutter clean` قبل أي اختبار حي.

## Notes

- **لا تُعِد كتابة منطق البحث أو التمييز البصري من الصفر** — انقلهم من الكود الحالي (v1) بأقل تعديل ممكن، لتفادي تكرار عمل تم التحقق منه بالفعل (`flutter analyze` نظيف على v1).
- منطق تسجيل الحضور نفسه (`toggleAttendance`, `markGroupAllPresent`, حسابات الإحصائيات) لا يُمس نهائيًا.
- **درس مستفاد من هذه الجلسة**: أي اختبار حي لاحق على الجهاز يجب أن يبدأ بالتأكد من أن آخر بناء فعلاً يعكس آخر تعديل (`ls -la build/app/outputs/flutter-apk/app-debug.apk` ومقارنة التاريخ، أو `flutter clean` مباشرة) — تجنبًا لتكرار حادثة الالتباس بسبب بناء قديم مُخزَّن مؤقتًا.
