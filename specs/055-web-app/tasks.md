# Tasks: نسخة الويب من Active Class (إضافة زي بوابة ولي الأمر)

**Input**: `specs/055-web-app/` (spec.md, plan.md, research.md, contracts/supabase-web-access.md, quickstart.md)

**Tests**: اختبارات وحدة للدوال الصرفة (قرار الأهلية، القائمة المتزامنة للإعدادات، أسماء ملفات التنزيل، فلترة الشاشات) + `flutter test --platform chrome` smoke + اختبارات SQL على السيرفر + checklist يدوي في quickstart.md.

**القاعدة**:
- كل مرحلة تنتهي بـ `flutter analyze` (من غير errors/warnings جديدة) و`flutter test` أخضر، **و`flutter build web --release` وبناء أندرويد direct ناجحين**.
- أندرويد مايتغيّرش سلوكه أبدًا: كل تغيير منصّة ورا واجهة `core/platform` أو `kIsWeb`.
- قاعدة sqflite: كل helper جوه transaction بياخد `txn` (حادثة deadlock 2026-10-17)، ونفس القاعدة على الويب.
- **أي تعديل على السيرفر (migration، Caddy، DNS، نشر) محتاج موافقة صريحة**، ونسخة احتياطية قبله.

**اختصارات**: `[APP]` = `C:\repo\active_class`، `[ADMIN]` = `C:\repo\active_class_admin`، `[SRV]` = VPS / Supabase.

**القرارات المحسومة**: إضافة منفصلة زي بوابة ولي الأمر (Q1)؛ جملة "اطلب التفعيل" لغير المفعّل (Q2)؛ المالك والمساعدين، والويب مستثنى من قفل الجهاز (Q3)؛ منع الكتابة أوفلاين (Q4)؛ حماية RLS بالـ Origin في النسخة التانية (Q5)؛ إنشاء الفريق تلقائيًا (Q6)؛ نسخة أولى مصغّرة (Q7)؛ مزامنة إعدادات الفريق (Q8)؛ App Check مش مفروض (Q9)؛ تجربة مقفولة شهر (Q10).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 [APP] سجّل خط الأساس: `flutter analyze` (العدد)، `flutter test` (العدد الناجح)، حجم APK direct، وزمن/حجم `flutter build web --release` (180ث، `main.dart.js` 7.6MB).
- [X] T002 [APP] أضف `sqflite_common_ffi_web` (+`sqflite_common` صريحة) لـ `pubspec.yaml`. أداة `setup` بتفشل (webdev) → نزّلنا `sqlite3.wasm` 3.5.2 يدويًا في `web/` واستخدمنا مصنع بلا worker. تأكد إن بناء أندرويد مايتأثرش.
- [X] T003 [P] [APP] `web/index.html` و`web/manifest.json`: `lang="ar" dir="rtl"`، العنوان "Active Class"، الوصف، الأيقونات من `assets/icon/logo.png`، شاشة تحميل HTML خفيفة (لوجو + "جاري التحميل") بتختفي أول إطار Flutter.

---

## Phase 2: Spike — إثبات الطريق (يمنع كل اللي بعده)

**اختبار مستقل**: بناء ويب على `localhost` يفتح، يسجّل دخول Supabase بحساب تجريبي، يسحب جدول `groups` لقاعدة sqflite على الويب، ويقرأ `licenses/{code}` من Firestore.

- [X] T004 [APP] `lib/core/platform/db_factory.dart` + `_io.dart` + `_web.dart` (استيراد شرطي): `openAppDatabase(name, version, onCreate, onUpgrade)`. io = السلوك الحالي بالحرف (`getDatabasesPath` + `openDatabase`)، web = `databaseFactoryFfiWeb`. وعدّل `DatabaseService` يستخدمها.
- [~] T005 [APP] (Firebase anon + Firestore + CORS Supabase تمّ؛ دخول Supabase/Realtime لسه) تأكد عمليًا: (أ) تسجيل الدخول المجهول في Firebase Auth شغال من المتصفح (لازم لقراءة `licenses/{code}`)، (ب) Supabase REST وRealtime من `http://localhost` (CORS في Kong)، (ج) `_onCreate` بكل الجداول على الويب.
- [ ] T006 [APP] قِس: زمن السحب الكامل لفريق حقيقي كبير على الويب، وحجم IndexedDB. سجّل الأرقام في research.md (R8). لو السحب أبطأ من SC-001 (≤60ث لـ 500 طالب)، أضف مهمة للسحب على دفعات قبل Phase 5.
- [ ] T007 **CHECKPOINT**: analyze + test + build web + build أندرويد direct، وقرار "نكمل" مع المستخدم بالأرقام.

