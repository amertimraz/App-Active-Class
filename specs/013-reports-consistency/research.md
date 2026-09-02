# Research: تناسق التقارير

**Feature**: 013-reports-consistency | **Date**: 2026-09-02

## جرد الوضع الحالي

### US1 — المؤرشف في شاشة التقارير
- `report_controller.dart:41` `getAllStudents()` → `allStudents.assignAll(students)` **بدون فلترة**.
- `_studentsActiveInMonth` (سطر 106) بيفلتر بـ`createdAt` بس، مش `isArchived`.
- المقارنة: `dashboard_controller:126/143/254` و`notification_service:232/273` و`StudentController.loadAllStudents:53` **كلهم** بيعملوا `.where((s) => !s.isArchived)`.
- `report_controller.allStudents` بيتمرّر كـ`siblingGroupMembers` لـ`PricingHelper` — استبعاد المؤرشف آمن (الأرشفة بتفكّ ربط الإخوة عبر `_unlinkOrphanedSiblingSurvivor` — عمل سابق).

### US2 — الشهر الافتراضي (كل الشاشات)
- `report_controller.dart:24-25` `selectedMonth = Rx(DateTime(now.year, now.month, 1))`.
- `reports_page.dart:95-113` أزرار تنقّل (`ctrl.setMonth`) + `showDatePicker`.
- `payment_controller.dart:33` `selectedMonth = Rx<DateTime?>(null)` — الـviews بتعمل `??= DateTime(now.year, now.month, 1)`:
  - `payments_page.dart:48` و`payments_report_page.dart:40` (وممكن `payments_page.dart:1585`).
  - القراءات `?? DateTime.now()` (payments_page:743، payments_report_page:92) fallback فقط — تفضل.
- موديل "تفاصيل الرسوم" في `group_details_page.dart:2447-2448` — `DateTime selected = DateTime(now.year, now.month, 1)` + `showDatePicker` سطر 2573.
- `settings.paymentGraceDays` و`settings.billingArrears` (spec 012) متاحين.
- **4 أماكن بتحدّد "الشهر الحالي" افتراضيًا → كلها تستخدم `defaultCollectionMonth()`.**

### US3 — موديل واتساب + منتقي شهر
| المسار | الملف/الدالة | الشهر حاليًا |
|--------|-------------|--------------|
| من المجموعة | `group_details_page.dart` `_pickAndSend` (~2003) | `now` ثابت (سطر 2006–2008) |
| جماعي من الإعدادات | `settings_page.dart` `_startWhatsappBatchSend` (~1660) | `now` ثابت (سطر 1666–1669) |
| صفحة طالب واحد | `student_details_page.dart` `_shareMonthlyReport` (~115) | `now` ثابت (سطر 122–124) |
- المسارات التلاتة **بتضمّن قسم "📝 الامتحانات" بالفعل** (group_details:2234، settings:1799، student_details:224) مفلتر بـ`examDate ∈ [start,end]`.
- `_pickAndSend` بيستخدم `getReportSentMap(ids, start)` لتتبّع "تم الإرسال" — بيعتمد على `start` (شهر)، فتغيير الشهر بيغيّر التتبّع تلقائيًا.
- **النص متكرّر في 3 نسخ** بباختلافات بسيطة (`canSeeFinancials`/`canSeeAcademics`, تنسيق) — FR-007b: استخراج `buildMonthlyReportMessage(student, month)` واحدة. أقرب مكان مناسب: `attendance_controller` (فيها `buildGuardianReportMessage` اليومي بالفعل) أو helper منفصل `lib/utils/report_message.dart`.

### US4 — كارت الدفعات في الداشبورد
- `dashboard_controller.dart` `_loadMonthStats` (سطر 135): `monthStart = DateTime(now.year, now.month, 1)` ثابت.
- `monthExpected` = Σ `monthlyDue(monthStart)`؛ `monthPaid` = Σ مدفوعات **مؤرّخة** في الشهر ده؛ `monthPaymentRate` = paid/expected؛ `unpaidStudentsCount` من `isOverdue`.
- **المشكلة**: "المتوقع" لشهر و"المحصّل" لشهر تاني (فلوس أغسطس اللي دخلت سبتمبر). النسبة مالهاش معنى.
- الكارت في `home/dashboard` view — Obx على `monthPaid`/`monthExpected`/`monthPaymentRate`.

