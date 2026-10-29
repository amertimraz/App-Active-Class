# Tasks: إعلانات وبنر الخصومات عن بعد

**Input**: `specs/054-remote-announcements/` (plan.md, spec.md, research.md, data-model.md, contracts/firestore-announcements.md, quickstart.md)

**Tests**: اختبارات وحدة للنواة الصرفة + widget smoke للبنر/النافذة + تحقق يدوي. بلا schema SQLite / migration / تغيير مزامنة الفريق.

**القاعدة**: كل مرحلة تنتهي بـ`flutter analyze` نضيف (بلا errors/warnings جديدة) و`flutter test` أخضر. مهام الأدمن تُنفَّذ في `C:\repo\active_class_admin` (مستودع مستقل، commit منفصل). **نشر قاعدة Firebase والإصدار** يحتاجان موافقة صريحة (إنتاج).

**اختصارات**: `[APP]` = `C:\repo\active_class`، `[ADMIN]` = `C:\repo\active_class_admin`.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 [APP] سجّل خط الأساس: `flutter analyze` (عدد الـinfo) و`flutter test` (464 ناجح).
- [X] T002 [P] [APP] `firestore.rules`: أضف `match /announcements/{id} { allow read: if true; allow write: if isAdmin(); }` (حسب contracts/firestore-announcements.md) — **بدون نشر**.
- [X] T003 (تُخطّي: ملف rules الأدمن قديم وغير منشور؛ المصدر الحقيقي في مشروع التطبيق) [P] [ADMIN] `firestore.rules`: نفس القاعدة بالحرف، وتأكد إن الملفين متطابقين.

---

## Phase 2: Foundational — النواة الصرفة والبنر [APP] (تمنع كل القصص)

- [X] T004 `lib/models/announcement_model.dart`: `Announcement` (كل حقول data-model.md) + `fromMap` متسامح (قيم مجهولة → افتراضيات: design=classic, color=purple, kind=news، حدود الأطوال) + `toJson/fromJson` للكاش + `fromRestDocument(Map)` لصيغة Firestore REST (stringValue/integerValue/doubleValue/booleanValue/timestampValue/nullValue/arrayValue/mapValue) + `version` (= updatedAt ms) و`displayKey` (`id:version`).
- [X] T005 `lib/utils/announcement_logic.dart` (صرف، بمعامل `now`): `isActive`، `matchesAudience(planKey)`، `pickAnnouncement(items, now, planKey, placement)`، `AnnouncementStatus statusOf(...)` (draft/scheduled/active/expired)، `countdownParts(end, now)` (أيام/ساعات/دقائق/ثواني، لا سالب)، `safeHttpUrl(String?)`، `whatsappUri({phone, message, name, code, planName})` (أرقام فقط 8–15، ترميز سليم، حذف الأسطر الفارغة، null لو رقم غير صالح)، `shouldShowOnce(lastKey, current)`.
- [X] T006 [P] `test/announcement_model_test.dart`: تحليل كامل، قيم مجهولة/ناقصة، REST بكل الأنواع، تمرير JSON ذهابًا وإيابًا، نص فيه `<b>` يبقى حرفيًا.
- [X] T007 [P] `test/announcement_logic_test.dart`: النشاط (قبل/داخل/بعد، بلا نهاية)، الجمهور (فاضي=الكل، trial/basic/pro/lifetime، ترقية)، `pick` (الأحدث نشرًا، المسودة تُستبعد، المكان المعطّل)، العداد عند الصفر وحدوده، روابط (`javascript:`/بلا بروتوكول مرفوض)، واتساب (رقم غير صالح، ترميز عربي، سطر فاضي).
- [X] T008 `lib/widgets/announcement_banner.dart`: `AnnouncementBanner` (Flutter صرف بلا GetX/Get) — 6 تصاميم (classic/poster/glass/strip/coupon/minimal) × 8 ألوان (جدول ramps في research.md §9) × فاتح/داكن حسب `Theme`، شارة، عداد حيّ (`Timer.periodic(1s)` داخل الويدجت فقط، يخفي نفسه عند الصفر عبر `onExpired`)، زرار CTA، زر إغلاق، `Semantics`، أهداف لمس ≥44، يحترم `disableAnimations`، مرونة نص لا يسبب overflow (عرض ≥ 280).
- [X] T009 [P] `test/announcement_banner_test.dart`: 6×8×(فاتح/داكن) تُرسم بلا استثناء ولا overflow على عرض 320 وخط كبير (1.5)؛ العداد ينقص ويختفي عند الصفر؛ تصميم/لون مجهول يرجع للافتراضي؛ CTA وإغلاق يستدعيان callbacks.
- [X] T010 **CHECKPOINT**: analyze + T006/T007/T009 + كل الاختبارات القائمة.