---

## Phase 3: Foundational — طبقة المنصّة وإخفاء غير المدعوم [APP]

- [ ] T008 `lib/utils/platform_features.dart` (صرف): `supportsLocalNotifications`، `supportsBackgroundTasks`، `supportsLocalBackup`، `supportsDriveBackup`، `supportsContactsPicker`، `supportsInAppReview`، `supportsInAppUpdate`، `supportsGallerySave` = `!isWeb` (بمعامل `isWeb` للاختبار).
- [ ] T009 `lib/utils/web_scope.dart` (صرف): `isScreenEnabledOnWeb(WebScreen)` للنسخة المصغّرة (Q7): مسموح = home, attendance, qrAttendance, payments, qrPayment, students, groups, reports, certificates, exams, onlineExams, basicSettings. ممنوع = bookings, booklets, questionBank, dataHealth, advancedSettings, scheduleAdvanced, backup, deleteRange.
- [ ] T010 [P] `test/platform_features_test.dart` + `test/web_scope_test.dart`.
- [ ] T011 `lib/core/platform/file_store.dart` + `_io.dart` + `_web.dart`: `saveBytes(fileName, bytes, mimeType)` (io = المسار الحالي: media_store_plus/share_plus/path_provider من غير أي تغيير سلوك؛ web = Blob + `<a download>`)، و`pickFileBytes(extensions)` (file_picker بـ `withData` على الويب).
- [ ] T012 [P] `lib/utils/download_file_name.dart` (صرف) + `test/download_file_name_test.dart`: أسماء ملفات آمنة بالعربي (من غير `/ \ : * ? " < > |`) بامتداد صحيح.
- [ ] T013 `lib/core/platform/device_id.dart` (+ `_io`/`_web`): انقل منطق `_initDeviceId` من `LicenseController` كما هو على io؛ على الويب UUID ثابت في localStorage.
- [ ] T014 `lib/main.dart`: فرع `kIsWeb` → من غير `NotificationService.initialize` ولا Workmanager ولا AppCheck أندرويد ولا `InstallSourceService` ولا `InAppUpdateService` ولا `RatePromptService`. وتأكد إن مسار أندرويد مالمسوش.
- [ ] T015 [P] احمِ `Platform.*` الغير محمي: `notification_service.dart` (133، 148، 170)، `install_source_service.dart:22`، `qr_gallery_page.dart` (404، 487).
- [ ] T016 حوّل التصدير والحفظ لـ `file_store`: `export_service.dart`، `excel_import_service.dart`، `performance_actions.dart`، `students_page.dart`، `student_details_page.dart`، `group_details_page.dart`، `qr_gallery_page.dart`، `exam_grades_page.dart`، `leaderboard_page.dart`، `online_exam_results_page.dart`، `certificates_sheet.dart`، `report_controller.dart`.
- [ ] T017 [P] الصور: `image_crop_picker.dart` (cropper.js محليًا + `WebUiSettings`)، وأي `Image.file` على الويب يبقى `Image.memory`.
- [ ] T018 أخفِ على الويب (حسب T008/T009): كل عناصر النسخ الاحتياطي (محلي/تلقائي/درايف)، الاستعادة، اختيار جهة اتصال، التقييم، التحديث، الحفظ في المعرض، الإشعارات وإعداداتها، وكل الشاشات الممنوعة في القوائم والرئيسية والإعدادات.
- [ ] T019 [P] `printing` و`mobile_scanner` على الويب: انقل pdf.js وZXing لـ `web/` ووجّه الحزم ليهم (من غير CDN خارجي — FR-023).
- [ ] T020 [P] شاشة "تراخيص البرمجيات" (`showLicensePage`) في "عن التطبيق" (FR-025).
- [ ] T021 **CHECKPOINT**: analyze + test + build web + build أندرويد direct + اختبار أندرويد سريع على الجهاز (التصدير والطباعة والـ QR والنسخ الاحتياطي من غير تغيير).

