# Tasks: الملازم والكتب — إدارة التسعير والتسليم والتحصيل

**Input**: Design documents from `specs/041-booklets-tracking/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/booklet-math.md, contracts/booklet-controller.md, quickstart.md

**Tests**: اختبار وحدة للدوال الصرفة (`test/booklet_math_test.dart`). باقي التحقق يدوي على جهاز حقيقي + جهازين للمزامنة (لا widget tests، اتساقًا مع specs 038–040).

**Organization**: حسب الـUser Stories (US1 إنشاء وتوزيع، US2 تسليم، US3 دفع، US4 متابعة/تفاصيل طالب). Foundational يشمل المخطط والمزامنة لأنها مشتركة بين كل الـStories.

## Format: `[ID] [P?] [Story?] Description`
- **[P]**: ممكن بالتوازي (ملفات مختلفة بلا تبعية)
- ملفات المسار نسبية لجذر المشروع `C:\repo\active_class`

---

## Phase 1: Setup

- [x] T001 في `lib/config/constants.dart`: رفع `DATABASE_VERSION` من 34 إلى 35؛ إضافة ثوابت الجداول الأربعة `TABLE_BOOKLETS='booklets'`, `TABLE_BOOKLET_GROUPS='booklet_groups'`, `TABLE_BOOKLET_RECORDS='booklet_records'`, `TABLE_BOOKLET_PAYMENTS='booklet_payments'` وأعمدتها `COL_BK_*` / `COL_BG_*` / `COL_BR_*` / `COL_BP_*` بنمط `COL_SO_*` (راجع data-model.md)؛ وَ`ROUTE_BOOKLETS='/booklets'` وَ`ROUTE_BOOKLET_DETAILS='/booklet_details'`

---

## Phase 2: Foundational (blocking prerequisites)

- [x] T002 [P] إنشاء `lib/models/booklet_model.dart`: `Booklet`, `BookletGroupLink`, `BookletRecord`, `BookletPayment` بـ`toMap`/`fromMap`/`copyWith` بنمط `Payment`/`Attendance` (راجع data-model.md)
- [x] T003 [P] إنشاء `lib/utils/booklet_math.dart` بالدوال الصرفة حسب `contracts/booklet-math.md`: `bookletPaid`, `bookletRemaining`, `bookletOverpaid`, `bookletPaymentStatus` (+ enum), `eligibleStudents`, `historicalStudents`, `studentBookletsRemaining`
- [x] T004 [P] إنشاء `test/booklet_math_test.dart` بالسيناريوهات السبعة في quickstart.md (شامل سعر 0، زيادة الدفع، تخفيض السعر بعد دفعات، مؤرشف/مستثنى)
- [x] T005 في `lib/services/database_service.dart`: تعريف `_bookletsTableSql`/`_bookletGroupsTableSql`/`_bookletRecordsTableSql`/`_bookletPaymentsTableSql` + فهارس UNIQUE `(booklet_id, group_id)` و`(booklet_id, student_id)` بنمط `_sessionOverridesTableSql`؛ تنفيذها في `_onCreate` (بجانب سطر ~368) وفي `_onUpgrade` داخل `if (oldVersion < 35)` (بعد فرع `< 34`) بـtry/catch
- [x] T006 في `lib/services/database_service.dart`: CRUD للجداول الأربعة بنمط `insertPayment`/`insertSessionOverride`: كل كتابة `_notifyChanged()` + `_queueSync(...)`؛ وحذف `_queueDelete(...)`؛ إضافة upsert كسول `upsertBookletRecord(bookletId, studentId, {delivered, excluded})` وقراءات: كل الملازم، الروابط، السجلات، الدفعات (لكل ملزمة ولكل طالب)
- [x] T007 في `lib/services/database_service.dart`: `deleteBooklet(int id)` بنفس نمط `deleteExam` (سطر ~2438): التقاط remote_id للأبناء (`booklet_groups`, `booklet_records`, `booklet_payments`) قبل الحذف المحلي ثم `_queueDelete` لكل ابن ثم الملزمة؛ وإرجاع أرقام (عدد التسليمات، إجمالي المدفوع) عبر دالة قراءة منفصلة `getBookletDeleteImpact(id)` لاستخدامها في رسالة التأكيد
- [x] T008 في `lib/services/database_service.dart`: إضافة التقاط/`_queueDelete` لصفوف `booklet_records` و`booklet_payments` التابعة للطالب داخل `deleteStudent` (سطر ~1334، بجانب التقاط `TABLE_PAYMENTS` ~1370)، ولصفوف `booklet_groups` + records/payments طلاب المجموعة داخل `deleteGroup` (~947) و`deleteStudentsByGroup` (~1036) بنفس أسلوب التقاط `TABLE_PAYMENTS` الموجود (أسطر ~971 و~1107) — لمنع صفوف يتيمة عند الطرف التاني
- [x] T009 [P] في `lib/services/sync_engine.dart`: إضافة الجداول الأربعة إلى `_tables` في **آخر** القائمة بترتيب `booklets`→`booklet_groups`→`booklet_records`→`booklet_payments`، وإلى `_extendedTables` (مش `_coreTables`)، وإلى `_pkCol` (4 حالات)
- [x] T010 في `lib/services/sync_engine.dart`: push mapping (نمط `TABLE_SESSION_OVERRIDES` سطر ~591): `booklet_groups` بـ`booklet_remote_id`+`group_remote_id`، `booklet_records`/`booklet_payments` بـ`booklet_remote_id`+`student_remote_id` (`return null` لو أب بلا remote_id بعد)؛ حقول `booklets` (name, price, created_at)
- [x] T011 في `lib/services/sync_engine.dart`: pull mapping (نمط ~1544) العكسي بـ`_localIdForRemote` مع `return null` لو الأب لسه ما وصلش؛ وreload switch (~1074): استدعاء `BookletController.load()` لو مسجّل لأي من الجداول الأربعة
- [x] T012 في `lib/services/sync_engine.dart`: reconcile duplicates (نمط spec 032 سطر ~1292) لـ`booklet_records` على `(booklet_id, student_id)` وَ`booklet_groups` على `(booklet_id, group_id)` عبر `_reconcileDuplicate`
- [x] T013 [P] إنشاء `supabase/migration_booklets.sql` بنفس قالب `migration_session_overrides.sql`: 4 جداول (uuid PK، team_id، origin_device_id، local_id، FKs بـ`*_remote_id` → الجداول المقابلة ON DELETE CASCADE، updated_at، deleted_at، unique(team_id,origin_device_id,local_id))، RLS (select/insert/update بـ`is_team_member`+`is_team_license_active`)، trigger حذف يعيد استخدام `delete_payments`، `trg_set_updated_at`، `replica identity full`، publication realtime
- [x] T014 التحقق من ملكية جداول السيرفر (`select tableowner from pg_tables where tablename='payments'`) ثم تطبيق `supabase/migration_booklets.sql` عبر SSH بمستخدم `supabase_admin` (نفس أمر spec 040)، والتأكد من ظهور الجداول الأربعة
- [x] T015 إنشاء `lib/controllers/booklet_controller.dart` (GetX) بالحالة (`booklets`, `links`, `records`, `payments`) وَ`load()` وتسجيله (`Get.put`) عند الحاجة، حسب `contracts/booklet-controller.md` — بدون عمليات الـStories بعد
- [ ] T016 **CHECKPOINT**: `flutter analyze` + `flutter test` (شامل T004) صفر تراجع؛ تشغيل التطبيق على جهاز والتأكد إن ترقية DB لـv35 بدون كراش

**Checkpoint**: المخطط والمزامنة والدوال الصرفة جاهزة.

---

## Phase 3: User Story 1 - إنشاء ملزمة وتوزيعها على مجموعة (Priority: P1) 🎯 MVP

**Goal**: إنشاء/تعديل/حذف ملزمة، ربطها بمجموعات، ظهور المؤهَّلين تلقائيًا، واستثناء طالب.

**Independent Test**: ملزمة بسعر 50 على مجموعة 10 طلاب → يظهر الكل بمتبقي 50؛ استثناء طالب يختفي؛ طالب جديد يظهر تلقائيًا؛ تعديل السعر يحدّث المتبقي (quickstart.md بند 1).

- [x] T017 [US1] في `booklet_controller.dart`: `createBooklet`, `updateBooklet` (مع مزامنة روابط المجموعات: إضافة/إزالة صفوف `booklet_groups`), `deleteBooklet`, `setExcluded` (upsert كسول، لا يمسح دفعات) حسب العقد
- [x] T018 [US1] في `booklet_controller.dart`: `rowsFor(bookletId)` يعتمد `getStudentsByGroup` لكل مجموعة مربوطة + السجلات + الدفعات ثم `eligibleStudents`/`booklet_math` (المتبقي = السعر كاملًا لحد ما US3)
- [x] T019 [P] [US1] إنشاء `lib/views/booklets/booklets_page.dart`: قائمة الملازم (اسم، سعر، عدد المجموعات/المؤهَّلين)، زر إضافة، نافذة إنشاء/تعديل (اسم + سعر ≥0 + اختيار مجموعات متعدد من `GroupController`)، وحذف بتأكيد يعرض `getBookletDeleteImpact` (عدد التسليمات وإجمالي المدفوع) ويستخدم `canDeletePaymentsNow`
- [x] T020 [P] [US1] إنشاء `lib/views/booklets/booklet_details_page.dart`: قائمة المؤهَّلين (اسم، كود، المتبقي، حالة "لم تُسلَّم") + إجراء "استثناء" لطالب بتأكيد يذكر مبلغ دفعاته المسجَّلة (لو فيه) وأنها ستبقى، + إجراء "إلغاء الاستثناء" من قائمة المستثنين
- [x] T021 [US1] تسجيل `GetPage` للمسارين في `lib/main.dart` (بجانب سطر ~257/269) وإضافة `_DrawerItem` "الملازم" في `lib/views/home_page.dart` بجانب "بنك الأسئلة" (سطر ~1258) يفتح `ROUTE_BOOKLETS`
- [ ] T022 [US1] **CHECKPOINT**: `flutter analyze` + `flutter test` ثم تحقق يدوي (quickstart.md بند 1)

**Checkpoint**: US1 مكتملة — MVP.

---

## Phase 4: User Story 2 - تسجيل التسليم مستقلًا عن الدفع (Priority: P1)

**Goal**: تسليم/إلغاء تسليم بضغطة، بلا أي ارتباط بالدفع، مع فلتر "لم يستلم".

**Independent Test**: تسليم بلا دفع، إلغاء التسليم، فلتر "لم يستلم بعد" (quickstart.md بند 2).

- [x] T023 [US2] في `booklet_controller.dart`: `setDelivered(bookletId, studentId, delivered)` (upsert كسول + `delivered_at`) وإضافة `BookletFilter` للتسليم (الكل/لم يستلم/استلم) في `rowsFor`
- [x] T024 [US2] في `booklet_details_page.dart`: مفتاح/زرار تسليم لكل صف (تبديل تم/لم يتم)، وشريط فلتر التسليم؛ المتاح لأي مستخدم (بدون قيد الصلاحية المالية)
- [ ] T025 [US2] **CHECKPOINT**: `flutter analyze` + `flutter test` ثم تحقق يدوي (quickstart.md بند 2)

---

## Phase 5: User Story 3 - الدفع الكامل أو الجزئي (Priority: P1)

**Goal**: دفعات بمبالغ دقيقة، متبقي وحالة مشتقين، رفض التجاوز، وفصل تام عن دفعات الاشتراك.

**Independent Test**: سعر 100: 40 ثم 60 → مدفوع بالكامل؛ تجاوز المتبقي مرفوض؛ حذف دفعة يعيد القيم؛ أرقام الاشتراك لا تتغيّر إطلاقًا (quickstart.md بند 3).

- [x] T026 [US3] في `booklet_controller.dart`: `addPayment` (يرجّع رسالة خطأ عربية لو المبلغ ≤ 0 أو > المتبقي)، `deletePayment`، وتوسيع `rowsFor` بالمدفوع/المتبقي/الحالة/الزيادة عبر `booklet_math` + فلتر حالة الدفع (الكل/لم يدفع/جزئي/كامل) في `BookletFilter`
- [x] T027 [US3] في `booklet_details_page.dart`: عرض شارة حالة الدفع (لم يدفع/جزئي/كامل) والمدفوع/المتبقي لكل صف، وbottom sheet لطالب: إضافة دفعة (مبلغ + تاريخ، زر تعبئة "المتبقي بالكامل")، قائمة دفعاته مع حذف محروس بـ`canDeletePaymentsNow`، ومؤشر "زيادة دفع" لو وُجدت؛ إخفاء كل الأرقام المالية والدفع عمن ليس `canSeeFinancials` (يبقى التسليم فقط)
- [x] T028 [US3] التحقق (قراءة كود + grep) إن لا ملف من `pricing_helper.dart`/`payment_controller.dart`/`dashboard_controller.dart`/`report_controller.dart`/`export_service.dart` اتعدّل أو بيقرأ جداول الملازم (FR-008/FR-009/SC-004)
- [ ] T029 [US3] **CHECKPOINT**: `flutter analyze` + `flutter test` ثم تحقق يدوي (quickstart.md بند 3) — مع مقارنة "مديونية متراكمة" و"دفعوا اليوم" و"إجمالي المحصّل" قبل/بعد تسجيل دفعات ملازم

---

## Phase 6: User Story 4 - المتابعة الشاملة وقسم الملازم في تفاصيل الطالب (Priority: P2)

**Goal**: ملخص لكل ملزمة، وقسم الملازم + "متبقي ملازم" في تفاصيل الطالب، وحفظ السجل التاريخي عند الأرشفة/النقل.

**Independent Test**: ملزمتان بحالات مختلطة → أرقام الملخص صحيحة، وتفاصيل الطالب تعرض ملازمه وإجمالي "متبقي ملازم" منفصلًا (quickstart.md بند 4/5).

- [x] T030 [US4] في `booklet_controller.dart`: `summaryFor(bookletId)` (مسلَّم/غير مسلَّم، كامل/جزئي/بلا، إجمالي المحصَّل، إجمالي المتبقي)، `linesForStudent(studentId)` (+ `studentBookletsRemaining`)، وعرض "السجل التاريخي" عبر `historicalStudents` (مؤرشف/مستثنى/منقول عنده تسليم أو دفعة)
- [x] T031 [P] [US4] في `booklets_page.dart`: عرض ملخص `summaryFor` تحت كل ملزمة (شرائح: مسلَّم/لم يُسلَّم، دفع كامل/جزئي/بلا، محصَّل، متبقي)، والأرقام المالية مخفية عمن ليس `canSeeFinancials`
- [x] T032 [P] [US4] في `booklet_details_page.dart`: مفتاح "عرض السجل التاريخي" يضم طلابًا مؤرشفين/مستثنين/منقولين لديهم بيانات (للقراءة، بدون إدراجهم في القوائم التشغيلية)
- [x] T033 [P] [US4] في `lib/views/students/student_details_page.dart` (تاب المدفوعات `_PaymentsTab`): قسم "الملازم" يعرض لكل ملزمة حالة التسليم + المدفوع/المتبقي، وإجمالي "متبقي ملازم" بعنوان صريح ومنفصل بصريًا عن كارت "مديونية متراكمة"؛ الطالب بلا ملازم = القسم مخفي
- [ ] T034 [US4] **CHECKPOINT النهائي**: `flutter analyze` + `flutter test` ثم تحقق يدوي (quickstart.md بنود 4، 5، 7)

---

## Phase 7: Polish & Cross-Cutting

- [ ] T035 تحقق مزامنة على جهازين (quickstart.md بند 6 — SC-006): إنشاء/تسليم/دفع من جهاز يظهر على الآخر، وسباق تسليم + استثناء لنفس الطالب لا يسبب تكرارًا ولا كراش؛ حذف ملزمة/طالب يختفي أبناؤها على الطرف التاني
- [x] T036 [P] `flutter analyze` كامل (صفر جديد عن الأساس 30) و`flutter test` كامل (شامل `booklet_math_test.dart`)
- [x] T037 تحديث `HANDOFF.md` بملخص spec 041 (الجداول الأربعة، DB v35، migration مُطبَّقة، قرار "جدول مستقل مش Payment"، حالة التحقق) بعد التحقق الفعلي على جهاز

---

## Dependencies & Execution Order

- **T001 → Foundational**: كل مهام Phase 2 تعتمد على ثوابت T001.
- **داخل Foundational**: T002/T003/T004 مستقلة بالتوازي؛ T005 قبل T006/T007/T008 (نفس الملف بالتسلسل)؛ T009 [P] مع T013 [P]؛ T010–T012 بعد T006 (نفس ملف sync_engine بالتسلسل)؛ T014 بعد T013؛ T015 بعد T006؛ T016 بوابة قبل أي Story.
- **US1 → US2/US3 → US4**: US2 وUS3 تعتمدان على وجود شاشة التفاصيل/`rowsFor` من US1؛ US2 وUS3 مستقلتان عن بعض تقنيًا (لكن كلاهما يعدّل `booklet_details_page.dart` فبالتسلسل). US4 بعد US3 (تحتاج مدفوعات فعلية للتحقق).
- **الترتيب داخل كل Story**: الـcontroller ثم الواجهة ثم CHECKPOINT.

### Parallel Opportunities
- T002 + T003 + T004؛ T009 + T013؛ T019 + T020 (ملفان جديدان)؛ T031 + T032 + T033 (US4، ملفات مختلفة)؛ T036.

## Implementation Strategy

**MVP**: T001–T016 (أساس) ثم US1 (T017–T022) → تحقق على جهاز. بعدها US2 (تسليم) ثم US3 (دفع — الأخطر ماليًا: يتحقق منه FR-008 صراحةً في T028/T029) ثم US4 والمزامنة (T035). كل Story لها CHECKPOINT (analyze + test + يدوي) قبل الانتقال.
