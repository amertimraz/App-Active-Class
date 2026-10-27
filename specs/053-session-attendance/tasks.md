# Tasks: الحضور بالحصة

**Input**: `specs/053-session-attendance/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)

**Tests**: اختبارات وحدة للنواة الصرفة + widget smoke للصفحة الجديدة + تحقق يدوي. بلا schema / migration / تغيير مزامنة.

**القاعدة**: كل مرحلة تنتهي بـ`flutter analyze` نضيف (بلا errors/warnings جديدة) و`flutter test` أخضر والتطبيق شغّال. ما نكسرش "غياب اليوم" ولا ورقة التسجيل الحالية.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 سجّل خط الأساس: `flutter analyze` (عدد الـinfo) و`flutter test` (425 ناجح) كمرجع قبل أي تعديل.

---

## Phase 2: Foundational — النواة الصرفة (تمنع كل القصص)

- [X] T002 [P] `lib/utils/absence_message.dart`: استخرج `buildAbsenceMessage` و`buildLateMessage` من `_AbsentTodayTabState._buildMessage/_buildLateMessage` في `lib/views/attendance/attendance_page.dart` كدوال صرفة بمعامل `date` (نفس النص حرفيًا: ⚠️ *تنبيه غياب/تأخير* + 👤 الاسم (الكود) + 👥 المجموعة + 📅 yyyy-MM-dd + 👨‍🏫 المعلم + 📘 التخصص، والسطرين الأخيرين اختياريين).
- [X] T003 [P] `test/absence_message_test.dart`: النص الكامل، بدون معلم/تخصص، تاريخ الحصة (مش اليوم)، تراجعي: نفس ناتج الدالة القديمة لتاريخ النهاردة.
- [X] T004 `lib/views/attendance/attendance_page.dart`: خلّي `_AbsentTodayTabState` يستخدم `absence_message.dart` (تاريخ `DateTime.now()`) وشيل الدالتين القديمتين. لا تغيير سلوكي.
- [X] T005 [P] `lib/utils/session_attendance.dart`: `SessionFilter`، `SessionRow`، `SessionSummary`، `buildSessionRows({students, records, day})` (استبعاد المؤرشف إلا لو له سجل اليوم، واستبعاد `attendanceStart > day`، ربط بسجل اليوم عبر Map، ترتيب بالاسم)، `summarize(rows)`، `filterRows(rows, filter, query)` (بحث بالاسم/الكود بتطبيع `arabic_normalize.dart`).
- [X] T006 [P] `test/session_attendance_test.dart`: الملخص يجمع للإجمالي، "لم يُسجَّل" ≠ غائب، المتأخر ضمن الحاضرين في `attended`، مؤرشف بدون سجل يُستبعد ومع سجل يظهر، `attendanceStart` بعد التاريخ يُستبعد، التصفية والبحث، مجموعة فاضية، 200 طالب.
- [X] T007 [P] `lib/utils/schedule_week.dart`: `weekStartSaturday`، `dateForDayIndex(anchor, weekOffset, dayIndex)` (السبت=0)، `weekOffsetFor(anchor, target)`، `dayIndexOf(date)`.
- [X] T008 [P] `test/schedule_week_test.dart`: حدود الأسبوع (السبت/الجمعة)، إزاحة موجبة/سالبة، عبور الشهر والسنة، تغيّر التوقيت الصيفي لا يكسر اليوم، `weekOffsetFor` عكس `dateForDayIndex`.
- [X] T009 **CHECKPOINT**: `flutter analyze` + T003/T006/T008 + كل الاختبارات القائمة (خصوصًا اختبارات الحضور).

---

## Phase 3: US1 — تفاصيل الحصة بملخصها (P1) 🎯 MVP

**اختبار مستقل**: من تبويب الحضور، زرار "تفاصيل الحصة" على كارت مجموعة يفتح الشاشة الجديدة بملخص مطابق للسجلات.

- [X] T010 [US1] `lib/views/attendance/session_detail_page.dart`: `SessionDetailPage({group, day})` — AppBar (اسم المجموعة + تاريخ + موعد `sessionTimeForGroupOnDay`)، كارت ملخص (حاضر/متأخر/غائب/لم يُسجَّل/الإجمالي) من `summarize`، قايمة طلاب `ListView.builder` للقراءة (اسم + كود + شارة حالة). يبني Map سجلات اليوم من `AttendanceController.attendance` داخل `Obx`. حالة فاضية "مفيش طلاب". يوم مستقبلي: رسالة "لسه ما بدأتش" بدل الملخص وللقراءة فقط.
- [X] T011 [US1] `lib/views/attendance/attendance_page.dart`: زرار صغير "تفاصيل الحصة" على `_GroupSummaryCard` يفتح `SessionDetailPage(group, selectedDay)`؛ الضغط على الكارت نفسه يفضل يفتح `showAttendanceSheet`.
- [X] T012 [P] [US1] `test/session_detail_page_test.dart` (widget smoke بأسلوب المشروع: GetX + controllers مسجّلة بدون DB): الصفحة تعرض أرقام الملخص الصحيحة، حالة فاضية، يوم مستقبلي.
- [X] T013 **CHECKPOINT**: analyze + اختبارات + تجربة يدوية سيناريو 1 و6 في quickstart.

---

## Phase 4: US2 — الغايبون في خانة لوحدهم + واتساب (P1)

**اختبار مستقل**: حصة فيها 3 غايبين → تبويب "غائب" يعرض 3 فقط ويبعتلهم.

- [X] T014 [US2] `session_detail_page.dart`: شريط تبويبات/Chips (الكل/حاضر/متأخر/غائب/لم يُسجَّل) بعدّاد، وحقل بحث بالاسم/الكود، مرتبطين بـ`filterRows`؛ التبويب الافتراضي "الكل" مع تمييز "غائب" بصريًا.
- [X] T015 [US2] `session_detail_page.dart`: في تبويب "غائب" — تحديد (checkbox لكل صف + تحديد الكل) وزرار "إرسال واتساب للغايبين المحددين (N)"؛ يستخدم نفس نمط `_sendToSelected` (حوار تأكيد/تخطي/إلغاء الكل لكل ولي أمر، تخطّي من بلا رقم وإظهار عدّادهم بعد الإرسال) عبر `launchGuardianWhatsapp` و`buildAbsenceMessage(date: تاريخ الحصة)` بمعلم/تخصص من `SettingsController`.
- [X] T016 [P] [US2] `test/session_detail_page_test.dart`: تبويب "غائب" يعرض الغايبين فقط، التحديد يغيّر العدّاد، التصفية بالبحث.
- [X] T017 **CHECKPOINT**: analyze + اختبارات + سيناريو 2.

---

## Phase 5: US3 — جدول الحصص بتنقّل التاريخ (P1)

**اختبار مستقل**: الرجوع أسبوع/شهر في جدول الحصص وفتح حصة قديمة بحضورها.

- [X] T018 [US3] `lib/views/schedule/schedule_page.dart`: أضف `_weekOffset` (0 = الأسبوع الحالي) وشريط تنقّل (أسبوع قبل/بعد، شهر قبل/بعد، اختيار تاريخ بـ`showDatePicker`، زرار "اليوم")؛ التاريخ المختار = `dateForDayIndex(DateTime.now(), _weekOffset, _selectedDay)`؛ رؤوس الأيام تعرض رقم اليوم/الشهر؛ اختيار تاريخ يضبط `_weekOffset` و`_selectedDay`.
- [X] T019 [US3] `schedule_page.dart`: `_slotsForDay` بتاريخ: حصص اليوم الأسبوعي مفلترة بـ`groupHasSessionOnDay(group, date)` (تستبعد الملغاة وتضيف التعويضية/الإضافية من `groupsForDayWithOverrides` بموعدها `sessionTimeForGroupOnDay`)؛ الملغاة تظهر بعلامة "ملغاة". تأكد إن `_isNow/_isPast` تشتغل فقط لتاريخ النهاردة. اطلب `AttendanceController`/`SessionOverrideController` (Get.find آمن) وحمّل الاستثناءات.
- [X] T020 [US3] `schedule_page.dart`: الضغط على كارت الحصة يفتح `SessionDetailPage(group, date)`؛ الضغط المطوّل (أو أيقونة صغيرة) يفتح تفاصيل المجموعة (`ROUTE_GROUP_DETAILS`) زي زمان. تاريخ بدون حصص → "مفيش حصص في اليوم ده".
- [X] T021 **CHECKPOINT**: analyze + اختبارات + سيناريو 3 (شهر فات، أسبوع جاي، عبور الشهر).

---

## Phase 6: US4 — تسجيل/تعديل الحضور من الشاشة (P2)

**اختبار مستقل**: طالب "لم يُسجَّل" → غائب ينتقل لتبويب "غائب" فورًا.

- [X] T022 [US4] `session_detail_page.dart`: صف الطالب فيه segmented مضغوط (حاضر/متأخر/غائب) يستدعي `AttendanceController.setAttendanceStatus(studentId, day, status)` (الضغط على المختار يلغي السجل → "لم يُسجَّل")؛ التحديث محلي فوري، بدون `loadAttendance` كامل. الأخطاء بـ`ToastHelper.error`.
- [X] T023 [US4] `session_detail_page.dart`: زرار "تحضير غير المسجَّلين (N)" يستدعي `markGroupAllPresent` على IDs غير المسجَّلين فقط (ما يلمسش اللي اتسجل)، بتأكيد، وزرار "ورقة التسجيل الكاملة" يفتح `showAttendanceSheet` (واجب/تسميع/تفاعل/تقرير).
- [X] T024 [P] [US4] `test/session_detail_page_test.dart`: الضغط على "غائب" لطالب غير مسجَّل ينقله للتبويب ويحدّث العدّادات؛ الضغط على المختار يعيده لـ"لم يُسجَّل".
- [X] T025 **CHECKPOINT**: analyze + اختبارات + سيناريو 4 (حصة قديمة تتحفظ بتاريخها).

---

## Phase 7: US5 — الحصص الملغاة والتعويضية (P2)

**اختبار مستقل**: حصة ملغاة بعلامة وبلا تسجيل؛ التعويضية في يومها.

- [X] T026 [US5] `session_detail_page.dart`: لو `sessionOverrideFor(group, day)?.type == cancelled` اعرض شارة "ملغاة" وعطّل التسجيل والملخص ("الحصة دي ملغاة")؛ التعويضية/الإضافية تظهر بشارة نوعها وموعدها الخاص.
- [X] T027 [P] [US5] `test/session_detail_page_test.dart`: حصة ملغاة بلا ملخص/تسجيل، تعويضية بشارة.
- [X] T028 **CHECKPOINT**: analyze + اختبارات + سيناريو 5.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T029 [P] أداء: اختبار/قياس مجموعة 200 طالب (فتح < ثانيتين، تبديل التبويبات بلا تقطيع) — سيناريو 7؛ لو بطيء اعمل Map ثابت للصفوف بدل إعادة البناء مع كل ضغطة.
- [X] T030 [P] مراجعة صلاحيات الفريق: الشاشة بلا مبالغ، وتشتغل بحساب مساعد — سيناريو 8.
- [X] T031 [P] تحديث `HANDOFF.md` وملف الذاكرة `spec-053-session-attendance.md` + سطر في `MEMORY.md`.
- [ ] T032 تحقق نهائي: `flutter analyze` + `flutter test` كاملين + quickstart يدوي على الموبايل؛ علّم الـspec "Implemented (device test pending)".

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 (T002/T005/T007 متوازيين؛ T004 بعد T002) → باقي المراحل.
- US1 (T010) ينتظر T005. US2 ينتظر US1 + T002. US3 ينتظر T007 + T010. US4 ينتظر US1. US5 ينتظر US1 + US3 (جزء الجدول).
- ترتيب التسليم المقترح: US1 → US2 (حل ألم الغياب مباشرة) → US3 → US4 → US5.

## Parallel Examples

- T002 / T005 / T007 (ملفات مختلفة) مع اختباراتهم T003 / T006 / T008.
- T012 / T016 / T024 / T027 كلها في ملف اختبار واحد → تتنفّذ بالتتابع داخليًا لكن بعد كل مرحلة لوحدها.

## Implementation Strategy

- **MVP = Phase 2 + US1 + US2**: شاشة تفاصيل الحصة من تبويب الحضور بملخص وتبويب غايبين وواتساب (الألم الأساسي). ممكن تتسلّم وتتجرّب قبل جدول الحصص.
- بعدها US3 (التنقّل بالتاريخ في الجدول)، ثم US4/US5 تحسينات.