---

## Phase 4: US2 + US3 — الأهلية والترخيص والإضافة (P1) 🎯

**اختبار مستقل**: مدرس A مفعّل له الويب من الأدمن ومدرس B مش مفعّل → A يدخل ويشتغل، B يشوف شاشة القفل. مسح localStorage مايدّيش تجربة.

### السيرفر [SRV] (بموافقة)

- [ ] T022 [SRV] اكتب `supabase/migration_web_access.sql`: أعمدة `teams.web_enabled/web_expires_at/web_last_seen_at` + `revoke update` على العمودين من `authenticated/anon` + `web_access_active()` + `get_web_entitlement()` + جدول `web_entitlements(license_code pk, enabled, expires_at)` (service_role بس) + trigger على `teams` insert ينسخ القيم من `web_entitlements` حسب `license_code` (contracts §1، §2، §5). **من غير** سياسات Origin (Q5 = النسخة التانية).
- [ ] T023 [SRV] (بموافقة) طبّق الـ migration عبر SSH كـ `supabase_admin`، وشغّل اختبارات SQL (contracts §7 بنود 1، 3، 4).

### لوحة الأدمن [ADMIN] — زي بوابة ولي الأمر

- [ ] T024 [ADMIN] `license_model.dart`: `webEnabled`، `webExpiresAt`، `webActiveNow` (نسخة من `parentPortal*`).
- [ ] T025 [ADMIN] `license_service.dart`: `setWebEnabled(code, bool)` و`setWebExpiresAt(code, DateTime?)` على Firestore (زي `parentPortal`).
- [ ] T026 [ADMIN] `accounts_service.dart`: `upsertWebEntitlement(code, enabled, expiresAt)` + `teamsByLicenseCode(code)` + `setTeamWebAccess(teamId, enabled, expiresAt)` بـ service_role.
- [ ] T027 [ADMIN] `license_actions_dialog.dart`: قسم "الويب" تحت قسم بوابة أولياء الأمور وبنفس الشكل: مفتاح + تاريخ انتهاء + أزرار سريعة "+شهر" و"+سنة" + "مدى الحياة". الحفظ بالترتيب: Firestore → `web_entitlements` → الفرق المرتبطة. تحذير لو مفيش فريق ("هيتعمل تلقائيًا أول ما المدرس يفتح التطبيق") أو لو فيه أكتر من فريق بنفس الكود (يختار الأدمن).
- [ ] T028 [P] [ADMIN] `licenses_page.dart`: شارة "ويب" جنب شارة البوابة + تاريخ الانتهاء + آخر دخول ويب.

### التطبيق [APP]

