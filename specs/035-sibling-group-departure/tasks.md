---

description: "Task list for feature implementation"
---

# Tasks: تعديل مجموعة الإخوة عند خروج عضو

**Input**: Design documents from `/specs/035-sibling-group-departure/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: اختبار وحدة واحد لمنطق `pricing_helper.dart` الصرف (الأهم — منطق مالي)؛ باقي التحقق يدوي عبر quickstart.md (نفس نمط specs 032/033 السابقة).

**Organization**: مُقسّمة حسب قصتي المستخدم في spec.md (US1/US2).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup (البنية المحلية)

- [ ] T001 إضافة `COL_STUDENT_SIBLING_GROUP_COMMITTED_COUNT` في `lib/config/constants.dart`
- [ ] T002 عمود جديد + migration (`oldVersion < 33`) في `lib/services/database_service.dart`، ورفع `DATABASE_VERSION` لـ٣٣
- [ ] T003 [P] كتابة `supabase/migration_sibling_group_committed_count.sql` (عمود نصي/رقمي عادي على `students`)

**Checkpoint**: العمود موجود محليًا وعلى السيرفر — بلا أي منطق عمل لسه.

---

## Phase 2: Foundational (الحقل + المزامنة + التحديث عند الربط)

**Purpose**: بنية مشتركة لازمة لكل القصص — حظر إلزامي قبلها.

- [ ] T004 إضافة `siblingGroupCommittedCount` في `lib/models/student_model.dart` (toMap/fromMap/copyWith)
- [ ] T005 `lib/services/sync_engine.dart`: إضافة الحقل لـ`_buildRemoteRow`/`_toLocalMap` (TABLE_STUDENTS) — نسخ مباشر بلا ترجمة remote_id، بنفس نمط `siblings_total`
- [ ] T006 `database_service.dart.linkSiblingGroup`: ضبط `committedCount = عدد الأعضاء` وقت كل ربط أولي (مع الـuuid الحالي، بلا تغيير في باقي المنطق)
- [ ] T007 تطبيق `migration_sibling_group_committed_count.sql` على قاعدة الإنتاج عبر SSH

**Checkpoint**: الحقل موجود، بيتزامن، وبيتحدّث صح عند أي ربط إخوة جديد — القصص جاهزة تُبنى فوقه.

---

## Phase 3: User Story 1 - المدرس بياخد قرار واعي (Priority: P1) 🎯 MVP

**Goal**: منع القفزة الصامتة في المديونية + عرض تنبيه قرار واضح.

**Independent Test**: سيناريوهات ١-٣ و٥-٦ في quickstart.md.

### Tests for User Story 1

- [ ] T008 [P] [US1] اختبار وحدة لدالة `siblingGroupDepartureAlert` الجديدة في `test/pricing_helper_departure_test.dart` — يغطي: لا فرق (null)، فرق عضو واحد (٣→٢)، عودة العدد (استرجاع، null تاني)، حالة عضوين→واحد (خارج النطاق، بلا تفاعل)

### Implementation for User Story 1

- [ ] T009 [US1] `lib/utils/pricing_helper.dart`: دالة `siblingGroupDepartureAlert(student, allStudents)` — مقارنة `siblingGroupSize` الحي بـ`committedCount` المخزَّن (يحقق FR-001/FR-007)
- [ ] T010 [US1] `pricing_helper.dart.monthlyDue`: تغيير القاسم في فرع مجموعة الإخوة من `siblingGroupSize(...)` الحي لـ`committedCount` المخزَّن (يحقق FR-004 — الحماية الفعلية، مش بس العرض)
- [ ] T011 [P] [US1] widget حوار جديد `lib/widgets/sibling_departure_dialog.dart` — عرض الاسم/المبلغ/العدد القديم والجديد + إجراءات (تأكيد/تعديل/لاحقًا) حسب `contracts/departure-decision-dialog.md`
- [ ] T012 [US1] دالة تحديث في `database_service.dart` (مثلاً `confirmSiblingGroupDeparture`) تحفظ `committedCount` الجديد (+ `siblingsTotal` لو اتعدّل) لكل الأعضاء الباقيين معًا (تحديث ذري، بنفس نمط `linkSiblingGroup`) + `_queueSync` لكل عضو
- [ ] T013 [US1] استدعاء الحوار عند فتح `lib/views/groups/group_details_page.dart` لو فيه عضو متأثر (يحقق FR-002/FR-008)
- [ ] T014 [US1] استدعاء الحوار عند فتح `lib/views/students/student_details_page.dart` لعضو متأثر

**Checkpoint**: قصة ١ قابلة للاختبار المستقل بالكامل — هذا هو الـMVP الفعلي (يقفل البلاغ الأساسي).

---

## Phase 4: User Story 2 - سجل الطالب اللي خرج يفضل سليم (Priority: P2)

**Goal**: تأكيد (مش بناء من الصفر — المنطق الحالي في `archiveStudent`/`deleteStudent` أصلاً بيحافظ على السجل التاريخي) إن الإصلاح الجديد مبيلمسش بيانات الطالب اللي خرج.

**Independent Test**: سيناريو ٤ في quickstart.md.

### Implementation for User Story 2

- [ ] T015 [US2] مراجعة يدوية: التأكد إن T010/T012 مبتلمسش أي صف حضور/دفعة تاريخي للطالب اللي خرج ولا للباقيين (قراءة فقط لسجلاتهم القديمة)
- [ ] T016 [US2] تنفيذ سيناريو ٤ من quickstart.md وتوثيق النتيجة

**Checkpoint**: القصتان شغّالتان معًا — الإصلاح الأساسي (US1) مؤكَّد إنه بلا أي أثر جانبي على البيانات التاريخية (US2).

---

## Phase 5: Polish

- [ ] T017 [P] تشغيل كل سيناريوهات quickstart.md الستة كتحقق نهائي شامل
- [ ] T018 تحديث `HANDOFF.md` والميموري بتفاصيل spec 035

---

## Dependencies & Execution Order

- **Setup (Phase 1)** → **Foundational (Phase 2)** يحظر كل القصص.
- **US1 (Phase 3)**: يعتمد على Foundational فقط — أول قصة تُبنى (MVP، يقفل البلاغ الأساسي).
- **US2 (Phase 4)**: يعتمد على US1 مكتملة (بيتحقق من أثرها، مش قصة منفصلة تقنيًا) — لسه بأولوية أقل لأنها تحقّق مش بناء.
- **Polish (Phase 5)**: بعد اكتمال الاتنين.

### Parallel Opportunities

- T003 (migration SQL) يتوازى مع T001/T002.
- T008 (اختبار الوحدة) يُكتب أول (TDD) قبل T009، ومستقل عن T011 (الحوار).
- T011 (الحوار) يتوازى مع T009/T010 (منطق مختلف تمامًا، ملف مختلف).

## Implementation Strategy

### MVP أولًا (US1 فقط)

1. Setup + Foundational.
2. US1 كاملة → تحقّق بسيناريوهات ١-٣، ٥-٦.
3. **هنا الباگ الأساسي مقفول فعليًا.**
4. US2 (تحقّق سريع، مش بناء جديد) → Polish.
