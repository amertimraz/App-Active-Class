---

description: "Task list for feature implementation"
---

# Tasks: ملخص تفصيلي لكارت دفعات الشهر (تفصيل حسب المجموعة)

**Input**: Design documents from `/specs/036-payment-month-summary/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/group-payment-summary-sheet.md, quickstart.md

**Tests**: اختبار وحدة واحد إلزامي لدالة التجميع الصرفة (يحقق SC-002 — تطابق المجموع). بلا اختبارات widget (مش نمط المشروع الحالي لباقي الشيتات).

**Organization**: Tasks مجمّعة حسب قصة المستخدم من spec.md.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: قابلة للتنفيذ بالتوازي (ملفات مختلفة، بلا اعتماديات)
- **[Story]**: US1/US2/US3 من spec.md
- كل Task فيها مسار الملف بالظبط

## Path Conventions

مشروع Flutter واحد — `lib/` في جذر `active_class/`، اختبارات في `test/`.

---

## Phase 1: Setup

مفيش تهيئة بنية جديدة مطلوبة — الميزة كلها تعديل داخل ملفات موجودة بالفعل (`dashboard_controller.dart`, `home_page.dart`)، بلا تبعيات/مجلدات جديدة. **هذه المرحلة فاضية عن قصد.**

---

## Phase 2: Foundational (Blocking Prerequisites)

**الهدف**: كيان البيانات الأساسي (`GroupPaymentSummaryEntry`) اللي كل الـuser stories بتعتمد عليه.

**⚠️ CRITICAL**: لازم يخلص قبل أي عمل في أي user story.

- [X] T001 عرّف `class GroupPaymentSummaryEntry` (حقول: `groupId` (`int?`), `groupName` (`String`), `expected`/`collected` (`double`), `remaining` getter مشتق، `unpaidStudentsCount` (`int`)) في `lib/controllers/dashboard_controller.dart` (بجانب `UnpaidStudentEntry` الموجود).
- [X] T002 أضف `final RxList<GroupPaymentSummaryEntry> paymentCardGroupBreakdown = <GroupPaymentSummaryEntry>[].obs;` في `lib/controllers/dashboard_controller.dart` بجانب حقول كارت الدفعات الموجودة (`paymentCardExpected` وأخواتها).

**Checkpoint**: الكيان والحقل التفاعلي جاهزين — التجميع الفعلي (تعبئة القائمة) بيحصل في US1.

---

## Phase 3: User Story 1 - تفصيل مستحق كل مجموعة (Priority: P1) 🎯 MVP

**الهدف**: المدرّس يضغط على جسم كارت الدفعات فيشوف قائمة مجموعات مرتبة تنازليًا حسب الباقي، بمجموع يطابق إجمالي الكارت تمامًا.

**اختبار مستقل**: افتح الشيت، اجمع "الباقي" لكل المجموعات الظاهرة يدويًا، وقارنه برقم "الباقي" الإجمالي في الكارت — لازم يتطابقوا (SC-002).

### Tests for User Story 1

- [X] T003 [P] [US1] اكتب اختبار وحدة جديد `test/dashboard_group_payment_breakdown_test.dart`: يبني مجموعة طلاب/مدفوعات/مجموعات تجريبية (شهري + بالحصة + إخوة)، وينادي دالة التجميع (T005) مباشرة، ويتأكد إن `Σ entry.remaining == إجمالي remaining المتوقع` وإن مجموعة معفاة بالكامل مش ظاهرة في الناتج (FR-006) — الاختبار المفروض يفشل قبل T005/T006.

### Implementation for User Story 1

- [X] T004 [US1] استخرج حلقة `for (final s in students.where((s) => !s.isFullyExempt))` الموجودة في `_computePaymentCardBody` (`lib/controllers/dashboard_controller.dart`) لتفضل هي نفسها مصدر التجميع الجديد — بلا حلقة تانية منفصلة (راجع research.md #1).
- [X] T005 [US1] جوه نفس الحلقة في `_computePaymentCardBody`، أضف تجميع فرعي بـ`groupId` (أو `null` لبلا مجموعة، FR-007): لكل طالب زوّد `expected`/`collected` (نفس `dueThisMonth`/`paidThisMonth` المحسوبين بالفعل للطالب ده) على `GroupPaymentSummaryEntry` المجموعة المطابقة في `Map<int?, GroupPaymentSummaryEntry>` مؤقّت، وزوّد `unpaidStudentsCount` لو `shortfall > 0.5`.
- [X] T006 [US1] بعد نهاية الحلقة في `_computePaymentCardBody`: رتّب قيم الـMap تنازليًا حسب `remaining` (FR-005)، استبعد أي entry `expected <= 0` (FR-006)، وخزّن الناتج في `paymentCardGroupBreakdown.assignAll(...)` (لازم يحصل تحت نفس حارس `if (token != _payCardToken) return;` الموجود، زي `_unpaidList.assignAll`).
- [X] T007 [US1] أضف اسم المجموعة: استخدم `groupById[groupId]?.name ?? 'بلا مجموعة'` (نفس `groupById` المبني بالفعل في `_computePaymentCardBody` من `getAllGroups()`).
- [X] T008 [US1] في `lib/views/home_page.dart`، أضف باراميتر جديد `onTapSummary` (`VoidCallback?`) لـ`_PaymentProgressCard` (بجانب `onTapUnpaid` الموجود)، ونادِ عليه من `GestureDetector` منفصل يغلّف جسم الكارت (بدون ما يتعارض مع `onHorizontalDragEnd` الموجود على نفس الـ`GestureDetector` الخارجي — استخدم `onTap` على نفس الـwidget، Flutter بيدعم الاتنين مع بعض بلا تعارض).
- [X] T009 [US1] في `lib/views/home_page.dart`، اربط `onTapSummary: canSeeFinancials ? () => _showPaymentMonthSummarySheet(context) : showLockedPermissionHint` عند بناء `_PaymentProgressCard` (بجانب `onTapUnpaid` الموجود، سطر ~719).
- [X] T010 [US1] أنشئ دالة جديدة `_showPaymentMonthSummarySheet(BuildContext context)` في `lib/views/home_page.dart` (بنفس نمط `_showUnpaidSheet` الموجودة، سطر ~1329): `showModalBottomSheet` بعنوان الشهر (`_PaymentProgressCard._arabicMonth`)، و`ListView.builder` على `_dashboardController.paymentCardGroupBreakdown` — كل صف يعرض اسم المجموعة، مستحقها، محصّلها، الباقي عليها، وعدد المتأخرين، مع تمييز بصري (لون/أيقونة مختلفة) للمجموعات اللي `remaining == 0` (FR-005).
- [X] T011 [US1] في نفس الدالة (T010)، أضف حالة فاضية واضحة ("مفيش مستحقات على أي مجموعة للشهر ده") لو `paymentCardGroupBreakdown.isEmpty`.

**Checkpoint**: US1 شغالة ومستقلة بالكامل — الضغط على الكارت بيفتح تفصيل المجموعات مرتب وصحيح.

---

## Phase 4: User Story 2 - الملخص العام أعلى الشيت (Priority: P2)

**الهدف**: نفس أرقام الكارت (المستحق/المحصّل/الباقي/النسبة) ظاهرة كرأس فوق قائمة المجموعات في نفس الشيت.

**اختبار مستقل**: افتح الشيت وقارن رأسه بأرقام الكارت قبل الضغط — لازم يتطابقوا بالظبط.

### Implementation for User Story 2

- [X] T012 [US2] في `_showPaymentMonthSummarySheet` (`lib/views/home_page.dart`، من T010)، أضف رأس فوق `ListView.builder` يعرض `_dashboardController.paymentCardExpected`/`paymentCardCollected`/`paymentCardRemaining`/`paymentCardRate` الموجودين بالفعل (بنفس تنسيق العرض المستخدم في `_PaymentProgressCard` — `fmtMoney`, نسبة مئوية) — بلا حساب جديد، قراءة مباشرة من الحقول الموجودة.

**Checkpoint**: US1 + US2 شغالين مع بعض — الشيت فيه سياق عام + تفصيل.

---

## Phase 5: User Story 3 - الضغط على مجموعة يفتح متأخريها بس (Priority: P3)

**الهدف**: من شيت الملخص، الضغط على صف مجموعة يفتح قائمة طلابها المتأخرين بس.

**اختبار مستقل**: اضغط على مجموعة فيها متأخرين من شيت الملخص، وتأكد إن القائمة الظاهرة فيها طلاب المجموعة دي بس.

### Implementation for User Story 3

- [X] T013 [US3] عدّل توقيع `_showUnpaidSheet` في `lib/views/home_page.dart` ليقبل باراميتر اختياري جديد `{int? groupIdFilter}`.
- [X] T014 [US3] جوه `_showUnpaidSheet` (T013)، لو `groupIdFilter != null`، فلتر `students` (المصدر `_dashboardController.paymentCardUnpaidList`) على `entry.student.groupId == groupIdFilter` قبل البناء، وعدّل عنوان الشيت ليعكس اسم المجموعة بدل "لم يدفعوا [الشهر] (N)" العام.
- [X] T015 [US3] في صف المجموعة داخل `_showPaymentMonthSummarySheet` (T010)، أضف `onTap: () { Navigator.of(context).pop(); _showUnpaidSheet(context, groupIdFilter: entry.groupId); }` — فقط لو `entry.unpaidStudentsCount > 0` (مفيش داعي فتح قائمة فاضية لمجموعة مكتملة الدفع).

**Checkpoint**: كل الـuser stories التلاتة شغالة مع بعض.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T016 [P] شغّل `flutter analyze` وتأكد إن `lib/controllers/dashboard_controller.dart` و`lib/views/home_page.dart` بلا مشاكل جديدة (نفس الـbaseline القديم).
- [X] T017 [P] شغّل `flutter test test/dashboard_group_payment_breakdown_test.dart` وباقي `flutter test` للتأكد من عدم وجود انحدار (regression) في اختبارات `dashboard_controller`/`pricing_helper` الموجودة.
- [ ] T018 نفّذ سيناريوهات `quickstart.md` (1–6) يدويًا على جهاز/محاكي حقيقي، مع التركيز على سيناريو ٦ (عدم انحدار السحب لتبديل الشهر وشريحة "N لم يدفع" الموجودة).
- [X] T019 حدّث `HANDOFF.md` بملخص الميزة الجديدة بعد التنفيذ والتحقق (نفس نمط توثيق باقي الـspecs في الملف).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: فاضية — لا حاجة للانتظار.
- **Foundational (Phase 2)**: يبدأ فورًا (T001, T002) — **يمنع** كل الـuser stories.
- **User Story 1 (Phase 3)**: يعتمد على Phase 2. MVP كامل ومستقل.
- **User Story 2 (Phase 4)**: يعتمد على Phase 2 فقط منطقيًا (الحقول `paymentCardExpected` وأخواتها موجودة بالفعل من قبل الميزة دي) — **لكن عمليًا** محتاج الشيت نفسه (T010 من US1) موجود عشان يضيف رأسه فوقه، فـT012 معتمدة على T010.
- **User Story 3 (Phase 5)**: يعتمد على T010 (الشيت) وعلى `_showUnpaidSheet` الموجودة (T013/T014 تعديل عليها).
- **Polish (Phase 6)**: بعد خلاص كل الـstories المطلوبة.

### Parallel Opportunities

- T001 وT002 (Phase 2) بينفصلوا لكن في نفس الملف — تنفيذ متتابع أسرع من التوازي هنا عمليًا.
- T003 (اختبار US1) ممكن يتكتب بالتوازي مع T004–T007 (نفس المنطق، ملف مختلف) طول ما الاختبار بيستهدف توقيع الدالة النهائي المتفق عليه في data-model.md.
- T016 وT017 (Polish) قابلين للتنفيذ بالتوازي.

---

## Implementation Strategy

### MVP First (User Story 1 فقط)

1. Phase 2 (Foundational) — T001, T002.
2. Phase 3 (US1) — T003–T011.
3. **قف وتحقّق**: نفّذ سيناريو ١ من quickstart.md يدويًا.
4. لو كويس، الميزة جاهزة للعرض حتى قبل US2/US3 (رأس الملخص وdrill-down تحسينات إضافية مش أساسية).

### Incremental Delivery

1. Foundational → US1 (MVP: تفصيل المجموعات مرتب وصحيح).
2. + US2 (رأس الملخص العام — سطر واحد إضافي عمليًا، مخاطرة شبه صفر).
3. + US3 (drill-down — تحسين تنقّل، مخاطرة منخفضة لأنه بيعيد استخدام `_showUnpaidSheet` الموجودة).
4. Polish (تحليل + اختبارات + تحقق يدوي + توثيق).
