---
description: "Task list — تقارير الفترة المخصصة (014-custom-period-reports)"
---

# Tasks: تقارير الفترة المخصصة

**Input**: Design documents from `specs/014-custom-period-reports/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: لا توجد بنية اختبار آلي في المشروع — التحقّق يدوي عبر [quickstart.md](quickstart.md). لا مهام اختبار.

**Organization**: 3 قصص. US1 (تصدير PDF فترة) و US2 (واتساب فترة) مستقلّتين تمامًا. US3 (تذكّر خلال الجلسة) اختيارية.

## Path Conventions

Mobile single-project — كل الكود تحت `lib/`. صفر تغييرات قاعدة بيانات.

---

## Phase 1: Setup

- [X] T001 تأكيد: `DATABASE_VERSION` في `lib/config/constants.dart` يفضل `22` (مفيش تغيير)، والعمل على فرع `main` زي باقي السبيكات. مفيش مهام setup فعلية.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: يحجب US1 فقط. US2/US3 مايعتمدوش عليه.

- [X] T002 في `lib/services/export_service.dart`: أضف `_periodLabel(DateTime from, DateTime to)` → `'من ${DateFormat('d MMMM yyyy', 'ar').format(from)} إلى ${DateFormat('d MMMM yyyy', 'ar').format(to)}'`، و`_fileRange(DateTime from, DateTime to)` → `'${_fileMonth-style yyyy-MM-dd}_الى_${...}'` (جنب `_fileMonth` سطر ~909).
- [X] T003 في `lib/services/export_service.dart` `exportAttendancePDF` (~149) و`exportHomeworkPDF` (~217): أضف معامل اختياري `DateTime? periodEnd`. احسب `final isRange = periodEnd != null;`، `start = isRange ? DateTime(month.year, month.month, month.day) : DateTime(month.year, month.month, 1)`، `endInclusive = isRange ? DateTime(periodEnd.year, periodEnd.month, periodEnd.day, 23, 59, 59) : DateTime(month.year, month.month + 1, 0, 23, 59, 59)`. فلترة `monthAtt`/`monthHw` تبقى `!d.isBefore(start) && !d.isAfter(endInclusive)` بدل مقارنة `year==/month==`. مرّر `start`, `endInclusive`, `isRange` لـ`_attendanceTable`/`_homeworkTable`. ترويسة الصفحة: `header: (_) => _pageHeader('تقرير الحضور — $gLabel — ${isRange ? _periodLabel(start, periodEnd) : monthLabel}')`. اسم الملف: `_savePdf(doc, isRange ? 'attendance_${_fileRange(start, periodEnd)}' : 'attendance_${_fileMonth(month)}')`. **مسار الوضع الشهري (periodEnd == null) لازم يفضل مطابق تمامًا لدلوقتي.**

**Checkpoint**: توقيعات الخدمة جاهزة، الوضع الشهري ما اتغيّرش

---

## Phase 3: User Story 1 - تصدير PDF لفترة مخصصة (Priority: P1) 🎯

**Goal**: تقرير حضور/واجب PDF يغطّي [from, to] بالظبط، بترويسة أعمدة بتاريخ كامل.

**Independent Test**: quickstart سيناريوهات 1، 2، 3، 4، 6.

- [X] T004 [US1] في `lib/services/export_service.dart` `_attendanceTable` (~510): غيّر التوقيع لـ`_attendanceTable(List<Student> students, Map<int, Map<int, String>> attMap, DateTime start, DateTime end, bool isRange)`. بدل `sortedDays` (`Set<int>` من `attMap.keys`) استخدم قائمة **تواريخ فعلية** مرتّبة: اجمع كل `DateTime` للسجلات في `[start, end]` (من `attMap` أو أعِد بناءه بمفتاح `date`). لكل عمود: الترويسة `_thSmall(isRange ? '${dt.day}/${dt.month}\n${_weekdayShort(dt.weekday)}' : '${dt.day}\n${_weekdayShort(dt.weekday)}')`. لو القائمة فاضية → `pw.Text('لا توجد حصص مسجّلة في ${isRange ? _periodLabel(start, end) : DateFormat('MMMM yyyy', 'ar').format(start)}', style: _style(size: 10, color: _grey))`. `colWidths` من طول القائمة. صفوف الطلاب: نفس منطق حساب حاضر/متأخر/غائب بس تكرار على التواريخ.
- [X] T005 [US1] في `lib/services/export_service.dart` `_homeworkTable` (~627): نفس تغيير T004 بالظبط لجدول الواجب (`hwMap`، عمل/لم يعمل، رسالة "لا يوجد واجب مسجّل في ...").
- [X] T006 [US1] في `lib/services/export_service.dart` `_attendanceSummary` (~569) و`_homeworkSummary` (~682): شيل معامل `int days` (مابقاش مستخدم)، والعدّ يفضل من `attMap.values`/`hwMap.values` مباشرة (غير متأثّر بالفترة). حدّث النداءات في `exportAttendancePDF`/`exportHomeworkPDF`.
- [X] T007 [US1] في `lib/controllers/report_controller.dart`: غيّر `exportAttendancePDF()` (~347) و`exportHomeworkPDF()` (~372) لـ`exportAttendancePDF({DateTime? from, DateTime? to})` / `exportHomeworkPDF({DateTime? from, DateTime? to})`. لو `from != null && to != null`: فلتر `allAttendance`/`allHomework` لـ`[from00:00, to23:59:59]` ومرّر `month: from, periodEnd: to`؛ غير كده السلوك الحالي (`month: selectedMonth.value`, بدون `periodEnd`).
- [X] T008 [US1] في `lib/views/reports/reports_page.dart` `_showExportMenu` (~899): لُفّ محتوى الشيت في `StatefulBuilder`. أضف `bool rangeMode` + `DateTime rangeFrom` (افتراضي `DateTime(selectedMonth.year, selectedMonth.month, 1)`) + `DateTime rangeTo` (افتراضي `DateTime.now()`). عنصر UI أعلى الشيت: `SegmentedButton`/`ToggleButtons` [شهر | فترة مخصصة]. في `rangeMode`:
  - صفّان InkWell "من" / "إلى" يفتحوا `showDatePicker` (`firstDate: DateTime(2020)`, `lastDate: DateTime.now().add(const Duration(days: 365))`). بعد اختيار "من"، لو `rangeTo.isBefore(rangeFrom)` → `rangeTo = rangeFrom`.
  - العنوان: `'تصدير تقرير — ${_periodLabelInline(rangeFrom, rangeTo)}'` (أو نص مباشر).
  - يظهر **بس** `_ExportOption` "تقرير الحضور" و"تقرير الواجب"؛ "تقرير الدفعات" و"ملخص المجموعات" مخفيّين.
  - `onTap` للحضور: `ctrl.exportAttendancePDF(from: rangeFrom, to: rangeTo)`؛ للواجب: `ctrl.exportHomeworkPDF(from: rangeFrom, to: rangeTo)`.
- [X] T009 [US1] في `lib/views/reports/reports_page.dart` `_showExportMenu`: في وضع "شهر" (الافتراضي) الشيت يفضل **مطابق تمامًا** — 4 خيارات، العنوان "تصدير تقرير — [شهر]"، النداءات `ctrl.exportPaymentsPDF()` / `ctrl.exportAttendancePDF()` / `ctrl.exportHomeworkPDF()` / `ctrl.exportGroupsSummaryPDF()` بدون معاملات.

**Checkpoint**: US1 كامل — PDF فترة للحضور والواجب، الوضع الشهري سليم

---

## Phase 4: User Story 2 - تقرير واتساب لفترة في صفحة الطالب (Priority: P2)

**Goal**: رسالة واتساب أكاديمية (بدون قسم مالي) تغطّي [from, to].

**Independent Test**: quickstart سيناريو 5.

- [X] T010 [US2] في `lib/utils/monthly_report_message.dart` `buildMonthlyReportMessage`: أضف `DateTime? periodStart` و`DateTime? periodEnd` (اختياريين). لو `periodStart != null`:
  - `monthLabel` يتحوّل لعنوان الفترة: `'من ${DateFormat('d MMMM yyyy', 'ar').format(periodStart)} إلى ${DateFormat('d MMMM yyyy', 'ar').format(periodEnd!)}'` والسطر الأول `'🧾 تقرير الفترة: $rangeLabel'` بدل `'🧾 تقرير الشهر: $monthLabel'`.
  - **تخطّى بلوك المدفوعات بالكامل** (`if (canSeeFinancials && periodStart == null) { ... }`) — لا سطر إجمالي ولا حلقة دفعات.
  - باقي البلوكات (حضور/سجلات/واجب/امتحانات/معلم) زي ما هي — المتصل بيمرّرها مفلترة.
- [X] T011 [US2] في `lib/views/students/student_details_page.dart` `_shareMonthlyReport` (~117): قبل `showDatePicker` الحالي، افتح `showModalBottomSheet` صغيّر باختيارين: **"تقرير شهر"** / **"تقرير فترة"**.
  - "تقرير شهر" → التدفّق الحالي بالكامل (منتقي شهر افتراضي `defaultCollectionMonth()` → `buildMonthlyReportMessage(month: ...)`).
  - "تقرير فترة" → منتقيي "من"/"إلى" (`showDatePicker`, `lastDate: DateTime.now().add(const Duration(days: 365))`، تحقّق `to >= from`). اجمع: `atts`/`hw` بفلترة `!date.isBefore(from) && !date.isAfter(toInclusive)`؛ الامتحانات `_canSeeAcademics ? (await DatabaseService().getStudentExamHistory(s.id!)).where((r) => !r.examDate.isBefore(from) && !r.examDate.isAfter(toInclusive)).toList() : []` (**بـ`examDate` الفعلي — Q1=A**)؛ ثم `buildMonthlyReportMessage(student: s, month: from, periodStart: from, periodEnd: to, groupName: _group?.name ?? '-', monthAtt: atts, monthHw: hw, monthPays: const [], monthExams: examsRange, teacherName: ..., teacherSpecialization: ..., canSeeFinancials: _canSeeFinancials, canSeeAcademics: _canSeeAcademics)` ثم نفس منطق `normalize` + `launchUrl(wa.me)`.

**Checkpoint**: US2 كامل — واتساب فترة أكاديمي بحت

---

## Phase 5: User Story 3 - تذكّر الوضع والنطاق خلال الجلسة (Priority: P3)

**Goal**: إعادة فتح شيت التصدير في نفس الجلسة تحتفظ بالوضع + التواريخ.

**Independent Test**: quickstart سيناريو 7.

- [X] T012 [US3] في `lib/views/reports/reports_page.dart`: ارفع `rangeMode` / `rangeFrom` / `rangeTo` من داخل `_showExportMenu` لمتغيّرات `static` على مستوى الملف (أو حقول في State لو الشاشة StatefulWidget). عند فتح الشيت، ابدأ من القيم المحفوظة؛ حدّثها مع كل تغيير. تتصفّر طبيعيًا مع إعادة تشغيل التطبيق (مش محفوظة في `SharedPreferences`).

**Checkpoint**: US3 كامل — أولوية منخفضة، ممكن يتأجّل

---

## Phase 6: Polish & Cross-Cutting

- [X] T013 جرد نداءات `exportAttendancePDF` / `exportHomeworkPDF`: `rg "exportAttendancePDF|exportHomeworkPDF" lib/` — أكّد إن `lib/views/attendance/attendance_page.dart` (~164) لسه بيمرّر `month:` بس (بدون `periodEnd`) فيشتغل بالوضع الشهري القديم بلا تغيير.
- [X] T014 `flutter analyze` — صفر أخطاء/تحذيرات جديدة.
- [ ] T015 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–7 على جهاز.
- [X] T016 ارفع `version` في `pubspec.yaml` (`1.2.36+54` → `1.2.37+55`) وابنِ `--split-per-abi` release.

---

## Dependencies & Execution Order

- **Phase 1** (T001) → لا شيء فعلي.
- **Phase 2** (T002 → T003): تسلسلي، نفس الملف. يحجب US1 فقط.
- **US1 (Phase 3)**: بعد Phase 2. T004/T005 [P ممكن نظريًا لكن نفس الملف → تسلسلي]. T006 بعد T004+T005. T007 بعد T003. T008 بعد T007. T009 مع T008 (نفس الدالة).
- **US2 (Phase 4)**: مستقل تمامًا عن US1 — بعد Phase 1 فقط. T010 → T011.
- **US3 (Phase 5)**: بعد US1 (T008).
- **Phase 6**: بعد الكل.

### تعارض ملفات

- `export_service.dart`: T002, T003, T004, T005, T006 — تسلسلي.
- `report_controller.dart`: T007.
- `reports_page.dart`: T008, T009, T012 — تسلسلي.
- `monthly_report_message.dart`: T010.
- `student_details_page.dart`: T011.

---

## Implementation Strategy

### MVP (US1)
Phase 1 + 2 + 3 → تحقّق (quickstart 1, 2, 3, 4, 6) → قابل للإصدار. ده جوهر الطلب (تصدير PDF لفترة الدورة).

### تدريجي
- + US2 (Phase 4) — واتساب فترة. مستقل، ممكن يتعمل بالتوازي مع US1.
- + US3 (Phase 5) — تذكّر خلال الجلسة. تحسين تجربة، ممكن يتأجّل.
- Phase 6: analyze + جهاز + بناء 1.2.37.

---

## Notes

- **صفر تغييرات قاعدة بيانات** — كله فلترة تواريخ + معاملات اختيارية.
- **الوضع الشهري الافتراضي في كل مكان** — كل النداءات الحالية بدون `periodEnd`/`from`/`to` تشتغل زي دلوقتي (SC-005).
- **الامتحانات بـ`examDate` الفعلي** (Q1=A) — مش `effectiveReportMonth`.
- **ملخص المجموعات PDF + تقرير الدفعات** مخفيّين في وضع الفترة (Q2=A) — مايتلمسوش برمجيًا.
- **تقرير واتساب الفترة بدون قسم مالي** (Q3=B) — `monthPays: const []` + شرط `periodStart == null` على بلوك المدفوعات.
- الإرسال الجماعي، البوابة، الإشعارات، كارت الداشبورد، شاشة الحضور — خارج النطاق.
