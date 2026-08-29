---

description: "Task list for three-sibling-group support"
---

# Tasks: دعم ربط 3 إخوة بخصم مشترك

**Input**: Design documents from `/specs/007-three-sibling-support/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md)

**Tests**: لم تُطلَب اختبارات آلية — التحقق عبر [quickstart.md](quickstart.md) اليدوي/على الجهاز، مع تركيز خاص على اختبار الـmigration على بيانات حقيقية (راجع تحذير quickstart.md).

**Organization**: المهام مقسَّمة حسب قصص المستخدم في spec.md. المرحلة التأسيسية (Foundational) إلزامية قبل أي قصة — كل القصص بتعتمد على وجود `sibling_group_id` وdالة `getStudentsInSiblingGroup`.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

مشروع Flutter موحّد واحد — المسارات نسبةً لجذر `C:\repo\active_class`.

---

## Phase 1: Foundational (البنية التحتية لمجموعة الإخوة)

**Purpose**: إضافة العمود الجديد، الـmigration، وحقل الموديل + دالة القراءة الأساسية — كل القصص التالية تعتمد عليها.

**⚠️ CRITICAL**: لا تبدأ أي قصة مستخدم قبل اكتمال هذه المرحلة والتحقق من الـmigration على بيانات حقيقية.

- [X] T001 في [lib/config/constants.dart](../../lib/config/constants.dart): ارفع `DATABASE_VERSION` من 17 إلى 18، وأضف ثابت جديد `COL_STUDENT_SIBLING_GROUP_ID = 'sibling_group_id'`.
- [X] T002 في [lib/models/student_model.dart](../../lib/models/student_model.dart): أضف حقل `final int? siblingGroupId;` + في `toMap`/`fromMap` + في `copyWith` (مع باراميتر `bool clearSiblingGroupId = false` زي `clearSiblingId` الموجود بالفعل).
- [X] T003 في [lib/services/database_service.dart](../../lib/services/database_service.dart)، داخل `_onUpgrade`: أضف كتلة migration لـ`oldVersion < 18`: `ALTER TABLE students ADD COLUMN sibling_group_id INTEGER`، ثم امسح كل صفوف `sibling_id IS NOT NULL`، وللأزواج المتبادلة صحيحة (`A.sibling_id == B.id AND B.sibling_id == A.id`) احسب `groupId = min(A.id, B.id)` واكتبه في `sibling_group_id` للاثنين (راجع القرار 2 في research.md — تجاهل أي حالة غير متبادلة بأمان بدون فشل الـmigration).
- [X] T004 في [lib/services/database_service.dart](../../lib/services/database_service.dart): أضف دالة جديدة `Future<List<Student>> getStudentsInSiblingGroup(int groupId, {int? excludeId})` — `SELECT * FROM students WHERE sibling_group_id = ?` مع استثناء `excludeId` لو موجود.

**Checkpoint**: نفّذ سيناريو 1 من quickstart.md (migration على بيانات فيها زوج أخوين حقيقي قديم) قبل المتابعة.

---

## Phase 2: User Story 1 - ربط 3 إخوة بإجمالي مشترك واحد (Priority: P1) 🎯 MVP

**Goal**: المدرس يقدر يربط حتى 3 طلاب مع بعض بإجمالي شهري مشترك، والمستحق الشهري لكل واحد = الإجمالي ÷ عدد الأعضاء الفعلي.

**Independent Test**: سيناريوهات 2 و3 من quickstart.md.

### Implementation for User Story 1

- [X] T005 [US1] في [lib/services/database_service.dart](../../lib/services/database_service.dart): عدّل/أضف دالة الربط (بديل `linkSiblings(s1, s2)` الحالية) لتقبل مجموعة طلاب (2 أو 3) وتكتب نفس `sibling_group_id` (أصغر ID بينهم) و`siblings_total` لكل الأعضاء داخل transaction واحدة، مع فحص FR-007 (رفض لو الناتج > 3 أعضاء).
- [X] T006 [US1] في [lib/controllers/student_controller.dart](../../lib/controllers/student_controller.dart): حدّث `linkSiblings` لتستدعي الدالة الجديدة، وتُحدِّث `students` المحليّة لكل الأعضاء المتأثرين (مش بس 2).
- [X] T007 [US1] في [lib/utils/pricing_helper.dart](../../lib/utils/pricing_helper.dart)، داخل `monthlyDue`: بدل `base = student.siblingsTotal! / 2.0` الثابتة، احسب عدد أعضاء مجموعة الطالب الفعلي (عبر `sibling_group_id`، إمّا بتمرير `memberCount` كباراميتر من الكونترولر المستدعي، أو استعلام مباشر) واقسم `siblingsTotal! / memberCount`.
- [X] T008 [US1] في [lib/widgets/add_student_sheet.dart](../../lib/widgets/add_student_sheet.dart) و[lib/widgets/edit_student_sheet.dart](../../lib/widgets/edit_student_sheet.dart): بدّل حالة `Student? _sibling` بقائمة `List<Student> _siblings` (بحد أقصى عضوين إضافيين)، مع زرار "إضافة عضو تالت" يظهر لما يكون عدد الأعضاء الحاليين في المجموعة أقل من 3، ومعطَّل (برسالة) لو وصل لـ3.
- [X] T009 [US1] في نفس الملفين: حدّث عرض "الأخ/الأخت" ليعرض **كل** الأعضاء الآخرين في المجموعة (اسم + كود لكل واحد) بدل اسم واحد بس.

**Checkpoint**: US1 شغالة ومختبَرة — نفّذ سيناريوهات 2، 3 من quickstart.md.

---

## Phase 3: User Story 2 - دفع عبر QR لمجموعة من 3 إخوة (Priority: P1)

**Goal**: مسح QR لأي عضو في مجموعة إخوة (2 أو 3) يوزّع المبلغ المقترح صح ويسجّل دفعة منفصلة لكل عضو بنصيبه.

**Independent Test**: سيناريو 4 من quickstart.md.

### Implementation for User Story 2

- [X] T010 [US2] في [lib/controllers/qr_controller.dart](../../lib/controllers/qr_controller.dart): بدّل منطق إنشاء `p1`/`p2` الثابت (قسمة `/2.0`) بحلقة تُنشئ دفعة لكل عضو في `getStudentsInSiblingGroup(groupId)` (شامل الطالب الممسوح)، بنصيب `total / memberCount` لكل واحد، ونص `note` يعكس `siblings=$memberCount` بدل `siblings=2` الثابتة.
- [X] T011 [US2] في نفس الملف، دالة حساب المبلغ المقترح (`_computeBaseAmount`/ما يعادلها): تأكد أنها بتستخدم نفس `memberCount` الديناميكي بدل `/2.0`. (ملاحظة: `_computeBaseAmount` نفسها بتفضل بتستخدم سعر الطالب الفردي — عرض الإخوة بيتطبّق بشكل منفصل قبلها في `confirmPayment`/`_recalculateTotal`، فمفيش داعي لتعديلها.)

**Checkpoint**: US2 شغالة ومختبَرة — نفّذ سيناريو 4 من quickstart.md.

---

## Phase 4: User Story 3 - فك الربط الجزئي أو الكامل (Priority: P2)

**Goal**: فك ربط عضو واحد من مجموعة 2-3 إخوة لا يفكّ باقي المجموعة؛ الحد الأقصى 3 مُطبَّق؛ الأرشفة تفكّ ربط عضو واحد بس.

**Independent Test**: سيناريوهات 5، 6، 7 من quickstart.md.

### Implementation for User Story 3

- [X] T012 [US3] في [lib/widgets/edit_student_sheet.dart](../../lib/widgets/edit_student_sheet.dart): زرار "فك الربط" الحالي (لطالب واحد) يمسح `sibling_group_id` (و`siblings_total`) لهذا الطالب بس، من غير ما يمسّ باقي أعضاء المجموعة.
- [X] T013 [US3] في [lib/services/database_service.dart](../../lib/services/database_service.dart)، داخل `archiveStudent`: عمّم منطق فك الربط الحالي (كان بيمسح `sibling_id`/`siblings_total` للطالب المؤرشف وللطرف التاني بس) ليمسح فقط بيانات الطالب المؤرشف نفسه (`sibling_group_id = null`)، من غير ما يأثر على باقي أعضاء المجموعة (لو كانت 3، الاتنين الباقيين يفضلوا مرتبطين).
- [X] T014 [US3] تأكد (مراجعة كود) أن فحص الحد الأقصى 3 (من T005) بيرفض أي محاولة إضافة عضو رابع من أي مسار (إضافة/تعديل)، برسالة توضيحية واضحة.

**Checkpoint**: US3 شغالة ومختبَرة — نفّذ سيناريوهات 5، 6، 7 من quickstart.md.

---

## Phase 5: Polish & Verification

- [X] T015 راجع كل استخدامات `student.siblingId`/`student.siblingsTotal` المتبقية في الكود (`grep -r siblingId lib/`) وتأكد أن كل مسار فعلي (مش عرض قديم متروك عمدًا) بقى بيعتمد على `siblingGroupId` بدل `siblingId`. (المتبقي: تعريف الحقل في `student_model.dart`، fallback القراءة القديم في `pricing_helper.dart`/`edit_student_sheet.dart`/`archiveStudent` — كلها موثّقة كـ"توافق قديم" متروكة عمدًا.)
- [X] T016 نفّذ سيناريو 1 من [quickstart.md](quickstart.md) (الـmigration) على نسخة من بيانات حقيقية فيها زوج أخوين قديم — **إلزامي قبل أي نشر**. (اتنفّذ فعليًا على الجهاز الحقيقي: 6 أزواج إخوة حقيقية موجودة اتحوّلت تلقائيًا لـ`sibling_group_id` صحيح — تحقّقنا بمقارنة نسخة قبل/بعد الـmigration، بدون أي تدخل يدوي، والتطبيق شغّال طبيعي بعدها بـ155 طالب حقيقي.)
- [X] T017 شغّل `flutter analyze` للتأكد من عدم وجود أخطاء/تحذيرات جديدة. (نظيف — نفس الملاحظات القديمة الموجودة قبل هذه الميزة بس.)

---

## Dependencies & Execution Order

- **Foundational (Phase 1)**: يبلوك كل القصص — لازم يكتمل ويتحقق منه (خصوصًا الـmigration) الأول.
- **US1 (Phase 2)**: يعتمد على Phase 1.
- **US2 (Phase 3)**: يعتمد على Phase 1 وT005 (دالة الربط الجديدة) من US1 — لكن مستقلة وظيفيًا عن باقي US1.
- **US3 (Phase 4)**: يعتمد على Phase 1 وT005.
- **Polish (Phase 5)**: يعتمد على اكتمال كل القصص.

## Implementation Strategy

### MVP First

1. Foundational (T001-T004) → تحقق الـmigration (سيناريو 1) — **لا تكمل قبل ده**.
2. US1 (T005-T009) → تحقق سيناريوهات 2، 3.
3. US2 (T010-T011) → تحقق سيناريو 4.
4. US3 (T012-T014) → تحقق سيناريوهات 5، 6، 7.
5. Polish (T015-T017).

## Notes

- **هذه الميزة تمس بيانات مالية حقيقية** (أزواج إخوة موجودة بالفعل عند مدرسين) — الـmigration (T003) والتحقق منه (T016) أهم خطوة في الميزة كلها، ويُفضَّل تنفيذهم واختبارهم بمعزل عن باقي التعديلات قبل المتابعة.
- الأعمدة القديمة (`sibling_id`, `siblings_total`) لا تُحذف من المخطط (راجع القرار 2 في research.md) — تُترك غير مُستخدَمة بعد اكتمال الانتقال.
