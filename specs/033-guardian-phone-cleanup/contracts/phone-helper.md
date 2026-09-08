# Contract: `PhoneHelper` (نقي)

`lib/utils/phone_helper.dart` — كل الدوال `static`، بلا حالة، بلا I/O.

## `toLatinDigits(String s) → String`
- U+0660–U+0669 (عربي-هندي) و U+06F0–U+06F9 (فارسي) → `0`–`9`.
- باقي المحارف كما هي.

## `cleanForStorage(String raw) → String`
1. `toLatinDigits`.
2. احذف كل محرف ليس `[0-9]` ولا `+` — بما يشمل: مسافة، `()`, `-`, `.`, `/`, وعلامات
   التحكّم في الاتجاه/التنسيق (U+200B–U+200F، U+202A–U+202E، U+2066–U+2069، U+00A0، U+FEFF).
3. أبقِ `+` فقط لو كان في **بداية** الناتج؛ احذف أي `+` داخلي.
4. لو الناتج يبدأ بـ`+2` ومتبوعًا بـ`0` → احذف `+2` (نسخ ناقص شائع لمصر).
5. لو الناتج يبدأ بـ`00` → استبدله بـ`+`.
6. أرجِع الناتج (قد يكون فارغًا، `01…`، `+20…`، `+966…`).

**لا يفرض رمز دولة، لا يحذف أصفارًا وطنية** — ده وظيفة `waMe` فقط.

## `waMe(String raw, String dialCode) → String`
1. `p = cleanForStorage(raw)`؛ احذف `+` البادئ.
2. لو `p` يبدأ بـ`dialCode` → أرجِع `p`.
3. لو `p` يطابق `^[1-9][0-9]{6,}$` (دولي بلا صفر بادئ) → أرجِع `p`.
4. وإلا → `dialCode + p.replaceFirst(RegExp(r'^0+'), '')`.
5. لو `p` فارغ → أرجِع `''` (المستدعي يتعامل).

**ثبات**: `waMe(waMe(x, d), d) == waMe(x, d)`.

## `displayIntl(String raw, String dialCode) → String`
- `w = waMe(raw, dialCode)`؛ لو فارغ → `''`.
- `national = w.substring(dialCode.length)`.
- أرجِع `'‎+$dialCode ' + <national مجمّعة>` — مصر (`dialCode=='20'`، طول 10): `N NNN NNN NNNN`؛
  غير ذلك: مجموعات 3 ثم 4.
- علامة LRM (`‎`) في البداية لضمان عرض LTR داخل نص عربي.

## `isLikelyValid(String raw, String dialCode) → bool`
- `c = cleanForStorage(raw)`؛ لو فيه أي محرف غير `[0-9+]` → `false` (مستحيل عمليًا بعد التنظيف،
  حارس).
- `national = waMe(raw, dialCode).substring(dialCode.length)`.
- `return national.length >= 7 && national.length <= 12`.

## `parseWhatsappHandle(String raw) → WhatsappHandle`
| الشرط (بالترتيب) | `kind` | `value` |
|---|---|---|
| `raw.trim().isEmpty` | `empty` | `''` |
| يطابق `^(https?://)?(www\.)?(wa\.me\|api\.whatsapp\.com\|chat\.whatsapp\.com)/\S+` | `waLink` | الرابط بـ`https://` مضمونة |
| `cleanForStorage(raw)` طوله ≥ 7 وكله `[0-9+]` | `phone` | `cleanForStorage(raw)` |
| يطابق `^@?[A-Za-z0-9._]{3,30}$` | `username` | بلا `@` |
| غير ذلك | `invalid` | `raw.trim()` |

## اختبارات (`test/phone_helper_test.dart`)
- جدول data-model §1 كامل (8 صفوف) لـ`cleanForStorage`/`waMe`/`isLikelyValid`.
- `toLatinDigits`: عربي خالص، فارسي، مختلط `010٠٠123`، بلا أرقام.
- علامات اتجاه: `'‪01001234567‬'` → `01001234567`.
- `waMe` ثبات (تطبيق مزدوج).
- `displayIntl`: مصري 10 خانات، فارغ → `''`، LRM في البداية.
- `parseWhatsappHandle`: `wa.me/x`, `https://wa.me/message/ABC`, `wa.me/201001234567`,
  `@ahmed_dad`, `ahmed`, `01001234567` (→ phone), `blabla !!` (→ invalid), `''` (→ empty).
