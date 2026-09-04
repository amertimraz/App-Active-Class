---
description: "Task list — طلاب محتاجين متابعة (021-at-risk-students)"
---

# Tasks: طلاب محتاجين متابعة (إنذار مبكّر)

**Input**: Design documents from `specs/021-at-risk-students/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/at-risk-service.md, quickstart.md

**Tests**: تحقّق يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات. مفيش مهام اختبار إلزامية (نفس نمط باقي المشروع) — مهمة وحدة اختبار اختيارية واحدة في Polish لأن `AtRiskService` منطق Dart نقي سهل التغطية.

**Organization**: 5 قصص. US1 (الشاشة + الرصد) P1 — MVP. US2 (الإقرار/التهدئة)، US3 (فلترة + كارت لوحة التحكم)، US5 (إشعار أسبوعي) — الكل P2. US4 (تخصيص العتبات) P3. جدول DB جديد واحد (`student_follow_ups`، v24→25).

## Path Conventions

Mobile single-project — `lib/`. المرجع: [data-model.md](data-model.md) و[contracts/at-risk-service.md](contracts/at-risk-service.md).

---

## Phase 1: Setup

- [X] T001 في `lib/config/constants.dart`: `DATABASE_VERSION` 24 → 25؛ `TABLE_STUDENT_FOLLOW_UPS='student_follow_ups'`؛ `COL_SFU_ID/STUDENT_ID/REASON_TYPES/ACKNOWLEDGED_AT/NOTE`؛ مفاتيح `SETTING_ATRISK_*` (تفعيل+عتبة لكل إشارة ×4، `atrisk_cooldown_days`، `atrisk_weekly_notif_enabled/_day/_hour/_minute`) — راجع [data-model.md](data-model.md#atrisksettings-مبنية-من-app_settings-مش-كيان-db-منفصل).

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: لا قصة تبدأ قبل ما الفيز دي تخلص.

- [X] T002 [P] في `lib/models/student_follow_up_model.dart` (جديد): كلاس `StudentFollowUp { id, studentId, reasonTypes: List<String>, acknowledgedAt, note }` — `toMap`/`fromMap` (نفس نمط `Homework`/`Payment`)، `reasonTypes` مخزّنة JSON في `COL_SFU_REASON_TYPES` (`jsonEncode`/`jsonDecode`).
- [X] T003 [P] في `lib/models/at_risk_model.dart` (جديد): `enum RiskSignalType { consecutiveAbsence, missingHomework, gradeDrop, latePayment }`؛ `class RiskSignal { type, reasonText, severityWeight }`؛ `class AtRiskStudent { student, group, signals: List<RiskSignal>, severityScore, guardianPhone }` — راجع [contracts](contracts/at-risk-service.md#lat_risk_modeldart-ضمنيًا-في-at_risk_servicedart).
- [X] T004 في `lib/services/database_service.dart`: أضف `_studentFollowUpsTableSql` (`CREATE TABLE` + `FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE` + `sync_updated_at`/`remote_id` زي `TABLE_HOMEWORK`) + `_studentFollowUpsIndexSql` (`CREATE INDEX ... ON student_follow_ups(student_id)`)؛ نادِهم من `onCreate` + من `onUpgrade` تحت `if (oldVersion < 25) { try {...} catch (_) {} }` — نفس نمط `exam_questions`/`exam_submissions` (spec 016). راجع [data-model.md](data-model.md#migration).
- [X] T005 في `lib/services/database_service.dart`: `Future<int> insertFollowUpAcknowledgement(StudentFollowUp f)`، `Future<List<StudentFollowUp>> getRecentFollowUps({int? sinceDays})`، `Future<void> deleteFollowUp(int id)` — كل كتابة تنادي `_queueSync(TABLE_STUDENT_FOLLOW_UPS, id, 'insert'|'delete', payload: ...)` الموجودة (زي باقي الجداول المتزامَنة). تأكد الحذف الناتج عن `deleteStudent` (cascade DB) مش محتاج كود إضافي.
- [X] T006 في `lib/services/sync_engine.dart`: أضف `TABLE_STUDENT_FOLLOW_UPS` لقائمة `_tables` + `COL_SFU_ID` في map المفتاح الأساسي + `case TABLE_STUDENT_FOLLOW_UPS:` في `_mapRowForRemote` (يحوّل `student_id` المحلي لـ`student_remote_id` عبر `_localRemoteId` الموجودة بالظبط زي حالة `TABLE_HOMEWORK`/`TABLE_PAYMENTS`).
- [X] T007 في `lib/controllers/settings_controller.dart`: أضف `RxBool`/`RxInt` لكل مفتاح `SETTING_ATRISK_*` من T001 (نفس نمط `paymentGraceDays` بالظبط — تحميل في `loadSettings`/دالة init، حفظ بدالة `setXxx` واحدة لكل إعداد تنادي `setSetting` وتحدّث الـRx).
- [X] T008 في `lib/services/at_risk_service.dart` (جديد، Dart نقي بدون Flutter/DB imports): `class AtRiskSettings` (من T007's values) + `List<AtRiskStudent> computeAtRiskStudents({...})` + 4 دوال خاصة `_checkConsecutiveAbsence`/`_checkMissingHomework`/`_checkGradeDrop`/`_checkLatePayment` (الأخيرة تنادي `PricingHelper.accumulatedDebt`/`isOverdue` الموجودتين مباشرة، بـ`graceDays = settings.paymentGraceDays` من `SettingsController` — **مش** عتبة `atrisk_*` مستقلة) + `_isAcknowledged` (تهدئة: `currentTypes ⊆ آخر follow-up.reasonTypes` خلال `cooldownDays`) + ترتيب تنازلي بـ`severityScore`. راجع [contracts/at-risk-service.md](contracts/at-risk-service.md) بالتفصيل.

**Checkpoint**: محرّك الرصد + الجدول + المزامنة + الإعدادات جاهزين — أي قصة تقدر تبدأ.

---

## Phase 3: User Story 1 - شاشة الرصد والعرض والتواصل (Priority: P1) 🎯 MVP

**Goal**: شاشة تجمّع الطلاب المرصودين (4 إشارات) وتوفّر تواصل مباشر (اتصال/واتساب/فتح صفحة الطالب).

**Independent Test**: quickstart سيناريوهات 1–3.

- [X] T009 [US1] في `lib/controllers/at_risk_controller.dart` (جديد، `GetxController`): `RxList<AtRiskStudent> items`، `RxInt count`، `Future<void> refresh()` — يحمّل من الـcontrollers/DB الموجودة (Student/Attendance/Homework/Exam/Payment، غير مؤرشفين) + `getRecentFollowUps` وينادي `computeAtRiskStudents` (T008). راجع [contracts](contracts/at-risk-service.md#libcontrollersat_risk_controllerdart-getx).
- [X] T010 [US1] في `lib/views/students/at_risk_students_page.dart` (جديد): `Scaffold` + `ListView` كروت — لكل `AtRiskStudent`: اسم، مجموعة، شرائح أسباب (`signal.reasonText`)، أزرار: اتصال (`url_launcher` `tel:`)، واتساب (`normalizeWhatsappPhone` + `wa.me`)، فتح صفحة الطالب (`Get.to(() => StudentDetailsPage(...))`) — الاتنين الأولانيين معطّلين لو `guardianPhone == null`. حالة فاضية إيجابية لو `items.isEmpty`.
- [X] T011 [US1] في `lib/views/home_page.dart`: أيقونة دخول مؤقتة (زي `IconButton`/badge بسيط، مش الكارت الكامل — ده جاي في US3) تفتح `AtRiskStudentsPage` وتنادي `Get.find<AtRiskController>().refresh()` قبل الفتح لو لسه ما اتحمّلش.

**Checkpoint**: US1 كامل ومستقل — المدرس يقدر يفتح الشاشة ويكلّم أولياء الأمور.

---

## Phase 4: User Story 2 - "تمّت المتابعة": إقرار وتهدئة (Priority: P2)

**Goal**: زر يخفي الطالب مؤقتًا بعد ما المدرس يتواصل معاه، مع رجوع تلقائي لو الوضع استمر.

**Independent Test**: quickstart سيناريو 4–6.

- [X] T012 [US2] في `lib/controllers/at_risk_controller.dart`: `RxList<AtRiskStudent> snoozed`؛ `Future<void> acknowledge(int studentId, {String? note})` — يبني `StudentFollowUp` بـ`reasonTypes` = أنواع إشارات الطالب الحالية، `insertFollowUpAcknowledgement`، `refresh()`؛ `Future<void> unacknowledge(int studentId)` — يحذف آخر `StudentFollowUp` نشط للطالب (`deleteFollowUp`)، `refresh()`.
- [X] T013 [US2] في `at_risk_students_page.dart`: زر "تمّت المتابعة" على كل كارت → حوار بملاحظة اختيارية → `controller.acknowledge(...)`؛ تبويب/فلتر "تمّت متابعتهم" يعرض `controller.snoozed` (تاريخ آخر إقرار + الملاحظة) مع زر "رجّعه للقائمة" → `unacknowledge`.

**Checkpoint**: US1+US2 يشتغلوا مع بعض — القائمة تفضل ذات معنى مع الوقت.

---

## Phase 5: User Story 3 - فلترة وترتيب + مدخل لوحة التحكم (Priority: P2)

**Goal**: اكتشاف أسهل (كارت بالعدّاد) + تركيز داخل الشاشة (فلاتر).

**Independent Test**: quickstart سيناريو 7–9 (فلترة فقط — الإعدادات في US4).

- [X] T014 [US3] في `lib/views/home_page.dart`: كارت "محتاجين متابعة (N)" كامل (نفس نمط `_TodayPaymentsCard` بصريًا)، `N = controller.count.value`، يختفي بالكامل لو `N == 0`، يفتح `AtRiskStudentsPage` عند الضغط. **تعديل عن الخطة الأصلية**: الأيقونة المؤقتة (T011) في الـAppBar اتسابت بدل ما تتشال — وصول أسرع بضغطة واحدة من أي مكان في الصفحة الرئيسية، والكارت بيديها بروز إضافي بره الـAppBar. الاتنين بيستخدموا نفس `count`/`onTap`.
- [X] T015 [US3] في `at_risk_controller.dart` + `at_risk_students_page.dart`: `Rxn<RiskSignalType> reasonFilter` + `RxnInt groupFilter` (يُطبَّقوا على `items`/الجلب، مش على `computeAtRiskStudents` نفسها) + UI فلترة (شرائح/قائمة منسدلة) فوق قائمة الكروت. الترتيب الافتراضي أصلاً بالخطورة من T008 — تأكيد بس.

**Checkpoint**: الاكتشاف والتركيز جاهزين.

---

## Phase 6: User Story 5 - إشعار أسبوعي ملخّص (Priority: P2)

**Goal**: تذكير أسبوعي محلي بعدد الطلاب المرصودين، يودّي للشاشة.

**Independent Test**: quickstart سيناريو 10.

- [X] T016 [US5] في `lib/services/notification_service.dart`: `_atRiskNotificationId` (مساحة IDs منفصلة زي `_latePaymentNotificationId`) + `_keyAtRiskEnabled` + `isAtRiskEnabled()`/`setAtRiskEnabled()` (نفس نمط `isLatePaymentEnabled`) + `Future<void> scheduleWeeklyAtRiskDigest()` — يحسب من الـDB مباشرة (نفس نمط `scheduleLatePaymentReminder`: يحمّل الطلاب/الحضور/الواجب/الدرجات/المدفوعات + `getRecentFollowUps` وينادي `computeAtRiskStudents`)، يجدول بـ`_nextInstanceOfWeekdayTime(day, time)` + `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` (نفس `scheduleDailyDigestNotifications`)، `payload: 'at_risk'`؛ `count == 0` → `cancelNotification(_atRiskNotificationId)`.
- [X] T017 [US5] في `notification_service.dart`: `_onNotificationTap` — لو `response.payload == 'at_risk'` → `Get.toNamed(...)` أو `Get.to(() => AtRiskStudentsPage())` لفتح الشاشة (حالة "التطبيق شغّال في الخلفية"؛ حالة cold-start موثّقة كقيد معروف في plan.md، تُنفَّذ لاحقًا لو الوقت سمح عبر `getNotificationAppLaunchDetails()`).
- [X] T018 [US5] في `lib/views/settings/settings_page.dart`: عنصر جديد لقسم "متابعة الطلاب" — مفتاح تفعيل الإشعار الأسبوعي + منتقي يوم (زي `_dayNameToWeekday` الموجودة) + منتقي وقت؛ أي تغيير يحفظ عبر `SettingsController` (T007) وينادي `scheduleWeeklyAtRiskDigest()` فورًا.
- [X] T019 [US5] اربط `scheduleWeeklyAtRiskDigest()` في نفس نقطة استدعاء `scheduleLatePaymentReminder()` الحالية (دورة `syncAllScheduledNotifications` + بعد تغييرات حضور/واجب/درجة/دفعة ذات صلة إن أمكن، وإلا الاكتفاء بدورة المزامنة الدورية الموجودة).

**Checkpoint**: المدرس ياخد تذكير أسبوعي من غير ما يفتح التطبيق بنفسه.

---

## Phase 7: User Story 4 - تخصيص العتبات (Priority: P3)

**Goal**: كل إشارة قابلة للتعطيل/التعديل من الإعدادات.

**Independent Test**: quickstart سيناريو 9 (كامل).

- [X] T020 [US4] في `settings_page.dart`: باقي عناصر قسم "متابعة الطلاب" (فوق نفس القسم اللي T018 بدأه) — مفتاح تفعيل + حقل عتبة لكل إشارة من الأربعة (`atrisk_absence_threshold`, `atrisk_homework_m/w`, `atrisk_grade_drop_points`) + حقل مدة التهدئة (`atrisk_cooldown_days`)، بقيم افتراضية معروضة لو المفتاح فاضي.
- [X] T021 [US4] في `at_risk_controller.dart`: تأكيد إن أي تغيير في إعدادات `SettingsController` (T007) بينعكس فورًا على `computeAtRiskStudents`/`count` من غير إعادة تشغيل — إما `ever()`/`listen` على الـRx المعنية تنادي `refresh()`، أو استدعاء `refresh()` صريح من `onChanged` كل عنصر إعداد في T020 (أبسط ومتّسق مع نمط التطبيق الحالي — بدون reactive listeners إضافية).

**Checkpoint**: كل القصص شغّالة.

---

## Phase 8: Polish

- [X] T022 `flutter analyze` — صفر أخطاء/تحذيرات.
- [ ] T023 [P] تحقّق بصري (فاتح/ليلي): `at_risk_students_page`، كارت `home_page`، قسم إعدادات "متابعة الطلاب". **⏳ لسه** — الكود بيتبع نفس أنماط isDark الموجودة بالضبط، بس مفيش سكرين شوت فعلي على جهاز/محاكي (تجنّبت بناء `flutter run` على جهاز فيه بيانات حقيقية — راجع [[apk-signing-consistency]]).
- [ ] T024 نفّذ [quickstart.md](quickstart.md) سيناريوهات 1–14 كاملة على جهاز حقيقي (خصوصًا 10 الإشعار، و11 مزامنة الفريق لو جهاز تاني متاح). **⏳ لسه** — تحقّق يدوي بحت، محتاج تفاعل مستخدم حقيقي + وقت (إشعار أسبوعي، جهازين فريق).
- [X] T025 [P] (اختياري) `test/at_risk_service_test.dart` — تغطية وحدة للحالات الحدّية الأربعة (`AtRiskService` منطق Dart نقي بدون DB، سهل الاختبار بمعطيات مصطنعة).
- [ ] T026 [P] تحقّق ترقية DB v24→25 على نسخة احتياطية حقيقية (نفس فحص backup/restore المعتاد قبل أي ريليس) — صفر فقدان بيانات. **جزئي** — الـSQL (`CREATE TABLE`/`INDEX`/cascade delete/إعادة التشغيل idempotent) اتأكد بمحاكاة Python `sqlite3` مباشرة ونجح؛ التأكيد الحقيقي على نسخة المدرس الفعلية لسه محتاج جهاز.
- [ ] T027 [P] حدّث ملاحظات الجلسة: سبيك 021، `AtRiskService`, `student_follow_ups`, إعادة استخدام `paymentGraceDays`, أول تنقّل-من-إشعار في المشروع.

---

## Dependencies & Execution Order

- **Phase 1–2**: أساس — يحجب كل القصص. T004→T005→T006 تسلسلي (نفس الجدول). T008 يحتاج T002/T003/T007.
- **US1 (T009–T011)**: بعد Foundational. T009→T010→T011. **MVP**.
- **US2 (T012–T013)**: بعد US1 (بيستخدم `at_risk_students_page`/`at_risk_controller` الموجودين). T012→T013.
- **US3 (T014–T015)**: بعد US1؛ T014 يستبدل T011. مستقل عن US2 لكن الفلترة (T015) بتتجاهل المؤجَّلين المحسوبين من US2 لو موجودة.
- **US5 (T016–T019)**: بعد Foundational (يستخدم `computeAtRiskStudents` مباشرة، مش محتاج US1 UI). T016→T017→T019؛ T018 مستقل عن T016/17 لكن يحتاجهم ليكون مفيد.
- **US4 (T020–T021)**: بعد Foundational + T018 (نفس قسم الإعدادات).
- **Polish**: بعد الكل.

### فرص التوازي
- T002/T003 (موديلات) [P].
- Polish: T023/T025/T026/T027 [P].
- US5 (T016–T019) ممكن يشتغل بالتوازي مع US2/US3 — الاتنين بعد Foundational مباشرة وملفاتهم مختلفة إلا `settings_page.dart` (T018 مع T020 لاحقًا).

---

## Implementation Strategy

**MVP**: Phase 1+2 + US1 → شاشة رصد وتواصل شغّالة (بدخول مؤقت). قف وتحقّق (quickstart 1–3).
**تدريجي**: US1 → US2 (الإقرار) → US3 (الاكتشاف والفلترة) → US5 (الإشعار) → US4 (التخصيص) → Polish.

## Notes

- **جدول DB جديد واحد بس** (`student_follow_ups`) — `DATABASE_VERSION` 24→25. الرصد نفسه صفر كتابة على أي جدول موجود.
- **تأخّر الدفع يعيد استخدام `paymentGraceDays` الموجود** — مفيش عتبة `atrisk_payment_*` مستقلة (راجع data-model.md).
- **أول تنقّل-من-إشعار في المشروع** (T017) — محدود لحالة `payload == 'at_risk'` بس، مش رواتر عام.
- كل تواصل مع ولي الأمر بضغطة صريحة من المدرس — صفر إرسال تلقائي.
- commit بعد كل قصة.