- [ ] T029 `lib/utils/web_entitlement.dart` (صرف): `decideWebAccess(rpc, license, now)` → `allowed(plan)` | `notInTeam` | `webDisabled` | `webExpired` | `licenseSuspended` | `licenseExpired` | `licenseNotActivated` (جدول contracts §2، المالك والمساعد بنفس القرار).
- [ ] T030 [P] `test/web_entitlement_test.dart`: كل حالة، الانتهاء على الحد بالظبط، مساعد ومالك، `web_expires_at = null` = مدى الحياة.
- [ ] T031 `lib/services/web_access_service.dart`: نداء `get_web_entitlement` + قراءة `licenses/{license_code}` (status/plan/expiresAt/deviceId) + القرار + إعادة الفحص كل 5 دقايق وعند رجوع التاب (`visibilitychange`) + قفل فوري لو اتلغت.
- [ ] T032 `LicenseController`: مسار ويب: من غير تجربة، من غير `_registerDevice`، من غير `activateCode`، من غير ربط `deviceId`؛ الباقة والحدود من ترخيص المالك عبر `WebAccessService` (FR-011)، و`teamModeBypassLimits` للمساعد زي الموبايل.
- [X] T033 (اتنفّذ: web_welcome_page + web_login_page + web_auth_widgets، وسبلاش يوجّه الويب للترحيب لو مفيش جلسة؛ الويب بيتخطى الشرح التعريفي) `lib/views/web/web_login_page.dart`: دخول Supabase بس برقم التليفون + باسورد عبر `AuthService.signIn` الموجودة (PhoneField + PhoneHelper)، من غير تسجيل ولا تجربة ولا كود (FR-008).
- [ ] T034 `lib/views/web/web_locked_page.dart`: رسالة لكل حالة من T029 + زرار واتساب للأدمن برسالة جاهزة فيها الكود + زرار "تسجيل خروج".
- [ ] T035 `TeamModeService` على الويب: من غير `claim_device` ومن غير لمس `bound_device_id` (FR-010b)، والمالك والمساعد يدخلوا بنفس المسار.
- [ ] T036 **CHECKPOINT**: اختبار US2/US3 على localhost بحسابين حقيقيين + analyze + test + build.

---

## Phase 5: US1 — الدخول والسحب الأول ومنع الكتابة أوفلاين (P1)

**اختبار مستقل**: مدرس مفعّل → دخول → سحب أول مرة بنسبة → نفس أعداد الموبايل؛ قطع النت → التعديل يقف والقراءة تفضل.

- [ ] T037 `lib/views/web/web_initial_sync_page.dart` + مؤشر تقدّم في `SyncEngine` (جدول x من 17) للسحب الكامل.
- [ ] T038 `lib/services/connectivity_gate.dart`: حالة الاتصال على الويب (`navigator.onLine` + فشل طلب Supabase) → `canWrite` Rx. بانر "لا يوجد اتصال — التعديل متوقف لحد ما النت يرجع".
- [ ] T039 اربط `canWrite` بكل أزرار الحفظ/الإضافة/الحذف/تسجيل الحضور/الدفع في شاشات النسخة الأولى (FR-010c). على الموبايل `canWrite` دايمًا true (من غير أي تغيير سلوك).
- [ ] T040 `lib/core/platform/tab_lock_web.dart`: Web Locks — تاب واحد نشط، والتاني يعرض "Active Class مفتوح في تاب تاني — استخدمه هنا؟" (FR-020).
- [X] T041 (اتنفّذ + اتجرّب؛ انظر research R12) تسجيل الخروج على الويب: يستنى الطابور يفضى (أو يحذّر)، وبعدين يمسح IndexedDB وprefs المستخدم (FR-021). و`beforeunload` لو فيه رفع شغال.
- [ ] T042 فحص الإصدار: يقرأ `version.json` كل 10 دقايق، ولو اتغيّر يعرض "نسخة جديدة — حدّث الصفحة".
- [ ] T043 **CHECKPOINT**: US1 كامل على localhost مع موبايل حقيقي (التعديل يظهر في الاتجاهين ≤60ث).

---

## Phase 6: مزامنة إعدادات الفريق (Q8) — بتأثّر على الموبايل كمان

**اختبار مستقل**: المالك يغيّر يوم الفوترة على الموبايل → المساعد والويب يشوفوا نفس المتأخرات خلال دقيقة.

- [ ] T044 [SRV] `supabase/migration_team_settings.sql`: جدول `team_settings(team_id, key, value text, updated_at)` pk `(team_id,key)` + RLS (عضو يقرأ، المالك بس يكتب) + trigger `updated_at` من السيرفر (زي spec 031) + إضافته لـ Realtime (القناة الموسّعة). (بموافقة) طبّقه.
- [ ] T045 [APP] `lib/utils/team_settings_keys.dart` (صرف): القائمة المتزامنة بالظبط زي FR-018 + `isTeamSetting(key)`، و`test/team_settings_keys_test.dart` (الإعدادات المحلية زي قارئ الباركود والغياب التلقائي مش جواها).
- [ ] T046 [APP] `SyncEngine`: دفع إعدادات القائمة لما المالك يغيّرها، وسحبها لكل الأعضاء (LWW)؛ أول تفعيل: المالك يرفع قيمه وهي اللي تكسب (FR-018c). الكتابة في `app_settings` جوه txn.
- [ ] T047 [APP] `SettingsController`: لما إعداد متزامن يوصل من السيرفر، حدّث الـ Rx (زي `billingDay` و`PricingHelper.billingDay`). المساعد يشوف الإعدادات دي للقراءة بس.
- [ ] T048 **CHECKPOINT**: اختبار على موبايلين (مالك + مساعد) + الويب، وتأكد إن مفيش سجل دفع قديم اتغيّر (FR-018d).

