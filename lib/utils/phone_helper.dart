// lib/utils/phone_helper.dart
//
// spec 033 — نقطة تطبيع رقم الهاتف الوحيدة في التطبيق. نقية، بلا حالة.
// السبب: النسخ المكرّرة القديمة كانت بتعمل replaceAll(RegExp(r'[^0-9+]'), '')
// اللي بيمسح الأرقام العربية-الهندية (٠١٢٣) بالكامل — فالرقم المنسوخ من سجل
// المكالمات على أندرويد عربي كان بيتبوّظ وواتساب يفتح صفحة فاضية.

enum WhatsappHandleKind { empty, waLink, phone, username, invalid }

class WhatsappHandle {
  final WhatsappHandleKind kind;

  /// waLink: رابط https كامل | phone: أرقام نظيفة | username: بلا @ | غيره: النص كما هو
  final String value;

  const WhatsappHandle(this.kind, this.value);
}

class PhoneHelper {
  PhoneHelper._();

  // أي محرف ليس رقمًا لاتينيًا أو '+' — يشمل المسافات والرموز وعلامات
  // التحكّم في الاتجاه والمحارف غير المرئية (بعد تحويل الأرقام العربية).
  static final RegExp _notPhoneChar = RegExp(r'[^0-9+]');
  static final RegExp _waLink = RegExp(
    r'^(https?://)?(www\.)?(wa\.me|api\.whatsapp\.com|chat\.whatsapp\.com)/\S+',
    caseSensitive: false,
  );
  static final RegExp _usernameLike = RegExp(r'^@?[A-Za-z0-9._]{3,30}$');
  static final RegExp _leadingZeros = RegExp(r'^0+');

  /// أرقام عربية-هندية (٠–٩) وفارسية (۰–۹) → لاتينية.
  static String toLatinDigits(String s) {
    if (s.isEmpty) return s;
    final b = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        b.writeCharCode(0x30 + (rune - 0x0660));
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        b.writeCharCode(0x30 + (rune - 0x06F0));
      } else {
        b.writeCharCode(rune);
      }
    }
    return b.toString();
  }

  /// تنظيف للتخزين: أرقام لاتينية، بلا مسافات/رموز/علامات اتجاه، '+' أول
  /// الحرف فقط، '+2'+'0…' → '0…'، '00…' → '+…'.
  static String cleanForStorage(String raw) {
    if (raw.isEmpty) return '';
    var p = toLatinDigits(raw).replaceAll(_notPhoneChar, '');
    if (p.isEmpty) return '';
    final hadPlus = p.startsWith('+');
    p = p.replaceAll('+', '');
    if (p.isEmpty) return '';
    if (hadPlus) return '+$p';
    if (p.startsWith('00')) return '+${p.substring(2)}';
    return p;
  }

  /// رقم wa.me (بلا '+' ولا صفر بادئ) باستخدام رمز الدولة عند الحاجة.
  ///  - '+' صريح (أو '00') → رقم دولي كما هو (بلا '+').
  ///  - بلا '+' ويبدأ بـ dialCode → كما هو.
  ///  - بلا '+'، طويل (≥11 خانة) وبلا صفر بادئ → رقم دولي بلا '+' (رمز
  ///    دولة مكتوب من غير '+'، زي 9665… أو 12015…).
  ///  - بلا '+' → dialCode + الرقم بعد إزالة أصفار البداية (رقم وطني، زي
  ///    01001234567 أو 1001234567).
  static String waMe(String raw, String dialCode) {
    final cleaned = cleanForStorage(raw);
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned.substring(1);
    if (cleaned.startsWith('00')) return cleaned.substring(2);
    if (cleaned.startsWith(dialCode)) return cleaned;
    if (cleaned.length >= 11 && !cleaned.startsWith('0')) return cleaned;
    return dialCode + cleaned.replaceFirst(_leadingZeros, '');
  }

  /// true لو الرقم بعد التنظيف يحمل رمز دولة صريح (سواء بـ'+' أو '00' أو
  /// تسلسل دولي طويل بلا صفر بادئ) — يعني displayIntl مايفترضش dialCode.
  static bool _hasExplicitCountry(String cleaned, String dialCode) {
    if (cleaned.startsWith('+') || cleaned.startsWith('00')) return true;
    if (cleaned.startsWith(dialCode)) return true;
    return cleaned.length >= 11 && !cleaned.startsWith('0');
  }

  /// للعرض تحت الحقل: "‎+20 100 123 4567" (LRM في البداية لضمان LTR).
  /// لو الرقم دولي بصريح رمز دولة مختلف، بيعرض الرقم الكامل بلا افتراض مصر.
  static String displayIntl(String raw, String dialCode) {
    final w = waMe(raw, dialCode); // بلا '+'
    if (w.isEmpty) return '';
    final cleaned = cleanForStorage(raw);
    final foreign = _hasExplicitCountry(cleaned, dialCode) &&
        !w.startsWith(dialCode);
    if (foreign) {
      // رقم دولي غير مصري — اعرضه كامل بمجموعات 3/4 بلا تقسيم رمز الدولة.
      return '‎+${_group(w)}'.trimRight();
    }
    final national = w.length > dialCode.length ? w.substring(dialCode.length) : '';
    final String grouped;
    if (dialCode == '20' && national.length == 10) {
      grouped = '${national.substring(0, 3)} ${national.substring(3, 6)} '
          '${national.substring(6)}';
    } else {
      grouped = _group(national);
    }
    return '‎+$dialCode $grouped'.trimRight();
  }

  static String _group(String digits) {
    final parts = <String>[];
    var i = 0;
    while (i < digits.length) {
      final take = (digits.length - i) > 4 ? 3 : (digits.length - i);
      parts.add(digits.substring(i, i + take));
      i += take;
    }
    return parts.join(' ');
  }

  /// الجزء الوطني بين 7 و12 رقمًا (أو 8..15 لرقم دولي صريح) وبلا حروف.
  static bool isLikelyValid(String raw, String dialCode) {
    final c = cleanForStorage(raw);
    if (c.isEmpty) return false;
    if (RegExp(r'[^0-9+]').hasMatch(c)) return false;
    final w = waMe(raw, dialCode);
    if (_hasExplicitCountry(c, dialCode) && !w.startsWith(dialCode)) {
      return w.length >= 8 && w.length <= 15; // E.164
    }
    final national = w.length > dialCode.length ? w.substring(dialCode.length) : w;
    return national.length >= 7 && national.length <= 12;
  }

  /// تحليل حقل «واتساب ولي الأمر».
  static WhatsappHandle parseWhatsappHandle(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return const WhatsappHandle(WhatsappHandleKind.empty, '');
    if (_waLink.hasMatch(t)) {
      final url = t.startsWith(RegExp(r'https?://', caseSensitive: false))
          ? t
          : 'https://$t';
      return WhatsappHandle(WhatsappHandleKind.waLink, url);
    }
    final cleaned = cleanForStorage(t);
    if (cleaned.replaceAll('+', '').length >= 7 &&
        !RegExp(r'[^0-9+]').hasMatch(cleaned)) {
      return WhatsappHandle(WhatsappHandleKind.phone, cleaned);
    }
    if (_usernameLike.hasMatch(t)) {
      return WhatsappHandle(
          WhatsappHandleKind.username, t.startsWith('@') ? t.substring(1) : t);
    }
    return WhatsappHandle(WhatsappHandleKind.invalid, t);
  }
}
