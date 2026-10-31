# Research: نسخة الويب (055)

**Date**: 2026-10-31. كل النتايج دي من فحص فعلي للكود والسيرفر في نفس اليوم (قراءة بس، مفيش أي تعديل).

## R1 — بناء تجريبي للويب (دليل عملي)

- `flutter build web --release` على الكود الحالي كما هو: **نجح** (exit 0، ~180 ثانية). يعني مفيش عائق وقت الترجمة؛ كل العوائق **وقت التشغيل**.
- الحجم: `main.dart.js` = **7.6MB** (قبل الضغط، ~2MB تقريبًا بـ gzip/br)، والمجلد كله ~39MB (أغلبه نسخ CanvasKit والأصول). أيقونات Material اتقلّصت 96.7% بالـ tree-shaking.
- Wasm dry-run: فيه عدم توافق في حزمة `image` 4.3.0 (فحوصات int/double) → **نبني بـ JS/CanvasKit في النسخة الأولى**، وwasm لاحقًا.
- تشغيل محلي في المتصفح: التطبيق **فتح فعلًا على شاشة الشرح التعريفي بالعربي وRTL سليم**. أول الأخطاء في الكونسول:
  - `Bad state: databaseFactory not initialized` (من SessionOverrideController وBookletController) → متوقع، حلّه `sqflite_common_ffi_web` (FR-003).
  - `Uncaught Error` متكرر من نفس الموضع → استدعاءات `dart:io` (`Platform.*`/`File`) وقت التشغيل.
  - فشل تسجيل service worker على السيرفر المحلي (مش مشكلة على HTTPS؛ وغالبًا هنقفل الـ SW أو نتحكم فيه عشان الكاش، راجع quickstart).
- الخلاصة: الطريق مفتوح، والشغل الأساسي = طبقة المنصّة + قاعدة الويب + بوابة الدخول.

## R2 — الحزم وحالتها على الويب

| الحزمة | الاستخدام (عدد الملفات) | الويب | الإجراء |
|---|---|---|---|
| sqflite 2.4.2 | DatabaseService/BackupService | ❌ | `sqflite_common_ffi_web` + `dart run sqflite_common_ffi_web:setup` (ينسخ `sqlite3.wasm` و`sqflite_sw.js` لـ `web/`) |
| path_provider | 12 | جزئي (`getApplicationDocumentsDirectory` يرمي) | عبر `file_store` |
| media_store_plus | 7 | ❌ أندرويد فقط | تنزيل Blob |
| share_plus | 13 | جزئي (Web Share API؛ الملفات محدودة) | تنزيل؛ مشاركة النص/الرابط فقط |
| file_picker | 2 | ✅ (`bytes` مش `path`) | `withData: true` على الويب |
| image_picker | 1 | ✅ (XFile بلا مسار حقيقي) | `readAsBytes` + `Image.memory` |
| image_cropper 8 | 1 | ✅ بس يحتاج cropperjs في index.html + `WebUiSettings` | أصول محلية |
| mobile_scanner 7.1.3 | 4 | ✅ (ZXing JS من CDN افتراضيًا) | خدمة السكربت من دومينّا |
| audioplayers | 1 | ✅ | — |
| pdf / printing 5.14 | 4 | ✅ (pdf.js من CDN افتراضيًا للمعاينة) | خدمة pdf.js محليًا |
| url_launcher | واتساب | ✅ | — |
| permission_handler | 4 | جزئي | تخطّي الطلب على الويب |
| flutter_local_notifications 17 | 2 | ❌ | إخفاء (`main.dart` محمي جزئيًا بـ `kIsWeb`؛ `NotificationService` بيستخدم `Platform` → يتحمي) |
| workmanager | main | ❌ | محمي بـ `kIsWeb` أصلًا |
| flutter_contacts | 1 | ❌ | إخفاء زرار "من جهات الاتصال" |
| android_id | license | ❌ | `LicenseController._initDeviceId` بيرجع UUID على الويب أصلًا (فرع else) |
| open_filex / in_app_update / in_app_review | 1/1/1 | ❌ | إخفاء |
| google_sign_in (Drive backup) | 1 | ✅ بفلو مختلف (GIS) | إخفاء النسخ على درايف في الويب |
| firebase_core/auth/firestore/storage | — | ✅ (`DefaultFirebaseOptions.web` موجود) | — |
| firebase_app_check | main | ✅ يحتاج ReCaptcha provider | حاليًا متخطّى على الويب؛ يعتمد على Q9 |
| supabase_flutter 2.16 | — | ✅ | التأكد من CORS/websocket على Kong |
| device_info_plus / package_info_plus / flutter_timezone / timezone / uuid / intl / get / dio / excel / archive / fl_chart / flutter_animate / spinkit / qr_flutter | — | ✅ | — |