### US5 — جدول PDF
- `export_service.dart` `_attendanceGrid` (~536) و`_homeworkTable` (~603): `for (var d = 1; d <= days; d++)` عمود لكل يوم.
- `_attendanceSummary` (~566) بيجمّع من `attMap.values` (السجلات) مش من الأعمدة → العدّادات مستقلة عن الأعمدة أصلاً ✓.
- `attMap` = `Map<int studentId, Map<int day, String status>>` — الأيام اللي فيها سجلات موجودة كـ keys.

### US6 — "شهر التقرير" للامتحان
- `exam_model.dart`: `Exam` — name/date/maxGrade/passingGrade/createdAt/groupIds. `toMap`/`fromMap`/`copyWith`.
- `constants.dart:60-65` أعمدة الامتحان. `DATABASE_VERSION = 21`.
- `database_service.dart:180` `_onCreate` جدول exams. `_onUpgrade` آخر guard `oldVersion < 21`. نمط `ALTER TABLE ... ADD COLUMN` موجود (سطر 346).
- `insertExam` (1606) / `updateExam` (1699) — بيكتبوا الأعمدة صراحةً + `_queueSync(TABLE_EXAMS، ...)`.
- `getStudentExamHistory` (2010) + `getAllStudentExamHistories` (2049) — SELECT من exams، بيرجّعوا `StudentExamRecord`.
- `sync_engine.dart:327` push exam payload، `:963` pull — لازم `report_month` يتضاف للاتنين.
- `_ExamFormSheet` في `exams_page.dart` (919) — فورم الإضافة/التعديل، فيه `_date` + `showDatePicker`.
- `ExamController.addExam`/`editExam` (exam_controller.dart 36/63).

## القرارات

### قرار 1: US1 — فلترة سطر واحد
`report_controller.dart:46`: `allStudents.assignAll(students.where((s) => !s.isArchived).toList());`
- كل الباقي (`_studentsActiveInMonth`، `unpaidStudents`، `groupSummaries`، PDF) بياخد منها.

### قرار 2: US2/US3/US4 — helper مشترك لـ"شهر التحصيل الافتراضي"
دالة واحدة (في `PricingHelper` أو helper منفصل):
```
DateTime defaultCollectionMonth() {
  final now = DateTime.now();
  final current = DateTime(now.year, now.month, 1);
  final graceOk = now.day <= max(settings.paymentGraceDays, 5);
  if (PricingHelper.billingArrears || graceOk) {
    return DateTime(now.year, now.month - 1, 1); // آخر شهر مكتمل
  }
  return current;
}
```
- `report_controller.selectedMonth` الأولي، `_pickAndSend`/`_startWhatsappBatchSend`/`_shareMonthlyReport` الشهر الابتدائي، وكارت الداشبورد الشهر المعروض الأولي — كلهم يستخدموها.
- **السبب**: نفس المنطق في 4 أماكن → helper واحد.

### قرار 3: US3 — منتقي شهر في الموديلات
- الموديلات التلاتة تاخد `Rx/state` للشهر المختار، افتراضيه `defaultCollectionMonth()`.
- الخيارات = من أقدم شهر فيه بيانات (أقدم `attendanceStart`/دفعة) لحد `defaultCollectionMonth()` أو `now.month - (arrears ? 1 : 0)` — يعني **شهور مكتملة فقط**.
- تغيير الشهر → إعادة حساب `load(selectedMonth)` + `getReportSentMap(ids, selectedMonth)`.
- رسالة الطالب: `start`/`end` = الشهر المختار → الحضور/الواجب/المدفوعات/الامتحانات كلها تتفلتر تلقائيًا.

