---
description: "Task list — حالة حضور متأخر (011-late-attendance)"
---

# Tasks: حالة حضور "متأخر"

**Input**: Design documents from `specs/011-late-attendance/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: لا توجد بنية اختبار آلي في المشروع — التحقّق يدوي عبر [quickstart.md](quickstart.md). لا مهام اختبار.

**Organization**: المهام مجمّعة حسب user story. مصدر الحقيقة الوحيد `lib/models/attendance_model.dart`
(نفس نمط `homework_model.dart` من spec 010).

## Path Conventions

Mobile single-project: كل الكود تحت `lib/`. الواجهة العامة تحت `booking_site/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: الثوابت وترقيم نسخة القاعدة

- [X] T001 في `lib/config/constants.dart`: أضف `const String ATTENDANCE_LATE = 'متأخر';` جنب `ATTENDANCE_PRESENT`/`ATTENDANCE_ABSENT`، وارفع `DATABASE_VERSION` من `20` إلى `21`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: طبقة التطبيع + الـmigration + الإعدادات + توسيع `setAttendanceStatus` — كله يسبق أي user story

**⚠️ CRITICAL**: مفيش شغل user story يبدأ قبل اكتمال المرحلة دي

- [X] T002 [P] أنشئ `lib/models/attendance_model.dart` بدوال top-level نقية (نمط `homework_model.dart`): `normalizeAttendanceStatus(String? raw) -> String?` (trim، فارغ→null، يطابق حاضر/غائب/متأخر → القيمة القياسية، غير كده→null)؛ `attendanceCountsAsPresent(String? s) -> bool` (`== ATTENDANCE_PRESENT || == ATTENDANCE_LATE` بعد التطبيع)؛ `attendanceStatusLabel(String? raw) -> String` (`'✅ حاضر'`/`'⏰ متأخر'`/`'❌ غائب'`/`'لم يُسجَّل'`)؛ `attendanceStatusColor(String? raw) -> Color` (`0xFF10B981`/`0xFFF59E0B`/`0xFFEF4444`/رمادي).
- [X] T003 في `lib/services/database_service.dart` `_onCreate` (سطر ~121): وسّع قيد `CHECK($COL_ATTENDANCE_STATUS IN ('$ATTENDANCE_PRESENT', '$ATTENDANCE_ABSENT', '$ATTENDANCE_LATE'))` (للتثبيتات الجديدة).
- [X] T004 في `lib/services/database_service.dart` `_onUpgrade`: أضف `if (oldVersion < 21) { try { ... } catch (_) {} }` — إعادة بناء جدول `attendance`: `CREATE TABLE attendance_new (...نفس الأعمدة... CHECK IN ('حاضر','غائب','متأخر'))` ثم `INSERT INTO attendance_new SELECT ... FROM attendance` ثم `DROP TABLE attendance` ثم `ALTER TABLE attendance_new RENAME TO attendance` ثم إعادة إنشاء `_attendanceDayUniqueIndexSql`. **`db.execute` مباشرة — ممنوع `db.transaction` متداخلة** (onUpgrade أصلاً transactional — نفس درس spec 010).
- [X] T005 في `lib/controllers/attendance_controller.dart` `setAttendanceStatus` (سطر ~220): غيّر التوقيع لـ`Future<void> setAttendanceStatus(int studentId, DateTime day, String? status)` — لو `status == null` → احذف السجل لليوم (نمط `clearHomework`)؛ غير كده upsert بالحالة. حافظ على rethrow + دفع بوابة أولياء الأمور.
- [X] T006 [P] في `lib/controllers/settings_controller.dart`: أضف `_keyLateGraceMinutes = 'late_grace_minutes'` + `RxInt lateGraceMinutes = 15.obs` + `_loadLateGraceMinutes()` (`_migrateInt(...) ?? 15`، أضفها لـ`Future.wait` في `loadSettings`) + `setLateGraceMinutes(int)` مع `clamp(0,120)` + `_dbSet`. وأضف `_keyQrAutoLateEnabled = 'qr_auto_late_enabled'` + `RxBool qrAutoLateEnabled = true.obs` + `_loadQrAutoLate()` (افتراضي `true` عند غياب المفتاح) + `setQrAutoLateEnabled(bool)` + `_dbSet`.

**Checkpoint**: التخزين + التطبيع + الإعدادات جاهزة — يبدأ شغل الـuser stories

---

## Phase 3: User Story 1 - تسجيل "متأخر" (Priority: P1) 🎯 MVP

