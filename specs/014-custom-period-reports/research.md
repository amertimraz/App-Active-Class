# Research: تقارير الفترة المخصصة

## قرار 1 — مكان حالة "الوضع + النطاق"

**Decision**: حالة محلية للـUI (متغيّرات داخل شيت التصدير + داخل تدفّق المشاركة في صفحة الطالب). **مش** في `ReportController`.

**Rationale**: `ReportController.selectedMonth` تغذّي شاشة التقارير كلها (KPIs، ملخصات المجموعات، قائمة غير المدفوعين، المحصّلات الشهرية). لو خلّينا الفترة تعدّل عليها، هنكسر كل العروض دي اللي مبنية على "شهر واحد". الفترة تخصّ التصدير فقط.

**Alternatives rejected**:
- `Rx<DateRange>` في الكنترولر: يسرّب مفهوم الفترة لعروض مش محتاجاه.
- شاشة تصدير منفصلة: زيادة سطح UI بدون داعٍ؛ الشيت الحالي كفاية.

**US3 (تذكّر خلال الجلسة)**: متغيّرات `static` بسيطة على مستوى ملف `reports_page.dart` (أو حقول في الـState لو الشيت جوّه StatefulWidget) — تعيش طول الجلسة، تتصفّر مع إعادة تشغيل التطبيق. أولوية P3، ممكن تتأجّل.

## قرار 2 — توقيع دوال `ExportService`

**Decision**: نضيف معامل اختياري `DateTime? periodEnd` لـ`exportAttendancePDF` و`exportHomeworkPDF`:

```dart
Future<ExportResult> exportAttendancePDF({
  required DateTime month,   // وضع الشهر: أي يوم بالشهر. وضع الفترة: تاريخ البداية (يُستخدم كما هو).
  DateTime? periodEnd,       // != null → وضع الفترة [month, periodEnd] شاملاً الطرفين
  required List<Student> students,
  required List<Attendance> attendance,
  required List<Group> groups,
})
```

`final isRange = periodEnd != null;`
- `start = isRange ? DateTime(month.year, month.month, month.day) : DateTime(month.year, month.month, 1)`
- `end   = isRange ? DateTime(periodEnd.year, periodEnd.month, periodEnd.day) : DateTime(month.year, month.month + 1, 0)`
- فلترة السجلات: `!d.isBefore(start) && !d.isAfter(endInclusive)` حيث `endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59)`.

**Rationale**: كل الاستدعاءات الحالية (`report_controller`, `attendance_page`) بتمرّر `month:` بالاسم — إضافة معامل اختياري متأخّر ما بتكسرهاش. صفر تغيير في نداءات الوضع الشهري.

**Alternatives rejected**:
- دالة جديدة `exportAttendanceRangePDF`: تكرار ~80% من الكود (بناء الصفحات لكل مجموعة، الملخص، الحفظ).
- `DateTimeRange` بدل تاريخين: نوع Flutter، بس تاريخين أوضح للتمرير من الكنترولر.

## قرار 3 — ترويسة عمود اليوم في وضع الفترة

**الوضع الحالي** (`_attendanceTable`/`_homeworkTable` بعد سبيك 013 US5): الأعمدة = الأيام اللي فيها تسجيل فعلي، والترويسة `_thSmall('$d\n$weekday')` حيث `d` = يوم الشهر (1–31).

**المشكلة**: فترة عابرة لشهرين ممكن يبقى فيها "3" مرتين (3 أغسطس و3 سبتمبر) — لبس.

**Decision**: في وضع الفترة، مفتاح خريطة الأعمدة يبقى **التاريخ الكامل** مش يوم الشهر. عمليًا:
- الخريطة الحالية `Map<int studentId, Map<int day, String status>>` تبقى `Map<int studentId, Map<DateTime dayDate, String status>>` **في وضع الفترة فقط** — أو أبسط: نبني الخريطة بمفتاح `int` = `date.difference(start).inDays` (ترتيب مضمون، فريد عبر الشهور)، ونحتفظ بجدول `List<DateTime> columnDates` للترويسة.
- الترويسة: `_thSmall('${dt.day}/${dt.month}\n$weekday')` في وضع الفترة، و`_thSmall('${dt.day}\n$weekday')` في الوضع الشهري (زي دلوقتي).