---

## Phase 7: US2 (الموبايل) — عنصر الويب + إنشاء الفريق تلقائيًا (Q2، Q6)

- [ ] T049 [APP] `LicenseController`: اقرأ `webEnabled/webExpiresAt` من مستند الترخيص (زي `parentPortalEnabled`) + `webActiveNow`، وخزّنهم في الكاش زي البوابة.
- [ ] T050 [APP] عنصر الويب في الإعدادات (وكارت مرة واحدة في الرئيسية):
  - المفعّل له: "افتح Active Class على الكمبيوتر" + الرابط + QR + تاريخ الانتهاء.
  - غير المفعّل له: "متاح على الكمبيوتر — اطلب التفعيل" + واتساب الأدمن برسالة فيها الكود (نفس دالة spec 054).
- [ ] T051 [APP] إنشاء الفريق تلقائيًا (FR-015c): لو `webActiveNow` ومفيش فريق → لو مسجّل دخول: `enableAsOwner` بنافذة "جاري تجهيز Active Class للكمبيوتر" بنسبة؛ لو مش مسجّل: شاشة "سجّل دخول أو أنشئ حساب عشان تستخدم الكمبيوتر" وبعدها يكمّل. مرة واحدة بس، ومن غير ما يكسر أي حاجة لو فشل (يعيد المحاولة الفتحة الجاية).
- [ ] T052 [P] [APP] اختبار widget للعنصر في الحالتين + اختبار للدالة اللي بتقرر "محتاج ينشئ فريق" (صرفة).

---

## Phase 8: US4 + US5 — الشاشات اليومية على الكمبيوتر (P2/P3)

- [ ] T053 [APP] الحضور بالـ QR بكاميرا اللابتوب + قارئ HID (spec 027) على الويب، وصوت البيب (audioplayers web).
- [ ] T054 [APP] الطباعة: التقارير والشهادات بالخط Cairo في معاينة المتصفح.
- [X] T055 (المستوى 1 اتنفّذ: إطار عرض أقصى 1100 + تكبير خط وأيقونات + قوائم سفلية محدودة العرض + أعمدة شبكات تتكيّف: الرئيسية والطلاب ومعرض QR؛ المستوى 2 = إعادة تخطيط الشاشات الأساسية لاحقًا) [APP] عرض أقصى للمحتوى على الشاشات العريضة (≥1024px) في شاشات النسخة الأولى، من غير ما يأثر على الموبايل، واختصارات Enter/Esc في النوافذ.
- [ ] T056 [P] [APP] `flutter test --platform chrome`: smoke للرئيسية والحضور والمدفوعات وشاشة القفل.

---

## Phase 9: الاستضافة والنشر [SRV] (بموافقة)

- [X] T057 [SRV] **المستخدم**: سجل DNS: A `app` → `192.99.145.122` (quickstart §1). تحقق بـ `nslookup`.
- [X] T058 [SRV] (اتنفّذ 2026-10-31 بموافقة، محمي بـ basic_auth مؤقتًا) (بموافقة) نسخة احتياطية من `/etc/caddy/Caddyfile` + إضافة بلوك `app.active-class.online` (quickstart §2) + `caddy validate` + `systemctl reload caddy`. وتحقق إن zmenu وwasla وamertimraz وactive-class.online وauth كلهم شغالين بعدها.
- [ ] T059 [APP] `tool/deploy_web.sh`: build بـ `--no-web-resources-cdn` → rsync لـ `releases/<version>` → symlink `current` → الاحتفاظ بآخر 3. وطريقة الرجوع.
- [ ] T060 [SRV] تحقق: HTTPS والشهادة، `Cache-Control` على index/bootstrap/version، `application/wasm`، CORS من Kong لـ `https://app.active-class.online`، وRealtime websocket.

