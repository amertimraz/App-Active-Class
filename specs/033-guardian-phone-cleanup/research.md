# Research: تنظيف وتوحيد رقم هاتف ولي الأمر

## قرار 1 — `PhoneHelper` نقي، نقطة تطبيع واحدة

**القرار**: `lib/utils/phone_helper.dart` — كلاس/دوال static نقية:
- `String cleanForStorage(String raw)` — يحوّل الأرقام العربية-الهندية (U+0660–U+0669) والفارسية
  (U+06F0–U+06F9) → لاتيني؛ يزيل كل ما هو ليس رقمًا لاتينيًا أو `+` **بعد** تحويل الأرقام (يشمل
  المسافات، `()`, `-`, `.`, وعلامات التحكّم في الاتجاه U+200E/U+200F/U+202A–U+202E/U+2066–U+2069
  وأي محارف تنسيق)؛ يبقي `+` فقط لو في البداية؛ يطبّق: `+2` + `01…` → `01…`؛ `00` بادئة → يُزال؛
  الناتج: `+<intl>` لو ظاهر رمز دولة صريح، وإلا `0<national>` أو `<national>` كما هو (بلا فرض رمز).
- `String waMe(String raw, String dialCode)` — يبني رقم `wa.me`: ينظّف، يزيل `+`، يزيل `00` بادئة،
  لو بدأ بـ`dialCode` يرجّعه؛ لو تسلسل دولي واضح (`^[1-9]\d{7,}$`) يرجّعه؛ وإلا `dialCode` +
  الرقم بعد إزالة أصفار البداية. (= منطق `normalizeWhatsappPhone` الحالي **بعد** خطوة تحويل الأرقام).
- `String displayIntl(String raw, String dialCode)` — «‎+20 100 123 4567» للمعاينة (تجميع خانات
  تقريبي: `+CC N NNN NNN NNNN` لمصر، fallback = تجميع كل 3–4).
- `bool isLikelyValid(String raw, String dialCode)` — طول الجزء الوطني بين 7 و12 رقمًا، بلا حروف
  متبقية بعد التنظيف.

**السبب**: السبب الجذري للأعطال = `RegExp(r'[^0-9+]')` بيمسح الأرقام العربية بالكامل. الإصلاح =
**تحويل الأرقام قبل التصفية** + إزالة صريحة لعلامات الاتجاه. نقطة واحدة تمنع تكرار الباج.

**البدائل المرفوضة**: مكتبة `libphonenumber` — ثقيلة، تحتاج بيانات لكل دولة، والنطاق مصر أساسًا.

---

## قرار 2 — `phone_format.dart` يصير غلافًا رفيعًا (توافق تدريجي)

**القرار**: `normalizeWhatsappPhone(input, dial)` يبقى موجودًا لكن جسمه = `PhoneHelper.waMe(input, dial)`.
النسخ المحلية في `attendance_page.dart` / `exam_grades_page.dart` / `reports_page.dart` /
`group_details_page.dart` / `at_risk_students_page.dart` / `online_exam_results_page.dart` تُحذَف
وتُستبدَل بـ`PhoneHelper.waMe(...)` (أو `whatsapp_launcher`).

**السبب**: تقليل مخاطر التغيير الكبير — الغلاف يبقي أي مستدعٍ لم يُهاجَر شغّالًا، والهجرة تتم كلها
في نفس المهمة لكن كل ملف على حدة.

---

## قرار 3 — حقل الرقم: LTR + inputFormatter + معاينة (`PhoneField`)

**القرار**:
- `CustomTextField` يكسب 3 بارامترات اختيارية: `TextDirection? textDirection`، `TextAlign textAlign =
  TextAlign.start`، `List<TextInputFormatter>? inputFormatters` — تُمرَّر لـ`TextFormField`. صفر أثر
  على أي استخدام قائم (كلها اختيارية بقيَم افتراضية).
- `lib/widgets/phone_field.dart` (جديد): `PhoneField({controller, onContactPick})` = `CustomTextField`
  بـ`textDirection: TextDirection.ltr`, `textAlign: TextAlign.left`, `keyboardType: phone`,
  `inputFormatters: [_PhoneSanitizerFormatter()]` + زر جهات الاتصال + تحته `Obx`/`ValueListenableBuilder`
  على `controller` يعرض: لو غير فارغ → «هيتبعت على: {PhoneHelper.displayIntl}» + لو `!isLikelyValid`
  → سطر تحذير برتقالي «الرقم يبدو غير مكتمل» (غير معطِّل).
- `_PhoneSanitizerFormatter extends TextInputFormatter`: في `formatEditUpdate` يمرّر النص عبر
  `PhoneHelper.cleanForStorage` ويضبط الـselection على النهاية (الأرقام قصيرة، لا حاجة لحفظ موضع
  المؤشر بدقة).

**السبب**: LTR يحلّ الانعكاس البصري؛ الـformatter يحلّ اللصق الملوّث لحظيًا؛ المعاينة تقفل حلقة
التغذية الراجعة (FR-008).

**البدائل المرفوضة**: تنظيف عند الحفظ فقط — المستخدم يفضل يشوف النص الملوّث ويرتبك.