`dart:io` موجود في **23 ملف** في `lib/`، و`File(` في 42 موضع (16 منهم في `backup_service.dart`)، و`Platform.` في 12 موضع (license_controller محمي بـ `!kIsWeb`؛ الباقي في notification_service وinstall_source_service وqr_gallery_page **مش محمي**).

## R3 — تراخيص الحزم الخارجية (التوزيع على الويب)

فحص ملفات LICENSE لكل الحزم في `.dart_tool/package_config.json` (206 حزمة من pub cache):

| الترخيص | العدد | التوزيع على الويب |
|---|---|---|
| BSD (2/3-clause) | 132 | ✅ مسموح، بشرط الاحتفاظ بنص الترخيص والإشعار |
| MIT | 52 | ✅ مسموح، نفس الشرط |
| Apache-2.0 | 19 (منها pdf، printing، flutter_timezone، image_picker جزئيًا) | ✅ مسموح، الاحتفاظ بالترخيص + ملف NOTICE لو موجود |
| MPL-2.0 | 2 (`dbus`، `gtk`) | ✅ — دول تبعيات **لينكس فقط** (عبر device_info_plus/package_info_plus) ومش بيدخلوا في bundle الويب أصلًا؛ وحتى لو دخلوا MPL على مستوى الملف ومش بيلزم فتح كودنا |
| `sky_engine` | 1 | ملف الإشعارات المجمّع بتاع Flutter نفسه (فيه نصوص تراخيص كتير منها GPL كمرجع لمكونات زي ICU/HarfBuzz المرخّصة بشروط متساهلة) — بيتوزّع تلقائيًا ضمن `NOTICES` |
| **GPL/AGPL/LGPL حقيقي** | **0** | — |

- **مكونات وقت التشغيل على الويب**: CanvasKit/Skia (BSD-3)، SQLite WASM (public domain) + حزمة `sqlite3` (MIT)، pdf.js (Apache-2.0)، ZXing-js (Apache-2.0)، Cropper.js (MIT) — كلها تسمح بإعادة الاستضافة على سيرفرنا.
- **الخط Cairo**: SIL Open Font License 1.1 → مسموح تضمينه وتوزيعه في تطبيق ويب (ممنوع بيع الخط لوحده فقط).
- **الواجب علينا**: Flutter بيولّد `assets/NOTICES` تلقائيًا في build/web؛ نضيف شاشة "تراخيص البرمجيات" (`showLicensePage`) في الويب (FR-025)، ونسيب ملف `NOTICES` منشور. مفيش أي حزمة بتمنع الاستخدام التجاري أو الاستضافة.
- **شروط خدمات طرف تالت**: Firebase (شروط Google Cloud، عادي للويب)، Google Sign-In على الويب بيتطلب إضافة `app.active-class.online` في OAuth client لو قررنا نفعّله لاحقًا.

## R4 — نظام الترخيص والاشتراك على الويب