---

## Phase 3: US2 + US2b + US5 + US6 — البنر في التطبيق (P1) 🎯 MVP [APP]

**اختبار مستقل**: إضافة مستند `announcements/test1` يدويًا من Firebase Console (published، placements.home=true، audience فاضية) → البنر يظهر على الرئيسية خلال ≤30 ثانية بالتصميم/اللون المختارين وعداد حيّ؛ إغلاقه يخفيه؛ تعديل المستند يعيده.

- [X] T011 `lib/services/announcement_service.dart`: `watch()` (Firestore `where status==published limit 20` → `List<Announcement>`)، `fetchOnce()`، `loadCache()/saveCache()` عبر SharedPreferences (`ann_cache`)، فشل صامت (`debugPrint`)، دالة `fetchViaRest()` (HttpClient من `dart:io`، مهلة 15 ثانية، تحليل `fromRestDocument`، تصفية `status`) للخلفية.
- [X] T012 `lib/controllers/announcement_controller.dart` (GetX): `items` RxList، تحميل الكاش فورًا ثم الاشتراك في `watch`، `forPlacement(placement)` (يستخدم `pickAnnouncement` بباقة `LicenseController.plan`)، مفاتيح الإغلاق (`ann_dismiss_home/plans`) عبر `dismiss(placement)` و`isDismissed`، يتفاعل مع تغيّر الباقة (Rx).
- [X] T013 (نُفِّذ داخل AnnouncementController بـ`ever(plan)` بدل تعديل LicenseController) `lib/controllers/license_controller.dart`: اكتب مفتاح الباقة (`ann_plan`) في SharedPreferences عند كل تغيّر لـ`plan` (تغيير صغير بلا تأثير على الباقي).
- [X] T014 `lib/main.dart`: سجّل `AnnouncementController` (دائم) بعد LicenseController، بدون تعطيل بدء التشغيل (`unawaited`).
- [X] T015 `lib/views/home_page.dart`: أدرج بنر الإعلان تحت `TrialBanner/PortalExpiryBanner` (سطر ~220) داخل `Obx`؛ الإغلاق يحفظ، CTA واتساب/رابط/باقات (`ROUTE_PLANS`) عبر دالة مشتركة `openAnnouncementCta(context, announcement)` في `announcement_logic`/service (فتح خارجي فقط، فشل صامت مع Toast مناسب).
- [X] T016 `lib/views/license/plans_page.dart`: نفس البنر أعلى قايمة الباقات (placement=plans) بإغلاق مستقل.
- [X] T017 [P] `test/announcement_controller_test.dart`: الاختيار حسب الباقة والمكان، الإغلاق يُحفظ ويعود عند تغيّر الإصدار، الانتهاء بدون نت من الكاش (منتهٍ لا يظهر)، ترقية الباقة تغيّر الاختيار.
- [X] T018 **CHECKPOINT**: analyze + اختبارات + تجربة يدوية سيناريوهات 2 و5 و6 و10 و11 في quickstart.

---

## Phase 4: US1 + US7 — لوحة الأدمن (P1) [ADMIN]

**اختبار مستقل**: من الأدمن: إنشاء إعلان ← معاينة تتحدث لحظيًا ← نشر ← يظهر في التطبيق (T018). قائمة بحالات صحيحة.

