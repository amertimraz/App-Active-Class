import 'package:active_class/utils/phone_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toLatinDigits', () {
    test('عربي-هندي', () {
      expect(PhoneHelper.toLatinDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });
    test('فارسي', () {
      expect(PhoneHelper.toLatinDigits('۰۱۲۳'), '0123');
    });
    test('مختلط', () {
      expect(PhoneHelper.toLatinDigits('010٠٠123'), '01000123');
    });
    test('بلا أرقام', () {
      expect(PhoneHelper.toLatinDigits('abc'), 'abc');
    });
  });

  group('cleanForStorage', () {
    test('مسافات', () {
      expect(PhoneHelper.cleanForStorage('+20 100 123 4567'), '+201001234567');
    });
    test('أرقام عربية', () {
      expect(PhoneHelper.cleanForStorage('٠١٠٠١٢٣٤٥٦٧'), '01001234567');
    });
    test('علامات اتجاه مخفية', () {
      // U+202A ... U+202C (LRE/PDF) + U+200E/U+200F (LRM/RLM)
      expect(
          PhoneHelper.cleanForStorage('\u202A01001234567\u202C'),
          '01001234567');
      expect(
          PhoneHelper.cleanForStorage('\u200E01001234567\u200F'),
          '01001234567');
    });
    test('بادئة 00', () {
      expect(PhoneHelper.cleanForStorage('00201001234567'), '+201001234567');
    });
    test('محلي مجرّد', () {
      expect(PhoneHelper.cleanForStorage('1001234567'), '1001234567');
    });
    test('+2 ناقص لمصر (نفس أرقام +20)', () {
      // "+2 01001234567" و "+20 100 123 4567" نفس الأرقام بعد التنظيف
      expect(PhoneHelper.cleanForStorage('+2 01001234567'), '+201001234567');
      expect(PhoneHelper.waMe('+2 01001234567', '20'), '201001234567');
    });
    test('دولي صريح غير مصري', () {
      expect(PhoneHelper.cleanForStorage('+966 50 123 4567'), '+966501234567');
    });
    test('أقواس وشرطات', () {
      expect(PhoneHelper.cleanForStorage('(010) 012-34567'), '01001234567');
    });
    test('فارغ', () {
      expect(PhoneHelper.cleanForStorage(''), '');
      expect(PhoneHelper.cleanForStorage('   '), '');
    });
  });

  group('waMe', () {
    test('من محلي', () {
      expect(PhoneHelper.waMe('01001234567', '20'), '201001234567');
    });
    test('من +20', () {
      expect(PhoneHelper.waMe('+201001234567', '20'), '201001234567');
    });
    test('من أرقام عربية', () {
      expect(PhoneHelper.waMe('٠١٠٠١٢٣٤٥٦٧', '20'), '201001234567');
    });
    test('من 00', () {
      expect(PhoneHelper.waMe('00201001234567', '20'), '201001234567');
    });
    test('محلي مجرّد', () {
      expect(PhoneHelper.waMe('1001234567', '20'), '201001234567');
    });
    test('دولي غير مصري يُحترم', () {
      expect(PhoneHelper.waMe('+966501234567', '20'), '966501234567');
    });
    test('رمز دولة بلا + (سعودي طويل) يُحترم', () {
      expect(PhoneHelper.waMe('966501234567', '20'), '966501234567');
    });
    test('محلي مصري 11 خانة بصفر → يتبقّى له 20', () {
      expect(PhoneHelper.waMe('01001234567', '20'), '201001234567');
    });
    test('ثبات — تطبيق مزدوج', () {
      final once = PhoneHelper.waMe('+20 100 123 4567', '20');
      expect(PhoneHelper.waMe(once, '20'), once);
    });
    test('فارغ', () {
      expect(PhoneHelper.waMe('', '20'), '');
    });
  });

  group('displayIntl', () {
    test('مصري 10 خانات', () {
      final d = PhoneHelper.displayIntl('01001234567', '20');
      expect(d.contains('+20'), true);
      expect(d.contains('100 123 4567'), true);
      expect(d.codeUnitAt(0), 0x200E); // LRM في البداية
    });
    test('فارغ', () {
      expect(PhoneHelper.displayIntl('', '20'), '');
    });
    test('دولي غير مصري — مايفترضش +20', () {
      final d = PhoneHelper.displayIntl('+966501234567', '20');
      expect(d.contains('+966'), true);
      expect(d.contains('+20'), false);
    });
  });

  group('isLikelyValid', () {
    test('رقم مصري كامل', () {
      expect(PhoneHelper.isLikelyValid('01001234567', '20'), true);
    });
    test('ناقص', () {
      expect(PhoneHelper.isLikelyValid('123', '20'), false);
    });
    test('فارغ', () {
      expect(PhoneHelper.isLikelyValid('', '20'), false);
    });
  });

  group('parseWhatsappHandle', () {
    test('رابط wa.me', () {
      final h = PhoneHelper.parseWhatsappHandle('wa.me/201001234567');
      expect(h.kind, WhatsappHandleKind.waLink);
      expect(h.value, 'https://wa.me/201001234567');
    });
    test('رابط message كامل', () {
      final h =
          PhoneHelper.parseWhatsappHandle('https://wa.me/message/ABC123');
      expect(h.kind, WhatsappHandleKind.waLink);
    });
    test('رقم', () {
      expect(PhoneHelper.parseWhatsappHandle('01001234567').kind,
          WhatsappHandleKind.phone);
    });
    test('username بـ@', () {
      final h = PhoneHelper.parseWhatsappHandle('@ahmed_dad');
      expect(h.kind, WhatsappHandleKind.username);
      expect(h.value, 'ahmed_dad');
    });
    test('username بلا @', () {
      expect(PhoneHelper.parseWhatsappHandle('ahmed').kind,
          WhatsappHandleKind.username);
    });
    test('غير صالح', () {
      expect(PhoneHelper.parseWhatsappHandle('blabla !!').kind,
          WhatsappHandleKind.invalid);
    });
    test('فارغ', () {
      expect(PhoneHelper.parseWhatsappHandle('').kind,
          WhatsappHandleKind.empty);
    });
  });
}