**الوضع الحالي (أندرويد):**
- `licenses/{code}` في Firestore: `plan`، `status`، `expiresAt`/`durationDays`، `deviceId` (ربط بجهاز واحد أول تفعيل)، `parentPortalEnabled`. القواعد بتمنع العميل يغيّر plan/status ويسمح بالربط مرة واحدة بس.
- التجربة: `devices/{deviceId}.firstLaunchAt` غير قابل للتعديل (anti-reset).
- الحدود: `app_config/limits` (real-time) → `_Limits` لكل باقة.
- وضع الفريق: `teams.owner_license_active` بيدفعه **موبايل المالك** (`set_team_license_active`) وRLS على كل جداول الفريق بتشترط `is_team_license_active`. المساعد بياخد `teamModeBypassLimits`.

**المشاكل لو شغّلنا نفس المسار على الويب:**
1. كود المالك مربوط بـ `deviceId` موبايله → الويب (UUID جديد) هيتقفل `trialExpired`.
2. مسح localStorage = `deviceId` جديد = مستند `devices` جديد = **تجربة مجانية جديدة** كل مرة (التف كامل على الاشتراك).
3. أي حد عارف كود ترخيص يقدر يفعّله في متصفح (لو الكود لسه مش مربوط).

**القرار:** على الويب
- **لا** تجربة، **لا** تفعيل كود، **لا** تسجيل مستند `devices` (FR-008/FR-014).
- الترخيص يتقرأ من `licenses/{teams.license_code}` (status/plan/expiresAt) **بدون** فحص `deviceId`، لأن الكود مربوط بموبايل المالك وده هو الصح.
- الأهلية من السيرفر: `get_web_entitlement()` (security definer) بترجع العضوية والدور و`web_enabled`/`web_expires_at` و`owner_license_active`.
- طبقة إجبارية على السيرفر: RLS حسب `Origin` (راجع contracts).

**ثغرات قائمة قبل الويب (خارج النطاق، متابعة منفصلة):**
- `create_team(_license_code)` بيقبل أي كود من العميل من غير تحقق إنه بتاع المستخدم → فريق ممكن يتعمل بكود حد تاني (الويب هيورث نفس الباقة). التخفيف في 055: الويب يرفض لو الترخيص `deviceId` بتاعه فاضي (يعني مش متفعّل على موبايل أصلًا)، والأدمن بيفعّل الويب يدويًا لفريق بعينه بعد ما يتأكد.
- `set_team_license_active` بيتنادى من العميل → مالك ترخيصه منتهي ممكن نظريًا يسيب العلم true. الحل الجذري: Edge Function/cron على السيرفر يقرأ Firestore ويحدّث العلم. **مقترح كمتابعة.**

## R5 — مفتاح التفعيل لكل مدرس

القرار: **Supabase `teams.web_enabled` + `teams.web_expires_at`** يكتبهم الأدمن بـ service_role من لوحة الأدمن (نفس مسار `AccountsService.setMaxAssistants`). المقارنة الكاملة في plan.md. الأسباب الحاسمة: (1) الويب أصلًا بيدخل بـ Supabase، (2) ينفع يتطبّق في RLS = حماية حقيقية، (3) قرار واحد بيغطي المالك ومساعديه، (4) الأدمن عنده الصلاحية والكود جاهز.

## R6 — السيرفر والاستضافة

- **Caddy v2.11.4** على 80/443 (**مش Nginx** زي ما كان متوقع) — بيطلّع شهادات Let's Encrypt تلقائيًا لأي بلوك دومين جديد بمجرد ما DNS يشاور على السيرفر. يعني مفيش certbot ولا تجديد يدوي.
- البلوكات الحالية: `active-class.online` (ملفات ثابتة من `/var/www/active-class.online` مع fallback لـ /book و/track و/exam)، `auth.active-class.online` → Kong (Supabase) على 8000، ودومينات تانية لمشاريع تانية على نفس السيرفر (zmenu، wasla، amertimraz) — **أي غلط في Caddyfile يوقّعهم كلهم** → لازم `caddy validate` قبل `reload` ونسخة احتياطية.
- DNS: `app.active-class.online` **مش موجود** (NXDOMAIN). الدومين الأساسي A → `192.99.145.122`. محتاج سجل A (وAAAA لو موجود للأساسي) من لوحة مزوّد الدومين — **ده في إيد المستخدم**.
- الموارد: القرص 77% (8.9GB فاضي)، RAM 3.7GB (1.2GB متاح). الويب ملفات ثابتة (~30–40MB لكل إصدار) → أثر مهمل.
- Supabase Kong: CORS افتراضيًا `*` في إعداد Supabase docker — يتأكد عمليًا في المرحلة 0 من `https://app.active-class.online`.

