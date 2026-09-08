# Data Model: تنظيف وتوحيد رقم هاتف ولي الأمر

## 1. `PhoneHelper` (`lib/utils/phone_helper.dart`) — نقي، بلا حالة

```dart
enum WhatsappHandleKind { empty, waLink, phone, username, invalid }

class WhatsappHandle {
  final WhatsappHandleKind kind;
  final String value; // waLink: رابط https كامل؛ phone: أرقام؛ username: بلا @
}

class PhoneHelper {
  /// أرقام عربية-هندية/فارسية → لاتيني.
  static String toLatinDigits(String s);

  /// تنظيف للتخزين: toLatinDigits ثم إزالة كل ما ليس [0-9] أو '+' (يشمل
  /// المسافات/الأقواس/الشرطات/النقط وعلامات التحكّم في الاتجاه)، '+' يبقى
  /// أول الحرف فقط، '+2'+'0…' → '0…'، بادئة '00' تُزال.
  static String cleanForStorage(String raw);

  /// رقم wa.me: cleanForStorage ثم إزالة '+' وبادئة '00'؛ لو يبدأ بـ
  /// dialCode يُرجَع؛ لو دولي واضح (^[1-9]\d{7,}$) يُرجَع؛ وإلا
  /// dialCode + (الرقم بلا أصفار بادئة).
  static String waMe(String raw, String dialCode);

  /// للعرض تحت الحقل: '‎+20 100 123 4567' (تجميع تقريبي).
  static String displayIntl(String raw, String dialCode);

  /// الجزء الوطني 7..12 رقمًا وبلا حروف متبقّية.
  static bool isLikelyValid(String raw, String dialCode);

  /// تحليل حقل «واتساب ولي الأمر».
  static WhatsappHandle parseWhatsappHandle(String raw);
}
```

**قواعد التحقّق** (من FR):
| المدخل | `cleanForStorage` | `waMe` (dial=20) | `isLikelyValid` |
|---|---|---|---|
| `+20 100 123 4567` | `+201001234567` | `201001234567` | ✅ |
| `٠١٠٠١٢٣٤٥٦٧` | `01001234567` | `201001234567` | ✅ |
| `‪01001234567‬` (بيدي) | `01001234567` | `201001234567` | ✅ |
| `00201001234567` | `+201001234567` | `201001234567` | ✅ |
| `1001234567` | `1001234567` | `201001234567` | ✅ |
| `+2 01001234567` | `01001234567` | `201001234567` | ✅ |
| `+966501234567` | `+966501234567` | `966501234567` | ✅ (دولي صريح) |
| `123` | `123` | `20123` | ❌ (تحذير) |
| `` (فارغ) | `` | `` | ❌ (بلا معاينة) |

## 2. `phone_format.dart` (قائم) — يصير غلافًا

```dart
String normalizeWhatsappPhone(String input, String defaultDial) =>
    PhoneHelper.waMe(input, defaultDial);
```

## 3. `CustomTextField` (`lib/widgets/custom_widgets.dart`) — بارامترات جديدة اختيارية

| بارامتر | نوع | افتراضي | يُمرَّر لـ |
|---|---|---|---|
| `textDirection` | `TextDirection?` | `null` | `TextFormField.textDirection` |
| `textAlign` | `TextAlign` | `TextAlign.start` | `TextFormField.textAlign` |
| `inputFormatters` | `List<TextInputFormatter>?` | `null` | `TextFormField.inputFormatters` |

صفر تأثير على ~40 استخدامًا قائمًا.

## 4. `PhoneField` (`lib/widgets/phone_field.dart`) — جديد

```dart
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onContactPick;   // زر جهات الاتصال (اختياري)
  final String dialCode;               // settings.countryDial.value
}
```
- `CustomTextField` بـ`textDirection: ltr`, `textAlign: left`, `keyboardType: phone`,
  `inputFormatters: [PhoneSanitizerFormatter()]`.
- تحته: `ValueListenableBuilder(controller)` →
  - `text.isEmpty` → `SizedBox.shrink()`.
  - وإلا سطر «هيتبعت على: {PhoneHelper.displayIntl(text, dialCode)}».
  - `!PhoneHelper.isLikelyValid(text, dialCode)` → سطر تحذير برتقالي (غير معطِّل).

`PhoneSanitizerFormatter extends TextInputFormatter`: `formatEditUpdate(old, new) =>
TextEditingValue(text: PhoneHelper.cleanForStorage(new.text), selection: collapsed(atEnd))`.

## 5. عمود `students.guardian_whatsapp` (US3 — DB v29 → **v30**)

### SQLite
`ALTER TABLE students ADD COLUMN guardian_whatsapp TEXT` (+ في `_createTables`). قيمة اختيارية،
`null` للطلاب القدامى.

### `Student` model
`final String? guardianWhatsapp;` — يُضاف للـconstructor، `toMap` (`'guardian_whatsapp'`),
`fromMap`, `copyWith`. بدون منطق تحقّق في الموديل (التحقّق طبقة عرض).

### Supabase `public.students`
`alter table public.students add column if not exists guardian_whatsapp text;` — عبر SSH.
`trg_set_updated_at` على `students` موجود (spec 031). RLS موروثة (نفس صفوف الطالب).

### `SyncEngine` (TABLE_STUDENTS)
- `_buildRemoteRow`: `'guardian_whatsapp': payload[COL_STUDENT_GUARDIAN_WHATSAPP]`
- `_toLocalMap`: `COL_STUDENT_GUARDIAN_WHATSAPP: remote['guardian_whatsapp']`

## 6. `whatsapp_launcher.dart` (US3) — دالة توجيه واحدة

```dart
Future<void> launchGuardianWhatsapp({
  required BuildContext context,
  String? phone,          // student.guardianPhone
  String? whatsapp,       // student.guardianWhatsapp
  required String message,
  required String dialCode,
});
```
أولوية: `parseWhatsappHandle(whatsapp)` → `waLink` يفتح مباشرة؛ وإلا رقم صالح (`phone` أو
`whatsapp==phone`) → `wa.me/<waMe>?text=`؛ وإلا `username` → فتح `wa.me/` + `Clipboard` + toast؛
وإلا خطأ لطيف.

## 7. لا تأثير

- `PricingHelper`، جداول الحضور/الدفع/الامتحان — بلا مساس.
- `guardian_phone` schema — بلا تغيير (النص فقط يُنظَّف عند الإدخال).
- كل استخدامات `CustomTextField` غير حقل الرقم — بلا تغيير.
