# Data Model: تناسق التقارير

**Feature**: 013-reports-consistency | **Date**: 2026-09-02

## 1. جدول `exams` — عمود واحد جديد (US6)

| العمود | النوع | ملاحظة |
|--------|------|--------|
| `report_month` | TEXT (nullable) | صيغة `"YYYY-M"` (مثلاً `"2026-8"`). `null` = بديله شهر `date`. |

- `constants.dart`: `const String COL_EXAM_REPORT_MONTH = 'report_month';` · `DATABASE_VERSION` **21 → 22**.
- `_onCreate` (جدول exams): أضف `$COL_EXAM_REPORT_MONTH TEXT` قبل أعمدة الـsync.
- `_onUpgrade`:
  ```
  if (oldVersion < 22) {
    try {
      await db.execute('ALTER TABLE $TABLE_EXAMS ADD COLUMN $COL_EXAM_REPORT_MONTH TEXT');
    } catch (_) {}
  }
  ```
  (نمط `ALTER TABLE ADD COLUMN` الموجود — مش إعادة بناء جدول.)

## 2. `Exam` model

```
final String? reportMonth; // "YYYY-M" أو null

// helper — الشهر الفعلي للفلترة
DateTime get effectiveReportMonth {
  final rm = reportMonth;
  if (rm != null) {
    final p = rm.split('-');
    final y = int.tryParse(p[0]); final m = int.tryParse(p.length > 1 ? p[1] : '');
    if (y != null && m != null) return DateTime(y, m, 1);
  }
  return DateTime(date.year, date.month, 1);
}
```

- `toMap`: `COL_EXAM_REPORT_MONTH: reportMonth`
- `fromMap`: `reportMonth: m['report_month'] as String?`
- `copyWith`: يضيف `String? reportMonth` (مع `bool clearReportMonth = false` أو `Object? reportMonth = _sentinel` لو محتاجين نفرّق بين "مش متغيّر" و"صفّره" — عمليًا الفورم دايمًا بيبعت قيمة، فـ`reportMonth ?? this.reportMonth` كافي).

## 3. `StudentExamRecord` (`exam_grade_model.dart`)

```
final DateTime reportMonth; // مشتق وقت البناء
```
- `getStudentExamHistory` / `getAllStudentExamHistories`:
  - SELECT `e.report_month AS report_month`
  - عند البناء: `reportMonth: _reportMonthFrom(r['report_month'], DateTime.parse(r['exam_date']))`
  - helper: `report_month` نصّي → `DateTime(y, m, 1)`؛ null → `DateTime(examDate.year, examDate.month, 1)`.

## 4. `insertExam` / `updateExam`

أضف `COL_EXAM_REPORT_MONTH: exam.reportMonth` للـmap المكتوب + للـ`_queueSync` payload.

## 5. `sync_engine.dart`

- **push** (`case TABLE_EXAMS` ~327): أضف `'report_month': payload[COL_EXAM_REPORT_MONTH]`.
- **pull** (~963): أضف `COL_EXAM_REPORT_MONTH: remote['report_month']`.

## 6. `defaultCollectionMonth()` — helper مشترك (US2/US3/US4)

في `PricingHelper` (أو `lib/utils/date_helpers.dart`):
```
static DateTime defaultCollectionMonth() {
  final now = DateTime.now();
  final current = DateTime(now.year, now.month, 1);
  final grace = _settingsGrace(); // paymentGraceDays أو 0 لو SettingsController مش جاهز
  final earlyInMonth = now.day <= (grace > 5 ? grace : 5);
  if (billingArrears || earlyInMonth) {
    return DateTime(now.year, now.month - 1, 1); // آخر شهر مكتمل (Dart بينرمل يناير→ديسمبر السابق)
  }
  return current;
}
```
- `_settingsGrace()`: `Get.isRegistered<SettingsController>() ? .paymentGraceDays.value : 0`.

## 7. US1 — فلترة `report_controller`

`report_controller.dart` `loadData` (~46):
```
allStudents.assignAll(students.where((s) => !s.isArchived).toList());
```
(كل شيء تحت — `_studentsActiveInMonth`، `unpaidStudents`، `groupSummaries`، `sessionBreakdown`، PDF — بياخد منها.)

## 8. US2 — الشهر الأولي (4 أماكن)

كلها تستخدم `PricingHelper.defaultCollectionMonth()` بدل `DateTime(now.year, now.month, 1)`:
1. `report_controller.dart:24-25` `selectedMonth` الأولي.
2. `payments_page.dart:48` (وممكن :1585) `selectedMonth.value ??= ...`.
3. `payments_report_page.dart:40` `selectedMonth.value ??= ...`.
4. `group_details_page.dart:2447-2448` `DateTime selected = ...` في موديل "تفاصيل الرسوم".

- التنقّل/المنتقي/`showDatePicker` في كل الشاشات زي ما هو — بيحترم أي تغيير يدوي (FR-005).
- القراءات `?? DateTime.now()` fallback تفضل زي ما هي.

## 8b. US3 — دالة رسالة موحّدة (FR-007b)