## R7 — إعدادات محلية مش متزامنة

`app_settings` (فيها `billing_day` وإعدادات التسعير/المتأخرات وغيرها) و`report_logs` و`student_follow_ups` **مش ضمن** `SyncEngine._tables`. على الويب هتبقى قيم افتراضية → أرقام المتأخرات والتقارير ممكن تختلف عن الموبايل. لازم قرار Q8 (مزامنة إعدادات الفريق) قبل الإطلاق.

## R8 — نتائج الـ spike (2026-10-31)

**اللي اتنفّذ**: T001–T005 (بدون أي تعديل على السيرفر).

- **خط الأساس (أندرويد/الاختبارات)**: `flutter analyze` = 43 info بلا errors/warnings، و`flutter test` = 745 ناجح. بعد التعديلات: نفس الأرقام بالظبط (43 / 745).
- **قاعدة البيانات على الويب**: شغّالة. `sqflite_common_ffi_web` بمصنع **بدون shared worker** (`databaseFactoryFfiWebNoWebWorker`) + `web/sqlite3.wasm` (748KB، نسخة 3.5.2 مطابقة للمقفولة في pubspec.lock). أداة `dart run sqflite_common_ffi_web:setup` **بتفشل** على بيئتنا (بناء webdev للـ worker)، فاستغنينا عنها: التاب الواحد النشط (FR-020) بيلغي الحاجة لمشاركة القاعدة بين تابات. القاعدة بتتخزّن في IndexedDB باسم `sqflite_databases`.
- **التطبيق على المتصفح**: بعد التعديل بيعدّي شاشة الشرح ويفتح الرئيسية بالعربي (باقة تجربة 30 يوم، أقسام، بلا أخطاء `databaseFactory`). **ده بيأكد إن مسار التجربة المجانية شغّال على الويب حاليًا** → لازم يتقفل في المرحلة 4 (FR-008/FR-014).
- **Firebase من المتصفح**: تسجيل الدخول المجهول (`accounts:signUp`) نجح، وقنوات Firestore Listen/Write اشتغلت. **App Check مش عائق**. (تنبيه: المتصفح التجريبي سجّل نفسه كجهاز تجربة في `devices/` على Firestore الإنتاج، زي أي تثبيت جديد.)
- **Supabase من المتصفح**: `https://auth.active-class.online` بيرد على طلبات الصفحة من أصل مختلف بدون حجب CORS (رد 401 لغياب مفتاح apikey، وده متوقع). **لم يتم** اختبار تسجيل الدخول الفعلي والـ Realtime (محتاج حساب تجريبي).
- **عوائق باقية ظاهرة**: خطأ `Uncaught Error` واحد متكرر في الكونسول = استدعاء `dart:io` غير محمي (مهمة T015/T014). و CanvasKit والخط من `gstatic` (T019/FR-023: `--no-web-resources-cdn`). حجم `main.dart.js` = 7.7MB.
- **لسه ماتقاسش (T006)**: زمن السحب الكامل لفريق حقيقي وحجم IndexedDB — محتاج حساب مدرس/فريق للاختبار (بيانات دخول يقدّمها المستخدم). **قرار "نكمل" (T007) مبدئيًا إيجابي**، ومشروط بقياس T006.

## R9 — أول نشر (2026-10-31، محمي بباسورد)

