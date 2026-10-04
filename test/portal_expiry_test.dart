// test/portal_expiry_test.dart — تنبيه انتهاء اشتراك بوابة أولياء الأمور
import 'package:active_class/utils/portal_expiry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 3, 12, 0);

  PortalExpiryInfo info(DateTime? exp, {bool enabled = true}) =>
      portalExpiryInfo(enabled: enabled, expiresAt: exp, now: now);

  group('portalExpiryInfo', () {
    test('غير مفعّلة أو مدى الحياة → none', () {
      expect(info(null).stage, PortalExpiryStage.none);
      expect(info(now.add(const Duration(days: 2)), enabled: false).stage,
          PortalExpiryStage.none);
    });

    test('بعيد (أكتر من 7 أيام) → none', () {
      expect(info(now.add(const Duration(days: 8))).stage,
          PortalExpiryStage.none);
    });

    test('7 أيام → warning، و3 أيام فأقل → urgent', () {
      final w = info(now.add(const Duration(days: 7, hours: 1)));
      expect(w.stage, PortalExpiryStage.warning);
      expect(w.daysLeft, 7);
      expect(info(now.add(const Duration(days: 3, hours: 2))).stage,
          PortalExpiryStage.urgent);
      expect(info(now.add(const Duration(days: 1, hours: 2))).stage,
          PortalExpiryStage.urgent);
    });

    test('أقل من 24 ساعة → urgent بـdaysLeft = 0 (ينتهي اليوم)', () {
      final i = info(now.add(const Duration(hours: 5)));
      expect(i.stage, PortalExpiryStage.urgent);
      expect(i.daysLeft, 0);
      expect(portalExpiryBannerText(i), contains('ينتهي اليوم'));
    });

    test('انتهى حديثًا → expired، وبعد 30 يوم → none', () {
      final i = info(now.subtract(const Duration(days: 5)));
      expect(i.stage, PortalExpiryStage.expired);
      expect(i.daysSinceExpiry, 5);
      expect(info(now.subtract(const Duration(days: 31))).stage,
          PortalExpiryStage.none);
    });

    test('نص البانر يذكر الامتحانات الإلكترونية', () {
      final i = info(now.add(const Duration(days: 5)));
      expect(portalExpiryBannerText(i), contains('الامتحانات الإلكترونية'));
      expect(portalExpiryBannerText(i), contains('5 أيام'));
    });
  });

  group('portalReminders', () {
    test('اشتراك بعد 10 أيام → 7 و3 و1 يوم + لحظة الانتهاء', () {
      final exp = DateTime(2026, 10, 13, 23, 59);
      final r = portalReminders(exp, now);
      expect(r.length, 4);
      expect(r[0].at, DateTime(2026, 10, 6, 9));
      expect(r[1].at, DateTime(2026, 10, 10, 9));
      expect(r[2].at, DateTime(2026, 10, 12, 9));
      expect(r[3].at, exp);
    });

    test('اشتراك بعد يومين → 1 يوم + الانتهاء بس (7 و3 فاتوا)', () {
      final exp = DateTime(2026, 10, 5, 23, 59);
      final r = portalReminders(exp, now);
      expect(r.map((e) => e.at).toList(),
          [DateTime(2026, 10, 4, 9), exp]);
    });

    test('منتهي بالفعل → لا إشعارات', () {
      expect(portalReminders(now.subtract(const Duration(days: 1)), now),
          isEmpty);
    });

    test('التذكير الأخير يقول "بكرة"', () {
      final exp = DateTime(2026, 10, 5, 23, 59);
      final r = portalReminders(exp, now);
      expect(r.first.body, contains('بكرة'));
    });
  });
}