**Goal**: المدرس يسجّل حاضر/متأخر/غائب بـsegmented ثلاثي؛ الزر الجماعي يتخطّى المتأخر؛ QR يحسب متأخر تلقائيًا (مع مفتاح ومهلة).

**Independent Test**: quickstart سيناريوهات 2، 3، 4.

- [X] T007 [US1] في `lib/views/attendance/attendance_page.dart`: استبدل جسم `_StudentAttendanceChip` (التبديل الدوّار) بـsegmented ثلاثي متصل — نفس نمط `_HomeworkStatusSegmented` (Container border+clip، Row من Expanded segments مفصولة بـ`Container(width:1)`، كل segment `GestureDetector(behavior: opaque)`): حاضر (`Icons.check_rounded`, `0xFF10B981`) / متأخر (`Icons.schedule_rounded`, `0xFFF59E0B`) / غائب (`Icons.close_rounded`, `0xFFEF4444`). `onSelect(status)` → `controller.setAttendanceStatus(id, day, status)`؛ الضغط على المختار → `onSelect(null)` (حذف). المختار = تعبئة لون صريحة + أيقونة/نص أبيض.
- [X] T008 [US1] في `lib/views/attendance/attendance_page.dart`: حدّث المستدعي لـ`_StudentAttendanceChip` — مرّر الحالة الحالية المطبَّعة (`normalizeAttendanceStatus`) وcallback الاختيار؛ احذف أي منطق دوّار قديم (`toggleAttendance` من مسار تبويب الحضور). تأكّد إن `Obx` الأب لسه بيقرأ observable (زي إصلاح spec 010 — مفيش `Obx` فاضي حوالين الصف).
- [X] T009 [US1] في `lib/controllers/attendance_controller.dart` `markGroupAllPresent` (سطر ~251): سجّل `ATTENDANCE_PRESENT` فقط للطلاب غير المسجّلين أو المسجّلين `ATTENDANCE_ABSENT`؛ **تخطَّ** المسجّلين `ATTENDANCE_LATE` (ما تكتبش فوقهم). اترك شرط "الكل حاضر بالفعل → امسح" مربوطًا بـ`== ATTENDANCE_PRESENT` فقط.
- [X] T010 [US1] في `lib/controllers/attendance_controller.dart`: استخرج helper `TimeOfDay? sessionStartTimeForGroupOnDay(Group group, DateTime day)` من منطق التحليل الموجود في `remainingSessionTime` (سطر ~582–596) لإعادة استخدامه بدون تكرار.
- [X] T011 [US1] في `lib/controllers/qr_controller.dart` `_recordAttendance` (سطر ~81–98): قبل التسجيل، لو `Get.find<SettingsController>().qrAutoLateEnabled.value` — احسب: `start = attendanceCtrl.sessionStartTimeForGroupOnDay(group, now)`؛ لو `start != null` و`now.isAfter(startDateTime.add(Duration(minutes: settings.lateGraceMinutes.value)))` → `status = ATTENDANCE_LATE`؛ غير كده `ATTENDANCE_PRESENT`. مرّر `status` المحسوب بدل `ATTENDANCE_PRESENT` الثابت.
- [X] T012 [P] [US1] في `lib/controllers/qr_controller.dart` (سطور ~534، ~585): غيّر `a.status == ATTENDANCE_PRESENT` في عدّادات الحصص للمجموعات "بالحصة" إلى `attendanceCountsAsPresent(a.status)` (FR-013).
- [X] T013 [P] [US1] في `lib/views/attendance/qr_scanner_attendance_page.dart`: لو فيه رسالة/توست تأكيد تسجيل، اجعلها تعكس الحالة الفعلية المسجّلة ("سُجّل متأخر" مقابل "سُجّل حاضر") عبر `attendanceStatusLabel`.
- [X] T014 [US1] في `lib/views/settings/settings_page.dart`: أضف في قسم الإعدادات المناسب — حقل رقمي "مهلة التأخير (دقائق)" مربوط بـ`lateGraceMinutes`/`setLateGraceMinutes` (نمط `payment_grace_days`)، ومفتاح `SwitchListTile` "تسجيل المتأخر تلقائيًا عبر QR" مربوط بـ`qrAutoLateEnabled`/`setQrAutoLateEnabled`، مع نص شرح مختصر.

**Checkpoint**: US1 كامل — التسجيل بالـsegmented + QR auto-late + الإعدادات شغّالين

---

## Phase 4: User Story 2 - "متأخر" في النسبة والإحصائيات (Priority: P1)

**Goal**: المتأخر يُحتسب حضورًا في كل النسب والفوترة، ويظهر كفئة منفصلة في الملخّص/الإحصائيات/الداشبورد.