- DNS `app` → `192.99.145.122` انتشر. شهادة Let's Encrypt اتطلّعت تلقائيًا من Caddy.
- النسخة 1.2.80_4098 (بناء `--no-web-resources-cdn`، 40MB) على `/var/www/app.active-class.online/releases/1.2.80_4098` والـ symlink `current`.
- بلوك Caddy مضاف في آخر `/etc/caddy/Caddyfile` بـ `basic_auth` (مستخدم `gate`، الهاش والباسورد في `/root/.web_gate_hash` و`/root/.web_gate_pw` على السيرفر). نسخ احتياطية: `/etc/caddy/Caddyfile.bak.20261031145427` و`/root/Caddyfile.pre-app.*`.
- تحقق: كل المواقع التانية (active-class.online، auth، zmenu، waslaapp، amertimraz) بترد زي ما كانت. `app` = 401 من غير باسورد و200 بالباسورد، wasm بنوع `application/wasm`، `index.html` بدون كاش.
- **لازم نشيل `basic_auth` بعد ما بوابة الأهلية (المرحلة 4) تخلص**، لأن النسخة دي فيها التجربة المجانية مفتوحة.
- Firebase JS SDK لسه بيتحمل من `gstatic.com` (حزمة firebase_core web بتحقنه) — ممكن تتخدم محليًا لاحقًا.
- الرجوع للخلف: `ln -sfn .../releases/<old> .../current`، أو استرجاع الـ Caddyfile من النسخة الاحتياطية ثم `caddy validate` و`systemctl reload caddy`.

## R10 — شاشتا الترحيب والدخول (2026-10-31)

- `lib/views/web/`: `web_welcome_page.dart` (ترحيب: كشف حضور بيتعلّم بعلامات صح مرة واحدة + زر "تسجيل الدخول")، `web_login_page.dart` (رقم التليفون + باسورد عبر `AuthController.signIn`؛ بلا تسجيل ولا تجربة؛ نسيت الباسورد → واتساب الدعم)، `web_auth_widgets.dart` (الألوان وكشف الحضور وشعار).
- التوجيه: `SplashPage` على الويب بيستعيد الجلسة، ولو مفيش → الترحيب؛ بعد الدخول يرجع للسبلاش. الشرح التعريفي بيتخطّى على الويب. مسار أندرويد ما اتغيّرش.
- اختبارات: `test/web_auth_pages_test.dart` (16) — سطح مكتب 1366/1920 وتابلت 800 وموبايل 360/320 وخط 1.5 وتقليل الحركة، بخط Cairo الحقيقي. الإجمالي 761 ناجح، analyze 43 (خط الأساس).
- منشور على `app.active-class.online` (محمي بالباسورد) إصدار `1.2.80_4098-welcome1`، والسابق محتفظ بيه للرجوع.

## R11 — تجاوب الشاشات العريضة، المستوى 1 (2026-10-31)

- `lib/utils/responsive.dart` (دوال صرفة)، `lib/widgets/web_responsive_frame.dart` (إطار فوق الـNavigator في `main.dart`: عرض أقصى 1100 متوسّط، تكبير خط 1.12 وأيقونات 26 من عرض 900، ويشمل النوافذ والـ bottom sheets)، `bottomSheetTheme` بحد 640 على الويب فقط.
- شبكات بتزيد أعمدتها من عرض 600: الرئيسية (3→حتى 6)، الطلاب (2→5)، معرض QR (2→5). أقل من 600 = نفس الأرقام الأصلية بالظبط.
- أندرويد: الإطار `enabled=false`، لا تغيير (تابلت ≥600 بياخد أعمدة أكتر في الشبكات التلاتة فقط).
- 8 اختبارات جديدة، الإجمالي 769 ناجح، analyze 43. منشور بإصدار `1.2.80_4098-responsive1`.
- لسه (المستوى 2): إعادة تخطيط الحضور والمدفوعات والرئيسية بعمودين/قائمة جانبية — بعد بوابة الأهلية.

## R12 — تسجيل الخروج ومسح بيانات الويب (2026-10-31، FR-021)