### قرار 4: US4 — كارت الداشبورد يتحوّل لـ"شهر + تنقّل" وأرقامه مشتقّة
- `dashboard_controller`: `Rx<DateTime> paymentCardMonth` (افتراضي `defaultCollectionMonth()`) + `setPaymentCardMonth(prev/next)`.
- الأرقام للشهر المعروض M:
  - `expected(M)` = `PricingHelper.totalDueThrough(month: M)` مجموع للطلاب النشطين وقتها.
  - `collected(M)` = `min(Σ كل دفعات الطالب, totalDueThrough(M))` مجموع — أو أبسط: `expected(M) - accumulatedDebtThrough(M)`.
  - `remaining(M)` = Σ `accumulatedDebtThrough(month: M)`.
  - `unpaidCount(M)` = عدد الطلاب اللي `accumulatedDebtThrough(M) > 0` (مع مهلة السماح للشهر الحالي بس).
- الكارت UI: سهمين + عنوان "دفعات [شهر M]".
- **السبب**: يخلي الكارت متّسق مع باقي التطبيق (المديونية المتراكمة) بدل النسبة المنفصلة المضلِّلة.

### قرار 5: US5 — الأعمدة من السجلات
- في `_attendanceGrid`/`_homeworkTable`: بدل `1..days`، احسب `sortedDays = attMap.values.expand((m) => m.keys).toSet().toList()..sort()`.
- لو `sortedDays` فاضية → اعرض صف "لا توجد حصص مسجّلة في [الشهر]".
- العدّادات زي ما هي (بتجمّع من `attMap.values` مباشرة).

### قرار 6: US6 — عمود `report_month` + migration v22
- `constants.dart`: `const String COL_EXAM_REPORT_MONTH = 'report_month';` + `DATABASE_VERSION 21 → 22`.
- `_onCreate`: أضف العمود `$COL_EXAM_REPORT_MONTH TEXT` لجدول exams.
- `_onUpgrade`: `if (oldVersion < 22) { try { await db.execute('ALTER TABLE $TABLE_EXAMS ADD COLUMN $COL_EXAM_REPORT_MONTH TEXT'); } catch (_) {} }`.
- تخزين: نص `"YYYY-MM"` (مثلاً `"2026-8"`). `null` = بديله شهر `date`.
- `Exam` model: `String? reportMonth` (أو `DateTime?`). helper `DateTime effectiveReportMonth` = `reportMonth != null ? parse : DateTime(date.year, date.month)`.
- `toMap`/`fromMap`/`copyWith` + `insertExam`/`updateExam` + `getStudentExamHistory`/`getAllStudentExamHistories` SELECT.
- `StudentExamRecord`: `DateTime reportMonth` (مشتق وقت البناء من `report_month ?? examDate`).
- `sync_engine`: push (سطر 327) + pull (963) يضيفوا `report_month`.
- `_ExamFormSheet`: منتقي "شهر التقرير" (افتراضيه شهر `_date`، بيتحدّث لو المدرس غيّر التاريخ ولسه ماغيّرش الشهر يدويًا).
- **كل فلترة امتحانات بالشهر** (المسارات التلاتة للواتساب + `getStudentExamHistory` consumers في `student_details` تبويب الامتحانات + `export_service` لو بيصدّر امتحانات) → تفلتر بـ`record.reportMonth` بدل `examDate`.

## المخاطر

- **US6 migration**: نفس درس specs 010/011 — `ALTER TABLE` بسيط (مش إعادة بناء)، guard `< 22`، `_onCreate` يتحدّث كمان.
- **US4**: الكارت في الداشبورد Obx على قيم متعددة — لازم `paymentCardMonth` يبقى Rx ويعيد الحساب عند التنقّل بدون إعادة تحميل كل الداشبورد.
- **US3**: تتبّع "تم الإرسال" (`report_logs`) مفتاحه `(studentId, monthStart)` — التغيير للشهر المختار طبيعي، بس نتأكد إن `getReportSentMap` بياخد الشهر مش ثابت.
- **`defaultCollectionMonth` وقت الإقلاع**: `SettingsController` ممكن يكون لسه ما حمّلش — استخدم `Get.isRegistered` + fallback `paymentGraceDays=0`.
- **يناير**: `DateTime(now.year, now.month - 1, 1)` → Dart بينرمل لديسمبر السنة اللي فاتت ✓.
- **البوابة**: مش متأثرة في spec 013 (الامتحانات في البوابة بتتفلتر... راجع — لو `parent_portal_service` بيفلتر امتحانات بالشهر، يتحدّث كمان).
