import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/models/free_month_promo.dart';
import 'package:active_class/services/promo_background.dart';

void main() {
  group('FreeMonthPromo.fromMap', () {
    test('null أو غير مفعّلة', () {
      expect(FreeMonthPromo.fromMap(null), isNull);
      expect(FreeMonthPromo.fromMap({'enabled': false})!.enabled, isFalse);
      expect(FreeMonthPromo.fromMap({})!.enabled, isFalse);
    });

    test('قيم افتراضية: 30 يوم وباقة pro وجمهور جدد وإشعار', () {
      final p = FreeMonthPromo.fromMap({'enabled': true})!;
      expect([p.enabled, p.days, p.plan], [true, 30, 'pro']);
      expect(p.audiences, [kPromoAudienceNew]);
      expect(p.notify, isTrue);
      expect(p.title, 'فعّل شهر مجانًا الآن');
      expect(p.campaignKey, isNull);
    });

    test('بيحترم القيم المخصّصة ويقصّ المدة ويفلتر الجمهور', () {
      final p = FreeMonthPromo.fromMap({
        'enabled': true,
        'days': 14,
        'plan': 'basic',
        'title': 'عرض خاص',
        'subtitle': '  أسبوعين  ',
        'audiences': ['expired', 'غلط'],
        'notify': false,
      }, updatedAtMs: 1700000000000)!;
      expect([p.days, p.plan, p.title, p.subtitle],
          [14, 'basic', 'عرض خاص', 'أسبوعين']);
      expect(p.audiences, [kPromoAudienceExpired]);
      expect(p.notify, isFalse);
      expect(p.campaignKey, 'promo:1700000000000');
      expect(FreeMonthPromo.fromMap({'enabled': true, 'days': 0})!.days, 30);
      expect(
          FreeMonthPromo.fromMap({'enabled': true, 'days': 9999})!.days, 365);
      // جمهور فاضي/كله غلط → افتراضي جدد
      expect(FreeMonthPromo.fromMap({'audiences': []})!.audiences,
          [kPromoAudienceNew]);
    });
  });

  test('تحليل رد Firestore REST', () {
    final p = FreeMonthPromo.fromRestDocument({
      'fields': {
        'enabled': {'booleanValue': true},
        'days': {'integerValue': '45'},
        'plan': {'stringValue': 'pro'},
        'title': {'stringValue': 'عرض'},
        'audiences': {
          'arrayValue': {
            'values': [
              {'stringValue': 'new'},
              {'stringValue': 'expired'}
            ]
          }
        },
        'notify': {'booleanValue': false},
        'updatedAt': {'timestampValue': '2026-11-05T12:00:00.500Z'},
      }
    })!;
    expect([p.enabled, p.days, p.plan, p.title], [true, 45, 'pro', 'عرض']);
    expect(p.audiences, [kPromoAudienceNew, kPromoAudienceExpired]);
    expect(p.notify, isFalse);
    expect(p.updatedAtMs,
        DateTime.utc(2026, 11, 5, 12, 0, 0, 500).millisecondsSinceEpoch);
    expect(FreeMonthPromo.fromRestDocument({'name': 'x'}), isNull);
  });

  test('جمهور حالة الترخيص', () {
    expect(promoAudienceForState('trial'), kPromoAudienceNew);
    expect(promoAudienceForState('trialExpired'), kPromoAudienceNew);
    expect(promoAudienceForState('expired'), kPromoAudienceExpired);
    for (final s in ['active', 'suspended', 'loading']) {
      expect(promoAudienceForState(s), isNull, reason: s);
    }
  });

  group('shouldShowFreeMonthPromo', () {
    const on = FreeMonthPromo(enabled: true);
    bool show({
      FreeMonthPromo? promo = on,
      String? audience = kPromoAudienceNew,
      bool pending = false,
      bool used = false,
      bool assistant = false,
    }) =>
        shouldShowFreeMonthPromo(
            promo: promo,
            audience: audience,
            hasPendingRequest: pending,
            alreadyUsed: used,
            isTeamAssistant: assistant);

    test('بيظهر للجدد في الحالة العادية', () => expect(show(), isTrue));
    test('مفيش حملة أو مطفية', () {
      expect(show(promo: null), isFalse);
      expect(show(promo: const FreeMonthPromo(enabled: false)), isFalse);
    });
    test('المنتهي اشتراكه: بس لو الجمهور يشمله', () {
      expect(show(audience: kPromoAudienceExpired), isFalse);
      expect(
          show(
              promo: const FreeMonthPromo(
                  enabled: true,
                  audiences: [kPromoAudienceNew, kPromoAudienceExpired]),
              audience: kPromoAudienceExpired),
          isTrue);
    });
    test('مفعّل، أو طلب معلّق، أو استخدمها، أو مساعد = لا', () {
      expect(show(audience: null), isFalse);
      expect(show(pending: true), isFalse);
      expect(show(used: true), isFalse);
      expect(show(assistant: true), isFalse);
    });
  });

  group('shouldNotifyFreeMonthPromo', () {
    const p = FreeMonthPromo(enabled: true, updatedAtMs: 100);
    bool notify({
      FreeMonthPromo? promo = p,
      String? audience = kPromoAudienceNew,
      bool blocked = false,
      String? last,
    }) =>
        shouldNotifyFreeMonthPromo(
            promo: promo,
            audience: audience,
            blocked: blocked,
            lastNotifiedKey: last);

    test('إشعار أول مرة للجمهور المستهدف', () => expect(notify(), isTrue));
    test('مرة واحدة لكل إصدار، وإصدار جديد = إشعار جديد', () {
      expect(notify(last: 'promo:100'), isFalse);
      expect(
          notify(
              promo: const FreeMonthPromo(enabled: true, updatedAtMs: 200),
              last: 'promo:100'),
          isTrue);
    });
    test('لا إشعار: notify مطفي، أو بلا تاريخ حفظ، أو محجوب، أو خارج الجمهور',
        () {
      expect(
          notify(
              promo: const FreeMonthPromo(
                  enabled: true, notify: false, updatedAtMs: 1)),
          isFalse);
      expect(notify(promo: const FreeMonthPromo(enabled: true)), isFalse);
      expect(notify(blocked: true), isFalse);
      expect(notify(audience: kPromoAudienceExpired), isFalse);
      expect(notify(audience: null), isFalse);
      expect(
          notify(promo: const FreeMonthPromo(enabled: false, updatedAtMs: 1)),
          isFalse);
    });
  });

  group('runPromoBackgroundCheck', () {
    const p = FreeMonthPromo(enabled: true, updatedAtMs: 500);

    test('بيبعت إشعار مرة واحدة ويحجز المفتاح', () async {
      SharedPreferences.setMockInitialValues({kPromoAudiencePrefsKey: 'new'});
      var shown = 0;
      Future<void> show(FreeMonthPromo _) async => shown++;
      await runPromoBackgroundCheck(fetch: () async => p, show: show);
      await runPromoBackgroundCheck(fetch: () async => p, show: show);
      expect(shown, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPromoNotifiedPrefsKey), 'promo:500');
    });

    test('مفيش جمهور معروف = ما بيقراش الشبكة أصلًا', () async {
      SharedPreferences.setMockInitialValues({});
      var fetched = false;
      await runPromoBackgroundCheck(
          fetch: () async {
            fetched = true;
            return p;
          },
          show: (_) async => fail('ما ينفعش يظهر'));
      expect(fetched, isFalse);
    });

    test('محجوب (طلب/استخدم) = بدون إشعار', () async {
      SharedPreferences.setMockInitialValues(
          {kPromoAudiencePrefsKey: 'new', kPromoBlockedPrefsKey: true});
      await runPromoBackgroundCheck(
          fetch: () async => p, show: (_) async => fail('محجوب'));
    });

    test('فشل الشبكة بيعدّي بهدوء', () async {
      SharedPreferences.setMockInitialValues({kPromoAudiencePrefsKey: 'new'});
      expect(
          await runPromoBackgroundCheck(
              fetch: () async => throw Exception('net')),
          isTrue);
    });
  });
}