**Independent Test**: quickstart سيناريو 5 (10 طلاب: 6+2+2 → 80% + عدّاد متأخر).

- [X] T015 [US2] في `lib/utils/pricing_helper.dart` `sessionsAttended`: غيّر `a.status == ATTENDANCE_PRESENT` إلى `attendanceCountsAsPresent(a.status)` — **حرج للفوترة** (متأخر = حصة كاملة).
- [X] T016 [P] [US2] في `lib/controllers/attendance_controller.dart`: راجع `getStudentMonthAttendance` وأي حساب نسبة/عدّ حاضرين — حوّل "معناه حضر" إلى `attendanceCountsAsPresent`؛ أضف عدّ منفصل للمتأخرين حيث يلزم.
- [X] T017 [P] [US2] في `lib/controllers/dashboard_controller.dart`: حوّل عدّ الحاضرين إلى `attendanceCountsAsPresent`؛ أضف فئة/عدّاد "متأخر" منفصل في إحصائيات الداشبورد.
- [X] T018 [P] [US2] في `lib/controllers/report_controller.dart`: أضف `lateByStudent` (تجميعة زي `presentByStudent`)؛ اطوِ المتأخر داخل نسبة الحضور (`present + late`)؛ خلِّ العدّاد متاحًا للتقرير الشهري و PDF.
- [X] T019 [P] [US2] في `lib/helpers/student_sort_helper.dart` (أو مسار `lib/utils/`): الفرز بنسبة الحضور يستخدم `attendanceCountsAsPresent`.
- [X] T020 [P] [US2] في `lib/views/groups/group_details_page.dart`: نسبة الحضور في بطاقات المجموعات تستخدم `attendanceCountsAsPresent`.
- [X] T021 [US2] في `lib/views/attendance/attendance_page.dart`: ملخّص موديل المجموعة يعرض 3 عدّادات ("حاضر X · متأخر Y · غائب Z") بدل "حاضر/إجمالي"؛ النسبة = `(حاضر+متأخر)/إجمالي`.
- [X] T022 [P] [US2] في تبويب الإحصائيات (`attendance_page.dart` أو ملف الإحصائيات المرتبط): أضف "متأخر" كفئة ظاهرة منفصلة.

**Checkpoint**: US2 كامل — كل النسب والفوترة صحيحة والمتأخر ظاهر كرقم منفصل

---

## Phase 5: User Story 3 - "متأخر" في تبويب "غياب اليوم" (Priority: P2)

**Goal**: المتأخر مايظهرش في قائمة الغياب، بل في قسم "متأخرين" منفصل تحته.

**Independent Test**: quickstart سيناريو 6.

- [X] T023 [US3] في `lib/views/attendance/attendance_page.dart` (تبويب "غياب اليوم" / `_AbsentTodayTab` أو ما يعادله): فلترة قائمة الغياب على `normalizeAttendanceStatus(status) == ATTENDANCE_ABSENT` (المتأخر يخرج تلقائيًا)؛ أضف تحتها `Divider` + قسم "متأخرين" يعرض الطلاب `== ATTENDANCE_LATE` بنفس نمط الصفوف؛ القسم يختفي/يهدأ لو مفيش متأخرين.
- [X] T024 [P] [US3] في `lib/controllers/attendance_controller.dart` (تقرير الغياب النصي، إن وُجد): تأكّد إن المتأخر مش مُدرَج كغايب.

**Checkpoint**: US3 كامل

---

## Phase 6: User Story 4 - "متأخر" في التقارير والبوابة (Priority: P1)

**Goal**: كل رسائل الواتساب + البوابة + PDF تعرض "متأخر" كحالة صريحة مميّزة.

**Independent Test**: quickstart سيناريوهات 7، 8.

