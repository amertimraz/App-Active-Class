# Research: تطبيق إعداد نظام الساعة (24 / 12) فورًا في كل التطبيق

**Feature**: 009-clock-format-setting | **Date**: 2026-08-31

## جرد الوضع الحالي (Phase 0 discovery)

### طبقة التنسيق

| المكان | الدالة | بتقرا الإعداد؟ | تفاعلية؟ |
|--------|--------|----------------|-----------|
| `lib/utils/helpers.dart` | `FormatHelper.formatTime(DateTime?)` | ✅ `use24hFormat.value` جوه `try` | ❌ static — بتقرا برّه أي `Obx` |
| `lib/utils/helpers.dart` | `FormatHelper.formatPaymentDate(DateTime?)` | ✅ | ❌ |
| `lib/utils/helpers.dart` | `FormatHelper.formatDateTime(DateTime?)` | ✅ | ❌ |
| `lib/views/schedule/schedule_page.dart` | `_fmtTime(TimeOfDay)` | ✅ | يعتمد على حيلة سطر `.value` جوه Obx |
| `lib/views/groups/groups_page.dart` | `_fmt(DateTime)` ~سطر 138، +1374 | ✅ | حيلة سطر `.value` (212) |
| `lib/views/groups/group_details_page.dart` | `_fmt(TimeOfDay)` ~سطر 233 | ✅ | حيلة سطر `.value` |
| `lib/services/notification_service.dart` | `_fmt(TimeOfDay)` سطر 438 | ❌ **دايمًا 24 ساعة** | غير منطبق (خارج شجرة الودجت) |

### حِيَل التحديث اليدوية المبعثرة (سطر `Get.find<SettingsController>().use24hFormat.value;` جوه `Obx`)

- `lib/views/attendance/attendance_page.dart:2206`
- `lib/views/students/student_details_page.dart:1343`
- `lib/views/schedule/schedule_page.dart:212`
- `lib/views/reports/payments_report_page.dart:354`
- `lib/views/payments/payments_page.dart:547`
- `lib/views/groups/groups_page.dart:212`
- `lib/views/groups/group_details_page.dart` (حوالي 1559 — قراءة `use24h` لمنتقي الوقت)

### نقاط عرض وقت من غير أي تفاعلية (البلاغ الأساسي)

- `lib/views/qr_scanner/qr_scanner_attendance_page.dart:633` — `'في ${FormatHelper.formatTime(record.date)}'`
- `lib/views/bookings/bookings_page.dart:394` — `'وصل ${FormatHelper.formatDateTime(request.createdAt)}'`
- `lib/views/groups/group_details_page.dart:2142` — `'آخر إرسال: ${FormatHelper.formatDateTime(last)}'`
- محتوى الإشعارات: `notification_service.dart:345` (`'الحصة الساعة ${_fmt(time)}'`) و`:367` (`'${g.name} الساعة ${_fmt(time)}'`)

### خارج النطاق (تفضل ثابتة `HH:mm`)

- تقارير واتساب النصية / ملخصات المشاركة: `qr_scanner_payment_page.dart:347,353`, `qr_scanner_attendance_page.dart:834`, `student_details_page.dart:196`, `settings_page.dart:1718`, `group_details_page.dart:2219`
- ملفات النسخ الاحتياطي / التصدير: `auto_backup_service.dart:34`, `backup_service.dart:64`, `export_service.dart:368`
- سجلّ الدفع الداخلي (نص مخزَّن): `qr_controller.dart:247`

## القرارات

### قرار 1: الطريقة الموحّدة = عائلة ودجت تفاعلية `ClockText` + `ClockBuilder`

**القرار**: ملف جديد `lib/widgets/clock_text.dart` فيه:
- `ClockText(DateTime? value, {style, ...})` — يعرض وقت فقط (`formatTime`).
- `ClockDateTimeText(DateTime? value, {...})` — تاريخ + وقت (`formatDateTime`).
- `ClockPaymentDateText(DateTime? value, {...})` — تاريخ + وقت بدقّة الدفعات (`formatPaymentDate`).
- `ClockBuilder({required Widget Function(BuildContext) builder})` — للحالات اللي الوقت متداخل جوه نص أكبر (`'في 2:30 م'`) أو جوه `title:`/`subtitle:`؛ الـbuilder بيتنفّذ جوه `Obx` بيشترك في `use24hFormat`.

كل واحدة بتلفّ محتواها في `Obx(() { Get.find<SettingsController>().use24hFormat.value; return ...; })` مرة واحدة في مكان واحد.

**السبب**:
- `FormatHelper.format*` static بتقرا الـRx خارج نطاق تفاعلي؛ الحل الوحيد الصحيح إن القراءة تحصل جوه `Obx`.
- حل على مستوى جذر التطبيق (لفّ `Navigator`/`MediaQuery` في `Obx`) **لا يعمل** لأن الـwidget instance مبيتغيّرش، فما فيش إعادة بناء للنسل، وكل نقاط العرض بتستخدم `FormatHelper` مباشرة مش `MediaQuery.of(context)`.
- ودجت واحدة موحّدة = نشيل كل الحِيَل المبعثرة ونمنع تكرارها (FR-003, FR-004, SC-003).