---

## قرار 4 — صيغة التخزين: «بشرية نظيفة»، التطبيع للـwa.me لحظة الإرسال

**القرار**: `guardian_phone` يُخزَّن كما يخرج من `cleanForStorage` (`01001234567` أو `+201...`).
**لا** يُخزَّن بصيغة `wa.me`. كل مسار إرسال يستدعي `PhoneHelper.waMe(stored, countryDial)` لحظتها.
البيانات القديمة (بأي صيغة) تعمل تلقائيًا لأن `waMe` يتعامل مع كل الصيغ.

**السبب**: (أ) المدرّس يفكّر بـ`01xxxxxxxxx` — تغيير الصيغة المعروضة يربكه؛ (ب) صفر ترحيل/موجة
مزامنة؛ (ج) `ContactPickerService` أصلًا يرجّع محلي.

**البدائل المرفوضة**: تخزين E.164 (`+20…`) — يتطلب ترحيل البيانات القديمة + يربك العرض.

---

## قرار 5 — US3: عمود `guardian_whatsapp` مُزامَن (DB v30) + `whatsapp_launcher`

**القرار**:
- `constants.dart`: `COL_STUDENT_GUARDIAN_WHATSAPP = 'guardian_whatsapp'` + `DATABASE_VERSION = 30`.
- `database_service.dart`: عمود في `_createTables` + `if (oldVersion < 30) ALTER TABLE students ADD
  COLUMN guardian_whatsapp TEXT` (try/catch).
- `student_model.dart`: `String? guardianWhatsapp` في الحقول/`toMap`/`fromMap`/`copyWith`.
- `sync_engine.dart`: `'guardian_whatsapp': payload[COL_STUDENT_GUARDIAN_WHATSAPP]` في `_buildRemoteRow`
  (TABLE_STUDENTS) + `COL_STUDENT_GUARDIAN_WHATSAPP: remote['guardian_whatsapp']` في `_toLocalMap`.
- `supabase/migration_guardian_whatsapp.sql`: `alter table public.students add column if not exists
  guardian_whatsapp text;` — يُطبَّق عبر SSH. (`trg_set_updated_at` على `students` موجود من spec 031.)
- `lib/utils/whatsapp_launcher.dart`: `Future<void> launchGuardianWhatsapp({required BuildContext
  context, String? phone, String? whatsapp, required String message, required String dialCode})`:
  1. `whatsapp` = رابط `wa.me`/`wa.me/message`/`wa.me/qr` صالح → `launchUrl` مباشرة (نضيف `?text=`
     لو `wa.me/<digits>` فقط).
  2. رقم صالح (`phone` أو `whatsapp` لو كان رقمًا) → `https://wa.me/${PhoneHelper.waMe(...)}?text=...`.
  3. `whatsapp` username (`@name` أو كلمة) → `launchUrl('https://wa.me/')` + `Clipboard.setData(message)`
     + `AppToast.info('اتنسخت الرسالة — الصقها في شات ولي الأمر')`.
  4. لا رقم ولا واتساب → رسالة خطأ لطيفة.

**السبب**: نمط `guardian_phone` بالحرف — أقل مفاجآت. `whatsapp_launcher` يوحّد ~10 نقاط إرسال.

**قيد**: واتساب مبيوفّرش رابط عميق لـusername لوحده — الحل جزئي (فتح + نسخ) وموثَّق في الـspec.

---

## قرار 6 — تحليل رابط/username واتساب

**القرار**: `PhoneHelper.parseWhatsappHandle(String raw)` يرجّع enum + قيمة:
- `waLink` لو `raw` يطابق `^(https?://)?(wa\.me|api\.whatsapp\.com|chat\.whatsapp\.com)/...`
  (بما فيها `/message/`, `/qr/`, `/<digits>`) → يُعاد رابطًا كاملًا `https://…`.
- `phone` لو بعد `cleanForStorage` يبقى ≥7 أرقام وبلا حروف.
- `username` غير ذلك (يُزال `@` البادئ للعرض).
- `invalid`/`empty` للتحذير عند الحفظ (FR-013، غير معطِّل).

**السبب**: منطق واحد مشترك بين حقل الإدخال (تحذير) و`whatsapp_launcher` (توجيه).

---

## ملخّص الحسم

| # | الموضوع | القرار |
|---|---|---|
| 1 | التطبيع | `PhoneHelper` نقي: حوّل الأرقام العربية **قبل** التصفية + شيل علامات الاتجاه |
| 2 | التوافق | `phone_format.dart` غلاف رفيع، هجرة الملفات الـ6 في نفس المهمة |
| 3 | حقل الإدخال | `PhoneField`: LTR + `inputFormatter` + معاينة «هيتبعت على..» + تحذير |
| 4 | صيغة التخزين | بشرية نظيفة كما هي؛ `waMe()` لحظة الإرسال؛ صفر ترحيل |
| 5 | US3 | عمود `guardian_whatsapp` مُزامَن (v30) + `whatsapp_launcher` بأولوية رابط/رقم/username |
| 6 | تحليل الواتساب | `parseWhatsappHandle` → waLink/phone/username/invalid |
