---
description: "Task list — تحصيل المديونية المتراكمة من شاشة الدفع بماسح QR"
---

# Tasks: تحصيل المديونية المتراكمة من شاشة الدفع بماسح QR

**Input**: `specs/026-qr-payment-accumulated-debt/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Tests**: مطلوبة — وحدات منطق نقي (plan.md §Testing، research.md R8).

**Organization**: مجموعة حسب user story. الميزة صغيرة: ملفان مصدر (`lib/controllers/qr_controller.dart`, `lib/views/qr_scanner/qr_scanner_payment_page.dart`) + ملف اختبار جديد. US1 وUS2 يشتركان في نفس الملفين → تسلسليان.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ملف مختلف، بلا تبعيات — يمكن التوازي
- **[Story]**: US1 / US2 / US3

## Path Conventions

Mobile single-project: `lib/` + `test/` في جذر المستودع.

---

## Phase 1: Setup

- [x] T001 إنشاء `test/qr_payment_debt_test.dart` بهيكل `flutter_test` فارغ (imports: `package:flutter_test/flutter_test.dart`, `package:active_class/utils/pricing_helper.dart`, نماذج `student_model`/`group_model`/`attendance_model`/`payment_model`) — placeholder `main()` بمجموعة `group('debt → sessions', ...)`.

---

## Phase 2: Foundational

**لا شيء.** لا سكيمة، لا ترقية DB، لا بنية تحتية مشتركة جديدة. `QRController.scannedStudentDebt` و`PricingHelper` و`DatabaseService.insertPayment` كلها قائمة.

**Checkpoint**: يمكن البدء في قصص المستخدم مباشرة.

---

## Phase 3: User Story 2 - تصحيح حساب الحصص المستحقة (Priority: P1) 🎯 MVP

**Goal**: عدّ الحصص غير المدفوعة وتواريخها في شاشة الدفع بالماسح يشمل كل الشهور من انضمام الطالب حتى الشهر الحالي — يطابق `scannedStudentDebt`. «دفع كل المستحق» يغطّي المتأخر القديم.

**Independent Test**: طالب per-session (سعر 20) حضر 6 حصص الشهر السابق + 1 الحالي بلا دفعات → فتح الشاشة يُظهر «الحصص المستحقة: 7» و7 تواريخ مرتّبة؛ «دفع كل المستحق» ثم «تأكيد» → مديونية 0.

> **نُفَّذ US2 قبل US1**: US1 (سطر «= N حصة») يعتمد على تطابق `unpaidSessionsCount` مع المديونية الذي يحقّقه US2؛ والقصتان تعدّلان نفس الملفين.

### Tests for User Story 2 ⚠️

- [x] T002 [P] [US2] في `test/qr_payment_debt_test.dart`: اختبار `PricingHelper.accumulatedDebt` لطالب per-session عبر شهرين — بناء `Group(isPerSession:true)`، `Student(price:20, attendanceStart: الشهر السابق)`، 7 صفوف `Attendance` (6 سابق + 1 حالي، status حاضر)، `payments: []` → توقّع `140`. حالة ثانية: `payments:[Payment(amount:60)]` → توقّع `80`.

### Implementation for User Story 2

- [x] T003 [US2] `lib/controllers/qr_controller.dart` — `_buildUpcomingMonths`: توقيع جديد `_buildUpcomingMonths(DateTime start, {bool perSession = false})`. عند `perSession`: بناء الشهور من `start` حتى الشهر الحالي فقط (بلا شهور مستقبلية)، بلا سقف 12 (سقف حارس 60). غير ذلك: بلا تغيير.
- [x] T004 [US2] `lib/controllers/qr_controller.dart` — `_preparePayment`: للمسار per-session اضبط `start = DateTime(joined.year, joined.month)` حيث `joined = student.attendanceStart ?? student.createdAt` (fallback `nowMonth` لو null)، ونادِ `_buildUpcomingMonths(start, perSession: true)`، واملأ `selectedMonths` بكل `months` حتى `nowMonth` (شامل). المسار الشهري: بلا تغيير. راجع `contracts/qr-controller-per-session-scope.md`.
- [x] T005 [US2] `lib/views/qr_scanner/qr_scanner_payment_page.dart` — تأكيد أن نص/مبلغ زر «دفع كل المستحق» وسطر «الحصص المستحقة: …» يعكسان القيمة الكلية (يتبعان `unpaidSessionsCount`/`unpaidSessionDates` تلقائيًا — تحقّق بصريًا فقط، عدّل النصوص لو أي منها يفترض «هذا الشهر»).
- [x] T006 [US2] `flutter analyze` + `flutter test test/qr_payment_debt_test.dart` — خضراء. تحقّق يدوي: quickstart سيناريو 2 + 3.

**Checkpoint**: عدّ الحصص صحيح؛ «دفع كل المستحق» يصفّر المديونية.

---

## Phase 4: User Story 1 - إظهار المديونية المتراكمة الحقيقية (Priority: P1)

**Goal**: شاشة الدفع بالماسح تعرض `scannedStudentDebt` للمجموعات بالحصة أيضًا، مع سطر «= N حصة».

**Independent Test**: طالب per-session مديونيته 140 ج / سعر 20 → الشاشة تعرض «متبقّي عليه: 140.00 ج» و«= 7 حصة» مطابقًا لكارت تفاصيل الطالب.

### Tests for User Story 1 ⚠️

- [x] T007 [P] [US1] في `test/qr_payment_debt_test.dart`: اختبار دالة تحويل نقية `int debtToSessions(double debt, double price) => price > 0 ? (debt / price).floor() : 0` — `(140,20)→7`, `(45,20)→2`, `(0,20)→0`, `(140,0)→0`. (عرّف الدالة في الاختبار كمرجع للمنطق المطلوب في الـgetter.)

### Implementation for User Story 1

- [x] T008 [US1] `lib/controllers/qr_controller.dart` — أضف `double get _effPrice => scannedStudent.value?.effectivePrice ?? 0;` و`int get scannedStudentDebtSessions => _effPrice > 0 ? (scannedStudentDebt / _effPrice).floor() : 0;`.
- [x] T009 [US1] `lib/views/qr_scanner/qr_scanner_payment_page.dart` (سطر ~1054) — غيّر شرط سطر المديونية من `if (!controller.isPerSessionGroup && !student.isFullyExempt)` إلى `if (!student.isFullyExempt)`. داخل `Obx`: أبقِ حالتَي «سديد الحساب» (أخضر، `debt <= 0.01`) و«متبقّي عليه: X» (برتقالي). أضف — للـper-session فقط وعندما `scannedStudentDebtSessions >= 1` — سطرًا ثانيًا أصغر «= {n} حصة». راجع `contracts/debt-display.md`.
- [x] T010 [US1] `flutter analyze` + `flutter test`. تحقّق يدوي: quickstart سيناريو 1 + سيناريو 5 (الشهري بلا سطر حصص) + حالات حديّة (معفى، سعر 0).

**Checkpoint**: رقم المديونية موحّد بين شاشة الماسح وكارت الطالب.

---

## Phase 5: User Story 3 - دفع مبلغ جزئي من المديونية (Priority: P2)

**Goal**: حقل مبلغ حرّ في شاشة الدفع بالماسح (per-session) مع معاينة «يغطّي X حصة» و«المتبقّي Y»، وتسجيل دفعة واحدة بـ`sessions=X`.

**Independent Test**: سعر 20 / مديونية 140 → إدخال «50» يُظهر «يغطّي 2 حصة • المتبقّي: 90.00 ج»؛ تأكيد → دفعة 50 ج بـ`sessions=2`، مديونية تصبح 90.

### Tests for User Story 3 ⚠️

- [x] T011 [P] [US3] في `test/qr_payment_debt_test.dart`: اختبارات نقية لمنطق التحقّق — `sessionsCoveredBy`: `(50,price20)→2`, `(45,20)→2`, `(10,20)→0`; `debtRemainingAfter`: `(debt140, amt50)→90`, `(debt140, amt200)→0 (clamp)`; قاعدة القبول: `amount>0 && amount <= debt+0.01`.

### Implementation for User Story 3

- [x] T012 [US3] `lib/controllers/qr_controller.dart` — أضف:
  - `int sessionsCoveredBy(double amount) => _effPrice > 0 ? (amount / _effPrice).floor() : 0;`
  - `double debtRemainingAfter(double amount) => (scannedStudentDebt - amount).clamp(0.0, double.infinity).toDouble();`
  - `final Rxn<int> _explicitSessionsForPayment = Rxn<int>();`
  - `bool applyDebtAmountPayment(double amount)` — تحقّق (`isPerSessionGroup`, student != null, `amount > 0`, `debt > 0.01`, `amount <= debt + 0.01`) مع توست خطأ مناسب؛ عند القبول: `setOverride(amount: amount, note: 'دفعة من المديونية')` ثم `_explicitSessionsForPayment.value = sessionsCoveredBy(amount)`؛ `return true`.
- [x] T013 [US3] `lib/controllers/qr_controller.dart` — اربط `_explicitSessionsForPayment`: اضبطه `= count` في `payAllUnpaidSessions` (بعد `setOverride`)؛ صفّره `= null` في `setOverride` (المسار العام — أضف صفرًا قبل نهايته، ثم أعد ضبطه في المستدعيين) و`_clearPaymentState` و`_preparePayment`. في `confirmPayment` (سطر ~376) استبدل حساب `sessionsBeingPaid` ليستخدم `_explicitSessionsForPayment.value ?? (<التقدير القديم بالـround>)`. راجع `contracts/debt-amount-payment.md` §`_explicitSessionsForPayment`.
- [x] T014 [US3] `lib/views/qr_scanner/qr_scanner_payment_page.dart` — أسفل زر «دفع كل المستحق» (per-session فقط، يظهر عندما `scannedStudentDebt > 0.01 && effectivePrice > 0 && !fullyPaidUp`): `TextField` رقمي «ادفع مبلغًا من المديونية» + `Obx` معاينة («يغطّي N حصة • المتبقّي بعد الدفع: …» / تحذير أحمر لو `> debt` / لا شيء لو فارغ/0/غير رقمي) + زر «تطبيق» → `controller.applyDebtAmountPayment(parsed)` (معطّل عند مدخل غير صالح). راجع `contracts/debt-amount-payment.md` §الواجهة.
- [x] T015 [US3] `flutter analyze` + `flutter test`. تحقّق يدوي: quickstart سيناريو 4 (شامل «200» و«0» و«abc» و«45»).

**Checkpoint**: كل القصص تعمل مستقلة.

---

## Phase 6: Polish & Cross-Cutting

- [ ] T016 [P] تحقّق عدم الانحدار للمجموعات الشهرية: quickstart سيناريو 5 كاملًا (month chips، اختيار شهور، تحصيل، لا حقل مبلغ حرّ، لا سطر «= N حصة»).
- [x] T017 [P] تحقّق مزامنة الفريق: quickstart سيناريو 6 (دفعة جزئية تظهر على جهاز المساعد بمبلغها) — أو تأكيد الكود أن المسار يمرّ بـ`insertPayment` بلا تفرّع.
- [x] T018 تحقّق `SessionLogController` / سجل «دفعوا اليوم»: الدفعة الكاملة والجزئية تظهران بمبلغهما الصحيح (`lastConfirmedPaymentId` يُضبط في كلا المسارين).
- [x] T019 تشغيل `flutter test` كامل + `flutter analyze` نظيف؛ مراجعة ذاتية أخيرة للباجات/الثغرات في `qr_controller.dart` diff (خاصة تصفير `_explicitSessionsForPayment` في كل المسارات، وحدود `clamp`).
- [x] T020 تحديث ملاحظة الذاكرة: أنشئ `memory/spec-026-qr-payment-accumulated-debt.md` + سطر في `MEMORY.md`.

---

## Dependencies & Execution Order

- **Setup (T001)**: أولًا.
- **Foundational**: لا شيء.
- **US2 (T002–T006)**: بعد Setup. يعدّل `qr_controller.dart` + الواجهة.
- **US1 (T007–T010)**: بعد US2 (نفس الملفين + يعتمد على تطابق العدّ). T007 مستقل [P].
- **US3 (T011–T015)**: بعد US1 (نفس الملفين، ويستخدم `_effPrice` من T008). T011 مستقل [P].
- **Polish (T016–T020)**: بعد US1+US2+US3.

### داخل كل قصة
- الاختبار قبل التنفيذ (تأكد أنه يفشل/غير مكتمل أولًا).
- `qr_controller.dart` قبل `qr_scanner_payment_page.dart`.

### فرص التوازي
- T002 / T007 / T011 (كلها في ملف الاختبار لكن مجموعات منفصلة — يمكن كتابتها معًا ثم دمجها) — عمليًا اكتب ملف الاختبار كاملًا مرة واحدة إن رغبت.
- T016 / T017 مستقلان.

---

## Implementation Strategy

### MVP (US2 + US1)
1. T001 → US2 كامل → **STOP & VALIDATE** (quickstart 1–3): رقم المديونية موحّد والعدّ صحيح — هذا يحل شكوى المدرس الأساسية.
2. أضف US1 (سطر «= N حصة») → validate.
3. أضف US3 (المبلغ الجزئي) → validate.
4. Polish.

### ملاحظات
- الالتزام بعد كل مهمة أو مجموعة منطقية.
- لا `git push` بدون إذن صريح.
- صفر تغيير في `PricingHelper` / `SyncEngine` / DB — أي مهمة تقترح غير ذلك = خطأ نطاق.