**البدائل المرفوضة**:
- **`KeyedSubtree` بمفتاح بيتقلب على مستوى الجذر**: بيعيد بناء كل شيء بس بيصفّر حالة التنقّل (يرجع المستخدم لأول شاشة) — غير مقبول.
- **تحويل كل الكود لـ`MaterialLocalizations.formatTimeOfDay` + `MediaQuery.alwaysUse24HourFormat`**: refactor ضخم (كل `DateTime`→`TimeOfDay`، context في كل مكان) وبيغيّر تفاصيل الصيغة نفسها — الـspec بتمنع تغيير الصيغة.
- **`ValueListenableBuilder`/`GetX<SettingsController>` لكل نقطة**: نفس فكرة `ClockBuilder` بس أقل قابلية للقراءة.

### قرار 2: `FormatHelper.formatClock(TimeOfDay)` جديدة لمواعيد الحصص + الإشعارات

**القرار**: أضف `static String formatClock(TimeOfDay t)` في `FormatHelper` بتحترم `use24hFormat` وبتتعامل صح مع 00:00 (12:00 ص) و12:00 (12:00 م). كل من `schedule_page._fmtTime` و`groups_page._fmt` و`group_details._fmt` و`notification_service._fmt` بيستدعوها (بدل منطق محلي مكرّر).

**السبب**: توحيد منطق تنسيق `TimeOfDay` في مكان واحد؛ `notification_service` حاليًا بيطبع 24 ساعة دايمًا وده أصل جزء من البلاغ ("مواعيد الحصص والإشعارات").

**البدائل المرفوضة**: إبقاء منطق منفصل لكل شاشة — بيخالف FR-003 وسهل ينساه حد تاني.

### قرار 3: `setUse24hFormat` يعيد جدولة الإشعارات

**القرار**: `SettingsController.setUse24hFormat` — بعد حفظ القيمة — ينادي `NotificationService().syncAllScheduledNotifications()` (زي ما `group_details._confirmArchiveStudent` بيعمل بعد تغييرات المجموعة).

**السبب**: نصوص إشعارات تذكير الحصة + ملخص اليوم بتتحدّد وقت الجدولة (مش وقت الإطلاق)، فمن غير إعادة جدولة الإشعارات المجدولة تفضل بالصيغة القديمة (edge case مقبول جزئيًا في الـspec، بس إعادة الجدولة أنضف وسهلة).

**البدائل المرفوضة**: ترك الإشعارات القديمة بصيغتها لحد أي مزامنة تانية — يخالف روح "كل مكان" وبيسيب سلوك محيّر.

### قرار 4: منتقيات الوقت الأصلية (`showTimePicker`) + `MediaQuery.alwaysUse24HourFormat`

**القرار**:
- في `main.dart` الـ`builder:` (جوه الـ`Obx` الخارجي الموجود) — نضيف `MediaQuery` override بـ`alwaysUse24HourFormat: settings.use24hFormat.value`.
- نشيل الـ`MediaQuery.copyWith(alwaysUse24HourFormat: use24h)` المكرّرة حوالين كل `showTimePicker` في `group_details_page.dart` و`groups_page.dart` (بقت زيادة).

**السبب**: منتقي الوقت الأصلي بيقرا `MediaQuery.alwaysUse24HourFormat`؛ ضبطه مرة واحدة على الجذر أنضف من التكرار، والـ`Obx` الخارجي في `main.dart` بيعيد بناء `MediaQuery` صح عند التبديل.

**البدائل المرفوضة**: إبقاء الـcopyWith المحلية — تكرار وسهل ينساه في منتقي جديد.

### قرار 5: نطاق الاستبدال

**القرار**: نستبدل نقاط العرض المرئية + مواعيد الحصص + محتوى الإشعارات ذات الوقت المطلق فقط. تقارير واتساب النصية وملفات PDF والنسخ الاحتياطي وسجلّ الدفع المخزَّن **تفضل** `DateFormat('HH:mm')` ثابتة.

**السبب**: FR-011 + الـAssumptions — دي مخرجات لأطراف تانية أو أسماء ملفات، تغييرها ممكن يلخبط أو يكسر توقّعات.

## المخاطر

- **الأداء**: `Obx` إضافية لكل نقطة وقت — التبديل نادر و`Obx` رخيصة؛ الأثر مهمَل.
- **نسيان نقطة عرض**: التخفيف = الجرد أعلاه + مهمة تحقّق نهائية (grep على `FormatHelper.formatTime|formatDateTime|formatPaymentDate` وعلى `showingTooltip`… لا، على `use24hFormat`).
- **إعادة جدولة الإشعارات**: `syncAllScheduledNotifications` بتلغي وتعيد الكل — آمنة، بتتنفّذ بالفعل في سياقات كتير.