`lib/utils/monthly_report_message.dart` (أو دالة في `attendance_controller`):
```
String buildMonthlyReportMessage({
  required Student student,
  required DateTime month,
  required Group? group,
  required List<Attendance> monthAtt,
  required List<Homework> monthHw,
  required List<Payment> monthPays,
  required List<StudentExamRecord> monthExams,
  required SettingsController settings,
}) { ... نفس البنية الحالية (أدق نسخة من التلاتة) ... }
```
- تراعي `TeamModeService().canSeeFinancials` / `canSeeAcademics` داخليًا.
- المسارات التلاتة (`_pickAndSend`, `_startWhatsappBatchSend`, `_shareMonthlyReport`) بتجمّع البيانات للشهر المختار وبتنادي الدالة.
- فلترة الامتحانات جوّه الدالة بـ`record.reportMonth` (US6).

## 9. US3 — منتقي الشهر في موديلات الواتساب

كل موديل (`_pickAndSend` / `_startWhatsappBatchSend` / `_shareMonthlyReport`):
- `state`/`Rx` للشهر: افتراضي `defaultCollectionMonth()`.
- عنصر UI فوق قائمة الطلاب: أزرار `‹ [شهر] ›` أو dropdown — خياراته من `_firstDataMonth()` لحد آخر شهر مكتمل (`now.month - (billingArrears ? 1 : (earlyInMonth ? 1 : 0))`).
- `_firstDataMonth()` = أقدم `min(attendanceStart/createdAt)` أو أقدم دفعة — أو ببساطة `now - 12 شهر` كحد.
- تغيير الشهر → `load(month)` + `getReportSentMap(ids, month)` + إعادة بناء.
- بناء رسالة الطالب: `start = month`, `end = آخر يوم في month` → كل الأقسام (حضور/سجلات/واجب/مدفوعات/**امتحانات**) تتفلتر تلقائيًا.
- **الامتحانات**: بدل `!r.examDate.isBefore(start) && !r.examDate.isAfter(end)` →
  `r.effectiveReportMonth.year == month.year && r.effectiveReportMonth.month == month.month`.

## 10. US4 — كارت الدفعات في الداشبورد

`dashboard_controller`:
- `final Rx<DateTime> paymentCardMonth = PricingHelper.defaultCollectionMonth().obs;`
- `void shiftPaymentCardMonth(int delta)` → `paymentCardMonth.value = DateTime(y, m + delta, 1)` (بحد أقصى الشهر الحالي، بحد أدنى أقدم شهر بيانات) + إعادة حساب.
- حساب أرقام الشهر M (دالة `_computePaymentCard(M)`):
  - `expected` = Σ `PricingHelper.totalDueThrough(student, group, month: M, ...)` − Σ `totalDueThrough(month: M-1)` → **مستحق شهر M بس**؟
    - أبسط وأدق مع "الرصيد الواحد": `expectedThrough = Σ totalDueThrough(M)`, `remainingThrough = Σ accumulatedDebtThrough(M)`, `collectedThrough = expectedThrough - remainingThrough`.
  - العرض: "محصّل [collectedThrough] / [expectedThrough]" + "متبقّي [remainingThrough]" + نسبة `collectedThrough/expectedThrough`.
  - `unpaidCount` = عدد الطلاب `accumulatedDebtThrough(M) > 0` (مع مهلة السماح للشهر الحالي فقط).
- الكارت UI (`home`): سهمين + `Text('دفعات ${DateFormat("MMMM", "ar").format(paymentCardMonth)}')`.

## 11. US5 — أعمدة جدول PDF من السجلات

`export_service.dart` `_attendanceGrid` (و`_homeworkTable`):
```
final daysWithRecords = <int>{};
for (final sAtt in attMap.values) { daysWithRecords.addAll(sAtt.keys); }
final sortedDays = daysWithRecords.toList()..sort();
if (sortedDays.isEmpty) return pw.Text('لا توجد حصص مسجّلة في $monthLabel');
// header: عمود لكل d في sortedDays (رقم اليوم + weekday)
// data: لكل طالب، لكل d في sortedDays: sAtt[d]
```
- العدّادات (`_attendanceSummary`) زي ما هي (بتجمّع من `attMap.values`).
- `colWidths` تتحسب من `sortedDays.length` بدل `days`.

## 12. US6 — فلترة الامتحانات في كل مكان

كل موضع بيفلتر امتحانات بالشهر → `record.reportMonth` (المشتق) بدل `examDate`:
- `group_details_page` قسم الامتحانات في تقرير الواتساب.
- `settings_page` `_startWhatsappBatchSend` قسم الامتحانات.
- `student_details_page` `_shareMonthlyReport` + تبويب الامتحانات الشهري (لو بيفلتر بالشهر).
- `export_service` أي تصدير امتحانات شهري.
- الفرز داخل الشهر يفضل بـ`examDate`.
- **البوابة**: `parent_portal_service` بياخد آخر 15 امتحان (مش مفلتر بالشهر) → **مش متأثرة**.

## 13. `_ExamFormSheet` (US6)

- `String? _reportMonth` (state)، افتراضيه `null` (= شهر التاريخ).
- منتقي: يعرض "شهر التقرير: [DateFormat MMMM yyyy من `_reportMonth ?? _date`]" + زر تغيير (`showDatePicker` أو month stepper).
- لو المدرس غيّر `_date` ولسه ماحددش `_reportMonth` صراحةً → المنتقي يتبع `_date` (يفضل `null`).
- `onSave` يبعت `reportMonth` (نص `"YYYY-M"` أو null) لـ`addExam`/`editExam`.