**نهج التنفيذ المفضّل**: بدل تعقيد الخريطة، نحسب `List<DateTime> sortedDates` (التواريخ الفعلية اللي فيها تسجيل داخل النطاق، مرتّبة) ونعمل حلقة عليها مباشرة — نفس فكرة سبيك 013 US5 بس بـ`DateTime` بدل `int day`. الوضع الشهري يفضل يستخدم `int day` زي ما هو، أو نوحّدهم على `DateTime` ونخلّي الترويسة شرطية. **القرار**: نوحّد على `DateTime` — أنضف، والترويسة `isRange ? 'd/M' : 'd'`.

## قرار 4 — `buildMonthlyReportMessage` في وضع الفترة

**Decision**: نضيف معاملين اختياريين:

```dart
String buildMonthlyReportMessage({
  required Student student,
  required DateTime month,          // يُتجاهل لو periodStart != null
  DateTime? periodStart,
  DateTime? periodEnd,
  ... (باقي المعاملات زي ما هي)
})
```

- لو `periodStart != null`:
  - العنوان: `'🧾 تقرير الفترة: من ${fmt(periodStart)} إلى ${fmt(periodEnd)}'` بدل `'تقرير الشهر: $monthLabel'`.
  - **يتخطّى القسم المالي بالكامل** (لا حلقة `monthPays`، لا سطر إجمالي) — بصرف النظر عن `canSeeFinancials` (Q3=B).
  - سطر "بداية الحضور" يفضل زي ما هو.
- المتصل مسؤول عن تمرير `monthAtt`/`monthHw`/`monthExams` مفلترة بالنطاق (الحضور/الواجب بتاريخهم، الامتحانات بـ`examDate` — Q1=A). `monthPays` يتمرّر فاضي في وضع الفترة.

**Rationale**: دالة واحدة موحّدة (نمط سبيك 013)، الفرق سطرين شرطيين.

## قرار 5 — واجهة اختيار الوضع

### شيت التصدير (`reports_page.dart`)
مفتاح `SegmentedButton` / `ToggleButtons` في أعلى الشيت: **[ شهر | فترة مخصصة ]**.
- وضع "شهر": الشيت زي ما هو دلوقتي (العنوان "تصدير تقرير — [شهر]"، الخيارات الأربعة).
- وضع "فترة مخصصة":
  - صفّان لاختيار التاريخ: "من" و"إلى" (`showDatePicker`، افتراضي: من = أول الشهر الحالي المختار، إلى = النهاردة).
  - تحقّق: "إلى" مش أقدم من "من" (لو حصل، نظبط "إلى" = "من").
  - العنوان: "تصدير تقرير — من [تاريخ] إلى [تاريخ]".
  - يظهر **خياران فقط**: تقرير الحضور، تقرير الواجب.
  - "تقرير الدفعات" و"ملخص المجموعات" **مخفيّين** (Q2=A + منطق: تقرير الدفعات شهري بطبيعته).

### صفحة الطالب (`student_details_page._shareMonthlyReport`)
حاليًا: `showDatePicker` مباشر لاختيار الشهر.
الجديد: `showModalBottomSheet` صغيّر فيه اختيار **[ تقرير شهر | تقرير فترة ]**:
- "تقرير شهر" → نفس التدفّق الحالي (`showDatePicker` شهر، افتراضي `defaultCollectionMonth()`).
- "تقرير فترة" → منتقيي "من"/"إلى" → `buildMonthlyReportMessage(periodStart:, periodEnd:, monthPays: [], ...)`، الامتحانات مفلترة بـ`examDate` في النطاق.

## قرار 6 — تسمية ملف PDF ونطاق `firstDate/lastDate`

- تسمية: `attendance_2026-08-15_الى_2026-09-15` (دالة `_fileRange(from, to)` جنب `_fileMonth`).
- `showDatePicker` في وضع الفترة: `firstDate = DateTime(2020)`, `lastDate = DateTime.now().add(Duration(days: 365))` (زي منتقي الشهر الحالي — الفترة ممكن تكون لسه شغالة).

## قرار 7 — الشاشات خارج النطاق (تأكيد)

- `attendance_page._exportPDF` (تصدير حضور مجموعة من شاشة الحضور): يفضل شهري — مايتمسّش. الاستدعاء ما بيمرّرش `periodEnd` فيشتغل بالوضع القديم.
- الإرسال الجماعي (`group_details_page._pickAndSend`, `settings_page._startWhatsappBatchSend`): شهري، مايتمسّش (سبيك 013).
- بوابة أولياء الأمور، الإشعارات، كارت الداشبورد: مايتمسّوش.
- `exportPaymentsPDF`, `exportGroupsSummaryPDF`: مايتمسّوش (مش معروضين في وضع الفترة).