- [X] T019 [ADMIN] `lib/models/announcement_model.dart`: نفس الحقول والافتراضيات، `toMap` (مع حذف الحقول الفاضية)، `fromDoc`، `statusOf(now)`، `validate()` يرجع أخطاء بالعربي لكل حقل (عنوان/نص/حدود/نهاية بعد بداية/رقم واتساب/رابط/عداد بلا نهاية).
- [X] T020 [ADMIN] `lib/services/announcement_service.dart`: `watchAll()` (مرتبة createdAt تنازليًا)، `saveDraft`، `publish` (يضبط `publishedAt` أول مرة، `updatedAt` server timestamp)، `unpublish`، `duplicate` (مسودة)، `delete`، و`lastWhatsappPhone` افتراضي (من أحدث إعلان).
- [X] T021 [ADMIN] انسخ `announcement_banner.dart` من التطبيق حرفيًا إلى `lib/widgets/` (تعتمد على نموذج الأدمن؛ عدّل الـimport فقط).
- [X] T022 [ADMIN] `lib/views/announcements_page.dart`: القائمة (عنوان، حالة ملوّنة مسودة/مجدول/فعّال/منتهٍ، نطاق التاريخ، الجمهور، أماكن الظهور) + أزرار تعديل/نسخ/إيقاف/حذف بتأكيد.
- [X] T023 [ADMIN] نفس الصفحة — المحرّر: حقول (عنوان، نص، شارة، كود كوبون، نوع)، **اختيار التصميم** بـ6 صور مصغّرة، **اختيار اللون** بـ8 دوائر، الجمهور (تجريبي/أساسي/احترافي/مدى الحياة + اختصارات الكل/مشترك)، التواريخ، أماكن الظهور (4 مفاتيح)، العداد، الزرار (واتساب/رابط/باقات + رقم + رسالة جاهزة) وإظهار الأخطاء بجانب الحقل.
- [X] T024 [ADMIN] نفس الصفحة — **المعاينة الحيّة**: تبديل فاتح/داكن، وعرض الإعلان كبنر/نافذة/إشعار حسب الأماكن المختارة، تتحدّث لحظيًا مع كل تغيير؛ أزرار "حفظ كمسودة" و"نشر الآن" (تحذير لو لا أماكن، أو عداد بلا نهاية).
- [X] T025 [ADMIN] `lib/views/dashboard_page.dart`: أضف عنصر تنقّل "الإعلانات" (الشريط الجانبي + الشريط العلوي) يفتح الصفحة.
- [X] T026 [P] [ADMIN] `test/announcement_model_test.dart`: التحقق (كل قاعدة)، `statusOf`، الذهاب والإياب `toMap/fromDoc`.
- [ ] T027 **CHECKPOINT**: [ADMIN] analyze + اختبارات؛ ثم (بعد موافقتك) نشر القاعدة `firebase deploy --only firestore:rules`، وتجربة النشر من الأدمن → الظهور في التطبيق (سيناريوهات 1 و7).

---

## Phase 5: US3 — نافذة منبثقة مرة واحدة (P2) [APP]

**اختبار مستقل**: إعلان placements.popup → تظهر مرة؛ الإغلاق وإعادة الفتح لا تظهر؛ تعديل الإعلان تظهر.

- [X] T028 `lib/widgets/announcement_popup.dart`: `showAnnouncementPopup(context, announcement, onCta)` (Dialog يستخدم `AnnouncementBanner` بتخطيط كبير + "لاحقًا")، لا تُغلق بالضغط خارجها بالخطأ أثناء CTA، تحترم الوضعين.
- [X] T029 `announcement_controller.dart`: `maybeShowPopup(context)` — يحجز المفتاح `ann_popup_seen` قبل العرض (يمنع التكرار)، يعرض مرة واحدة لكل `displayKey`، لا يعرض أثناء شاشة أخرى مفتوحة فوق الرئيسية.
- [X] T030 `lib/views/home_page.dart`: استدعِ `maybeShowPopup` في أول frame بعد تحميل الرئيسية (بعد أي حوارات بدء التشغيل الحالية، بلا تعارض).
- [X] T031 [P] اختبار (في test/announcement_controller_test.dart): مرة واحدة لكل إصدار، تعديل يعيدها، لا تظهر لو المكان معطّل أو خارج الجمهور.

---

## Phase 6: US4 — إشعار النظام داخل التطبيق وخارجه (P2) [APP]

**اختبار مستقل**: إعلان placements.notify → إشعار واحد لا يتكرر؛ الضغط يفتح التطبيق/الباقات؛ ومقفول يصل خلال دورة الفحص.

