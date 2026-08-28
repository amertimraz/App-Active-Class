---

description: "Task list for أرشفة الطلاب"
---

# Tasks: أرشفة الطلاب

**Input**: Design documents from `specs/002-student-archiving/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: لا يوجد test suite آلي في المشروع (راجع plan.md) — بوابة الجودة هي `flutter analyze` + التحقق اليدوي عبر `quickstart.md`. لا تُنشأ مهام اختبار آلي.

**Organization**: المهام مجمَّعة حسب قصص المستخدم في spec.md لإتاحة تنفيذ/اختبار كل قصة بشكل مستقل.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: قابلة للتنفيذ بالتوازي (ملفات مختلفة، بدون اعتماد على مهام غير مكتملة)
- **[Story]**: القصة اللي تخص المهمة (US1-US4)

---

## Phase 1: Setup

**Purpose**: تجهيز نقطة البداية (لا يوجد مشروع جديد — تعديل داخل مشروع Flutter قائم)

- [X] T001 إنشاء ملف الترحيل `supabase/migration_student_archiving.sql` (هيكل فارغ فقط الآن، يُملأ في Polish) وإضافة سطر توثيقي في أعلاه يشرح الغرض، بنفس أسلوب `supabase/migration_homework.sql` الموجود

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: البنية التحتية اللي كل قصص المستخدم (US1-US4) محتاجاها قبل ما تشتغل

**⚠️ CRITICAL**: لا تبدأ أي قصة مستخدم قبل ما المرحلة دي تخلص بالكامل وتتأكد بـ `flutter analyze`

- [X] T002 إضافة `isArchived` (bool, default false) و `archivedAt` (DateTime?) لكلاس `Student` في `lib/models/student_model.dart` (الحقول، الكونستركتور، `toMap`/`fromMap`، `copyWith`)
- [X] T003 ترقية `DATABASE_VERSION` في `lib/config/constants.dart` وإضافة أعمدة `is_archived`/`archived_at` لجدول `students` في `_createTables` (لتثبيت جديد) وفي `_onUpgrade` عبر `ALTER TABLE` (للتثبيتات القائمة) في `lib/services/database_service.dart` — بنفس نمط ترقيات الأعمدة السابقة الموجودة في نفس الملف
- [X] T004 [P] إضافة `Future<void> archiveStudent(int studentId)` في `lib/services/database_service.dart`: يضبط `is_archived=1, archived_at=now()`، يفكّ أي ربط أخوي (`sibling_id`/`siblings_total`) على الطرفين لو موجود (راجع research.md قرار 3)، يستدعي `_notifyChanged()` و`_queueSync` (لو `teamModeEnabled`) بنفس نمط `updateStudent` الموجود
- [X] T005 [P] إضافة `Future<void> unarchiveStudent(int studentId)` في `lib/services/database_service.dart`: يضبط `is_archived=0, archived_at=NULL`، يستدعي `_notifyChanged()` و`_queueSync`
- [X] T006 [P] إضافة `Future<List<Student>> getActiveStudents()` و `Future<List<Student>> getArchivedStudents()` في `lib/services/database_service.dart` (استعلام `WHERE is_archived = 0/1` على جدول `students`)
- [X] T007 في `lib/controllers/student_controller.dart`: تعديل `loadAllStudents()`/`students`/`filteredStudents` لتُرجع النشطين فقط بشكل افتراضي (راجع research.md قرار 2)، وإضافة `RxList<Student> archivedStudents` جديدة + `Future<void> loadArchivedStudents()`، و `Future<void> archiveStudent(int id)` / `Future<void> unarchiveStudent(int id)` تستدعي دوال `DatabaseService` من T004/T005 ثم تُعيد تحميل القائمتين
- [X] T008 التأكد إن `LicenseController.checkCanAddStudent` (في `lib/controllers/license_controller.dart`) لسه بياخد عدد **كل** الطلاب (نشط+مؤرشف) — تتبّع كل نقاط استدعائه الحالية وتأكيد إنها بتمرر مصدر بيانات غير مفلتر (زي `DatabaseService().getAllStudents().length` أو ما يعادله)، مش `studentController.students.length` بعد تعديل T007 (قرار FR-013)
- [X] T009 تشغيل `flutter analyze` والتأكد من عدم وجود أخطاء جديدة قبل البدء في أي قصة مستخدم

**Checkpoint**: البنية التحتية جاهزة — قصص المستخدم تقدر تبدأ

---

## Phase 3: User Story 1 - أرشفة طالب سايب المجموعة (Priority: P1) 🎯 MVP

**Goal**: المدرس يقدر يأرشف طالب من أي شاشة بيانات طالب، ويختفي فورًا من كل الشاشات والحسابات النشطة مع بقاء بياناته التاريخية كاملة

**Independent Test**: أرشفة طالب من صفحة الطلاب الرئيسية، والتأكد إنه اختفى من القوائم/الحضور/QR/الداشبورد فورًا مع بقاء سجله كامل عند مراجعته لاحقًا (سيناريو 1 في quickstart.md)

### Implementation for User Story 1

- [X] T010 [P] [US1] إضافة زرار/خيار "أرشفة" (بدل أو بجانب "حذف") مع حوار تأكيد في `lib/views/students/students_page.dart` (بديل لـ `_confirmDelete` الحالي أو مضاف بجواره) يستدعي `studentController.archiveStudent(id)`
- [X] T011 [P] [US1] نفس الإضافة في `lib/views/groups/group_details_page.dart` (زرار "أرشفة" لكل طالب في قائمة طلاب المجموعة)
- [X] T012 [P] [US1] نفس الإضافة في `lib/views/students/student_details_page.dart` (زرار "أرشفة" في شاشة تفاصيل الطالب)
- [X] T013 [US1] مراجعة `lib/controllers/dashboard_controller.dart`: التأكد إن كل الاستعلامات (`_loadGeneralStats`, `_loadMonthStats`, إلخ) بتستخدم `studentController.students` (النشطين بس بعد T007) مش `getAllStudents()` مباشرة في أي مكان يتجاوز الفلترة
- [X] T014 [US1] مراجعة `lib/views/attendance/attendance_page.dart`: التأكد إن قوائم تسجيل الحضور بتُبنى من `studentController.students`/`filteredStudents` (النشطين بس) فمفيش طالب مؤرشف يظهر للتحضير
- [X] T015 [US1] مراجعة `lib/controllers/qr_controller.dart` و `lib/views/qr_scanner/qr_scanner_payment_page.dart`: أي بحث بالاسم/الكود بيمر عبر القائمة النشطة؛ وأي مسار بيقرأ طالب مباشرة بالـid (كود QR مطبوع قديم) لازم يتحقق صراحةً `!student.isArchived` بعد الجلب ويعرض رسالة "الطالب مؤرشف" بدل ما يكمل (راجع research.md قرار 5)
- [X] T016 [US1] تشغيل `flutter analyze` + تنفيذ سيناريو 1 و5 و6 من `quickstart.md` يدويًا (أرشفة، تأثير عرض الإخوة، حد الباقة)

**Checkpoint**: القصة الأولى (MVP) شغالة ومختبرة بشكل مستقل

---

## Phase 4: User Story 2 - مراجعة الطلاب المؤرشفين (Priority: P2)

**Goal**: المدرس يقدر يفتح شاشة "الأرشيف" ويشوف بيانات وسجل أي طالب مؤرشف

**Independent Test**: فتح شاشة الأرشيف (بافتراض وجود طلاب مؤرشفين من US1) ومراجعة بيانات وسجل طالب مؤرشف من غيرها (سيناريو 2 في quickstart.md)

### Implementation for User Story 2

- [X] T017 [US2] إنشاء شاشة جديدة `lib/views/students/archived_students_page.dart`: قائمة تُبنى من `studentController.archivedStudents` (تستدعي `loadArchivedStudents()` في `initState`)، تعرض عدد الطلاب المؤرشفين بوضوح (FR-012)
- [X] T018 [US2] ربط عنصر تنقل لشاشة الأرشيف (زرار/أيقونة في `lib/views/students/students_page.dart` أو `lib/views/home_page.dart` حسب الأنسب) + تسجيل المسار في `lib/config/routes.dart` (أو ما يعادله من ملف تعريف الـroutes الحالي)
- [X] T019 [US2] عرض بيانات وسجل الطالب المؤرشف عند الضغط عليه من شاشة الأرشيف — إعادة استخدام `lib/views/students/student_details_page.dart` الموجودة (تمرير الـ`Student` object زي باقي نقاط التنقل الحالية لها) مع التأكد إن تبويبات الحضور/المدفوعات/الامتحانات بتشتغل عادي لطالب مؤرشف (بياناته التاريخية لسه موجودة)
- [X] T020 [US2] تشغيل `flutter analyze` + تنفيذ سيناريو 2 من `quickstart.md` يدويًا

**Checkpoint**: القصتان US1 وUS2 شغالتين مع بعض بشكل مستقل

---

## Phase 5: User Story 3 - استعادة طالب مؤرشف (Priority: P2)

**Goal**: المدرس يقدر يلغي أرشفة طالب من شاشة الأرشيف فيرجع نشط في كل الشاشات فورًا

**Independent Test**: إلغاء أرشفة طالب من شاشة الأرشيف (بافتراض وجود طلاب مؤرشفين) والتأكد إنه رجع نشط في كل الشاشات مع سجله كامل (سيناريو 3 في quickstart.md)

### Implementation for User Story 3

- [X] T021 [US3] إضافة زرار "إلغاء الأرشفة" لكل عنصر في `lib/views/students/archived_students_page.dart` (من T017) يستدعي `studentController.unarchiveStudent(id)` مع حوار تأكيد بسيط، ويزيل الطالب من القائمة فورًا بعد النجاح
- [X] T022 [US3] تشغيل `flutter analyze` + تنفيذ سيناريو 3 من `quickstart.md` يدويًا

**Checkpoint**: القصص US1-US3 شغالة مع بعض — دورة أرشفة/استعادة كاملة

---

## Phase 6: User Story 4 - حذف نهائي لطالب مؤرشف (Priority: P3)

**Goal**: المدرس يقدر يحذف طالب مؤرشف حذف نهائي (غير قابل للتراجع) من شاشة الأرشيف فقط

**Independent Test**: حذف طالب مؤرشف اختباري حذف نهائي من شاشة الأرشيف، والتأكد من زوال كل أثر له؛ والتأكد إن الخيار ده مش متاح لطالب نشط مباشرة (سيناريو 4 في quickstart.md)

### Implementation for User Story 4

- [X] T023 [US4] إضافة زرار "حذف نهائي" في `lib/views/students/archived_students_page.dart` (من T017) بحوار تحذير صريح لا لبس فيه (نص مختلف وأوضح من حوار الأرشفة العادي) يستدعي دالة الحذف الحالية `DatabaseService.deleteStudent`/ما يعادلها (الموجودة بالفعل ومربوطة بـ `ON DELETE CASCADE`) — بدون تعديل منطق الحذف نفسه، فقط نقل نقطة الوصول له
- [X] T024 [US4] إزالة/تعطيل زرار "حذف نهائي" المباشر من الشاشات النشطة (`students_page.dart`, `group_details_page.dart`, `student_details_page.dart`) بحيث يبقى "أرشفة" هو الإجراء الوحيد المتاح مباشرة على طالب نشط (الحذف الفعلي بقى خطوة تانية من داخل الأرشيف بس — FR-008)
- [X] T025 [US4] تشغيل `flutter analyze` + تنفيذ سيناريو 4 من `quickstart.md` يدويًا

**Checkpoint**: كل قصص المستخدم (US1-US4) شغالة ومختبرة

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: تحسينات وتوسعات بتأثر على أكتر من قصة مستخدم — مش شرط لأي MVP لكن مطلوبة لاكتمال المواصفة بالكامل (FR-009: المزامنة)

- [X] T026 [P] ملء `supabase/migration_student_archiving.sql` (من T001) بإضافة `is_archived boolean not null default false` و `archived_at timestamptz` لجدول `students` عبر `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`، بنفس أسلوب ملفات الترحيل السابقة في `supabase/`
- [X] T027 [P] في `lib/services/sync_engine.dart`: إضافة `is_archived`/`archived_at` لحمولة `_buildRemoteRow` الخاصة بـ `TABLE_STUDENTS` (الدفع)، وفك التشفير المقابل في `_toLocalMap` (الاستقبال) — بنفس نمط باقي أعمدة الطالب المُزامَنة حاليًا
- [X] T028 تشغيل ملف الترحيل من T026 فعليًا على قاعدة بيانات Supabase الحية (نفس أسلوب تنفيذ ملفات الترحيل السابقة هذه الجلسة)
- [ ] T029 اختبار حي (سيناريو 7 في quickstart.md) بجهازين في وضع الفريق (مدرس + مساعد) للتأكد من وصول حالة الأرشفة/الاستعادة بين الجهازين — **لسه محتاج جهاز تاني** (جهاز واحد بس كان متاح وقت التنفيذ)
- [X] T030 [P] مراجعة نهائية: البحث في المشروع كله عن أي استخدام مباشر لـ `DatabaseService().getAllStudents()` (بدل `studentController.students`) في شاشات نشطة، للتأكد من عدم تسرّب طالب مؤرشف من مسار منسي
- [X] T031 تشغيل `flutter analyze` نهائي على المشروع كامل، والتأكد من عدم وجود مشاكل جديدة عن الأساس الحالي (38 ملاحظة قديمة معروفة)
- [ ] T032 تنفيذ كل سيناريوهات `quickstart.md` (1-7) كاملة كمراجعة شاملة أخيرة قبل الاعتبار الميزة جاهزة — **سيناريوهات 1، 2، 3 اتنفذوا واتأكدوا فعليًا على جهاز حقيقي (بناء direct-debug + تثبيت) وطلعوا نضاف: أرشفة (مع ديالوج التأكيد)، عرض شاشة الأرشيف (بالتاريخ الصحيح)، استعادة، وحالة الأرشيف الفارغة. باقي سيناريو 4 (حذف نهائي)، 5 (تأثير عرض الإخوة)، 6 (حد الباقة)، و7 (يحتاج جهازين)**

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: بدون اعتماديات — يبدأ فورًا
- **Foundational (Phase 2)**: يعتمد على Setup — **يمنع** أي قصة مستخدم قبل اكتماله بالكامل (خصوصًا T007 اللي بيغيّر معنى `students` المستخدَم في كل مكان)
- **User Stories (Phase 3-6)**: كلها تعتمد على اكتمال Foundational. US1 هي MVP المستقل. US2 وUS3 بيعتمدوا منطقيًا على وجود شاشة أرشيف واحدة (T017) فمن الأفضل تنفيذهم بالترتيب (US2 قبل US3) رغم إنهم مفهوميًا مستقلين. US4 يعتمد على وجود شاشة الأرشيف من US2 أيضًا.
- **Polish (Final Phase)**: يعتمد على اكتمال US1 على الأقل (المزامنة بتغطي حقل موجود بالفعل من Foundational، فتقدر تتنفذ بالتوازي مع US2-US4 لو حابب)

### ملاحظة مهمة على الترتيب الفعلي

على عكس القالب العام، **US2 (T017) شرط تقني مسبق فعليًا لـ US3 وUS4** (شاشة الأرشيف نفسها لازم تكون موجودة قبل ما نضيف عليها زرار الاستعادة أو الحذف النهائي) — لذلك التنفيذ المتسلسل بالترتيب P1→P2→P2→P3 هو الأنسب هنا، مش التوازي الكامل المقترح في القالب العام.

### Parallel Opportunities

- T004, T005, T006 (دوال DatabaseService مختلفة) قابلة للتوازي بعد T002/T003
- T010, T011, T012 (نفس التعديل في 3 شاشات مختلفة) قابلة للتوازي
- T026, T027 (Supabase migration + sync_engine.dart) قابلة للتوازي مع بعض ومع Phase 3-6

---

## Implementation Strategy

### MVP أولًا (User Story 1 فقط)

1. Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1)
2. **توقف وتحقق**: نفّذ سيناريو 1، 5، 6 من quickstart.md
3. في المرحلة دي، الأرشفة شغالة والطالب بيختفي من كل مكان — لكن مفيش طريقة تشوفه تاني إلا برجوع مباشر لقاعدة البيانات. ده MVP مقبول مؤقتًا لو المدرس عايز يجرب الفكرة الأساسية بسرعة، لكن الميزة مش مكتملة عمليًا من غير US2.

### التسليم التدريجي المقترح

1. Setup + Foundational → الأساس جاهز
2. US1 (أرشفة) → تحقق مستقل
3. US2 (شاشة الأرشيف/المراجعة) → تحقق مستقل — **من هنا الميزة بقت مفيدة عمليًا للمدرس**
4. US3 (الاستعادة) → تحقق مستقل — الميزة بقت دورة كاملة (soft delete حقيقي)
5. US4 (الحذف النهائي) → تحقق مستقل
6. Polish (المزامنة + المراجعة النهائية) → اكتمال المواصفة بالكامل

---

## Notes

- لا توجد مهام اختبار آلي (لا يوجد test suite في المشروع) — كل تحقق عبر `flutter analyze` + سيناريوهات `quickstart.md` اليدوية.
- كل مهمة `flutter analyze` مطلوب تنفيذها فعليًا وتصفير أي مشاكل جديدة قبل الانتقال للمهمة التالية — نفس الانضباط المتبع طوال هذه الجلسة.
- كومت (commit) مقترح بعد كل Checkpoint (نهاية كل Phase) وليس بعد كل مهمة فردية، بنفس نمط الكومتات المستخدم في هذه الجلسة.
