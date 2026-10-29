# Research: إعلانات وبنر الخصومات عن بعد

## 1. التخزين: مجموعة بدل مستند واحد

- **Finding**: `firestore.rules` يسمح بقراءة `app_config/*` للجميع وكتابتها للأدمن، لكن الطلب تطوّر لـ"لوحة كاملة" (قائمة مسودات/مجدول/فعّال/منتهي).
- **Decision**: مجموعة `announcements/{id}` (مستند لكل إعلان) + قاعدة جديدة: `allow read: if true; allow write: if isAdmin();`.
- **Rationale**: مستند واحد لا يخزّن تاريخًا ولا مسودات. القراءة العامة آمنة (محتوى تسويقي، لا بيانات حساسة).
- **Alternatives**: حقل مصفوفة داخل `app_config` → ينتفخ ويُصعّب التعديل المتزامن؛ رُفض.

## 2. استعلام التطبيق

- **Decision**: `where('status', isEqualTo: 'published').limit(20)` ثم الترتيب والتصفية **على العميل** (publishedAt تنازليًا).
- **Rationale**: استعلام بشرط مساواة على حقل واحد لا يحتاج فهرس مركّب؛ العدد صغير. التصفية بالتواريخ والجمهور والمكان على العميل لأنها تعتمد على ساعة الجهاز وباقته.
- **Alternatives**: `orderBy` مع `where` = فهرس مركّب يحتاج نشر؛ بلا داعٍ.

## 3. تحديث لحظي في المقدمة

- **Decision**: `snapshots().listen` على نفس الاستعلام (مثل `_watchRemoteConfig` في `license_controller.dart`) أثناء فتح التطبيق، مع كتابة آخر نتيجة في `SharedPreferences` كنسخة أوفلاين.
- **Rationale**: يحقق "يظهر خلال 30 ثانية بدون تحديث"، ونفس نمط موجود فيقل الخطر. الفشل صامت.

## 4. الإشعار الخارجي (التطبيق مقفول)

- **Finding**: `workmanager` موجود لكن `callbackDispatcher` في `main.dart` ينفّذ منطق **المهمة الشهرية** لأي مهمة تصله دون فحص اسمها؛ ولا تهيئة Firebase في الـisolate.
- **Decision**: (أ) تفريق المهام بـ`switch (task)` مع إبقاء سلوك المهمة الشهرية كما هو حرفيًا، (ب) مهمة دورية جديدة `announcement_check_task` كل ~3 ساعات بقيد "اتصال متاح"، (ج) داخلها: قراءة REST عامة `GET https://firestore.googleapis.com/v1/projects/active-class-72e0f/databases/(default)/documents/announcements?pageSize=20` عبر `dart:io HttpClient` (مفيش مكتبة http)، فك الصيغة المطبوعة (`stringValue/integerValue/booleanValue/timestampValue/arrayValue/mapValue`) في دالة صرفة مختبَرة، اختيار إعلان الإشعار بنفس منطق التطبيق، ثم إظهار إشعار محلي إن لم يُرسَل لهذا الإصدار.
- **Rationale**: بدون FCM أو سيرفر، ومقبول التأخير. القراءة عامة فلا حاجة لمصادقة.
- **Alternatives**: `Firebase.initializeApp` في الخلفية = أثقل ويحتاج plugins registrant؛ FCM = خارج النطاق.
- **قيد**: باقة العميل في الخلفية تُقرأ من `SharedPreferences` (يكتبها `LicenseController` عند التغيّر)، وإن لم توجد تُعامَل تجريبي.

## 5. منع تكرار الإشعار/النافذة

- **Decision**: مفتاح لكل إعلان = `id:version` حيث `version` = `updatedAt` بالمللي ثانية (يتغيّر مع كل حفظ). نخزّن آخر مفتاح لكل نوع (`popup`/`notify`) وإغلاق كل بنر (`dismiss_home`, `dismiss_plans`) في `SharedPreferences`.
- **Rationale**: تعديل الإعلان يعيد ظهور النافذة/الإشعار/البنر تلقائيًا؛ وإعادة الفتح بدون تعديل لا تكرر.
- **تسابق**: المقدمة والخلفية يكتبان نفس مفتاح الإشعار → نعيد قراءة المفتاح قبل الإظهار مباشرة.

## 6. الاستهداف

- **Finding**: `AppPlan { trial, basic, pro, lifetime }` في `LicenseController` (`plan` Rx)؛ "المجاني" = التجريبي.
- **Decision**: الجمهور قائمة مفاتيح باقات (`trial/basic/pro/lifetime`)، فاضية = الكل. العميل بلا ترخيص = `trial`. يُقارَن بالباقة الحالية وقت العرض.
- **Edge**: ترقية من تجريبي لأساسي تحدّث `plan.value` فيُعاد اختيار الإعلان تلقائيًا (Obx).

## 7. زرار الواتساب

- **Decision**: دالة صرفة `whatsappUri(phone, message, extras)` تنظّف الرقم لأرقام فقط وتشفّر النص بـ`Uri.encodeComponent`، وتُلحق `الاسم / كود الترخيص / الباقة` من `SettingsController`/`LicenseController`. تُفتح بـ`launchUrl(mode: externalApplication)`. رقم غير صالح (<8 أرقام) → يُخفى الزرار.
- **Rationale**: يطابق مسار واتساب الموجود (`wa.me`) بدون الاعتماد على `launchGuardianWhatsapp` (مصمّم لأولياء الأمور).

## 8. أمان المحتوى

- **Decision**: كل النصوص تُعرض بـ`Text` (لا HTML). `safeHttpUrl` يقبل `http/https` فقط ويرفض غيره. تصميم/لون مجهول → `classic/purple`.
- **ملاحظة**: الأدمن يتحقق من نفس القواعد قبل الحفظ (دفاع مزدوج).

## 9. تصميم البنر

- **Decision**: ويدجت واحد `AnnouncementBanner({announcement, compact?, onClose, onCta})` بـ6 تصاميم (كلاسيك مليان، ملصق خصم، زجاجي بحدود، شريط مدمج، كوبون/تذكرة، هادئ مينيمال). الألوان من 8 ramps (50/100/200/400/600/800/900) مع تحويل فاتح/داكن: فاتح `bg=50, fg=800, acc=600, on=white`؛ داكن `bg=800, fg=100, acc=200, on=900`. تباين ≥4.5:1 مضمون بالجدول. العداد `ValueListenableBuilder` على `Ticker`/`Timer.periodic(1s)` محلي للويدجت فقط (لا يعيد بناء الشاشة).
- **Rationale**: Flutter صرف بلا GetX ليُنسخ للأدمن. الحركة تحترم `MediaQuery.disableAnimations`. أهداف اللمس ≥44.
- **تدرّج لوني**: في التطبيق الفعلي مسموح كتحسين بسيط على التصميم (1) و(2) فقط؛ المعاينة مسطّحة، وكلاهما يحقق التباين.

## 10. ترتيب العمل بين المشروعين

- **Decision**: أولًا التطبيق (النموذج + المنطق + الويدجت + الخدمة + الشاشات + الإشعار)، مع إمكانية اختباره بإضافة مستند يدويًا من Firebase Console؛ ثم الأدمن (نسخ الويدجت + الصفحة)؛ ثم نشر القاعدة؛ ثم إصدار التطبيق. الأدمن لا يتطلّب إصدار التطبيق ليعمل.
