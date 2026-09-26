# Tasks: شاشة الإخوة — عرض العيلات وتفاصيلها

**Input**: specs/042-siblings-overview/ (plan, spec, research, data-model, contracts, quickstart)
**Tests**: اختبار وحدة للمنطق الصرف + تحقق يدوي.
**No DB / sync / migration** — عرض فقط.

## Phase 1: Setup
- [x] T001 إضافة `ROUTE_SIBLINGS = '/siblings'` في `lib/config/constants.dart` وتسجيل `GetPage` في `lib/main.dart`

## Phase 2: Foundational (منطق صرف)
- [x] T002 إنشاء `lib/utils/siblings_overview.dart`: `SiblingMember`, `SiblingFamily`, `buildSiblingFamilies` (تجميع بـ`siblingGroupId`، ≥2 نشط، مرتّب: عليها متبقي أولًا ثم الاسم) حسب `contracts/siblings-math.md`؛ المستحق/المتبقي من `PricingHelper`، المدفوع بدون `kDebtWriteOffNote`، حضور الشهر، phones بدون تكرار
- [x] T003 [P] في نفس الملف: `filterFamilies` و`buildFamilyMessage` (`withFinance=false` ⇒ بلا أرقام مالية)
- [x] T004 [P] إنشاء `test/siblings_overview_test.dart` (تجميع، مؤرشف، مطابقة PricingHelper، إسقاط المديونية، حضور/null، أرقام بلا تكرار، فلترة، رسالة بلا ماليات)
- [x] T005 **CHECKPOINT**: `flutter analyze` + `flutter test` صفر تراجع

## Phase 3: US1 — العيلات في شاشة واحدة (P1) 🎯 MVP
- [x] T006 [US1] إنشاء `lib/views/students/siblings_page.dart`: Scaffold + `Obx` يقرأ `StudentController.students` و`GroupController.groups` و`AttendanceController.attendance` و`PaymentController.payments`، يعرض كارت لكل عيلة (أسماء + كود + مجموعة كل أخ) والضغط على أخ يفتح تفاصيله (`ROUTE_STUDENT_DETAILS` بنفس طريقة students_page)، `EmptyState` عند عدم وجود عيلات مع شرح الربط
- [x] T007 [US1] إضافة `CustomSearchBar` للبحث بالاسم/الكود عبر `filterFamilies`
- [x] T008 [US1] إضافة زر "الإخوة" (أيقونة `Icons.family_restroom_rounded`) في AppBar `lib/views/students/students_page.dart` يفتح `ROUTE_SIBLINGS`
- [x] T009 [US1] **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart بنود 1، 3، 6)

## Phase 4: US2 — المتابعة المالية (P1)
- [x] T010 [US2] في `siblings_page.dart`: ملخص العيلة (الإجمالي المشترك، إجمالي المدفوع، إجمالي المتبقي) بـ`CurrencyText stacked` وشريط تقدّم (`LabeledProgress` من `booklet_widgets.dart`)، ولكل أخ سطر (مستحق/مدفوع/متبقي بألوان `AppTheme`)
- [x] T011 [US2] فلتر "عليها متبقي" (ChoiceChip) وإخفاء كل العناصر المالية والفلتر عمّن ليس `canSeeFinancials`
- [x] T012 [US2] **CHECKPOINT**: تحقق يدوي (بنود 2، 4، 5، 8، 9) — مقارنة الأرقام مع تفاصيل الطالب

## Phase 5: US3 — الحضور (P2)
- [x] T013 [US3] عرض حضور الشهر لكل أخ (حاضر/غائب/نسبة أو "لا توجد سجلات") في بطاقة الأخ

## Phase 6: US4 — واتساب العيلة (P2)
- [x] T014 [US4] عرض أرقام ولي الأمر (بدون تكرار) في الكارت
- [x] T015 [US4] زر "رسالة للعيلة": رقم واحد ⇒ `launchGuardianWhatsapp` مباشرة؛ أرقام متعددة ⇒ bottom sheet للاختيار؛ صفر أرقام ⇒ الـlauncher ينبّه؛ الرسالة من `buildFamilyMessage(withFinance: canSeeFinancials)`
- [x] T016 [US4] **CHECKPOINT**: تحقق يدوي (بند 7)

## Phase 7: Polish
- [x] T017 [P] `flutter analyze` كامل + `flutter test` كامل
- [x] T018 بناء release وتثبيته على الجهاز والتحقق النهائي، وتحديث `HANDOFF.md` بملخص spec 042

## Dependencies
T001 → T006/T008؛ T002 → T003/T004 → T005 → كل الـUS؛ US1 → US2 → US3/US4 (نفس ملف الشاشة فبالتسلسل).

## MVP
T001–T009 (شاشة العيلات + بحث + زر)، ثم US2 (الماليات) وهي الأهم بعده، ثم US3/US4.