---

## Phase 10: Polish + التجربة المقفولة

- [ ] T061 [P] [APP] `HANDOFF.md` + ملف الذاكرة `spec-055-web-app.md`؛ [ADMIN] ملاحظة في README عن مفتاح الويب.
- [ ] T062 [APP+ADMIN] checklist الـ quickstart §6 كامل على Chrome وEdge (1366×768 و1920×1080) + اختبار أندرويد direct وplay من غير تراجع؛ علّم الـ spec "Implemented (beta pending)".
- [ ] T063 (بموافقة) إصدار الموبايل (عشان عنصر الويب ومزامنة الإعدادات وإنشاء الفريق تلقائيًا) + أول نشر للويب.
- [ ] T064 التجربة المقفولة: الأدمن يفعّل الويب لمدرسين يختارهم لمدة شهر (+شهر)، ومتابعة الأخطاء والملاحظات، وتحديد السعر قبل نهاية الشهر.

---

## النسخة التانية (مش في الخطة دي — للتذكير)

- حماية RLS حسب `Origin` على كل جداول الفريق (FR-013، contracts §3) — Q5.
- الشاشات المخفية: الحجوزات، الملازم، بنك الأسئلة، صحة البيانات، الإعدادات المتقدمة.
- التحقق من الترخيص على السيرفر بدل `set_team_license_active` من العميل، والتحقق إن `create_team(_license_code)` بكود المستخدم نفسه (research.md R4).
- دخول الويب بـ QR من الموبايل (زي واتساب ويب): يحتاج مكوّن سيرفر يطلّع جلسة للمتصفح بعد موافقة الموبايل.
- بناء wasm بعد ما حزمة `image` تتوافق.

---

## Dependencies & Execution Order

- Phase 1 → **Phase 2 (spike، فيها قرار نكمل)** → Phase 3.
- Phase 4: السيرفر (T022–T023) قبل الأدمن (T026–T027) وقبل T031. الأدمن T024–T025 والتطبيق T029–T030 ممكن بالتوازي.
- Phase 5 تنتظر Phase 3 وT031.
- Phase 6 مستقلة عن Phase 4/5 بعد Phase 3 (بتلمس الموبايل والسيرفر)، ولازم تخلص **قبل** التجربة المقفولة.
- Phase 7 تنتظر T022–T023 (الـ trigger) وT024–T027.
- Phase 9 ممكن تبدأ بعد Phase 2 (DNS بياخد وقت ينتشر)، والنشر الفعلي بعد Phase 5.
- Phase 10 آخر حاجة.

## Parallel Examples

- T008/T009/T012 (دوال صرفة) مع T004.
- الأدمن (T024–T028) بالتوازي مع التطبيق (T029–T035) بعد T022.
- T057 (DNS من المستخدم) في أي وقت بدري.
- T044 (migration الإعدادات) مع T022 في نفس جلسة SSH بعد الموافقة.

## Implementation Strategy

- **أولًا الـ spike (Phase 2)**: يومين–تلاتة يثبتوا إن sqflite على الويب والدخول وFirestore شغالين بأرقام حقيقية، وبعدها نكمّل.
- **MVP = Phase 1–5 + 9**: مدرس مفعّل من الأدمن يدخل من `app.active-class.online` ويشتغل على الحضور والمدفوعات والطلاب والتقارير والامتحانات.
- بعده Phase 6 (الإعدادات) وPhase 7 (عنصر الموبايل وإنشاء الفريق) **قبل** التجربة المقفولة، لأن من غيرهم الأرقام ممكن تختلف والمدرس اللي معندوش فريق مايقدرش يدخل.
- نقاط تحقق بعد كل مرحلة؛ أي تغيير على السيرفر أو إصدار بموافقتك.
