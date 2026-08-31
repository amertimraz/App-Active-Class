---
description: "Task list — تطبيق إعداد نظام الساعة (24 / 12) فورًا في كل التطبيق"
---

# Tasks: تطبيق إعداد نظام الساعة (24 / 12) فورًا في كل التطبيق

**Input**: Design documents from `/specs/009-clock-format-setting/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: اختبار وحدة واحد فقط (اختياري لكن مُفضَّل) لـ`FormatHelper.formatClock` — دالة نقية. باقي التحقّق يدوي عبر quickstart.md (اتساقًا مع المشروع).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ينفع بالتوازي (ملفات مختلفة، لا تبعية)
- **[Story]**: US1 / US2 / US3

---

## Phase 1: Setup

**Purpose**: لا تهيئة جديدة — المشروع قائم. تأكيد نقطة الانطلاق فقط.

- [X] T001 تأكيد أن `flutter analyze lib` نضيف قبل البدء (نقطة مرجعية) وأن `SettingsController.use24hFormat` (`RxBool`) موجود في `lib/controllers/settings_controller.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: البنية الموحّدة اللي كل القصص بتعتمد عليها.

**⚠️ CRITICAL**: مفيش أي شغل قصة يبدأ قبل ما الطور ده يخلص.

- [X] T002 أضف `static String formatClock(TimeOfDay t)` في `class FormatHelper` داخل `lib/utils/helpers.dart` — يقرا `use24hFormat` بنفس نمط `try/catch` الموجود؛ 24 ساعة → `HH:mm` (صفر بادئ)؛ 12 ساعة → `DateFormat('h:mm a', 'ar').format(DateTime(2000, 1, 1, t.hour, t.minute))` (بيتعامل صح مع 00:00→`12:00 ص` و12:00→`12:00 م`)
- [X] T003 أنشئ `lib/widgets/clock_text.dart` فيه:
      `ClockText(DateTime? value, {TextStyle? style, TextAlign? textAlign, String? fallback})`،
      `ClockDateTimeText(...)`، `ClockPaymentDateText(...)` — كل واحدة `Obx(() { Get.find<SettingsController>().use24hFormat.value; return Text(FormatHelper.formatTime|formatDateTime|formatPaymentDate(value), style: style, textAlign: textAlign); })`؛
      و`ClockBuilder({required Widget Function(BuildContext context) builder})` → `Obx(() { Get.find<SettingsController>().use24hFormat.value; return builder(context); })`
- [X] T004 [P] أنشئ `test/format_clock_test.dart` — يغطّي `FormatHelper.formatClock` لـ 24 و12 ساعة وحواف `00:15` (`12:15 ص`) و`12:15` (`12:15 م`) و`13:00` (`1:00 م`). (يتطلب `initializeDateFormatting('ar')` في `setUpAll`.)

**Checkpoint**: الودجت الموحّدة + `formatClock` جاهزين — القصص تقدر تبدأ.

---

## Phase 3: User Story 1 — تطبيق فوري على الشاشة المفتوحة (Priority: P1) 🎯 MVP

**Goal**: تغيير المفتاح من الإعدادات ينعكس فورًا على الشاشات الأساسية اللي المدرس بيستخدمها أكتر، من غير إعادة تشغيل، وبما فيها التبويبات المخبّأة.

**Independent Test**: افتح تفاصيل طالب → المدفوعات، غيّر المفتاح من الإعدادات، ارجع — الوقت اتحوّل (`14:30` ↔ `2:30 م`). بدّل تبويبات — كلها اتحوّلت.

- [X] T005 [US1] في `lib/views/students/student_details_page.dart`: استبدل `Text(FormatHelper.formatPaymentDate(p.date))` (سطر ~1490، `title:` في صف الدفعة) بـ`ClockPaymentDateText(p.date)`، واحذف سطر الحيلة `Get.find<SettingsController>().use24hFormat.value;` (سطر ~1343) لو بقى بلا لزوم بعد الاستبدال. تأكد أن `formatFullDate` (تبويبات الحضور/الواجب) — تاريخ فقط بدون وقت — مش محتاج تغيير.
- [X] T006 [US1] في `lib/views/attendance/attendance_page.dart`: استبدل `Text(FormatHelper.formatTime(att.date))` (سطر ~2271) بـ`ClockText(att.date, style: ...)`، واحذف سطر الحيلة (سطر ~2206) لو بقى بلا لزوم
- [X] T007 [US1] في `lib/main.dart`: داخل الـ`builder:` الحالي (جوه الـ`Obx` الخارجي اللي بيقرا `themeMode`) لفّ المحتوى في `MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: Get.find<SettingsController>().use24hFormat.value), child: Directionality(...))` — عشان منتقيات الوقت الأصلية تبقى متسقة على مستوى التطبيق
- [ ] T008 [US1] `flutter analyze lib` نضيف؛ تحقّق يدوي: quickstart.md **سيناريو 1**

