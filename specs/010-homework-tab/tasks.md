---
description: "Task list — تبويب واجب داخل موديل المجموعة (3 حالات + ربط غياب + تقارير)"
---

# Tasks: تبويب واجب داخل موديل المجموعة

**Input**: Design documents from `/specs/010-homework-tab/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: يدوي عبر quickstart.md (اتساقًا مع المشروع). لا اختبارات آلية جديدة مطلوبة في الـspec.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ملفات مختلفة، لا تبعية
- كل الشغل قصة واحدة **US1** (الـspec فيها user story واحدة تغطّي كل حاجة)

---

## Phase 1: Setup

- [X] T001 تأكيد `flutter analyze lib` نضيف كنقطة مرجعية، ومراجعة `_AttendanceSheet` في `lib/views/attendance/attendance_page.dart` (السطور ~620-1350) و`HomeworkController` في `lib/controllers/homework_controller.dart` قبل البدء

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: كل شغل US1 يعتمد على الطور ده.

- [X] T002 في `lib/config/constants.dart`: أضف `const String HOMEWORK_PARTIAL = 'ناقص';` تحت `HOMEWORK_DONE`/`HOMEWORK_NOT_DONE` (اللي يفضلوا `'عمل'`/`'لم يعمل'` كما هم — بيانات قديمة)
- [X] T003 في `lib/controllers/homework_controller.dart` (أو `lib/utils/helpers.dart` لو أنسب): أضف `String? normalizeHomeworkStatus(String? raw)` — `'عمل'→'عمل'`/`HOMEWORK_DONE`، `'لم يعمل'→HOMEWORK_NOT_DONE`، `'ناقص'→HOMEWORK_PARTIAL`، null→null. (القيم القديمة تُقبل وتُرجَّع كقيمها القياسية.)
- [X] T004 أضف `String homeworkStatusLabel(String? raw, {bool absent = false})` (نفس ملف T003) — يرجّع: `absent` → `'غائب (لا واجب)'`؛ وإلا حسب `normalizeHomeworkStatus`: `'🟢 تم الحل'` / `'🟡 ناقص'` / `'🔴 لم يُحل'` / null → `'لم يُسجَّل'`. ده **مصدر الحقيقة الوحيد** لتسمية الحالة في كل العرض والتقارير.
- [X] T005 في `HomeworkController`: أضف `Future<void> setHomeworkStatus(int studentId, DateTime day, String? status)` — لو `status == null` أو `== statusFor(studentId, day)` → حذف السجل؛ وإلا upsert بالحالة المحددة. يستدعي `loadHomework()` + `ParentPortalService().pushStudentSummary(studentId)` (نفس نمط `toggleHomework`)
- [X] T006 في `HomeworkController`: أضف `Future<void> clearHomework(int studentId, DateTime day)` — حذف سجل واجب اليوم لو موجود (يُنادى عند تسجيل غياب) + `pushStudentSummary`
- [X] T007 في `HomeworkController`: أضف `({int done, int partial, int notDone, int unset}) homeworkSummary(List<int> studentIds, DateTime day)` — يعدّ الحالات عبر `normalizeHomeworkStatus(statusFor(...))` للـids المُعطاة (المُستدعي بيبعتها بدون الغائبين)
- [X] T008 في `HomeworkController.markGroupAllHomeworkDone`: تأكد إنها تشتغل صح لو `studentIds` مفلترة (بدون الغائبين) — لو محتاجة تعديل خليها تتعامل مع القائمة المُمرَّرة فقط (منطق "لو الكل done → إلغاء" يتحسب على المُمرَّر)
- [X] T009 احذف/علّم `HomeworkController.toggleHomework` كـ deprecated (هيتشال بعد ما التبويب الجديد يستبدله)

**Checkpoint**: منطق الحالات الثلاث + التطبيع + التسمية + الغياب جاهز.

---

## Phase 3: User Story 1 — تبويب واجب داخل الموديل (Priority: P1)

**Goal**: موديل المجموعة يفتح على "حضور" وجنبه "واجب"؛ الواجب 3 أزرار صريحة؛ الغائب بلا واجب؛ حالة الواجب في كل التقارير.

**Independent Test**: quickstart.md كامل (9 سيناريوهات).

### 3أ — شريط التبويبين داخل `_AttendanceSheet`

- [X] T010 [US1] في `attendance_page.dart` `_AttendanceSheetState.build`: احسب `groupStudents` مرة واحدة (نشطين + انضموا ≤ اليوم + مفروزين بالاسم) قبل أي تبويب، واحسب `statusMap` للحضور (studentId → status) لنفس اليوم
- [X] T011 [US1] لفّ جسم الموديل في `DefaultTabController(length: 2, initialIndex: 0)` + `TabBar(tabs: [Tab(text:'حضور'), Tab(text:'واجب')])` تحت الهيدر المشترك، + `Expanded(child: TabBarView(children: [_buildAttendanceTab(...), _buildHomeworkTab(...)]))`
- [X] T012 [US1] استخرج قائمة الحضور الحالية (صفوف الطلاب + زر "تحضير الكل") كـ`_buildAttendanceTab(groupStudents, ...)` — **بدون** تمرير `homeworkStatus`/`onHomeworkTap`، و**بدون** بلوك زر "واجب الكل" (~سطر 882)

### 3ب — تبويب "واجب"

- [X] T013 [US1] أضف ودجت `_HomeworkStatusSegmented({required String? status, required ValueChanged<String?> onSelect})` في `attendance_page.dart` — 3 أزرار (نقطة ملوّنة + تسمية قصيرة): تم الحل (أخضر) / ناقص (أصفر) / لم يُحل (أحمر). المختار مميّز؛ الضغط على غير المختار → `onSelect(thatStatus)`؛ الضغط على المختار → `onSelect(null)`
- [X] T014 [US1] أضف `_buildHomeworkTab(groupStudents, statusMap, ...)` في `attendance_page.dart`:
      · `Obx` على `homeworkCtrl.homework`
      · صف ملخّص فوق القائمة من `homeworkCtrl.homeworkSummary(<ids غير الغائبين>, day)`: `تم الحل: X · ناقص: Y · لم يُحل: Z · غير مسجّل: W`
      · زر "الكل عمل / إلغاء الكل" → `homeworkCtrl.markGroupAllHomeworkDone(<ids غير الغائبين>, day)`
      · `ListView` لصفوف الطلاب: أفاتار + اسم + (لو `statusMap[id] == ATTENDANCE_ABSENT` → نص `'غائب — لا واجب'`؛ وإلا `_HomeworkStatusSegmented(status: homeworkCtrl.statusFor(id, day), onSelect: (s) => homeworkCtrl.setHomeworkStatus(id, day, s))`)
- [X] T015 [US1] احذف `_HomeworkBadge` من `attendance_page.dart` لو مبقاش له مستدعي (أو سيبه لو مستخدم في مكان تاني — تأكد بـ`rg`)

### 3ج — ربط الغياب

- [X] T016 [US1] في `_AttendanceSheet` (تبويب "حضور"): عند تسجيل طالب `ATTENDANCE_ABSENT` بنجاح، نادِ `widget.homeworkCtrl.clearHomework(studentId, widget.selectedDay)` — عشان سجل واجبه لنفس اليوم يتحذف
- [X] T017 [US1] تأكد إن تبويب "واجب" بيعيد البناء لما حالة الحضور تتغيّر (الاتنين تحت نفس `Obx` على `controller.attendance` أو التبويب بيقرا `statusMap` محسوبة في build الموديل الأب)

### 3د — التقارير والبوابة (FR-012, FR-013)

- [X] T018 [P] [US1] في `lib/controllers/attendance_controller.dart` `buildGuardianReportMessage`: استبدل حساب `hwLabel` (سطر ~637-639) بـ`homeworkStatusLabel(homeworkStatus, absent: attendanceStatus == ATTENDANCE_ABSENT)`
- [X] T019 [P] [US1] في `lib/views/students/student_details_page.dart` `_shareMonthlyReport` (~سطر 180-195): عدّاد 3 حالات (تم الحل/ناقص/لم يُحل) بدل 2، وسطور اليوم تستخدم `homeworkStatusLabel`
- [X] T020 [P] [US1] في `lib/views/settings/settings_page.dart` (التقرير الشهري، ~سطر 1700): نفس تعديل T019
- [X] T021 [P] [US1] في `lib/services/parent_portal_service.dart` (~سطر 198-229): `homeworkHistory[].status` يتطبّع عبر `normalizeHomeworkStatus`؛ أضف عدّاد `homeworkPartial` جنب `homeworkDone`/`homeworkNotDone`
- [X] T022 [P] [US1] في `lib/controllers/report_controller.dart` (~سطر 130-137, 186-188): أضف `homeworkPartialByStudent` للتجميعات وعرّضه في تقرير الواجب PDF
- [X] T023 [US1] `flutter analyze lib` نضيف؛ فحص `rg "== HOMEWORK_DONE|== HOMEWORK_NOT_DONE" lib/` — كل موضع يتعامل مع "ناقص" (عبر helper) أو معلَّق بسبب

**Checkpoint**: US1 كاملة. quickstart.md 1-9.

---

## Phase 4: Polish & Cross-Cutting

- [X] T024 [P] تحقّق: هل `booking_site/track/index.html` بيعرض حالة الواجب أصلاً؟ `rg -i "homework|واجب" booking_site/track/index.html`. لو أيوة → حدّثها للقيم الثلاث + انشرها على الـVPS (نفس مسار spec 003). لو لأ → لا شيء.
- [X] T025 [P] فحص نهائي: `rg -n "واجب الكل|_HomeworkBadge|toggleHomework" lib/views/attendance/attendance_page.dart` — لا نتائج في مسار تبويب الحضور
- [X] T026 تحقّق يدوي: quickstart.md سيناريو 9 (عدم انحدار — تسجيل حضور مجموعة كاملة + تقرير جماعي)
- [ ] T027 `flutter build apk --debug --flavor direct` ثم `adb install -r build/app/outputs/flutter-apk/app-direct-debug.apk`؛ نفّذ quickstart.md بالكامل على الجهاز
- [X] T028 حدّث `HANDOFF.md` بحالة الميزة (اتعملت / اتأكدت لايف / commit)

---

## Dependencies & Execution Order

- **Phase 1**: فورًا
- **Phase 2 (Foundational)**: يعتمد على Phase 1 — **يبلوك كل US1**. T002 → T003 → T004 → (T005, T006, T007, T008, T009). T003/T004 قبل أي شيء يستخدم التسمية/التطبيع
- **Phase 3 (US1)**:
  - 3أ (T010-T012) قبل 3ب (T013-T015) قبل 3ج (T016-T017)
  - 3د (T018-T022) كلها **[P]** (ملفات مختلفة) — تعتمد فقط على T003/T004 (Phase 2)، تقدر تتعمل بالتوازي مع 3أ-3ج
  - T023 بعد كل 3أ-3د
- **Phase 4**: بعد Phase 3

### Parallel Opportunities

- Phase 2: T005/T006/T007/T008/T009 بعد T003/T004
- Phase 3د: T018, T019, T020, T021, T022 كلها بالتوازي (5 ملفات مختلفة)
- Phase 4: T024, T025 بالتوازي

---

## Parallel Example: Phase 3د (التقارير)

```text
# بعد Phase 2 (T003/T004 جاهزين):
Task: "attendance_controller.buildGuardianReportMessage → homeworkStatusLabel"
Task: "student_details_page._shareMonthlyReport → 3 حالات"
Task: "settings_page التقرير الشهري → 3 حالات"
Task: "parent_portal_service → تطبيع + homeworkPartial"
Task: "report_controller → homeworkPartialByStudent"
```

---

## Implementation Strategy

### أصغر إصدار قابل للعرض

1. Phase 1 → Phase 2 (Foundational)
2. Phase 3أ + 3ب (التبويبان + الـsegmented + الملخّص) → **قف وجرّب** quickstart 1-4, 6-7
3. Phase 3ج (ربط الغياب) → جرّب quickstart 5
4. Phase 3د (التقارير) → جرّب quickstart 8
5. Phase 4 (الصفحة العامة + فحص + build + HANDOFF)

### Incremental

كل مرحلة فرعية (3أ / 3ب / 3ج / 3د) قابلة للـcommit والتجربة مستقلة.

---

## Notes

- [P] = ملفات مختلفة، لا تبعية
- **لا هجرة قاعدة بيانات** — قيمة نصّية جديدة + تطبيع
- التقرير الشهري في `student_details_page` بيعرض الواجب بالفعل (عمل X / لم يعمل Y) — التعديل توسعة لـ3 حالات مش إضافة من الصفر
- commit بعد كل مرحلة فرعية
- أرقام الأسطر تقريبية — أكّدها بالـ`rg` وقت التنفيذ
