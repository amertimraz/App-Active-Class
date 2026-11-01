// test/parent_portal_helper_test.dart — منطق قسم بوابة أولياء الأمور (صرف).
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/parent_portal_helper.dart';

Student _s({String code = 'A1', String? phone, String? wa}) => Student(
    id: 1,
    name: 'منى',
    code: code,
    groupId: 1,
    price: 0,
    guardianPhone: phone,
    guardianWhatsapp: wa);

void main() {
  group('portalUrl', () {
    test('بيركّب الرابط من الـslug', () {
      expect(portalUrl('abc123'), 'https://active-class.online/track/abc123');
    });
  });

  group('portalLast4', () {
    test('آخر 4 أرقام', () => expect(portalLast4('01012345678'), '5678'));
    test('بيتجاهل الرموز والمسافات',
        () => expect(portalLast4('+20 101-234 5678'), '5678'));
    test('أرقام عربية-هندية', () => expect(portalLast4('٠١٠١٢٣٤٥٦٧٨'), '5678'));
    test('أقل من 4 أرقام أو فاضي → null', () {
      expect(portalLast4('123'), isNull);
      expect(portalLast4(''), isNull);
      expect(portalLast4(null), isNull);
    });
  });

  group('portalStudentState', () {
    test('كود + رقم صالح → ready', () {
      expect(portalStudentState(_s(phone: '01012345678'), codeOnly: false),
          PortalStudentState.ready);
    });
    test('بلا رقم والدخول بكود + 4 أرقام → noPhone', () {
      expect(portalStudentState(_s(), codeOnly: false),
          PortalStudentState.noPhone);
      expect(portalStudentState(_s(phone: '12'), codeOnly: false),
          PortalStudentState.noPhone);
    });
    test('بلا رقم والدخول بالكود فقط → ready', () {
      expect(portalStudentState(_s(), codeOnly: true),
          PortalStudentState.ready);
    });
    test('بلا كود → noCode في الوضعين', () {
      expect(portalStudentState(_s(code: '  ', phone: '01012345678'),
              codeOnly: false),
          PortalStudentState.noCode);
      expect(portalStudentState(_s(code: ''), codeOnly: true),
          PortalStudentState.noCode);
    });
  });

  group('portalHasContact', () {
    test('رقم أو واتساب', () {
      expect(portalHasContact(_s(phone: '0100')), isTrue);
      expect(portalHasContact(_s(wa: 'https://wa.me/20100')), isTrue);
      expect(portalHasContact(_s(phone: '  ')), isFalse);
      expect(portalHasContact(_s()), isFalse);
    });
  });

  group('portalCounts', () {
    test('بيعدّ كل حالة', () {
      final list = [
        _s(phone: '01012345678'),
        _s(phone: '01099998888'),
        _s(),
        _s(code: ''),
      ];
      final c = portalCounts(list, codeOnly: false);
      expect(c.ready, 2);
      expect(c.noPhone, 1);
      expect(c.noCode, 1);
      expect(c.total, 4);
      expect(c.hidden, 2);
      final c2 = portalCounts(list, codeOnly: true);
      expect(c2.ready, 3);
      expect(c2.hidden, 1);
    });
    test('قايمة فاضية', () {
      final c = portalCounts(const [], codeOnly: false);
      expect(c.total, 0);
    });
  });

  group('portalStatus', () {
    final now = DateTime(2026, 11, 1, 12);
    test('غير مفعّلة وبلا تاريخ → off', () {
      final s = portalStatus(enabled: false, expiresAt: null, now: now);
      expect(s.kind, PortalStatusKind.off);
      expect(s.isActive, isFalse);
    });
    test('غير مفعّلة وليها تاريخ → expired', () {
      final s = portalStatus(
          enabled: false, expiresAt: DateTime(2026, 10, 1), now: now);
      expect(s.kind, PortalStatusKind.expired);
      expect(s.isActive, isFalse);
    });
    test('مفعّلة بلا تاريخ → lifetime', () {
      final s = portalStatus(enabled: true, expiresAt: null, now: now);
      expect(s.kind, PortalStatusKind.lifetime);
      expect(s.isActive, isTrue);
    });
    test('مفعّلة لكن التاريخ فات → expired', () {
      final s = portalStatus(
          enabled: true, expiresAt: DateTime(2026, 10, 31), now: now);
      expect(s.kind, PortalStatusKind.expired);
    });
    test('قريبة الانتهاء (7 أيام أو أقل)', () {
      final s = portalStatus(
          enabled: true, expiresAt: DateTime(2026, 11, 5, 12), now: now);
      expect(s.kind, PortalStatusKind.expiringSoon);
      expect(s.daysLeft, 4);
      expect(s.isActive, isTrue);
    });
    test('بعيدة → active', () {
      final s = portalStatus(
          enabled: true, expiresAt: DateTime(2027, 3, 1), now: now);
      expect(s.kind, PortalStatusKind.active);
      expect(s.daysLeft, greaterThan(7));
    });
  });

  group('buildPortalInviteMessage', () {
    test('كود + آخر 4 أرقام', () {
      final m = buildPortalInviteMessage(
          studentName: 'منى',
          studentCode: 'a1',
          url: 'https://active-class.online/track/x',
          codeOnly: false);
      expect(m, contains('منى'));
      expect(m, contains('https://active-class.online/track/x'));
      expect(m, contains('A1'));
      expect(m, contains('آخر 4 أرقام'));
    });
    test('بالكود فقط من غير سطر الأرقام', () {
      final m = buildPortalInviteMessage(
          studentName: 'منى',
          studentCode: 'A1',
          url: 'https://active-class.online/track/x',
          codeOnly: true);
      expect(m, isNot(contains('آخر 4 أرقام')));
    });
    test('من غير توقيع المدرس (بيتضاف عند الإرسال)', () {
      final m = buildPortalInviteMessage(
          studentName: 'منى', studentCode: 'A1', url: 'u', codeOnly: false);
      expect(m, isNot(contains('👨‍🏫')));
    });
  });
}