- [X] T025 [US4] في `lib/controllers/attendance_controller.dart` `buildGuardianReportMessage`: استخدم `attendanceStatusLabel(attendanceStatus)` لعرض حالة الحضور (يشمل "⏰ متأخر") بدل التحقّق الثنائي حاضر/غائب.
- [X] T026 [P] [US4] في `lib/views/students/student_details_page.dart`: تبويب الحضور — يعرض "متأخر" في يومها بلون/رمز مميّز؛ `_shareMonthlyReport` (~سطر 150–186) — أضف عدّاد "أيام تأخير" وسطور الأيام تعرض الحالة الصحيحة عبر `attendanceStatusLabel`؛ النسبة = `(حاضر+متأخر)/إجمالي`.
- [X] T027 [P] [US4] في `lib/views/settings/settings_page.dart` (~سطر 1673–1682، التقرير الشهري): أضف عدّاد المتأخرين + عرض الحالة الثلاثي عبر `attendanceStatusLabel`.
- [X] T028 [P] [US4] في `lib/services/parent_portal_service.dart` (~سطر 193–232): أضف عدّاد `attendanceLate`؛ `attendanceHistory[].status` يمرّ عبر `normalizeAttendanceStatus` + `statusLabel` من `attendanceStatusLabel`؛ عدّ الحاضرين يستخدم `attendanceCountsAsPresent`.
- [X] T029 [P] [US4] في `lib/services/export_service.dart` (~سطر 636–665، تقرير الحضور PDF): خانة اليوم للطالب المتأخر تتميّز بلون/رمز؛ أضف عدّاد "متأخر" منفصل؛ عدّ الحضور يستخدم `attendanceCountsAsPresent`.
- [X] T030 [P] [US4] في `booking_site/track/index.html` (~سطر 304–360): أضف `attLabel()`/`attClass()` JS helpers لثلاث حالات، عدّاد `attendanceLate`، CSS `.att-late` (كهرماني)، وسّع شبكة العدّادات لثلاثة. **ملاحظة: نشر VPS يدوي — مش جزء من البناء.**

**Checkpoint**: US4 كامل — كل مسارات التقارير والبوابة تعرض "متأخر"

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T031 جرد شامل: `rg "== ATTENDANCE_PRESENT|== ATTENDANCE_ABSENT" lib/` — راجع كل موضع؛ كل "معناه حضر" → `attendanceCountsAsPresent`؛ وثّق أي موضع اتُرك عمدًا (المتأخر ≠ غائب).
- [X] T032 `flutter analyze` — صفر أخطاء جديدة.
- [ ] T033 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–10 على جهاز فيه بيانات حضور قديمة (تحقّق migration v20→v21 + توافق تاريخي).
- [ ] T034 ارفع `version` في `pubspec.yaml` (+build number) وابنِ `--split-per-abi` release.

---

## Dependencies & Execution Order

- **Phase 1 (Setup)**: فورًا.
- **Phase 2 (Foundational)**: بعد Phase 1 — **يحجب كل الـuser stories**. T002 و T006 متوازيان؛ T003→T004 تسلسلي (نفس الملف)؛ T005 مستقل.
- **Phase 3 (US1)**: بعد Phase 2. T007→T008 تسلسلي (نفس الملف/الودجت). T009، T010 في `attendance_controller` (T010 قبل T011). T011 بعد T010 + T006. T012، T013، T014 متوازية.
- **Phase 4 (US2)**: بعد Phase 2 (يعتمد على T002). معظمه `[P]` (ملفات مختلفة). T021/T022 في `attendance_page.dart` — تسلسلي مع Phase 3 نفس الملف.
- **Phase 5 (US3)**: بعد Phase 2. T023 في `attendance_page.dart`.
- **Phase 6 (US4)**: بعد Phase 2 (يعتمد على T002). كله `[P]` تقريبًا (ملفات مختلفة).
- **Phase 7 (Polish)**: بعد كل ما سبق.

### ملاحظة تعارض ملفات
`lib/views/attendance/attendance_page.dart` يتعدّل في T007/T008 (US1)، T021/T022 (US2)، T023 (US3) — نفّذها بالترتيب مش بالتوازي.
`lib/controllers/attendance_controller.dart` يتعدّل في T005، T009، T010، T016، T024، T025.

---

## Implementation Strategy

### MVP (US1 + US2)
1. Phase 1 + Phase 2 (Foundational).
2. Phase 3 (US1) → **وقفة وتحقّق** (quickstart 2–4).
3. Phase 4 (US2) → تحقّق (quickstart 5). النسبة والفوترة صح = MVP قابل للإصدار.

### تسليم تدريجي
- + US3 (Phase 5) → تحقّق (quickstart 6).
- + US4 (Phase 6) → تحقّق (quickstart 7–8) + نشر `booking_site` على VPS يدويًا.
- Phase 7: جرد + analyze + بناء.

---

## Notes

- مصدر الحقيقة الوحيد: `lib/models/attendance_model.dart` — كل عرض/عدّ يمر عليه.
- Migration: بلا `db.transaction` متداخلة، guard `< 21` (درس spec 010).
- `booking_site/track/index.html` نشره يدوي على VPS — خارج البناء.
- الطالب "متأخر" له واجب (spec 010) — لا تغيير في شرط `== ATTENDANCE_ABSENT` بتبويب الواجب.
- commit بعد كل مرحلة أو مجموعة منطقية.