- [X] T032 `lib/services/notification_service.dart`: `showAnnouncement(Announcement)` (قناة `active_class_channel`، payload `announcement`، معرّف إشعار ثابت لكل إعلان)، و`_onNotificationTap` يعالج `announcement` (يفتح `ROUTE_PLANS` لو CTA=plans وإلا يفتح التطبيق فقط).
- [X] T033 `announcement_controller.dart`: `maybeNotify()` عند الفتح وعند وصول تحديث (placement=notify)، يحجز `ann_notified` ثم يُظهر الإشعار مرة لكل `displayKey` (يعيد قراءة المفتاح قبل الإظهار لتفادي سباق الخلفية).
- [X] T034 `lib/main.dart`: افصل `callbackDispatcher` بـ`switch(task)` — `kMonthlyCheckTask` يحتفظ بالمنطق الحالي حرفيًا، و`kAnnouncementCheckTask` جديد؛ سجّل مهمة دورية كل 3 ساعات بقيد الاتصال (`ExistingPeriodicWorkPolicy.keep`).
- [X] T035 مهمة الإعلانات (isolate الخلفية): `WidgetsFlutterBinding`/تهيئة `NotificationService` الخفيفة، `fetchViaRest()`، `pickAnnouncement(placement: notify, planKey من ann_plan أو trial)`، فحص `ann_notified`، حجز المفتاح ثم الإشعار؛ أي استثناء → `true` بصمت (لا إعادة محاولة متواصلة).
- [X] T036 [P] اختبار صرف لقرار الإشعار (استخراج `shouldNotify(items, now, plan, lastKey)` إلى announcement_logic وتغطيته): لا تكرار، منتهٍ لا يُرسل، خارج الجمهور لا يُرسل.
- [X] T037 **CHECKPOINT**: analyze + اختبارات + تجربة يدوية سيناريو 4 (تشغيل المهمة يدويًا من debug لتسريع الاختبار).

---

## Phase 7: Polish & Cross-Cutting

- [ ] T038 [P] [APP] مراجعة a11y/تصميم: تباين النصوص في 6×8×2 (جدول)، أهداف لمس ≥44، `Semantics`، خط كبير، RTL، أبعاد 320/360/411.
- [X] T039 [P] [APP] `HANDOFF.md` + ملف الذاكرة `spec-054-remote-announcements.md` + سطر في `MEMORY.md`؛ [ADMIN] ملاحظة في README.
- [ ] T040 [APP+ADMIN] تحقق نهائي: `flutter analyze` + `flutter test` في المشروعين + quickstart كامل على موبايل حقيقي؛ علّم الـspec "Implemented (device test pending)".
- [ ] T041 (بموافقة صريحة) نشر قاعدة Firebase، ثم إصدار التطبيق (1.2.80+) على GitHub/VPS؛ الـAAB على Play يدويًا؛ ونسخة الأدمن تُشغَّل محليًا.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 (T004 → T005 → T008؛ T006/T007/T009 مع أصحابها) → باقي المراحل.
- Phase 3 تنتظر Phase 2. Phase 4 (الأدمن) **مستقلة عن Phase 3** بعد T004/T008 (تنسخ منها)، لكن اختبار النشر الكامل يحتاج نشر القاعدة (T027).
- Phase 5 تنتظر T012. Phase 6 تنتظر T012 وT005.
- T013 يسبق T035 (الباقة المحفوظة للخلفية).

## Parallel Examples

- T002 / T003 (ملفين مختلفين في مشروعين).
- T006 / T007 / T009 بعد ملفاتها.
- Phase 4 كلها (مشروع الأدمن) ممكن بالتوازي مع Phase 3 من شخص/جلسة تانية بعد T008.

## Implementation Strategy

- **MVP = Phase 1–3**: بنر على الرئيسية والباقات بتصميم ولون وعداد واستهداف وانتهاء وأوفلاين، يتجرّب بإضافة مستند يدويًا من Firebase Console (بعد نشر القاعدة).
- ثم **Phase 4** (لوحة الأدمن الكاملة)، ثم **Phase 5** (النافذة) و**Phase 6** (الإشعار الخارجي، الأعلى مخاطرة بسبب قيود الخلفية).
- نقاط تحقق بعد كل مرحلة؛ إصدار التطبيق وقاعدة Firebase آخر خطوة وبموافقتك.
