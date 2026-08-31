# Implementation Plan: تطبيق إعداد نظام الساعة (24 / 12) فورًا في كل التطبيق

**Branch**: `009-clock-format-setting` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/009-clock-format-setting/spec.md`

## Summary

إعداد "نظام الساعة 24" (`SettingsController.use24hFormat`, `RxBool`) بيتخزّن ويترجع صح،
لكن دوال العرض `FormatHelper.formatTime/formatPaymentDate/formatDateTime` دوال `static`
بتقرا القيمة **خارج** أي نطاق تفاعلي، فالشاشات المبنية مبتعيدش البناء عند التبديل. الحل:
عائلة ودجت تفاعلية موحّدة `ClockText` / `ClockBuilder` (ملف جديد `lib/widgets/clock_text.dart`)
تلفّ قراءة الإعداد في `Obx` مرة واحدة، تحلّ محل كل نقاط عرض الوقت وكل الحِيَل المبعثرة؛
دالة `FormatHelper.formatClock(TimeOfDay)` جديدة لمواعيد الحصص والإشعارات؛ و`setUse24hFormat`
يعيد جدولة الإشعارات عشان نصوصها المجدولة تتحدّث.

## Technical Context

**Language/Version**: Dart / Flutter (نفس إصدار المشروع)

**Primary Dependencies**: GetX (`SettingsController`, `Obx`)، `intl` (`DateFormat`)، `flutter_local_notifications` عبر `NotificationService`

**Storage**: `sqflite` عبر `DatabaseService` — **لا تغيير** (المفتاح `use_24h_time_format` في `app_settings` موجود)

**Testing**: يدوي/على الجهاز (اتساقًا مع المشروع) + اختبار وحدة واحد اختياري لـ`FormatHelper.formatClock` (دالة نقية)

**Target Platform**: Android (Flutter mobile)

**Project Type**: تطبيق موبايل موحّد واحد (لا فصل frontend/backend)

**Performance Goals**: غير منطبق — التبديل عملية نادرة؛ `Obx` إضافية لكل نقطة وقت أثرها مهمَل

**Constraints**: ممنوع تغيير صيغة التاريخ نفسها أو صيغ الـPDF/الواتساب النصية (FR-011). لازم إزالة كل الحِيَل المبعثرة (FR-004, SC-003)

**Scale/Scope**: ~10 ملفات عرض + `helpers.dart` + `settings_controller.dart` + `notification_service.dart` + `main.dart` + ملف ودجت جديد

## Constitution Check

لا يوجد ملف دستور مملوء فعليًا (`.specify/memory/constitution.md` لسه قالب) — لا بوابات واجبة. المبادئ الضمنية المتّبعة: إعادة استخدام الموجود، لا تكرار منطق، تغيير أدنى.

## Project Structure

### Documentation (this feature)

```text
specs/009-clock-format-setting/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — الجرد + القرارات
├── data-model.md        # Phase 1 — لا تغيير بيانات
├── quickstart.md        # Phase 1 — سيناريوهات تحقّق يدوية
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

مشروع Flutter موحّد. الملفات المتأثرة:

```text
lib/
├── widgets/
│   └── clock_text.dart              # جديد: ClockText / ClockDateTimeText /
│                                    #        ClockPaymentDateText / ClockBuilder
├── utils/
│   └── helpers.dart                 # + FormatHelper.formatClock(TimeOfDay)
│                                    #   (يتعامل صح مع 00:00 / 12:00)
├── controllers/
│   └── settings_controller.dart     # setUse24hFormat → + syncAllScheduledNotifications()
├── services/
│   └── notification_service.dart    # _fmt(TimeOfDay) → FormatHelper.formatClock
├── main.dart                        # builder: + MediaQuery(alwaysUse24HourFormat:
│                                    #   settings.use24hFormat.value) جوه الـObx الخارجي
└── views/
    ├── students/student_details_page.dart   # ClockPaymentDateText + شيل حيلة 1343
    ├── attendance/attendance_page.dart       # ClockText + شيل حيلة 2206
    ├── schedule/schedule_page.dart           # _fmtTime → formatClock + ClockBuilder + شيل حيلة 212
    ├── reports/payments_report_page.dart     # ClockPaymentDateText + شيل حيلة 354
    ├── payments/payments_page.dart           # ClockPaymentDateText + شيل حيلة 547
    ├── groups/groups_page.dart               # _fmt → formatClock + ClockBuilder + شيل حيلة 212 + شيل copyWith
    ├── groups/group_details_page.dart        # _fmt → formatClock + ClockBuilder("آخر إرسال") + شيل copyWith
    ├── qr_scanner/qr_scanner_attendance_page.dart  # ClockBuilder حوالين "في {time}"
    └── bookings/bookings_page.dart           # ClockDateTimeText حوالين "وصل {time}"
```

