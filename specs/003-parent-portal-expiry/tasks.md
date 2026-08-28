---

description: "Task list for مدة تفعيل بوابة متابعة أولياء الأمور"
---

# Tasks: مدة تفعيل بوابة متابعة أولياء الأمور

**Input**: Design documents from `specs/003-parent-portal-expiry/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: لا يوجد test suite آلي في المشروع — بوابة الجودة هي `flutter analyze` + التحقق اليدوي عبر `quickstart.md`. لا تُنشأ مهام اختبار آلي.

**Organization**: المهام مجمَّعة حسب قصص المستخدم في spec.md لإتاحة تنفيذ/اختبار كل قصة بشكل مستقل.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: قابلة للتنفيذ بالتوازي (ملفات مختلفة، بدون اعتماد على مهام غير مكتملة)
- **[Story]**: القصة اللي تخص المهمة (US1، US2)

---

## Phase 1: Setup

**Purpose**: تجهيز نقطة البداية — لا يوجد مشروع جديد ولا اعتماديات جديدة، لا مهام Setup مطلوبة.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: البنية الأساسية في `LicenseController` اللي القصتين (US1 وUS2) محتاجينها قبل ما تشتغلوا

**⚠️ CRITICAL**: لا تبدأ أي قصة مستخدم قبل ما المرحلة دي تخلص بالكامل وتتأكد بـ `flutter analyze`

- [X] T001 في `lib/controllers/license_controller.dart`: إضافة `Rxn<DateTime> parentPortalExpiresAt` كحقل جديد على الكلاس (بجانب `parentPortalEnabled` الموجود)
- [X] T002 في `lib/controllers/license_controller.dart`: قراءة `parentPortalExpiresAt` من `data['parentPortalExpiresAt'] as Timestamp?` وتحويله لـ`DateTime?` في *كل* الأماكن التلاتة اللي بتقرأ `parentPortalEnabled` من مستند الترخيص حاليًا (`_validateLicense`، `_watchLicense` مرتين — عند وجود المستند وعند حذفه: يترجع `null`)
- [X] T003 في `lib/controllers/license_controller.dart`: إضافة getter محسوب `bool get parentPortalActiveNow => parentPortalEnabled.value && (parentPortalExpiresAt.value == null || parentPortalExpiresAt.value!.isAfter(DateTime.now()))` (راجع data-model.md قسم 2)
- [X] T004 في `lib/controllers/license_controller.dart`: إضافة `Timer.periodic` كل 5 دقايق (يبدأ لما ترخيص نشط يتفعّل، يتوقف/يُلغى في `onClose` وعند فقدان الترخيص) بينادي تحديث خفيف (مثلاً `parentPortalEnabled.refresh()`) عشان أي `Obx` مبني على `parentPortalActiveNow` يعيد التقييم حتى بدون حدث Firestore جديد (راجع research.md قرار 3)
- [X] T005 تشغيل `flutter analyze lib/controllers/license_controller.dart` والتأكد من عدم وجود أخطاء جديدة قبل البدء في أي قصة مستخدم

**Checkpoint**: `LicenseController` جاهز — قصص المستخدم تقدر تبدأ

---

## Phase 3: User Story 1 - قفل تلقائي لبوابة أولياء الأمور بعد انتهاء مدتها (Priority: P1) 🎯 MVP

**Goal**: بوابة أولياء الأمور تقفل تلقائيًا (في التطبيق وعلى الصفحة العامة) بعد انتهاء مدتها، من غير أي تدخل يدوي وقت الانتهاء

**Independent Test**: ضبط `parentPortalExpiresAt` لتاريخ في الماضي القريب على ترخيص تجريبي، والتأكد إن قسم الإعدادات يختفي وصفحة `/track/{slug}` تقفل، من غير أي إجراء إضافي (سيناريوهات 2، 3، 6، 7 في quickstart.md)

### Implementation for User Story 1

- [X] T006 [P] [US1] في `lib/views/settings/settings_page.dart`: تغيير شرط ظهور قسم "متابعة أولياء الأمور" من `Get.find<LicenseController>().parentPortalEnabled.value` إلى `.parentPortalActiveNow`
- [X] T007 [P] [US1] في `lib/services/parent_portal_service.dart`: تغيير الفحوصات الأربعة (`publishProfile`, `pushStudentSummary`, والفحصين المتبقيين) من `LicenseController.to.parentPortalEnabled.value` إلى `LicenseController.to.parentPortalActiveNow`
- [X] T008 [US1] في `lib/services/parent_portal_service.dart`: إضافة حقل `parentPortalExpiresAt` (ISO string عبر `.toIso8601String()`، أو `null`) لحمولة `_publishProfile` اللي بتُكتب على `parent_portal/{slug}` العام (راجع data-model.md قسم 4)
- [X] T009 [US1] في `lib/services/parent_portal_service.dart`: إضافة مستمع `ever()` (في الـconstructor أو دالة init مناسبة تتنادى مرة واحدة) على `LicenseController.to.parentPortalEnabled` وعلى `LicenseController.to.parentPortalExpiresAt` بينادي `publishProfile()` تلقائيًا عند أي تغيير — عشان تحديثات المطور (تفعيل/تعديل مدة) تتنشر بسرعة للصفحة العامة (راجع research.md قرار 4)
- [X] T010 [US1] تحميل نسخة من `track/index.html` الحالية من السيرفر (`root@192.99.145.122:/var/www/active-class.online/track/index.html`) للتعديل عليها محليًا
- [X] T011 [US1] في نسخة `track/index.html` المحلية: داخل `init()`، بعد قراءة `profileSnap`، إضافة فحص `parentPortalExpiresAt` — لو موجود و`new Date(p.parentPortalExpiresAt) < new Date()`، اعرض شاشة "الخدمة غير متاحة حاليًا — تواصل مع المعلم" (نفس أسلوب `renderNotFound()` الموجود) بدل `renderForm()`، ووقف من غير عرض أي فورم لإدخال كود
- [X] T012 [US1] رفع نسخة `track/index.html` المعدَّلة للسيرفر عبر SSH (نفس أسلوب تحديثات الموقع السابقة) واستبدال الملف الأصلي
- [X] T013 [US1] تشغيل `flutter analyze` على الملفات المعدَّلة (`settings_page.dart`, `parent_portal_service.dart`) والتأكد من عدم وجود أخطاء جديدة
- [ ] T014 [US1] تنفيذ سيناريوهات 2، 3، 6، 7 من `quickstart.md` يدويًا (قفل بعد إعادة فتح التطبيق، قفل والتطبيق فاضل مفتوح، عدم تأثر انتهاء الترخيص الأساسي بيها، عدم تأثر باقي التطبيق)

**Checkpoint**: القصة الأولى (MVP) شغالة ومختبرة — البوابة بتقفل تلقائيًا في التطبيق وعلى الصفحة العامة

---

## Phase 4: User Story 2 - ضبط/تجديد مدة التفعيل يدويًا وقت الدفع (Priority: P1)

**Goal**: المطور يقدر يفعّل بوابة أولياء الأمور بمدة محددة لمدرس جديد، أو يمدّد مدة قائمة، بنفس أسلوب التعديل الحالي بلا أدوات إضافية

**Independent Test**: ضبط تاريخ انتهاء مستقبلي لبوابة أولياء أمور مدرس تجريبي، والتأكد إنها تفضل شغالة لحد التاريخ ده بالظبط وتتجدد لما تُمدّد (سيناريوهات 1، 4، 5 في quickstart.md)

### Implementation for User Story 2

- [X] T015 [US2] لا يوجد كود إضافي مطلوب هنا — القصة دي بتعتمد بالكامل على البنية اللي اتبنت في Foundational وUS1 (حقل `parentPortalExpiresAt` قابل للتعديل مباشرة زي `expiresAt`/`status`، ومُعاد تقييمه تلقائيًا في كل قراءة). المهمة هنا توثيقية/تحققية بس.
- [ ] T016 [US2] تنفيذ سيناريوهات 1، 4، 5 من `quickstart.md` يدويًا (تفعيل بمدة مستقبلية، تجديد بعد انتهاء، مدرس مدى الحياة بلا تأثر)

**Checkpoint**: القصتان US1 وUS2 شغالتين مع بعض — دورة تفعيل/انتهاء/تجديد كاملة

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: مراجعة نهائية شاملة قبل اعتبار الميزة جاهزة

- [ ] T017 تشغيل `flutter analyze` نهائي على المشروع كامل، والتأكد من عدم وجود مشاكل جديدة عن الأساس الحالي (38 ملاحظة قديمة معروفة وقت كتابة هذه المهام)
- [ ] T018 تنفيذ كل سيناريوهات `quickstart.md` (1-7) كاملة كمراجعة شاملة أخيرة قبل الاعتبار الميزة جاهزة
- [X] T019 [إضافة خارج نطاق الخطة الأصلية] تبيّن إن يوجد فعليًا لوحة تحكم أدمن منفصلة (`C:\repo\active_class_admin`، Flutter Web، شغّالة على `localhost:5056`) بها "إجراءات سريعة" لكل ترخيص فيها تفعيل بوابة أولياء الأمور — الخطة الأصلية افترضت تعديل يدوي مباشر على Firestore بس (research.md قرار 1). أضفنا حقل "مدة التفعيل" (تاريخ انتهاء مستقل، أو "مدى الحياة") في نفس بطاقة "بوابة متابعة أولياء الأمور" داخل تبويب "إجراءات سريعة" — `lib/models/license_model.dart` (`parentPortalExpiresAt` + `parentPortalActiveNow`)، `lib/services/license_service.dart` (`setParentPortalExpiresAt`)، `lib/widgets/license_actions_dialog.dart` (منتقي تاريخ + زر "مدى الحياة"، بنفس أسلوب حقل تاريخ انتهاء الباقة الأساسية الموجود). `flutter analyze` على الملفات الثلاثة رجّع 0 أخطاء (3 ملاحظات قديمة غير متعلقة بالتعديل).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: بدون اعتماديات — يبدأ فورًا. **يمنع** أي قصة مستخدم قبل اكتماله بالكامل (T003 اللي كل حاجة تانية بتعتمد عليها)
- **User Stories (Phase 3-4)**: كلاهما يعتمد على اكتمال Foundational. US1 هي MVP الفعلي (القفل التلقائي هو جوهر المشكلة). US2 مبنية على نفس البنية من غير كود إضافي حقيقي — تقدر تتنفذ بالتوازي مع US1 أو بعدها مباشرة.
- **Polish (Final Phase)**: يعتمد على اكتمال US1 على الأقل.

### ملاحظة على US1 تحديدًا

T010-T012 (تعديل ورفع `track/index.html`) بتحصل على **مستودع/سيرفر خارج هذا الـgit repo** — لازم صلاحية SSH على الـVPS (نفس الأسلوب المستخدم لتحديثات الموقع سابقًا هذه الجلسة). لو مفيش وصول وقت التنفيذ، باقي مهام US1 (T006-T009) لسه تقدر تكتمل وتُختبر بشكل مستقل داخل التطبيق نفسه (سيناريو 2/3 جزء "شاشة الإعدادات")، والصفحة العامة تفضل معلّقة لحد ما يتوفر الوصول.

### Parallel Opportunities

- T001-T002 (نفس الملف، متتاليين) ثم T003-T004 (نفس الملف، متتاليين بعدهم)
- T006، T007 (ملفات مختلفة) قابلة للتوازي
- T010-T012 (الصفحة العامة) مستقلة تمامًا عن T006-T009 (كود Flutter) — قابلة للتوازي

---

## Implementation Strategy

### MVP أولًا (Foundational + US1)

1. Phase 2 (Foundational) → Phase 3 (US1)
2. **توقف وتحقق**: نفّذ سيناريوهات 2، 3، 6، 7 من quickstart.md
3. في المرحلة دي، القفل التلقائي شغال بالكامل (جوهر طلب المستخدم) — الميزة عمليًا جاهزة للاستخدام الفعلي.

### التسليم التدريجي المقترح

1. Foundational → الأساس جاهز (`parentPortalActiveNow` + الفحص الدوري)
2. US1 (القفل التلقائي — تطبيق + صفحة عامة) → تحقق مستقل — **من هنا المشكلة الأساسية اتحلّت**
3. US2 (التفعيل/التجديد اليدوي) → تحقق مستقل — تأكيد إن دورة الحياة كاملة (تفعيل → انتهاء → تجديد) شغالة صح
4. Polish (مراجعة نهائية شاملة) → اكتمال المواصفة بالكامل

---

## Notes

- لا توجد مهام اختبار آلي (لا يوجد test suite في المشروع) — كل تحقق عبر `flutter analyze` + سيناريوهات `quickstart.md` اليدوية.
- كل مهمة `flutter analyze` مطلوب تنفيذها فعليًا وتصفير أي مشاكل جديدة قبل الانتقال للمهمة التالية.
- كومت (commit) مقترح بعد كل Checkpoint (نهاية كل Phase) وليس بعد كل مهمة فردية.
- T010-T012 لوحدهم بيلمسوا كود خارج هذا الـrepo (الموقع على VPS) — لازم تنويه واضح للمستخدم قبل التنفيذ الفعلي (تعديل سيرفر حي).