- زرار خروج ظاهر في هيدر الرئيسية (ويب فقط) + نفس الخيار في الإعدادات ← الحساب والفريق، وكلاهما عبر `lib/views/web/web_session.dart` (`confirmAndSignOutWeb`): تأكيد، وتحذير بعدد التعديلات اللي لسه ماترفعتش (`sync_outbox`)، ثم خروج + مسح + إعادة تحميل.
- **اكتشاف مهم (اتجرّب عمليًا في المتصفح)**: `deleteDatabase` لـ SQLite WASM لوحده **ما بيمسحش** محتوى IndexedDB (بيسيب blocks يتيمة جواها بيانات قديمة)، وحتى بعد `DELETE` + `VACUUM` الـblocks اللي بعد طول الملف الجديد بتفضل. الحل المعتمد بالترتيب: `PRAGMA secure_delete` + حذف كل الصفوف + `VACUUM` → إغلاق وحذف الملف → **مسح مخازن IndexedDB نفسها** (`browser_storage_purge_web.dart`) → `SharedPreferences.clear()` → `window.location.reload()`.
- التحقق: زرعنا علامة داخل block في IndexedDB وعمل خروج؛ العلامة اختفت وبقت قاعدة جديدة (108 blocks، طول الملف الافتراضي)، وlocalStorage اتمسح، والصفحة اتعمل لها reload.
- الاختبار الآلي لخطوة المسح نفسها غير مضاف (محتاج متصفح)؛ اختباري يدوي عبر بناء معاينة مؤقت بعلامة `PREVIEW_NO_AUTH` اتشالت من الكود.

## R13 — حادثة قفل الفريق من الويب (2026-10-31) — خطأ في نسختنا

- **السبب الجذري:** الويب كان بيشغّل `TeamModeService._startEngine` بفرع المالك زي الموبايل، ومنه `_watchOwnerLicense` اللي بيبعت `set_team_license_active(_hasRealPaidLicense)`. ترخيص الويب المحلي = تجربة (مفيش كود)، فبيبعت `false` مع كل فتح بجلسة دخول، فـ`teams.owner_license_active=false` → RLS على كل الجداول بيقفل القراءة والكتابة للمالك **والمساعدين** (والمساعد بيقطع اتصاله تلقائيًا بـ`_handleLicenseInactive`). ده كمان اللي منع الموبايل من رفع 4701 عملية (42501) وخلّى الويب فاضي.
- **الإصلاح:** `if (kIsWeb) return;` بعد `_engine!.start()` في `_startEngine` — الويب ما بيبعتش حالة الترخيص ولا بيانات المالك (اسم/بوابة/مالكين شركاء/وسم الجهاز). منشور `1.2.80_4098-nopush1`.
- **كان ممكن يتمنع من الأول:** كان لازم بوابة الأهلية (المرحلة 4) تسبق أي دخول حقيقي. درس: أي مسار على الويب بيكتب في بيانات الفريق/المالك لازم يتفحص إنه read/edit-only قبل ما أي مدرس حقيقي يدخل بيه.
- **متبقي:** اختبار آلي لضمان إن الويب ما بيناديش RPCs المالك (مش مضاف)، وعرض «الترخيص مقفول» على الويب لو `is_team_license_active` = false (مرحلة 4).

## R14 — ترخيص صاحب الفريق على الويب (2026-10-31، T031/T032 جزئيًا)

- بعد استعادة الفريق على الويب (`_startEngine` بفرع `kIsWeb`) بنجيب `teams.license_code` من Supabase ثم نقرا `licenses/{code}` من Firestore **قراءة بس** (`LicenseController.applyOwnerLicenseReadOnly`): من غير ربط جهاز ولا تجربة ولا أي كتابة. الحالة من `webOwnerLicenseStatus` (دالة صرفة + 4 اختبارات): موقوف > منتهي > فعّال (بلا تاريخ = مدى الحياة).
- `_checkTrial` بيتخطّى على الويب بعد التطبيق (`webOwnerLicenseApplied`) عشان التجربة المحلية ماتكتبش فوق الترخيص. بانر التجربة بيختفي وبتظهر الباقة وحدودها.
- لسه (المرحلة 4): إعادة فحص دوري، شاشة «الترخيص مقفول»، وإيقاف تسجيل جهاز التجربة `devices/{uuid}` على الويب.
