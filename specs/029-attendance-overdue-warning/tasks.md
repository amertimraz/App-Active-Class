---
description: "Task list for feature 029 — تنبيه المتأخر في شاشة الحضور"
---

# Tasks: تنبيه "عليه متأخر في الدفع" في شاشة الحضور — ذكي حسب نوع التسعير

**Input**: Design documents from `/specs/029-attendance-overdue-warning/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة لدالة `PricingHelper.showsAttendanceOverdueWarning` فقط (منطق نقي قابل للعزل). لا اختبارات widget.

**Organization**: مجمّعة حسب user story. MVP = US1 + US2 (القاعدة الذكية) — لكن الاتنين يعتمدوا على نفس الدالة، فـPhase 3 يغطّيهما معًا.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ملفات مختلفة، بلا اعتماد متبادل
- **[Story]**: US1 (شهري) / US2 (per-session) / US3 (مفتاح التحكّم)

## Path Conventions

تطبيق Flutter مفرد: `lib/` و`test/` في جذر المستودع.

---

## Phase 1: Setup (بنية مشتركة)

- [X] T001 أضف `SETTING_ATTENDANCE_OVERDUE_WARNING = 'attendance_overdue_warning'` في `lib/config/constants.dart` بجوار `SETTING_QR_AUTO_LATE_ENABLED`.
- [X] T002 في `lib/controllers/settings_controller.dart`: أضف `final RxBool attendanceOverdueWarning = true.obs;` بجوار `qrAutoLateEnabled`، حمّله في `_loadLateAttendanceSettings` (أو دالة تحميل إعدادات الحضور) عبر `await _migrateBool(SETTING_ATTENDANCE_OVERDUE_WARNING) ?? true`، وأضف `Future<void> setAttendanceOverdueWarning(bool v)` على نمط `setQrAutoLateEnabled`.

**Checkpoint**: الإعداد يُحفظ ويُقرأ (افتراضي true)؛ لا أثر UI.

---

## Phase 2: Foundational (شرط حاجز لكل القصص)

**⚠️ CRITICAL**: القصص الثلاث تعتمد على الدالة والودجت.

- [X] T003 [P] في `lib/utils/pricing_helper.dart`: أضف `static int sessionsAttendedOn({required Student student, required DateTime day, required List<Attendance> allAttendance})` — عدد سجلّات الطالب في نفس اليوم اللي `attendanceCountsAsPresent(a.status)`. أضف `static bool showsAttendanceOverdueWarning({required Student student, required Group? group, required List<Attendance> allAttendance, required List<Payment> payments, required int graceDays, List<Student>? siblingGroupMembers})` وفق المنطق في [contracts/pricing-helper-overdue-warning.md](./contracts/pricing-helper-overdue-warning.md): `isFullyExempt`→false؛ شهري/بلا مجموعة → `isOverdue(...)`؛ per-session → `debt = accumulatedDebt(...)`، لو `debt <= 0.01` false، وإلا `(debt - sessionsAttendedOn(today) * student.effectivePrice) > 0.01`.
- [X] T004 [P] أنشئ `test/attendance_overdue_warning_test.dart` — 10 حالات من جدول العقد: شهري متأخر خارج المهلة → true؛ شهري ضمن المهلة → false؛ شهري مدفوع → false؛ معفى → false؛ per-session حصة اليوم فقط → false؛ per-session حصتين أمس → true؛ per-session قديم مدفوع + اليوم → false؛ per-session قديم 100 دفع 60 + اليوم → true؛ `effectivePrice==0` → false؛ `sessionsAttendedOn` يحسب "متأخر" كحضور.
- [X] T005 [P] أنشئ `lib/widgets/overdue_warning_badge.dart` — `OverdueWarningBadge({required double debtAmount, bool compact = false})` StatelessWidget وفق [contracts/overdue-warning-widget.md](./contracts/overdue-warning-widget.md): شريط كامل بلون `0xFFEF4444` + `Icons.warning_amber_rounded` + "متأخر في الدفع • مديونية ${FormatHelper.formatCurrency(debtAmount)}"؛ `compact` = شارة صغيرة. بلا `onTap`.

**Checkpoint**: `flutter test test/attendance_overdue_warning_test.dart` أخضر.

---

## Phase 3: User Story 1 + 2 — التنبيه في شاشة "تسجيل الحضور بـ QR" (Priority: P1) 🎯 MVP

**Goal**: التنبيه يظهر في بانل نتيجة المسح وكروت البحث بشاشة `QRScannerAttendancePage` وفق القاعدة الذكية (شهري + per-session).

**Independent Test**: quickstart سيناريوهات 1–8 على شاشة الـQR للحضور.

### Implementation

- [X] T006 [US1] في `lib/views/qr_scanner/qr_scanner_attendance_page.dart` `initState`: اكتسب `PaymentController _payCtrl` (`Get.isRegistered ? find : put`)، وفي `postFrameCallback` القائم أضف `await _payCtrl.loadPayments();` بجانب تحميل الطلاب/المجموعات/الحضور.
- [X] T007 [US1] نفس الملف — `_AttendancePanel`: مرّر `PaymentController` + `SettingsController` + `List<Student>` (أو `Get.find` داخله). بعد بطاقة الطالب، لو `settings.attendanceOverdueWarning.value` واستدعاء `PricingHelper.showsAttendanceOverdueWarning(...)` رجع true → `OverdueWarningBadge(debtAmount: PricingHelper.accumulatedDebt(...))`. `group` من `groupCtrl.groups.firstWhereOrNull((g) => g.id == student.groupId)`.
- [X] T008 [US2] نفس الملف — `_StudentSearchCard`: نفس الحساب، `OverdueWarningBadge(debtAmount: debt, compact: true)` كسطر تحت `${student.code} · ${group?.name}`. (نفس الدالة تغطّي US1 وUS2 — القرار داخلها.)
- [X] T009 [US2] تحقّق أن الودجت يُعاد بناؤه عند تغيّر `_payCtrl.payments` (عبر `Obx`) أو `setState` للمسح — يحقّق التحديث الفوري بعد دفعة (FR-009).

**Checkpoint**: US1 + US2 يعملان في شاشة الـQR — MVP قابل للتسليم.

---

## Phase 4: User Story 1 + 2 (امتداد) — التنبيه في شاشة الحضور العادية (Priority: P2)

**Goal**: نفس البادج بجوار اسم الطالب المتأخر في `attendance_page.dart`.

**Independent Test**: quickstart سيناريو 9 (الجزء الثاني).

### Implementation

- [X] T010 [US1] في `lib/views/attendance/attendance_page.dart`: تأكّد `_payCtrl.loadPayments()` اتنادت عند فتح الشاشة (لو لأ ضيفها في `initState`/`postFrameCallback`). في عنصر قائمة الطالب بتبويب تسجيل الحضور (`itemBuilder` ~سطر 277/2195): بعد اسم الطالب، لو `settings.attendanceOverdueWarning.value` والدالة رجعت true → `OverdueWarningBadge(compact: true, debtAmount: debt)`.
- [X] T011 [P] [US2] لو `_SessionSheet` أو أي عرض طلاب آخر بالشاشة يعرض أسماء طلاب في سياق الحضور — أضف نفس البادج المضغوط (اختياري لو مش سياق حضور فعلي).

**Checkpoint**: التنبيه في الشاشتين.

---

## Phase 5: User Story 3 — مفتاح التحكّم في الإعدادات (Priority: P3)

**Goal**: سطر Switch يتحكّم في كل مواضع التنبيه.

**Independent Test**: quickstart سيناريو 10.

### Implementation

- [X] T012 [US3] في `lib/views/settings/settings_page.dart`: أضف سطر `_buildSwitchTile` في قسم إعدادات الحضور (بجانب "تسجيل متأخر تلقائيًا عبر QR") — العنوان "تنبيه المتأخر في شاشة الحضور"، الأيقونة `Icons.warning_amber_rounded`، اللون `Color(0xFFF59E0B)`، `rxValue: settings.attendanceOverdueWarning`، `onChanged: (v) async => await settings.setAttendanceOverdueWarning(v)`، النصّان الفرعيان من [contracts/overdue-warning-widget.md](./contracts/overdue-warning-widget.md).
- [X] T013 [US3] تأكّد أن كل موضع عرض بادج محاط بشرط `settings.attendanceOverdueWarning.value` (T007/T008/T010/T011) — لو معطّل الودجت لا يُبنى والدالة لا تُنادى (SC-005).

**Checkpoint**: كل القصص تعمل.

---

## Phase 6: Polish & Cross-Cutting

- [X] T014 [P] شغّل `flutter test` كاملًا + `flutter analyze` — صفر مشاكل جديدة فوق baseline (34 info).
- [ ] T015 نفّذ quickstart سيناريوهات 1–10 على جهاز/محاكي.
- [X] T016 [P] حدّث `HANDOFF.md` و`memory/` بملخّص spec 029 (`PricingHelper.showsAttendanceOverdueWarning`، إعداد `attendanceOverdueWarning` محلي، `OverdueWarningBadge`، القاعدة: شهري=isOverdue بمهلة / per-session=debt−حصص اليوم، صفر DB/مزامنة).

---

## Dependencies & Execution Order

- **Phase 1**: T001 → T002.
- **Phase 2**: T003 (الدالة) قبل/مع T004 (اختبارها)؛ T005 (الودجت) مستقل — الثلاثة متوازية عمليًا.
- **Phase 3**: بعد Phase 2. T006 → T007 → T008 → T009 (نفس الملف، تسلسلي).
- **Phase 4**: بعد Phase 2 (مستقل عن Phase 3 — ملف مختلف). T010 → T011.
- **Phase 5**: T012 مستقل (يُفضّل مبكرًا مع Phase 1). T013 يعتمد T007/T008/T010.
- **Phase 6**: بعد كل القصص.

### Parallel Opportunities

- T003 + T004 + T005.
- T012 (سطر الإعدادات) موازٍ لأي شيء بعد Phase 1.
- Phase 3 (شاشة QR) و Phase 4 (شاشة عادية) لمطوّرَين مختلفَين بعد Phase 2.

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 3 + T012)

الدالة + الودجت + التنبيه في شاشة الـQR للحضور + المفتاح. يغطّي US1 وUS2 في أهم شاشة. quickstart 1–8 + 10.

### Incremental

Setup+Foundational → شاشة QR (MVP) → شاشة الحضور العادية → صقل.