**Checkpoint**: US1 شغّالة ومُختبَرة بمعزل — MVP جاهز.

---

## Phase 4: User Story 2 — كل نقاط عرض الوقت متسقة (Priority: P1)

**Goal**: صفر شاشة "منسية". كل نقطة عرض وقت في الواجهة + مواعيد الحصص + محتوى الإشعارات ذات الوقت المطلق تتبع الإعداد.

**Independent Test**: بالمفتاح على 12 ساعة، امشي على جدول quickstart.md **سيناريو 2 + 3** — كل نقطة `h:MM ص/م`.

- [X] T009 [P] [US2] `lib/views/schedule/schedule_page.dart`: خلّي `_fmtTime(TimeOfDay)` يرجّع `FormatHelper.formatClock(t)` (شيل الفرع المحلي 24/12)؛ لفّ ودجت عرض أوقات الحصص في `ClockBuilder`؛ احذف سطر الحيلة (سطر ~212)
- [X] T010 [P] [US2] `lib/views/groups/groups_page.dart`: خلّي `_fmt(...)` (سطر ~138 و~1374) يستخدم `FormatHelper.formatClock`؛ لفّ عرض "الحصة القادمة" في `ClockBuilder`؛ احذف سطر الحيلة (سطر ~212) واحذف `MediaQuery.copyWith(alwaysUse24HourFormat: ...)` حوالين `showTimePicker` (سطر ~1392) — بقت زيادة بعد T007
- [X] T011 [P] [US2] `lib/views/groups/group_details_page.dart`: خلّي `_fmt(TimeOfDay)` (سطر ~233) يستخدم `FormatHelper.formatClock`؛ استبدل `'آخر إرسال: ${FormatHelper.formatDateTime(last)}'` (سطر ~2142) بـ`ClockBuilder(builder: (_) => Text('آخر إرسال: ${FormatHelper.formatDateTime(last)}'))`؛ احذف `MediaQuery.copyWith(alwaysUse24HourFormat: ...)` حوالين `showTimePicker` (سطر ~1564)
- [X] T012 [P] [US2] `lib/views/qr_scanner/qr_scanner_attendance_page.dart`: لفّ `'في ${FormatHelper.formatTime(record.date)}'` (سطر ~633) في `ClockBuilder`. (سطر ~834 `DateFormat('HH:mm')` = ملخص مشاركة نصي → **لا تغيير**)
- [X] T013 [P] [US2] `lib/views/bookings/bookings_page.dart`: استبدل `'وصل ${FormatHelper.formatDateTime(request.createdAt)}'` (سطر ~394) بـ`ClockBuilder(builder: (_) => Text('وصل ${FormatHelper.formatDateTime(request.createdAt)}'))`
- [X] T014 [P] [US2] `lib/views/payments/payments_page.dart`: استبدل `Text(FormatHelper.formatPaymentDate(p.date))` (سطر ~573) بـ`ClockPaymentDateText(p.date)`؛ احذف سطر الحيلة (سطر ~547)
- [X] T015 [P] [US2] `lib/views/reports/payments_report_page.dart`: استبدل `Text('${group?.name ...} • ${FormatHelper.formatPaymentDate(p.date)}')` (سطر ~452) بـ`ClockBuilder(builder: (_) => Text('${group?.name ...} • ${FormatHelper.formatPaymentDate(p.date)}'))`؛ احذف سطر الحيلة (سطر ~354)
- [X] T016 [US2] `lib/services/notification_service.dart`: خلّي `_fmt(TimeOfDay t)` (سطر ~438) يرجّع `FormatHelper.formatClock(t)` — يؤثّر على نص "🔔 حصة ... — الحصة الساعة {t}" (سطر ~345) و"📅 حصص اليوم" (سطر ~367)
- [X] T017 [US2] `lib/controllers/settings_controller.dart`: في `setUse24hFormat(bool v)` بعد `_dbSet(...)` أضف `unawaited(NotificationService().syncAllScheduledNotifications());` (import `dart:async` + `notification_service.dart` لو مش موجودين) — عشان الإشعارات المجدولة تتعاد جدولتها بالصيغة الجديدة
- [ ] T018 [US2] `flutter analyze lib` نضيف؛ تحقّق يدوي: quickstart.md **سيناريو 2 + 3 + 5**

**Checkpoint**: US1 + US2 شغّالين — كل نقاط العرض مغطّاة.

---

## Phase 5: User Story 3 — الثبات بعد إعادة التشغيل (Priority: P2)

**Goal**: تأكيد عدم انحدار — الاختيار محفوظ ويُطبَّق تلقائيًا عند الإقلاع.

**Independent Test**: غيّر المفتاح، اقفل التطبيق بالكامل، افتحه — المفتاح محفوظ وكل الأوقات بالنظام المختار.

