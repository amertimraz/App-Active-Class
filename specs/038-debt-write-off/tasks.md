# Tasks: إسقاط المديونية المتراكمة — زرار مع تأكيد صريح

**Input**: Design documents from `specs/038-debt-write-off/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/write-off-debt.md, quickstart.md

**Tests**: مطلوبة (quickstart.md بيحدّد سيناريوهات اختبار وحدة صريحة) — تُنفَّذ ضمن Foundational وUS1/US2.

**Organization**: مقسَّمة حسب الـUser Stories من spec.md (US1 = P1، US2 = P2، US3 = P3) لضمان تسليم تدريجي قابل للاختبار.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- ملفات المسار كلها نسبية لجذر المشروع `C:\repo\active_class`

---

## Phase 1: Setup

- [X] T001 إضافة الثابت `const String kDebtWriteOffNote = 'إسقاط مديونية';` في `lib/config/constants.dart` (بجانب باقي ثوابت `SETTING_*`/نصوص التطبيق الموجودة)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: البنية الأساسية اللي كل الـUser Stories محتاجاها قبل ما تبدأ

- [X] T002 إضافة دالة `Future<String?> writeOffDebt({required Student student, required Group? group, required List<Attendance> allAttendance, required List<Payment> payments, required double graceDays, List<Student>? siblingGroupMembers})` في `lib/controllers/payment_controller.dart` طبقًا للعقد في `specs/038-debt-write-off/contracts/write-off-debt.md`: تعيد حساب `PricingHelper.accumulatedDebt(...)` بنفس المدخلات لحظة الاستدعاء، لو `<= 0` ترجع رسالة عربية وتلغي بدون إنشاء أي شيء، لو `> 0` تنادي `DatabaseService().insertPayment(Payment(studentId: student.id!, date: DateTime.now(), amount: <الناتج>, note: kDebtWriteOffNote))` وترجع `null`
- [X] T003 [P] إضافة `RxBool writeOffBusy` (أو ما يعادلها) في `PaymentController` لمنع استدعاء متكرر لـ`writeOffDebt` أثناء التنفيذ (FR-009) — نفس نمط `busy` في `GoogleDriveBackupController`

**Checkpoint**: دالة `writeOffDebt` جاهزة ومُختبَرة منطقيًا (بدون واجهة بعد) — الأساس لكل الـUser Stories جاهز.

---

## Phase 3: User Story 1 - إسقاط مديونية طالب بضغطة مع تأكيد (Priority: P1) 🎯 MVP

**Goal**: المدرّس يقدر يضغط زرار "إسقاط المديونية" جنب كارت "مديونية متراكمة"، يأكّد من نافذة تحذيرية، والمديونية تتصفّر فورًا من الشاشة.

**Independent Test**: طالب عليه مديونية 300 جنيه → فتح شاشة تفاصيله → ضغط الزرار → تأكيد النافذة → التأكد من اختفاء الكارت فورًا و`accumulatedDebt == 0`.

### Tests for User Story 1

- [X] T004 [P] [US1] إنشاء `test/debt_write_off_test.dart` — اختبار: طالب عليه مديونية 300 جنيه → `writeOffDebt(...)` ترجع `null` و`PricingHelper.accumulatedDebt(...)` بعدها تساوي 0
- [X] T005 [P] [US1] في نفس الملف `test/debt_write_off_test.dart` — اختبار: طالب مديونيته صفر بالفعل → `writeOffDebt(...)` ترجع رسالة خطأ غير فارغة، وعدد مدفوعاته لا يتغيّر (لا يُنشأ `Payment` جديد)
- [X] T006 [P] [US1] في نفس الملف `test/debt_write_off_test.dart` — اختبار: الصف الناتج من `writeOffDebt` له `note == kDebtWriteOffNote` بالضبط

### Implementation for User Story 1

- [X] T007 [US1] في `lib/views/students/student_details_page.dart` (مكان الكومنت الحالي "زر تعديل المديونية مخفي مؤقتًا"، سطر ~1622): إضافة `IconButton`/`TextButton` "إسقاط المديونية" يظهر بس لما `accumulatedDebt > 0` (نفس شرط ظهور الكارت الأحمر)
- [X] T008 [US1] في نفس الملف: عند الضغط على الزرار، فتح `AlertDialog` تأكيد (بنفس نمط نافذة التأكيد الموجودة في نفس الملف سطر ~758) تعرض المبلغ الحالي (`accumulatedDebt`) وتحذير نصي واضح إن الإجراء غير قابل للتراجع تلقائيًا، بزرارين "إلغاء" و"تأكيد"
- [X] T009 [US1] في نفس الملف: زرار "تأكيد" داخل النافذة يستدعي `PaymentController.writeOffDebt(...)` (مع تعطيل الزرار فور الضغطة الأولى عبر `writeOffBusy` من T003 لمنع التكرار — FR-009)، وعند النجاح (`null`) يقفل النافذة؛ عند الفشل (رسالة غير null) يعرض رسالة الخطأ للمستخدم (مثلاً عبر `Get.snackbar`) ويقفل النافذة بدون تغيير أي بيانات
- [X] T010 [US1] التأكد إن الشاشة بعد نجاح الإسقاط بتعيد بناء نفسها تلقائيًا (عبر `Obx`/الـstream الموجود بالفعل على `PaymentController.payments`) بحيث كارت "مديونية متراكمة" وزرار الإسقاط يختفوا فورًا بدون أي كود إضافي غير إعادة البناء العادية (FR-005)

**Checkpoint**: US1 مكتملة ومستقلة تمامًا — MVP قابل للتسليم هنا.

---

## Phase 4: User Story 2 - تمييز الإسقاط عن التحصيل الفعلي في السجلات والتقارير (Priority: P2)

**Goal**: أي مكان بيعرض أو يصدّر مدفوعات/إجماليات مالية يفرّق بوضوح بين فلوس محصّلة فعليًا وعمليات إسقاط دفترية.

**Independent Test**: بعد إسقاط مديونية طالب (من US1) → فتح سجل مدفوعاته وتقرير المدفوعات الشهري والتصدير PDF/Excel → التأكد إن السطر موسوم بوضوح "إسقاط مديونية" وإن "الإجمالي المحصَّل" في كل الأماكن دي لم يزد بقيمة الإسقاط.

### Implementation for User Story 2

- [X] T011 [P] [US2] في `lib/views/students/student_details_page.dart` (قائمة سجل المدفوعات في نفس الشاشة): عرض أيقونة/تنسيق مختلف للسطر لما `payment.note == kDebtWriteOffNote` (بدل شكل الدفعة العادية) بحيث يتضح فورًا إنه إسقاط
- [X] T012 [US2] في `lib/controllers/dashboard_controller.dart` — دالة `computeMonthlyBreakdown()`: تعديل حساب `collected`/`paidThisMonth` النهائي (المُستخدَم في `MonthlyPaymentBreakdown.collected` وكارت الصفحة الرئيسية) بحيث يُحسب من نسخة مفلترة تستبعد `p.note == kDebtWriteOffNote`، بينما حساب `totalPaid`/`dueBefore` الداخلي (المستخدَم لتحديد "لم يدفع"/الحالة الشهرية لكل طالب) يفضل شامل صفوف الإسقوط زي ما هو (راجع تفصيل research.md § "تفصيل تقني مهم")
- [X] T013 [P] [US2] في `lib/controllers/report_controller.dart`: تعديل `monthTotalCollected` (سطر ~82-83) ليستبعد `p.note == kDebtWriteOffNote` من مجموع `monthPayments.fold(...)`
- [X] T014 [P] [US2] في نفس الملف `lib/controllers/report_controller.dart`: مراجعة `groupSummaries`/`paidByStudent` (سطر ~127-131) — التأكد إن أي إجمالي مالي معروض (لا حالة الطالب) يستخدم نسخة مفلترة من `monthPayments` تستبعد صفوف الإسقوط
- [X] T015 [P] [US2] في `lib/services/export_service.dart` — `exportPaymentsPDF()`: فصل حساب `totalPaid` المستخدَم في `_summaryRow` (سطر ~118) ليستبعد `note == kDebtWriteOffNote`، مع إبقاء `paidMap` (سطر ~101-104) المستخدَم في عمود "الحالة" شامل كل المدفوعات بما فيها الإسقاط
- [X] T016 [US2] `exportPaymentsPDF()` جدولها (`_paymentsTable`) مُجمَّع لكل طالب (لا يعرض معاملات فردية أصلًا — عمود "الحالة" ده اللي بيعكس الإسقاط، وهو صحيح بالفعل لأن `paidMap` شاملة). لا يوجد تصدير Excel لمدفوعات في المشروع. الوسم الفعلي على مستوى المعاملة اتنفّذ في T011 (شاشة الطالب) وT017 (تقرير اليوم) — دول المكانين الوحيدين اللي بيعرضوا معاملات فردية.
- [X] T017 [P] [US2] في `lib/views/reports/payments_report_page.dart`: عرض نفس الوسم البصري/النصي للإسقوط في أي قائمة معاملات تعرضها الشاشة (اتساقًا مع T011)

**Checkpoint**: US2 مكتملة — التقارير والتصدير كلها بتفرّق الإسقوط عن التحصيل الفعلي، وUS1 لسه شغالة زي ما هي.

---

## Phase 5: User Story 3 - إسقاط المديونية في وضع الفريق (مزامنة) (Priority: P3)

**Goal**: التأكد إن عملية الإسقاط بتنتشر لباقي أعضاء الفريق عبر آلية المزامنة الموجودة بدون أي كود إضافي.

**Independent Test**: جهازين في وضع فريق واحد — إسقاط مديونية من الجهاز الأول، والتأكد إن الجهاز التاني بيعرض نفس المديونية (صفر) بعد دورة المزامنة التالية.

### Implementation for User Story 3

- [ ] T018 [US3] تحقّق يدوي فقط (لا كود جديد متوقَّع): تنفيذ الخطوة 9 من `specs/038-debt-write-off/quickstart.md` على جهازين حقيقيين في وضع فريق — التأكد إن `insertPayment` الموجودة بالفعل (اللي `writeOffDebt` من T002 بتستخدمها) بتُزامن صف الإسقوط تلقائيًا عبر `_queueSync` الموجود بدون أي تعديل إضافي؛ لو ظهرت أي مشكلة (مثلاً صف الإسقوط ما وصلش أو وصل بملاحظة مختلفة)، يُفتح task إصلاح منفصل عندها

**Checkpoint**: كل الـUser Stories الثلاثة مكتملة ومُتحقَّق منها.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T019 [P] تشغيل `flutter analyze` والتأكد من صفر تحذيرات/أخطاء جديدة بسبب التعديلات
- [X] T020 [P] تشغيل `flutter test` كامل (بما فيه `test/debt_write_off_test.dart` الجديد) والتأكد من نجاح كل الاختبارات
- [ ] T021 تنفيذ التحقق اليدوي الكامل (خطوات 1-8 و10) في `specs/038-debt-write-off/quickstart.md` على جهاز حقيقي
- [ ] T022 تحديث `HANDOFF.md` بملخص الميزة بعد التحقق الكامل (نمط الجلسات السابقة — رقم سبيك، ملفات متأثرة، حالة التحقق)

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** → **Phase 2 (Foundational)**: T002/T003 محتاجين `kDebtWriteOffNote` من T001
- **Phase 2 → Phase 3 (US1)**: US1 محتاجة `writeOffDebt`/`writeOffBusy` من Phase 2
- **Phase 3 (US1) → Phase 4 (US2)**: US2 بتفترض وجود صفوف إسقاط فعلية (من US1) لاختبارها على الشاشات/التقارير، لكن تعديلات الكود في US2 (T012-T017) مستقلة تقنيًا عن UI الزرار — ممكن تتنفّذ بالتوازي مع US1 لو الفريق أكبر من شخص، لكن **الاختبار المستقل** لـUS2 محتاج US1 شغالة الأول عمليًا
- **Phase 5 (US3)**: تحقّق فقط، بيعتمد على US1 شغالة (مفيش كود جديد في Phase 2/دوال أخرى)
- **Phase 6 (Polish)**: بعد اكتمال كل الـUser Stories المطلوبة

### Parallel Opportunities

- T004/T005/T006 (اختبارات US1) تقدر تتكتب بالتوازي (نفس الملف لكن سيناريوهات مستقلة تمامًا في الكتابة، وتشتغل مع بعض في نفس ملف الاختبار)
- T011/T013/T014/T015/T017 (US2) كلها في ملفات مختلفة — تقدر تتنفّذ بالتوازي
- T019/T020 (Polish) بالتوازي

---

## Implementation Strategy

### MVP First (US1 فقط)

1. Phase 1 (T001) → Phase 2 (T002-T003) → Phase 3 (T004-T010)
2. **STOP and VALIDATE**: اختبر US1 بمفردها (quickstart.md خطوات 1-5) — المديونية بتتصفّر فورًا بعد التأكيد
3. سلّم/اعرض النتيجة لو محتاج قرار مبكر

### Incremental Delivery

1. Setup + Foundational + US1 → اختبار → **MVP جاهز للاستخدام الفعلي** (الإسقاط شغال، لكن لسه مش موسوم بوضوح في التقارير)
2. إضافة US2 → اختبار → التقارير والتصدير بقت دقيقة ماليًا
3. إضافة US3 (تحقّق فقط) → اختبار على جهازين
4. Polish → نشر
