# Tasks: تقسيم شاشات إضافة/تعديل الطالب والمجموعة الضخمة

**Input**: Design documents from `specs/039-ui-forms-refactor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/shared-widgets.md, quickstart.md

**Tests**: مطلوب اختبار وحدة آلي واحد فقط (`group_schedule_conflict_test.dart` — أول منطق قابل للاختبار الآلي من الأربعة). باقي التحقق يدوي بالكامل على جهاز حقيقي بعد كل خطوة (لا widget tests لهذه الشاشات — FR-008).

**Organization**: مقسَّمة حسب الـUser Stories من spec.md (US1 = P1 طالب، US2 = P1 مجموعة، US3 = P2 تقسيم الشاشتين). **مهم**: كل خطوة تنتهي بـ`flutter analyze` + `flutter test` + تحقق يدوي فوري (راجع quickstart.md) قبل الانتقال للتالية — لا تُجمَّع عدة خطوات تنفيذ بدون تحقق بينها.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- ملفات المسار كلها نسبية لجذر المشروع `C:\repo\active_class`

---

## Phase 1: Setup

- [X] T001 إنشاء مجلد `lib/widgets/student_form/` ومجلد `lib/views/groups/group_form/` (فاضيين، تحضيرًا لنقل الوحدات)
- [X] T002 تسجيل الأساس المرجعي: تشغيل `flutter analyze` و`flutter test` وحفظ العدد الحالي (تحذيرات/نجاح) للمقارنة بعده كل خطوة تالية

---

## Phase 2: Foundational

لا مهام Foundational مشتركة حقيقية — US1 (طالب) وUS2 (مجموعة) مستقلتان تمامًا (ملفات مختلفة، بدون أي كود مشترك بينهما). التبعية الوحيدة داخل كل Story موضّحة في قسمها.

---

## Phase 3: User Story 1 - فهم وتعديل شاشة إضافة/تعديل الطالب بسرعة وأمان (Priority: P1)

**Goal**: تقسيم `add_student_sheet.dart` و`edit_student_sheet.dart` لوحدات مشتركة صغيرة بدون أي تغيير سلوك.

**Independent Test**: فتح الشاشتين بعد كل خطوة والتأكد أن الشكل/السلوك مطابق 100% لما قبلها (راجع quickstart.md خطوات 3-4).

### Implementation for User Story 1 (بترتيب المخاطرة من research.md #6: الأقل خطورة أولًا)

- [X] T003 [US1] إنشاء `lib/widgets/student_form/student_date_button.dart` بويدجت `StudentDateButton` (راجع contracts/shared-widgets.md) بنفس padding/أحجام نسخة `_DateBtn` الحالية في `edit_student_sheet.dart` (الأحدث زمنيًا — فرق بصري <2px غير ملحوظ عن نسخة add، راجع research.md #1)
- [X] T004 [US1] استبدال `_DatePickerBtn` في `lib/widgets/add_student_sheet.dart` باستخدام `StudentDateButton` الجديد، وحذف تعريف `_DatePickerBtn` القديم
- [X] T005 [US1] استبدال `_DateBtn` في `lib/widgets/edit_student_sheet.dart` باستخدام `StudentDateButton` الجديد، وحذف تعريف `_DateBtn` القديم
- [X] T006 [US1] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي (quickstart.md خطوة 3) — زرَّي تاريخ الميلاد وبداية الحضور في الإضافة والتعديل بنفس الشكل بالضبط
- [X] T007 [US1] إنشاء `lib/widgets/student_form/sibling_picker.dart` بدالة `showSiblingPicker(...)` (راجع contracts/shared-widgets.md) تجمع منطق `_pickSibling`/`_addSiblingCandidate` من الملفين، بمعامل `excludeStudentId` اختياري
- [X] T008 [US1] استبدال `_pickSibling`/`_addSiblingCandidate` في `lib/widgets/add_student_sheet.dart` باستدعاء `showSiblingPicker(...)` (بدون `excludeStudentId`)، وحذف الدوال القديمة
- [X] T009 [US1] استبدال `_pickSibling`/`_addSiblingCandidate` في `lib/widgets/edit_student_sheet.dart` باستدعاء `showSiblingPicker(...)` (مع `excludeStudentId: widget.student.id`)، وحذف الدوال القديمة
- [X] T010 [US1] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي (quickstart.md خطوة 4) — ربط/فك ربط إخوة من الإضافة والتعديل، والتأكد أن الطالب الحالي نفسه لا يظهر في نتائج بحث شاشة التعديل
- [X] T011 [US1] إنشاء `lib/widgets/student_form/student_code_field.dart` بويدجت `StudentCodeField` (راجع contracts/shared-widgets.md) يجمع قسم الكود التلقائي/اليدوي + سويتش + زرار مسح QR، مع `onReset` اختياري
- [X] T012 [US1] استبدال قسم الكود في `lib/widgets/add_student_sheet.dart` باستخدام `StudentCodeField` (بدون `onReset`)
- [X] T013 [US1] استبدال قسم الكود في `lib/widgets/edit_student_sheet.dart` باستخدام `StudentCodeField` (مع `onReset: _resetCode`)
- [X] T014 [US1] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي كامل لشاشتي الإضافة والتعديل (كل الحقول، الحفظ، رسائل التحقق — quickstart.md خطوات US1 كاملة)

**Checkpoint**: US1 مكتملة ومستقلة تمامًا عن US2/US3.

---

## Phase 4: User Story 2 - توحيد شيتات تعديل المجموعة المكرَّرة (Priority: P1)

**Goal**: توحيد شيت تعديل المجموعة ومحرر المواعيد ودالة فحص التعارض بين `groups_page.dart` و`group_details_page.dart`.

**Independent Test**: تعديل مجموعة من كل شاشة والتأكد أن الشيت الموحَّد يعمل ويحفظ صح من المكانين (راجع quickstart.md خطوات 1-2 و5).

### Tests for User Story 2

- [X] T015 [P] [US2] إنشاء `test/group_schedule_conflict_test.dart` بـ4 سيناريوهات (راجع quickstart.md): بلا تعارض، تعارض جزئي، تداخل داخل نفس النص، نص تالف/فاضي — تُكتَب مبدئيًا ضد الدالة الحالية `_findConflictingGroup`/`_hasScheduleOverlap` من `groups_page.dart` (import مؤقت) لضمان أن الاختبار يعكس السلوك الحالي **قبل** الدمج

### Implementation for User Story 2 (بترتيب المخاطرة من research.md #6: الأقل خطورة أولًا)

- [X] T016 [US2] إنشاء `lib/views/groups/group_form/group_schedule_conflict.dart` بالدوال الصرفة `parseDaySlots`, `hasScheduleOverlap`, `findConflictingGroup` (نسخة طبق الأصل من `_findConflictingGroup`/`_parseDaySlots` في `groups_page.dart` — النسختان متطابقتان منطقيًا 100%، راجع research.md #4)
- [X] T017 [US2] تحديث `test/group_schedule_conflict_test.dart` (من T015) ليستورد من الملف الجديد `group_schedule_conflict.dart` بدل الدالة القديمة في `groups_page.dart`، والتأكد من نجاح كل السيناريوهات الأربعة
- [X] T018 [US2] استبدال `_findConflictingGroup`/`_hasScheduleOverlap`/`_parseDaySlots` في `lib/views/groups/groups_page.dart` باستيراد من `group_schedule_conflict.dart`، وحذف التعريفات القديمة
- [X] T019 [US2] استبدال `_findConflictingGroupGD`/`_validateScheduleText`/`_parseDaySlotsGD` في `lib/views/groups/group_details_page.dart` باستيراد من `group_schedule_conflict.dart` (مع الإبقاء على رسائل `_validateScheduleText` النصية الخاصة بشاشة التفاصيل لو مختلفة عن رسائل groups_page — راجع الفرق الفعلي وقت التنفيذ)، وحذف التعريفات القديمة المكرَّرة
- [X] T020 [US2] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع، شامل الاختبار الجديد) ثم تحقق يدوي (quickstart.md خطوة 1) — تعارض مواعيد من الشاشتين بنفس الرسائل
- [X] T021 [US2] إنشاء `lib/views/groups/group_form/group_schedule_editor.dart` بويدجت `GroupScheduleEditor` (نسخة طبق الأصل من `_ScheduleEditor` في `groups_page.dart` — صفر فرق سلوكي، راجع research.md #3)
- [X] T022 [US2] استبدال `_ScheduleEditor` في `lib/views/groups/groups_page.dart` باستخدام `GroupScheduleEditor` الجديد، وحذف التعريف القديم (شامل `_ScheduleEntry`)
- [X] T023 [US2] **تعديل وقت التنفيذ**: بمراجعة الكود الفعلي تبيّن إن `_GDScheduleEditor` مختلف بصريًا عن `_ScheduleEditor` (تخطيط مختلف: قائمة يوم بلا تسمية + صندوقين وقت بينهم "-" وتحذير للموعد الناقص، مقابل قائمة يوم بتسمية "اليوم" + صندوقين "من"/"إلى" بتسمية منفصلة) — خلافًا لدالة تعارض المواعيد (سؤال 4) اللي كانت متطابقة 100%. استبداله الآن (قبل T028) كان هيدخل تغيير بصري ظاهر في خطوة المفروض تكون "صفر تغيير" (يخالف توقع CHECKPOINT T024). **القرار**: تأجيل حذف `_GDScheduleEditor`/`_GDScheduleLabel`/`_Slot`/`_TimeBox` لحد T028 (لما `_GroupEditSheet` كله بيتحذف ويتستبدل بـ`GroupFormSheet` أصلًا — وقتها التغيير البصري في محرر المواعيد بيبقى جزء من نفس الاستثناء الموافَق عليه، مش خطوة منفصلة تكسر التوقع).
- [X] T024 [US2] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي (quickstart.md خطوة 2) — إضافة/تعديل/حذف مواعيد من الشاشتين
- [X] T025 [US2] إنشاء `lib/views/groups/group_widgets.dart` بنقل `_PickerSheet`, `_FormLabel`, `_PricingTypeChip`, `_AppearancePreviewTile`, `_ErrorText` من `groups_page.dart` كما هي (ويدجتس مساعدة يحتاجها الشيت الموحَّد الجديد في T026)
- [X] T026 [US2] إنشاء `lib/views/groups/group_form/group_form_sheet.dart` بويدجت `GroupFormSheet` (راجع contracts/shared-widgets.md) — نسخة طبق الأصل من `_GroupFormSheet` الحالي في `groups_page.dart` (اختيار أيقونة/لون/نوع تسعير + تحقق تكرار الاسم/الكود + رسائل خطأ inline)، يستورد الويدجتس المساعدة من `group_widgets.dart` (T025) ومحرر المواعيد من `group_schedule_editor.dart` (T021)
- [X] T027 [US2] استبدال استخدام `_GroupFormSheet` في `lib/views/groups/groups_page.dart` بـ`GroupFormSheet` الجديد، وحذف التعريف القديم بالكامل
- [X] T028 [US2] استبدال استخدام `_GroupEditSheet` في `lib/views/groups/group_details_page.dart` بـ`GroupFormSheet` الجديد (تمرير `group: <المجموعة الحالية>`)، وحذف `_GroupEditSheet` بالكامل — **ملاحظة**: هذه الخطوة تُدخل التغيير السلوكي الموافَق عليه صراحةً (شاشة "تفاصيل المجموعة" تكتسب تعديل أيقونة/لون/نوع تسعير، راجع research.md #2)
- [X] T029 [US2] **CHECKPOINT (الأخطر)**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي كامل (quickstart.md خطوة 5) — تعديل مجموعة من الشاشتين، والتأكد الصريح أن شاشة "تفاصيل المجموعة" أصبحت تعرض اختيار الأيقونة/اللون/نوع التسعير كما هو متوقَّع (وليس عيبًا)

**Checkpoint**: US2 مكتملة — لا نسخ مكرَّرة متبقية لشيت تعديل المجموعة أو محرر المواعيد أو دالة التعارض.

---

## Phase 5: User Story 3 - تقسيم شاشتَي المجموعات لتسهيل التنقل (Priority: P2)

**Goal**: بعد استخراج المشترك (US2)، تقسيم ما تبقى من `groups_page.dart` و`group_details_page.dart` لملفات أصغر بنفس نمط `student_details_page.dart` الحالي في المشروع (كلاس رئيسي + ويدجتس مساعدة في ملف منفصل، راجع research.md #5).

**Independent Test**: فتح شاشتي "المجموعات" و"تفاصيل المجموعة" والتأكد من ظهور كل الأقسام بنفس الشكل والترتيب (quickstart.md خطوة 6).

### Implementation for User Story 3

- [X] T030 [P] [US3] نقل `_GroupCard`, `_SummaryPill` من `lib/views/groups/groups_page.dart` إلى `lib/views/groups/group_widgets.dart` (الملف المُنشأ في T025) كما هي بدون تعديل منطق
- [X] T031 [US3] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي — شاشة "المجموعات" بنفس الكروت والملخصات
- [X] T032 [P] [US3] إنشاء `lib/views/groups/group_details_widgets.dart` ونقل `_HeaderStat`, `_ActionChip`, `_StudentCard`, `_IconBtn` من `lib/views/groups/group_details_page.dart` كما هي بدون تعديل منطق
- [X] T033 [US3] **CHECKPOINT**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي — شاشة "تفاصيل المجموعة": الإحصائيات، قائمة الطلاب، وأزرار الإجراءات
- [X] T034 [P] [US3] نقل `_SendStatBadge`, `_GDSessionDay`, `_GDResumeObserver` من `lib/views/groups/group_details_page.dart` إلى `lib/views/groups/group_details_widgets.dart` (من T032) كما هي بدون تعديل منطق
- [X] T035 [US3] **CHECKPOINT النهائي**: `flutter analyze` + `flutter test` (صفر تراجع) ثم تحقق يدوي كامل (quickstart.md خطوة 6) لشاشتي "المجموعات" و"تفاصيل المجموعة" بكل أقسامهما — والتأكد أن حجم كل ملف من الأربعة الأصلية أصبح ضمن نطاق معقول للقراءة (SC-001)

**Checkpoint**: كل الـUser Stories الثلاثة مكتملة.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T036 [P] مراجعة نهائية: عدد أسطر الملفات الأربعة الأصلية بعد كل التعديلات — النتيجة: `add_student_sheet.dart` 1076→887، `edit_student_sheet.dart` 848→648، `groups_page.dart` 1467→274 (-81%)، `group_details_page.dart` 2704→1842 (-32%). 8 ملفات مشتركة/مساعدة جديدة (student_form/×3، group_form/×3، group_widgets.dart، group_details_widgets.dart) بإجمالي ~2000 سطر منظَّمة حسب الوظيفة. `group_details_page.dart` لسه أكبر ملف (1842 سطر) — الباقي منطق خاص بالشاشة (حوارات/أقسام بناء متعددة) مش مكرَّر ولا سهل الفصل بدون إعادة هيكلة أعمق تتجاوز نطاق "تقسيم بدون تغيير سلوك"؛ يُذكر كتحسين مستقبلي محتمل بدل تنفيذه الآن (Out of Scope في spec.md).
- [X] T037 [P] تشغيل `flutter analyze` كامل للمشروع، والتأكد من مطابقة العدد للأساس المرجعي من T002 بالضبط (صفر جديد)
- [X] T038 [P] تشغيل `flutter test` كامل للمشروع، والتأكد من نجاح كل الاختبارات (شامل `group_schedule_conflict_test.dart` الجديد)
- [X] T039 تحديث `HANDOFF.md` بملخص الـrefactor بعد التحقق الكامل على جهاز حقيقي (نمط الجلسات السابقة — رقم سبيك، الملفات المتأثرة/الجديدة، والاستثناء الوحيد الموافَق عليه من "صفر تغيير سلوك")

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** → **Phase 3 (US1)** و**Phase 4 (US2)**: كلاهما يعتمد فقط على T001 (المجلدات) وT002 (الأساس المرجعي)، مستقلان تمامًا عن بعض بعدها.
- **US1 وUS2 مستقلتان بالكامل** — يمكن تنفيذهما بالتوازي (فريقين مختلفين) أو بالترتيب (أيًا كان)، حسب أولوية المستخدم.
- **US2 → US3**: US3 تعتمد على وجود `group_widgets.dart` و`group_schedule_editor.dart`/`group_form_sheet.dart` من US2 (T025-T028) قبل ما تقسّم باقي الملفين — لازم US2 تخلص الأول.
- **داخل كل Story**: الترتيب الرقمي إلزامي (كل خطوة CHECKPOINT بوابة قبل التالية) — لا تقسيم متوازي داخل نفس الـStory لأن كل خطوة بتحذف كود بتعتمد عليه الخطوة اللي بعدها.

### Parallel Opportunities

- **US1 كامل** مقابل **US2 كامل**: قابلين للتنفيذ بالتوازي (ملفات مختلفة تمامًا) لو فيه أكتر من مطوّر.
- T030 و T032 (بداية US3): ملفات مختلفة، قابلة للتوازي لو اتنفذوا بمعزل عن بعض قبل الـcheckpoints بينهم.
- T036/T037/T038 (Polish): بالتوازي.

---

## Implementation Strategy

### MVP الأول (الأقل خطورة، قيمة فورية)

1. Setup (T001-T002) → US1 كامل (T003-T014) **أو** US2 حتى T024 (قبل شيت المجموعة الأخطر) → **STOP and VALIDATE** على جهاز حقيقي.
2. لو كل حاجة تمام: كمّل باقي US2 (T025-T029، فيها التغيير السلوكي الموافَق عليه) ثم US3.

### Incremental Delivery (بالترتيب المقترح الكامل)

1. Setup → US1 (تقسيم شاشتي الطالب، صفر مخاطرة سلوكية) → تحقق → تسليم جزئي.
2. US2 خطوات T015-T024 (دمج دالة التعارض + محرر المواعيد — صفر مخاطرة سلوكية) → تحقق → تسليم جزئي.
3. US2 خطوات T025-T029 (توحيد شيت تعديل المجموعة — فيه التغيير السلوكي الموافَق عليه، الأخطر في كل السبيك) → تحقق مركَّز خاص → تسليم.
4. US3 (تقسيم باقي الملفين) → تحقق نهائي شامل → Polish → نشر.