- [ ] T019 [US3] تحقّق يدوي: quickstart.md **سيناريو 4** — لا حاجة لتغيير كود (منطق `_loadUse24hFormat` / `_dbSet` غير متأثّر)؛ لو فشل، افحص أن T017 ما كسرش تسلسل الحفظ (الحفظ لازم يحصل قبل `syncAllScheduledNotifications`)

**Checkpoint**: الثلاث قصص متحقّقة.

---

## Phase 6: Polish & Cross-Cutting

- [X] T020 [P] فحص نهائي: `rg "use24hFormat\.value;" lib/views` — لازم **لا نتائج** (SC-003). أي بقايا تتحوّل لـ`ClockText`/`ClockBuilder`
- [X] T021 [P] فحص نهائي: `rg "FormatHelper.format(Time|DateTime|PaymentDate)\(" lib/views` — كل نتيجة لازم تكون جوه `ClockText*`/`ClockBuilder` أو مستثناة صراحةً (ملخص مشاركة/تقرير نصي) مع تعليق
- [ ] T022 جرد يدوي أخير لكل شاشات التطبيق اللي بتعرض وقت (شاشة الأرشيف، لوحة التحكم، تفاصيل المجموعة، …) — تأكيد استجابة كل واحدة للتبديل (SC-002)
- [ ] T023 `flutter build apk --debug --flavor direct` ثم `adb install -r build/app/outputs/flutter-apk/app-direct-debug.apk`؛ نفّذ quickstart.md بالكامل على الجهاز
- [X] T024 حدّث `HANDOFF.md` بحالة الميزة (اتعملت / اتأكدت لايف / commit)

---

## Dependencies & Execution Order

- **Phase 1 (Setup)**: فورًا
- **Phase 2 (Foundational)**: يعتمد على Phase 1 — **يبلوك كل القصص**. T002 و T003 قبل أي استبدال. T004 [P] مع T002/T003
- **Phase 3 (US1)**: يعتمد على Phase 2
- **Phase 4 (US2)**: يعتمد على Phase 2 (مش على US1). T009–T015 كلها [P] (ملفات مختلفة). T016 قبل/مع T017. T018 بعد T009–T017
- **Phase 5 (US3)**: يعتمد على Phase 4 (بسبب T017)
- **Phase 6 (Polish)**: بعد كل القصص المطلوبة

### Within Each User Story

- Foundational (T002, T003) قبل أي استبدال call-site
- في US2: `notification_service._fmt` (T016) قبل ربط إعادة الجدولة (T017)

### Parallel Opportunities

- T004 [P] مع T002/T003
- داخل US2: T009, T010, T011, T012, T013, T014, T015 كلها بالتوازي (ملفات مختلفة، لا تبعية) — بعد كده T016 → T017 → T018

---

## Parallel Example: User Story 2

```text
# بعد ما Phase 2 تخلص، شغّل بالتوازي:
Task: "schedule_page.dart — _fmtTime → formatClock + ClockBuilder + شيل حيلة"
Task: "groups_page.dart — _fmt → formatClock + ClockBuilder + شيل حيلة + شيل copyWith"
Task: "group_details_page.dart — _fmt → formatClock + ClockBuilder(آخر إرسال) + شيل copyWith"
Task: "qr_scanner_attendance_page.dart — ClockBuilder حوالين 'في {time}'"
Task: "bookings_page.dart — ClockDateTimeText/ClockBuilder حوالين 'وصل {time}'"
Task: "payments_page.dart — ClockPaymentDateText + شيل حيلة"
Task: "payments_report_page.dart — ClockBuilder + شيل حيلة"
# ثم بالتسلسل:
Task: "notification_service.dart — _fmt → formatClock"
Task: "settings_controller.dart — setUse24hFormat → syncAllScheduledNotifications"
```

---

## Implementation Strategy

### MVP (US1 فقط)

1. Phase 1 → Phase 2 (Foundational — يبلوك الكل)
2. Phase 3 (US1)
3. **قف وتحقّق**: quickstart سيناريو 1 على الجهاز
4. لو تمام → الباقي تحسين تغطية

### Incremental

1. Foundational → الأساس جاهز
2. US1 → تحقّق → MVP (الشاشات الأساسية بتتحوّل فورًا)
3. US2 → تحقّق → كل نقاط العرض + الإشعارات
4. US3 → تحقّق عدم الانحدار
5. Polish → فحص grep + جرد + build + HANDOFF

---

## Notes

- [P] = ملفات مختلفة، لا تبعية
- التقارير النصية (واتساب/المشاركة) وملفات PDF/النسخ الاحتياطي وسجلّ الدفع المخزَّن (`qr_controller.dart:247`) **خارج النطاق** — تفضل `DateFormat('HH:mm')` ثابتة (FR-011)
- commit بعد كل قصة (أو مجموعة منطقية)
- أرقام الأسطر تقريبية — أكّدها بالـgrep وقت التنفيذ
