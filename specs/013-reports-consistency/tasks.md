---
description: "Task list — تناسق التقارير (013-reports-consistency)"
---

# Tasks: تناسق التقارير

**Input**: Design documents from `specs/013-reports-consistency/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: لا توجد بنية اختبار آلي — التحقّق يدوي عبر [quickstart.md](quickstart.md). لا مهام اختبار.

**Organization**: 6 قصص. helper مشترك `defaultCollectionMonth()` + plumbing عمود `report_month`
في المرحلة الأساسية.

## Path Conventions

Mobile single-project: كل الكود تحت `lib/`. الواجهة العامة تحت `booking_site/`.

---

## Phase 1: Setup

- [X] T001 في `lib/config/constants.dart`: أضف `const String COL_EXAM_REPORT_MONTH = 'report_month';` جنب أعمدة الامتحان، وارفع `DATABASE_VERSION` من `21` إلى `22`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: مفيش شغل user story يبدأ قبل اكتمال المرحلة دي

### 2أ — helper الشهر الافتراضي (يحجب US2/US3/US4)

- [X] T002 في `lib/utils/pricing_helper.dart`: أضف `static DateTime defaultCollectionMonth()` — `now = DateTime.now()`؛ `grace = Get.isRegistered<SettingsController>() ? Get.find<SettingsController>().paymentGraceDays.value : 0`؛ `earlyInMonth = now.day <= (grace > 5 ? grace : 5)`؛ لو `billingArrears || earlyInMonth` → `DateTime(now.year, now.month - 1, 1)`؛ غير كده `DateTime(now.year, now.month, 1)`. (استيراد `get` + `SettingsController` لو مش موجود — أو helper منفصل `lib/utils/date_helpers.dart` لو خوف من circular import مع settings_controller اللي بيستورد pricing_helper.)

### 2ب — plumbing عمود `report_month` (يحجب US6 + فلترة امتحانات US3)

- [X] T003 في `lib/services/database_service.dart` `_onCreate` (جدول `$TABLE_EXAMS` سطر ~180): أضف `$COL_EXAM_REPORT_MONTH TEXT,` قبل أعمدة الـsync.
- [X] T004 في `lib/services/database_service.dart` `_onUpgrade` (بعد guard `oldVersion < 21`): أضف `if (oldVersion < 22) { try { await db.execute('ALTER TABLE $TABLE_EXAMS ADD COLUMN $COL_EXAM_REPORT_MONTH TEXT'); } catch (_) {} }`.
- [X] T005 [P] في `lib/models/exam_model.dart`: أضف `final String? reportMonth;` (صيغة `"YYYY-M"`) للكونستركتور + `toMap` (`COL_EXAM_REPORT_MONTH: reportMonth` — لاحظ toMap بيستخدم string literals مش الثوابت، استخدم `'report_month'`) + `fromMap` (`reportMonth: m['report_month'] as String?`) + `copyWith` (`String? reportMonth` → `reportMonth ?? this.reportMonth`). أضف getter `DateTime get effectiveReportMonth` — يفكّ `reportMonth` "YYYY-M" لـ`DateTime(y, m, 1)`؛ لو null أو غير صالح → `DateTime(date.year, date.month, 1)`.
- [X] T006 في `lib/services/database_service.dart` `insertExam` (~1606) و`updateExam` (~1699): أضف `COL_EXAM_REPORT_MONTH: exam.reportMonth` للـmap المكتوب وللـ`_queueSync` payload.
- [X] T007 في `lib/services/database_service.dart` `getStudentExamHistory` (~2010) و`getAllStudentExamHistories` (~2049): أضف `e.$COL_EXAM_REPORT_MONTH AS report_month` للـSELECT، وعند بناء `StudentExamRecord` مرّر `reportMonth` المشتق (helper: `report_month` نصّي → `DateTime(y,m,1)`؛ null → `DateTime(examDate.year, examDate.month, 1)`).
- [X] T008 [P] في `lib/models/exam_grade_model.dart` `StudentExamRecord`: أضف `final DateTime reportMonth;` للكونستركتور (required).
- [X] T009 في `lib/services/sync_engine.dart`: في push `case TABLE_EXAMS` (~327) أضف `'report_month': payload[COL_EXAM_REPORT_MONTH]`؛ في pull (~963) أضف `COL_EXAM_REPORT_MONTH: remote['report_month']`.
- [X] T010 في `lib/controllers/exam_controller.dart` `addExam` و`editExam`: أضف بارامتر `String? reportMonth` ومرّره لـ`Exam(...)` / `copyWith`.

**Checkpoint**: `defaultCollectionMonth()` متاح، وعمود `report_month` بيتخزّن/يتقرا/يتزامن

---

## Phase 3: User Story 1 - المؤرشف مستبعد من شاشة التقارير (Priority: P1) 🎯

**Goal**: الطالب المؤرشف ما يظهرش في أي جزء من شاشة التقارير.

**Independent Test**: quickstart سيناريو 1.

- [X] T011 [US1] في `lib/controllers/report_controller.dart` `loadData` (~46): غيّر `allStudents.assignAll(students);` إلى `allStudents.assignAll(students.where((s) => !s.isArchived).toList());`. تأكّد إن `_studentsActiveInMonth` و`unpaidStudents` و`groupSummaries` و`sessionBreakdown` كلهم بياخدوا من `allStudents` (مفيش قراءة تانية لـ`getAllStudents`).

**Checkpoint**: US1 كامل — سطر واحد

---

## Phase 4: User Story 2 - الشهر الافتراضي في كل الشاشات (Priority: P1)

**Goal**: التقارير/المدفوعات/تقرير المدفوعات/تفاصيل الرسوم تفتح على شهر التحصيل الفعلي.

**Independent Test**: quickstart سيناريو 2.

- [X] T012 [US2] في `lib/controllers/report_controller.dart` (سطر ~24-25): غيّر `selectedMonth` الأولي من `DateTime(now.year, now.month, 1)` إلى `PricingHelper.defaultCollectionMonth()`.
- [X] T013 [P] [US2] في `lib/views/payments/payments_page.dart` (سطر ~48، وأي `??= DateTime(now...)` تاني زي ~1585): غيّر `controller.selectedMonth.value ??= DateTime(now.year, now.month, 1)` إلى `??= PricingHelper.defaultCollectionMonth()`. سيب القراءات `?? DateTime.now()` زي ما هي.
- [X] T014 [P] [US2] في `lib/views/reports/payments_report_page.dart` (سطر ~40): نفس تغيير T013 لـ`paymentController.selectedMonth.value ??= ...`.
- [X] T015 [P] [US2] في `lib/views/groups/group_details_page.dart` موديل "تفاصيل الرسوم" (سطر ~2447-2448): غيّر `DateTime selected = DateTime(now.year, now.month, 1)` إلى `PricingHelper.defaultCollectionMonth()`.

**Checkpoint**: US2 كامل — 4 أماكن، helper واحد

---

## Phase 5: User Story 3 - منتقي شهر + رسالة موحّدة لتقرير الواتساب (Priority: P1)

**Goal**: موديلات الواتساب التلاتة تبدأ بمنتقي شهر (شهور مكتملة)، والرسالة من دالة واحدة.

**Independent Test**: quickstart سيناريو 3.

- [X] T016 [US3] أنشئ `lib/utils/monthly_report_message.dart` — دالة `String buildMonthlyReportMessage({required Student student, required DateTime month, required Group? group, required List<Attendance> monthAtt, required List<Homework> monthHw, required List<Payment> monthPays, required List<StudentExamRecord> monthExams, required SettingsController settings})`. انقل أدق نسخة من الرسالة (من `group_details_page` ~2193-2261) — رأس + حضور (شامل متأخر spec 011) + سجلات + واجب + مدفوعات (بشرط `TeamModeService().canSeeFinancials`) + امتحانات (بشرط `canSeeAcademics`) + معلم. **فلترة الامتحانات جوّه الدالة بـ`monthExams` المُمرَّرة (المتصل بيفلترها بـ`effectiveReportMonth`).**
- [X] T017 [US3] في `lib/views/groups/group_details_page.dart` `_pickAndSend` (~2003): أضف `state` للشهر (`DateTime selectedReportMonth = PricingHelper.defaultCollectionMonth()`)، وعنصر UI فوق قائمة الطلاب (`‹ [MMMM yyyy] ›` أو منتقي) خياراته الشهور المكتملة (من `now - 12 شهر` أو أقدم بيانات لحد `defaultCollectionMonth()`). تغيير الشهر → إعادة `load` + `getReportSentMap(ids, selectedReportMonth)`. بناء رسالة كل طالب: جمّع سجلاته للشهر المختار (حضور/واجب/مدفوعات + `getStudentExamHistory(id).where((r) => r.reportMonth.year==m.year && r.reportMonth.month==m.month)`) ثم `buildMonthlyReportMessage(...)`.
- [X] T018 [US3] في `lib/views/settings/settings_page.dart` `_startWhatsappBatchSend` (~1660): نفس T017 — منتقي شهر + `buildMonthlyReportMessage`. احذف بناء النص المحلي (~1739-1810).
- [X] T019 [US3] في `lib/views/students/student_details_page.dart` `_shareMonthlyReport` (~115): نفس T017 — يفتح منتقي شهر (افتراضي `defaultCollectionMonth()`) قبل الإرسال + `buildMonthlyReportMessage`. احذف بناء النص المحلي (~166-230).

**Checkpoint**: US3 كامل — 3 مسارات، دالة واحدة، منتقي شهر، امتحانات بـreportMonth

---

## Phase 6: User Story 4 - كارت الدفعات في الداشبورد (Priority: P1)

**Goal**: الكارت يعرض شهر التحصيل + تنقّل، أرقامه من المديونية المتراكمة.

**Independent Test**: quickstart سيناريو 4.

- [X] T020 [US4] في `lib/controllers/dashboard_controller.dart`: أضف `final Rx<DateTime> paymentCardMonth = PricingHelper.defaultCollectionMonth().obs;` + `RxDouble paymentCardExpected/Collected/Remaining` + `RxInt paymentCardUnpaid` + `RxDouble paymentCardRate`. أضف `void shiftPaymentCardMonth(int delta)` — يعدّل `paymentCardMonth` (بحد أقصى الشهر الحالي) وينادي `_computePaymentCard()`.
- [X] T021 [US4] في `lib/controllers/dashboard_controller.dart`: أضف `Future<void> _computePaymentCard()` — للشهر `M = paymentCardMonth.value`، للطلاب النشطين (غير مؤرشفين، غير مُعفيين كليًا): `expected = Σ PricingHelper.totalDueThrough(month: M)`؛ `remaining = Σ PricingHelper.accumulatedDebtThrough(month: M)`؛ `collected = expected - remaining`؛ `rate = expected>0 ? collected/expected : 0`؛ `unpaid = عدد الطلاب accumulatedDebtThrough(M) > 0` (مع `isOverdue` graceDays للشهر الحالي). نادِها من `_loadMonthStats` (أو `loadDashboardData`).
- [X] T022 [US4] في ودجت كارت الدفعات في الداشبورد (`lib/views/home/...` — الكارت اللي عنوانه "دفعات [الشهر]"): أضف سهمين (‹ ›) يستدعوا `shiftPaymentCardMonth(-1/+1)`، وغيّر العنوان لـ`'دفعات ${DateFormat('MMMM', 'ar').format(ctrl.paymentCardMonth.value)}'`، واربط الأرقام بـ`paymentCardCollected/Expected/Remaining/Rate/Unpaid` بدل `monthPaid/monthExpected/...`. لفّها في `Obx`.

**Checkpoint**: US4 كامل — كارت متنقّل بأرقام متّسقة

---

## Phase 7: User Story 5 - جدول PDF يعرض أيام التسجيل فقط (Priority: P2)

**Goal**: جدول الحضور/الواجب PDF يعرض أعمدة الأيام اللي فيها تسجيل فقط.

**Independent Test**: quickstart سيناريو 5.

- [X] T023 [US5] في `lib/services/export_service.dart` `_attendanceGrid` (~536): قبل بناء الأعمدة، احسب `final days = <int>{}; for (final m in attMap.values) days.addAll(m.keys); final sortedDays = days.toList()..sort();`. لو `sortedDays.isEmpty` → `return pw.Text('لا توجد حصص مسجّلة في $monthLabel', ...)`. غيّر حلقات الـheader والصفوف من `for (var d = 1; d <= days; d++)` إلى `for (final d in sortedDays)`. `colWidths` تتحسب من `sortedDays.length`.
- [X] T024 [P] [US5] في `lib/services/export_service.dart` `_homeworkTable` (~603): نفس T023 لجدول الواجب (`hwMap`).
- [X] T025 [US5] تحقّق `_attendanceSummary` (~566): بيجمّع من `attMap.values` مباشرة → العدّادات صحيحة بدون تغيير. أكّد فقط.

**Checkpoint**: US5 كامل

---

## Phase 8: User Story 6 - "شهر التقرير" للامتحان في كل مكان (Priority: P2)

**Goal**: منتقي "شهر التقرير" في شاشة الامتحان + كل فلترة امتحانات بالشهر تتبعه.

**Independent Test**: quickstart سيناريو 6.

- [X] T026 [US6] في `lib/views/exams/exams_page.dart` `_ExamFormSheet` (~919): أضف `String? _reportMonth` (state، افتراضي `null`). أضف صف "شهر التقرير" — يعرض `DateFormat('MMMM yyyy', 'ar').format(_reportMonth != null ? parse(_reportMonth) : _date)` + زر تغيير (`showDatePicker` → `_reportMonth = '${p.year}-${p.month}'`). لو `_date` اتغيّر و`_reportMonth == null` → يفضل null (يتبع التاريخ). `onSave` يبعت `_reportMonth`.
- [X] T027 [US6] في `lib/views/exams/exams_page.dart` `_showExamSheet` `onSave` (~409): مرّر `reportMonth` لـ`_ec.addExam(...)` / `existing.copyWith(reportMonth: ...)` + `_ec.editExam`.
- [X] T028 [US6] في `lib/views/students/student_details_page.dart` تبويب الامتحانات (لو بيفلتر/يجمّع بالشهر): استخدم `record.reportMonth` بدل `examDate` للتجميع الشهري؛ الفرز داخل الشهر يفضل بـ`examDate`.
- [X] T029 [P] [US6] في `lib/services/export_service.dart`: أي تصدير امتحانات شهري — فلترة بـ`record.reportMonth`.
- [X] T030 [US6] جرد: `rg "examDate.isBefore|examDate.isAfter|examDate.*month|r.examDate"` عبر `lib/` — كل موضع بيفلتر/يجمّع امتحانات **بالشهر** يتحوّل لـ`effectiveReportMonth` / `record.reportMonth`. (مسارات الواتساب اتغطّت في T016-T019.)

**Checkpoint**: US6 كامل — الامتحان بيروح للشهر الصح في كل عرض شهري

---

## Phase 9: Polish

- [X] T031 `flutter analyze` — صفر أخطاء/تحذيرات جديدة.
- [ ] T032 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–6 على جهاز — خصوصًا migration v21→v22 فوق بيانات قديمة + الامتحانات القديمة سليمة.
- [X] T033 ارفع `version` في `pubspec.yaml` (+build) وابنِ `--split-per-abi` release.

---

## Dependencies & Execution Order

- **Phase 1** → **Phase 2**. داخل Phase 2: T002 مستقل. T003→T004 (نفس الملف). T005/T008 [P]. T006/T007 بعد T003. T009 بعد T005. T010 بعد T005.
- **US1 (Phase 3)**: بعد Phase 1 فقط (مش محتاج Phase 2) — سطر واحد.
- **US2 (Phase 4)**: بعد T002. T012 (report_controller) · T013/T014/T015 [P] (ملفات مختلفة).
- **US3 (Phase 5)**: بعد T002 + T007 (getStudentExamHistory بترجّع reportMonth). T016 أولًا، بعده T017/T018/T019 (كلهم بينادوه — [P] ملفات مختلفة).
- **US4 (Phase 6)**: بعد T002. T020→T021→T022 (نفس الكنترولر ثم الودجت).
- **US5 (Phase 7)**: مستقل تمامًا (بعد Phase 1). T023/T024 [P].
- **US6 (Phase 8)**: بعد Phase 2ب كاملة. T026→T027 (نفس الملف). T028/T029/T030.
- **Phase 9**: بعد الكل.

### تعارض ملفات
- `pricing_helper.dart`: T002.
- `database_service.dart`: T003, T004, T006, T007 — تسلسلي.
- `exam_model.dart`: T005. `exams_page.dart`: T026, T027 — تسلسلي.
- `report_controller.dart`: T011, T012 — تسلسلي.
- `dashboard_controller.dart`: T020, T021 — تسلسلي.
- `export_service.dart`: T023, T024, T029 — تسلسلي.
- `group_details_page.dart`: T015, T017. `settings_page.dart`: T018. `student_details_page.dart`: T019, T028.

---

## Implementation Strategy

### MVP (US1 + US2 + US3 + US4)
كلهم P1. US1 لوحده سطر. US2 helper + 4 سطور. US3 الأكبر (دالة موحّدة + 3 موديلات). US4 كارت.
→ تحقّق (quickstart 1–4) → قابل للإصدار.

### تدريجي
- + US5 (Phase 7) — جدول PDF. مستقل، ممكن يتعمل في أي وقت.
- + US6 (Phase 8) — "شهر التقرير". فيه migration، خليه آخر حاجة قبل البناء.
- Phase 9: analyze + جهاز + بناء.

---

## Notes

- **الافتراضيات محفوظة**: امتحانات قديمة `report_month=null` → بتاريخها. شهور بعد المهلة (بدون تحصيل مؤخّر) → الشهر الحالي زي دلوقتي.
- migration v22 = `ALTER TABLE ADD COLUMN` بسيط، guard `< 22`، `_onCreate` يتحدّث كمان (نمط specs 010/011).
- `defaultCollectionMonth()`: لو خوف من circular import (`settings_controller` بيستورد `pricing_helper` بعد spec 012) — حطّها في `lib/utils/date_helpers.dart` وخليها تقرأ `PricingHelper.billingArrears` (static) + `Get.find<SettingsController>()` بحذر.
- الإشعارات / الواجب / بوابة الامتحانات — متّسقين بالفعل، مفيش شغل (موثّق في spec Assumptions).
- `booking_site` — مش متأثر في spec 013.