**Structure Decision**: تطبيق موحّد — لا خيارات هيكلية. التغيير أفقي عبر طبقة العرض، مُركَّز في
ودجت واحدة جديدة + دالة helper واحدة جديدة، والباقي استبدالات في نقاط الاستدعاء.

## نهج التنفيذ (تفصيل من research.md)

### 1. الودجت الموحّدة — `lib/widgets/clock_text.dart`

- `ClockText(DateTime? value, {TextStyle? style, TextAlign? textAlign, String? fallback})`
  → `Obx(() { Get.find<SettingsController>().use24hFormat.value; return Text(FormatHelper.formatTime(value), ...); })`
- `ClockDateTimeText(...)` نفس الفكرة بـ`formatDateTime`.
- `ClockPaymentDateText(...)` نفس الفكرة بـ`formatPaymentDate`.
- `ClockBuilder({required Widget Function(BuildContext) builder})`
  → `Obx(() { Get.find<SettingsController>().use24hFormat.value; return builder(context); })`
  للحالات المتداخلة (`'في ${FormatHelper.formatTime(x)}'`، `title:`/`subtitle:` جوه `ListTile`).

### 2. `FormatHelper.formatClock(TimeOfDay t)` في `helpers.dart`

- يقرا `use24hFormat` (نفس نمط `try/catch` الموجود).
- 24 ساعة: `'${_pad(h)}:${_pad(m)}'`.
- 12 ساعة: `DateFormat('h:mm a', 'ar').format(DateTime(2000,1,1,h,m))` — `intl` بيتعامل صح مع 0/12.
- يحلّ محل المنطق المكرّر في: `schedule_page._fmtTime`، `groups_page._fmt`، `group_details._fmt`، `notification_service._fmt`.

### 3. إعادة جدولة الإشعارات — `settings_controller.dart`

```
setUse24hFormat(bool v):
  use24hFormat.value = v
  await _dbSet(...)
  unawaited(NotificationService().syncAllScheduledNotifications())   // جديد
```

### 4. جذر التطبيق — `main.dart`

داخل الـ`Obx` الخارجي الموجود (اللي بيقرا `themeMode`)، الـ`builder:` يلفّ `child` في:
`MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: settings.use24hFormat.value), child: Directionality(...))`
— ويُشال الـ`MediaQuery.copyWith(alwaysUse24HourFormat: ...)` المكرّر حوالين `showTimePicker` في
`group_details_page.dart` و`groups_page.dart`.

### 5. استبدال نقاط الاستدعاء + إزالة الحِيَل

لكل ملف في الجدول أعلاه: استبدل `Text(FormatHelper.formatTimeX(...))` بالودجت المناسبة، أو لفّ
النص المتداخل في `ClockBuilder`، واحذف سطر `Get.find<SettingsController>().use24hFormat.value;`
اليدوي لو بقى بلا لزوم.

### خارج النطاق (تفضل `DateFormat('HH:mm')`)

تقارير واتساب/المشاركة، ملفات PDF/النسخ الاحتياطي/التصدير، سجلّ الدفع المخزَّن (`qr_controller.dart:247`).

## Complexity Tracking

لا مخالفات دستورية. لا يوجد ما يُبرَّر.
