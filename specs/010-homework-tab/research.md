# Research: تبويب واجب + 3 حالات + ربط الغياب + التقارير

**Feature**: 010-homework-tab | **Date**: 2026-09-01

## الوضع الحالي (جرد موسّع)

### الواجهة — `lib/views/attendance/attendance_page.dart`

| العنصر | ~السطر | الوصف |
|--------|-------|-------|
| `showAttendanceSheet` / `_AttendanceSheet` | 620 / 662 | موديل المجموعة: هيدر + صف "تحضير الكل" + **"واجب الكل"** (~882) + قائمة صفوف الطلاب |
| صف الطالب | 1015 / 1195 / 1238 | يمرّر `homeworkStatus` + `onHomeworkTap` |
| `_HomeworkBadge` | ~1345 | الشارة الدوّارة الحالية |

### المنطق — `HomeworkController` (`homework_controller.dart`)

- `statusFor(id, day)` → نص أو null
- `toggleHomework(id, day)` → غير مسجّل → عمل → لم يعمل → حذف (دوّار)
- `markGroupAllHomeworkDone(ids, day)` → لو الكل "عمل" يلغي، وإلا يسجّل "عمل" للكل

### الثوابت — `lib/config/constants.dart`

- `HOMEWORK_DONE = 'عمل'` · `HOMEWORK_NOT_DONE = 'لم يعمل'`

### التقارير والبوابة — كلها بتقارن بـ`HOMEWORK_DONE`/`HOMEWORK_NOT_DONE`

| مكان | ~السطر | الاستخدام |
|------|-------|-----------|
| `attendance_controller.buildGuardianReportMessage` | 637-639 | **تقرير الحصة/اليوم لطالب** — `'📗 عمل'` / `'📙 لم يعمل'` / `'لم يُسجَّل'` |
| `student_details_page._shareMonthlyReport` | ~180-195 | **التقرير الشهري** — `📖 الواجب: عمل X • لم يعمل Y` + سطور لكل يوم |
| `settings_page` (تقرير شهري) | ~1700 | مشابه |
| `parent_portal_service` | 198-229 | مستند البوابة — `homeworkDone` / `homeworkNotDone` / `homeworkHistory[].status` |
| `report_controller` | 130-137, 186-188 | تجميعات تقرير الواجب PDF |

## القرارات

### قرار 1: التبويبان **داخل `_AttendanceSheet`** (زي ما اتفق)

`DefaultTabController(length: 2)` + `TabBar(['حضور','واجب'])` + `Expanded(TabBarView(...))`،
`initialIndex: 0`، الهيدر مشترك فوق. تبويب "حضور" = القائمة الحالية ناقص شارة الواجب وزر "واجب الكل".
تبويب "واجب" = قائمة جديدة مبسّطة.

### قرار 2: 3 حالات صريحة بدل الشارة الدوّارة

- ثابت جديد `HOMEWORK_PARTIAL = 'ناقص'` في `constants.dart`. القيم الجديدة: `'تم الحل'` / `'ناقص'` / `'لم يُحل'`.
  **قرار فرعي**: نغيّر نصوص `HOMEWORK_DONE`/`HOMEWORK_NOT_DONE` نفسها لـ`'تم الحل'`/`'لم يُحل'`؟
  **لأ** — نسيبهم `'عمل'`/`'لم يعمل'` (بيانات قديمة)، ونضيف طبقة تطبيع `normalizeHomeworkStatus(raw)`
  في `HomeworkController` (أو helper) تحوّل القديم للجديد للعرض/التجميع. الكتابة الجديدة بالقيم الجديدة.
  *(بديل: migration نصّية تحدّث الصفوف القديمة — مرفوض، غير ضروري ويكبّر المخاطرة.)*
- `HomeworkController`:
  - جديد `setHomeworkStatus(id, day, String? status)` — يضبط الحالة المحدّدة، ولو `status == null`
    أو نفس الحالة الحالية → حذف السجل.
  - `toggleHomework` يفضل للتوافق أو يُشال (مفيش مستدعي بعد التبويب الجديد).
  - `markGroupAllHomeworkDone(ids, day)` — **يستثني الطلاب الغائبين** من `ids` (المُستدعي يفلترهم).
  - `homeworkSummary(ids, day)` → أعداد تم الحل / ناقص / لم يُحل / غير مسجّل (بعد استثناء الغائبين).
- ودجت `_HomeworkStatusSegmented` — 3 أزرار (نقطة ملوّنة + تسمية قصيرة)، المختار مميّز، `onSelect(status?)`.

### قرار 3: ربط الغياب بالواجب

- في `_AttendanceSheet` (نفس الموديل) حالة الحضور معروفة → تبويب "واجب" يقرا `statusMap[studentId]`:
  - `ATTENDANCE_ABSENT` → صف الطالب يعرض "غائب — لا واجب" (بدون أزرار)، ومستثنى من "الكل عمل" والملخّص.
- **حذف سجل الواجب عند تسجيل غياب**: عند ضبط طالب `ATTENDANCE_ABSENT` (في `_AttendanceSheet` أو
  `AttendanceController`)، يُنادى `homeworkCtrl` لحذف سجل واجبه لنفس اليوم (لو موجود).
  المكان الأنسب: بعد نجاح تسجيل الغياب في الموديل → `homeworkCtrl.clearHomework(id, day)`.
  *(بديل: تجاهل السجل بصمت بدون حذف — مرفوض، بيسيب بيانات ملغومة تظهر في التقارير.)*

### قرار 4: حالة الواجب في **كل** رسائل التقارير

- `buildGuardianReportMessage` (تقرير اليوم): `hwLabel` يتوسّع →
  `تم الحل 🟢` / `ناقص 🟡` / `لم يُحل 🔴` / `غائب (لا واجب)` / `لم يُسجَّل`.
- التقرير الشهري (`student_details_page` + `settings_page`): عدّادات 3 حالات بدل 2، وسطور اليوم بالقيمة الصح.
- `parent_portal_service`: `homeworkHistory[].status` يتطبّع، + عدّاد `homeworkPartial` جديد.
  الصفحة العامة (`booking_site/track`) تعرض الحالة الجديدة — **يُتحقق إن كانت الصفحة تعرض الواجب أصلاً**.
- `report_controller` تجميعات: إضافة `homeworkPartialByStudent`.
- helper واحد `homeworkStatusLabel(String? raw, {bool absent})` يُعاد استخدامه في كل نقاط العرض (مصدر حقيقة واحد).

### قرار 5: بدون هجرة قاعدة بيانات

`DATABASE_VERSION` + بنية جدول `homework` بدون تغيير. راجع data-model.md.

## المخاطر

- **انتشار المقارنة `== HOMEWORK_DONE`**: 5+ ملفات. التخفيف: helper تطبيع + بحث `rg "HOMEWORK_(DONE|NOT_DONE)"`
  للتأكد إن كل موضع بيتعامل مع "ناقص" و"غائب".
- `_AttendanceSheet` كبير — إدخال `TabBar` + ودجت segmented + منطق الغياب. تخفيف: تعديل مُركّز +
  `flutter analyze` + تجربة حضور عادي + تقرير واتساب + بوابة بعده.
- الصفحة العامة (`booking_site/track/index.html`) على VPS — لو بتعرض الواجب، محتاجة تحديث ونشر
  (زي ما حصل في spec 003). التخفيف: التحقق أول، ولو مش بتعرض الواجب → خارج النطاق.
- ارتفاع البوتوم شيت مع `TabBarView` (unbounded height) — `Expanded` داخل `Column` بارتفاع الشيت.
