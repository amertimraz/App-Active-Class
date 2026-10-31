# Implementation Plan: نسخة الويب من Active Class

**Branch**: `055-web-app` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/055-web-app/spec.md`

## Summary

نبني نفس كود Flutter للويب كـ**عميل أونلاين لوضع الفريق**: الدخول بحساب Supabase، الأهلية (عضو فريق + ترخيص المالك ساري + الويب مفعّل للفريق) بتتقرر من دالة سيرفر، وقاعدة sqflite بتتبدل على الويب بـ `sqflite_common_ffi_web` (SQLite WASM/IndexedDB) وتشتغل ككاش يتملي من SyncEngine الموجود. كل `dart:io` والحزم الأندرويدية بتتعزل ورا واجهات بتطبيق io وتطبيق web، والميزات اللي مالهاش مقابل بتتخفي. مفتاح التفعيل لكل مدرس = عمودين جداد في `teams` يكتبهم الأدمن من لوحة الأدمن بنفس طريقة `max_assistants`، مع طبقة رفض اختيارية في RLS حسب `Origin`. الاستضافة: سجل DNS + بلوك Caddy جديد لـ `app.active-class.online` (شهادة تلقائية) ومجلد إصدارات بـ symlink.

**مفيش تغيير على Firestore rules. فيه تغيير على Supabase (migration) وعلى لوحة الأدمن وعلى الموبايل (عزل منصّات + مزامنة إعدادات).**

## Technical Context

**Language/Version**: Dart 3.5 / Flutter 3.38 (نفس الحالي)

**Primary Dependencies**: الموجودة + `sqflite_common_ffi_web` (جديد، BSD-2) + `web` (package:web للتنزيل/Web Locks، BSD-3). لا حاجة لـ `universal_html`.

**Storage**: الويب: SQLite WASM فوق IndexedDB (كاش)، `shared_preferences` → localStorage، جلسة Supabase في localStorage. السيرفر: Supabase (مصدر الحقيقة) + Firestore (الترخيص فقط، قراءة).

**Testing**: `flutter test` (وحدة للدوال الصرفة: قرار الأهلية، ترجمة حالة الترخيص للويب، أسماء ملفات التنزيل) + `flutter test --platform chrome` لاختبارات واجهة smoke + checklist يدوي على Chrome/Edge (quickstart.md) + اختبار SQL لدالة الأهلية وسياسات RLS على السيرفر.

**Target Platform**: Web (Chrome/Edge ديسكتوب) + Android بدون أي تراجع.

**Project Type**: mobile-app + web build من نفس الكود + مشروع أدمن منفصل + Supabase self-hosted + Caddy.

**Performance Goals**: SC-001/SC-006: أول دخول ≤60ث لفريق 500 طالب، أول تحميل ≤8ث، المتكرر ≤2ث.

**Constraints**: صفر تأثير على أندرويد؛ لا CDN خارجي؛ لا تجربة مجانية على الويب؛ تاب واحد نشط.

**Scale/Scope**: ~23 ملف `dart:io` + ~45 موضع لـ `File(`/`Platform.` + 17 حزمة فيها أجزاء أندرويد فقط؛ ~10 ملفات جديدة (طبقة المنصة، بوابة الويب، شاشات القفل)؛ migration واحدة؛ صفحة/حقلين في الأدمن؛ بلوك Caddy.

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ → لا بوابات رسمية. الالتزام بمبادئ المشروع العملية: (1) منطق صرف قابل للاختبار منفصل عن الواجهة (قرار الأهلية دالة صرفة)، (2) عدم كسر سلوك قائم (أندرويد لازم يفضل زي ما هو — كل تغيير ورا واجهة منصّة)، (3) كل helper في DatabaseService بياخد txn (درس deadlock sqflite — نفس الـ API على الويب فنفس الخطر)، (4) الأمان من السيرفر مش من الواجهة (FR-013/FR-016)، (5) الفشل الصامت للميزات الاختيارية بس، مش للترخيص. **النتيجة: pass بشرط حسم Q5 (الحماية على السيرفر).**

## القرار المعماري الأساسي (ليه كده؟)

| البديل | الحكم | السبب |
|---|---|---|
| **أ. عميل أونلاين لوضع الفريق + كاش sqflite-web** | ✅ المختار | يعيد استخدام SyncEngine وRLS والـ LWW كما هم؛ مسح المتصفح = لا فقد؛ تغيير الكود أقل. |
| ب. نسخة ويب أوفلاين مستقلة (sqflite-web كمصدر حقيقة) | ❌ | IndexedDB قابل للمسح → فقد بيانات حقيقي؛ ومعاه ثغرة التجربة. |
| ج. ويب بيقرأ Supabase مباشرة من غير قاعدة محلية | ❌ للنسخة الأولى | يتطلب إعادة كتابة كل الشاشات اللي بتقرأ من `DatabaseService` (93 ألف سطر). |
| د. Flutter Windows/Desktop بدل الويب | بديل جانبي | `windows/` موجود أصلًا، بس مش "رابط على الموقع" ومحتاج تثبيت. |

### مفتاح التفعيل لكل مدرس — المقارنة

| المكان | مع | ضد | الحكم |
|---|---|---|---|
| **Firestore `licenses/{code}.webEnabled/webExpiresAt` (زي بوابة ولي الأمر) + نسخة في Supabase `teams.web_enabled/web_expires_at`** | طلب المستخدم صراحة "زي بوابة ولي الأمر": نفس النافذة ونفس الشكل في الأدمن؛ الموبايل بيقرأ الحالة من مستند الترخيص اللي بيقراه أصلًا (عرض الرابط أو جملة "اطلب التفعيل")؛ والنسخة في Supabase بتخلّي السيرفر يطبّقها في RLS ويقرّر الأهلية | الأدمن بيكتب في مكانين (Firestore + Supabase) في نفس الحفظ | ✅ **المختار (بعد قرار المستخدم 2026-10-31)** |
| Supabase `teams.web_*` بس | حماية حقيقية | شكل مختلف عن بوابة ولي الأمر في الأدمن؛ الموبايل مش بيشوفه من غير طلب إضافي | ❌ لوحده |
| Firestore `licenses/{code}.webEnabled` بس | أبسط | تطبيقه من الواجهة بس | ❌ لوحده |
| `plans_config` (لكل باقة) | سهل | مش "لمدرسين بعينهم" | ❌ لوحده؛ ممكن لاحقًا كـ"افتراضي للباقة" [Q1] |
| Firestore `app_config` allowlist | سريع | قايمة يدوية، تطبيق من الواجهة بس | ❌ |

## Project Structure

### Documentation (this feature)

```text
specs/055-web-app/
├── spec.md
├── plan.md
├── research.md                  # فحص كل حزمة + التراخيص + نتيجة البناء التجريبي
├── contracts/
│   └── supabase-web-access.md   # الأعمدة + get_web_entitlement + RLS حسب Origin
├── quickstart.md                # DNS + Caddy + النشر + checklist التحقق
└── tasks.md                     # /speckit-tasks (بعد الإجابة على الأسئلة)
```

### Source Code — التطبيق (`C:\repo\active_class`)

```text
lib/
├── core/platform/                          # جديد: طبقة المنصّة (استيراد شرطي)
│   ├── file_store.dart                     #   واجهة: saveBytes(name, bytes, mime) / readPicked()
│   ├── file_store_io.dart                  #   أندرويد: path_provider + media_store_plus + share_plus (الحالي)
│   ├── file_store_web.dart                 #   ويب: Blob + <a download>
│   ├── db_factory.dart                     #   واجهة: openAppDatabase()
│   ├── db_factory_io.dart                  #   sqflite العادي (الحالي)
│   ├── db_factory_web.dart                 #   databaseFactoryFfiWeb
│   ├── device_id.dart (+ _io/_web)         #   android_id/windows على io، UUID في localStorage على الويب
│   └── tab_lock_web.dart                   #   Web Locks: تاب واحد نشط
├── utils/platform_features.dart            # جديد (صرف): supportsNotifications/backup/contacts/... = !kIsWeb
├── utils/web_entitlement.dart              # جديد (صرف): من رد RPC + حالة الترخيص → WebAccessDecision
├── services/web_access_service.dart        # جديد: get_web_entitlement + إعادة الفحص كل 5د + عند focus
├── views/web/                              # جديد
│   ├── web_login_page.dart                 #   دخول فقط (بلا تجربة/كود/تسجيل)
│   ├── web_locked_page.dart                #   شاشات القفل لكل حالة + واتساب
│   └── web_initial_sync_page.dart          #   سحب أول مرة بنسبة
├── main.dart                               # تعديل: فرع kIsWeb → WebBootstrap (بلا Workmanager/Notifications/AppCheck-android)
├── controllers/license_controller.dart     # تعديل: مسار ويب: الترخيص من teams.license_code بلا فحص deviceId وبلا تجربة
├── services/database_service.dart          # تعديل: openDatabase عبر db_factory (بلا getDatabasesPath على الويب)
├── services/sync_engine.dart               # تعديل صغير: مؤشر تقدّم للسحب الكامل + beforeunload لو الطابور مش فاضي
├── services/backup_service.dart … export_service.dart, excel_import_service.dart  # تعديل: عبر file_store
├── views/** (≈15 ملف)                       # تعديل: إخفاء العناصر غير المدعومة + Image.memory بدل Image.file
└── web/index.html, manifest.json           # تعديل: العنوان/الأيقونات/lang=ar dir=rtl/شاشة تحميل/cropper.js
web/sqflite_sw.js, web/sqlite3.wasm          # جديد: من `dart run sqflite_common_ffi_web:setup`
tool/deploy_web.sh                           # جديد: build + rsync لمجلد إصدار + symlink
supabase/migration_web_access.sql            # جديد
test/web_entitlement_test.dart, test/platform_features_test.dart, test/file_name_test.dart
```

### Source Code — لوحة الأدمن (`C:\repo\active_class_admin`)

```text
lib/models/license_model.dart          # + webEnabled, webExpiresAt, webActiveNow (نسخة من parentPortal*)
lib/services/license_service.dart      # + setWebEnabled(code, bool) / setWebExpiresAt(code, DateTime?) — زي parentPortal
lib/services/accounts_service.dart     # + teamsByLicenseCode(code) + setTeamWebAccess(teamId, enabled, expiresAt) بـ service_role
lib/widgets/license_actions_dialog.dart# + قسم "الويب" تحت قسم بوابة أولياء الأمور بنفس الشكل (مفتاح + تاريخ)؛ الحفظ يكتب Firestore ثم Supabase، وتحذير لو 0 أو >1 فريق
lib/views/licenses_page.dart           # + شارة "ويب" جنب شارة البوابة + آخر دخول ويب
```

وفي التطبيق: `LicenseController` يقرأ `webEnabled/webExpiresAt` من مستند الترخيص (زي `parentPortalEnabled`) عشان عنصر الويب في الإعدادات/الرئيسية (FR-017)، و`create_team` ياخد القيمتين لو الفريق اتعمل بعد التفعيل (FR-015b).

### السيرفر

```text
Supabase: supabase/migration_web_access.sql (تطبيق عبر SSH كـ supabase_admin زي spec 033)
DNS:      A  app.active-class.online → 192.99.145.122  (+ AAAA لو الدومين الأساسي عنده)
Caddy:    /etc/caddy/Caddyfile  ← بلوك جديد app.active-class.online (نسخة احتياطية قبل التعديل)
Files:    /var/www/app.active-class.online/releases/<version>/  +  current → symlink
```

## خريطة العوائق (ملخص — التفاصيل في research.md)

| الفئة | الحالة على الويب | المعالجة |
|---|---|---|
| sqflite | ❌ مفيش web | `sqflite_common_ffi_web` + `db_factory` |
| `dart:io` (23 ملف، `File(` ×42، `Platform.` ×12) | يترجم بس يرمي وقت التشغيل | طبقة `core/platform` + `kIsWeb` |
| path_provider (12 ملف) | جزئي (Documents يرمي) | عبر file_store |
| media_store_plus (7) | ❌ أندرويد فقط | تنزيل Blob |
| share_plus (13) | جزئي (Web Share) | تنزيل على الويب |
| file_picker (2) / image_picker | ✅ بس بايتات مش path | قراءة `bytes` بدل `path` |
| image_cropper | ✅ يحتاج cropper.js في index.html | إضافة الأصول محليًا |
| mobile_scanner | ✅ (ZXing JS من CDN افتراضيًا) | خدمة السكربت محليًا |
| printing / pdf | ✅ (pdf.js من CDN افتراضيًا) | خدمة pdf.js محليًا |
| flutter_local_notifications / workmanager | ❌ | إخفاء (main محمي جزئيًا أصلًا) |
| permission_handler (4) | جزئي | تخطّي على الويب |
| flutter_contacts / android_id / open_filex / in_app_update / in_app_review / media_store | ❌ | إخفاء/بديل |
| google_sign_in (Drive backup) | ✅ بس فلو مختلف | إخفاء (السيرفر هو النسخة) |
| firebase_* | ✅ إعدادات web موجودة | App Check web حسب Q9 |
| supabase_flutter | ✅ | CORS من Kong (تأكيد) |
| audioplayers, device_info_plus, package_info_plus, flutter_timezone, url_launcher | ✅ | — |
| CanvasKit/الخطوط | ✅ بس من gstatic افتراضيًا | `--no-web-resources-cdn` + خط احتياطي للإيموجي |

## المراحل والتقدير

> التقدير بأيام عمل فعلية (مطوّر واحد + Claude)، شامل الاختبار على الجهاز والمتصفح.

| # | المرحلة | المحتوى | تقدير | يعتمد على |
|---|---|---|---|---|
| 0 | تحقيق تقني (spike) | بناء ويب يفتح الرئيسية + sqflite-web + دخول Supabase + CORS + Firestore من `localhost` | 2–3 أيام | — |
| 1 | طبقة المنصّة | `core/platform/*` + تحويل الـ 23 ملف + إخفاء الميزات غير المدعومة + اختبارات أندرويد عدم تراجع | 5–7 أيام | 0 |
| 2 | الدخول والأهلية والترخيص | migration + `get_web_entitlement` + `WebAccessService` + شاشات الدخول/القفل/السحب الأول + مسار ترخيص الويب | 3–4 أيام | 0 |
| 3 | لوحة الأدمن | مفتاح الويب + الانتهاء + آخر دخول | 1 يوم | 2 (migration) |
| 4 | مزامنة الإعدادات المؤثرة (FR-018) | جدول/عمود إعدادات الفريق + سحب/دفع + migration | 2–3 أيام | Q8 |
| 5 | الشاشات اليومية على الكمبيوتر | QR/طباعة/تصدير/تنزيل + عرض أقصى للمحتوى + تاب واحد | 3–5 أيام | 1 |
| 6 | الاستضافة والنشر | DNS + Caddy + سكربت النشر + version check + صفحة التراخيص | 1 يوم | 0 |
| 7 | حماية السيرفر (FR-013) | RLS حسب Origin على كل جداول الفريق + اختبار SQL | 1–2 يوم | 2، Q5 |
| 8 | Beta مقفول | 2–3 مدرسين أسبوعين، إصلاحات | 3–5 أيام شغل موزعة | الكل |

**القرار (Q7 = نسخة مصغّرة)**: المرحلة 1 تتعمل على شاشات النسخة الأولى بس (الباقي يتخفي)، والمرحلة 5 على الحضور/المدفوعات/الطباعة/التصدير بس. منع الكتابة أوفلاين (Q4) بيبسّط المزامنة على الويب.

| المرحلة | تقدير النسخة المصغّرة |
|---|---|
| 0 spike | 2–3 |
| 1 طبقة المنصّة (شاشات النسخة الأولى) + إخفاء الباقي | 3–4 |
| 2 الدخول والأهلية + المساعدين + منع الكتابة أوفلاين | 3–4 |
| 3 الأدمن (زي بوابة ولي الأمر) + عنصر الويب في الموبايل | 1–2 |
| 4 مزامنة إعدادات الفريق (Q8 = موافقة): `team_settings` + migration + سحب/دفع للقائمة المتزامنة في SyncEngine + المالك يكسب أول مرة | 2–3 |
| 5 الحضور/المدفوعات/الطباعة/التصدير على الكمبيوتر | 2–3 |
| 6 الاستضافة والنشر | 1 |
| 3b إنشاء الفريق تلقائيًا من الموبايل لما الويب يتفعّل (Q6) | 1–2 |
| 7 حماية السيرفر | **النسخة التانية (Q5)** — 0 دلوقتي |
| **الإجمالي** | **≈ 15–22 يوم** (من غير التجربة المقفولة، شهر) |

App Check مش مفروض على Firestore (اتفحص: REST من غير توكن = 200) → مفيش شغل reCAPTCHA.

## المخاطر

| # | الخطر | الأثر | الاحتمال | التخفيف |
|---|---|---|---|---|
| R1 | فقد بيانات من مسح المتصفح مع طابور غير مرفوع | عالي | متوسط | Q4=منع الكتابة أوفلاين، أو `beforeunload` + مؤشر "تعديلات لم ترفع" |
| R2 | تراجع على أندرويد من عزل `dart:io` | عالي | متوسط | كل تغيير ورا واجهة؛ اختبار أندرويد كامل لكل مرحلة؛ لا تغيير سلوك io |
| R3 | أداء SQLite WASM/السحب الكامل لفرق كبيرة | متوسط | متوسط | سحب على دفعات + مؤشر؛ قياس في المرحلة 0 |
| R4 | حجم الـ bundle وبطء أول فتح (CanvasKit + ~6–10MB JS) | متوسط | عالي | كاش طويل للأصول، شاشة تحميل HTML، deferred imports للشاشات الكبيرة، وwasm لاحقًا |
| R5 | تجاوز الحماية من الواجهة (تعديل JS) | متوسط | منخفض | FR-013 (RLS حسب Origin) + الأهلية من السيرفر |
| R6 | ثغرات قديمة: العميل بيحدد `teams.license_code` و`owner_license_active` بنفسه | متوسط | منخفض | خارج النطاق — متابعة منفصلة: التحقق من الترخيص على السيرفر (Edge Function/cron يقرأ Firestore) |
| R7 | إعدادات محلية (`app_settings`) تخلي أرقام الويب مختلفة عن الموبايل | عالي | مؤكد بدون FR-018 | المرحلة 4 قبل الإطلاق |
| R8 | ذاكرة/مساحة الـ VPS (77% مستخدم، 1.2GB RAM متاح) | منخفض | منخفض | ملفات ثابتة بس (~30–40MB لكل إصدار)، الاحتفاظ بآخر 3 إصدارات |
| R9 | تعليق sqflite لو helper نادى db جوه txn (نفس الـ API على الويب) | عالي | منخفض | نفس قاعدة txn في كل helper؛ اختبار السحب الكامل على الويب |
| R10 | App Check مفروض يمنع الويب من Firestore | عالي | غير معروف | Q9؛ ReCaptcha v3 provider للويب لو لازم |
| R11 | Kong CORS أو Realtime websocket من دومين جديد | متوسط | منخفض | تحقق في المرحلة 0 |

## Complexity Tracking

| الإضافة | ليه لازمة | البديل الأبسط المرفوض |
|---|---|---|
| طبقة `core/platform` بالاستيراد الشرطي | `dart:io` بيرمي على الويب، و`kIsWeb` لوحده مش كفاية لما الكلاس نفسه (File) هو المشكلة | `if (kIsWeb)` متفرّق في 45 مكان: صعب يتراجع وسهل يتنسي |
| RLS حسب `Origin` | الحماية الوحيدة اللي مايقدرش JS في المتصفح يزوّرها | الاعتماد على الواجهة: يتلف عليه بتعديل الـ JS |
| مزامنة إعدادات الفريق | من غيرها أرقام المتأخرات على الويب تختلف عن الموبايل | قيم افتراضية على الويب: أرقام غلط قدام المدرس |
