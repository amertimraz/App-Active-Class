import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/services/rate_prompt_service.dart';
import 'package:active_class/utils/rate_prompt.dart';

final now = DateTime(2026, 10, 31, 12);

RatePromptState st({
  int days = 10,
  int launches = 8,
  int lastDays = -1,
  int later = 0,
  bool done = false,
}) =>
    RatePromptState(
      firstSeen: now.subtract(Duration(days: days)),
      launches: launches,
      lastShown: lastDays < 0 ? null : now.subtract(Duration(days: lastDays)),
      laterCount: later,
      done: done,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldShowRatePrompt', () {
    test('مستخدم فعلي → يظهر', () {
      expect(shouldShowRatePrompt(st(), now), isTrue);
    });
    test('جديد أو قليل الفتح أو بلا تاريخ → لا', () {
      expect(shouldShowRatePrompt(st(days: 1), now), isFalse);
      expect(shouldShowRatePrompt(st(launches: 2), now), isFalse);
      expect(shouldShowRatePrompt(const RatePromptState(), now), isFalse);
    });
    test('قيّم → لا يظهر أبدًا', () {
      expect(shouldShowRatePrompt(st(done: true), now), isFalse);
    });
    test('فاصل 14 يوم بعد آخر عرض', () {
      expect(shouldShowRatePrompt(st(lastDays: 5), now), isFalse);
      expect(shouldShowRatePrompt(st(lastDays: 14), now), isTrue);
    });
    test('بعد 3 "لاحقًا" يقف', () {
      expect(shouldShowRatePrompt(st(later: 2), now), isTrue);
      expect(shouldShowRatePrompt(st(later: 3), now), isFalse);
    });
  });

  group('RatePromptService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('registerLaunch يسجّل أول استخدام ويعدّ', () async {
      final s = RatePromptService.instance;
      await s.registerLaunch(now: now);
      final a = await s.load();
      expect(a.firstSeen, isNotNull);
      expect(a.launches, greaterThanOrEqualTo(0));
    });

    test('markLater يزوّد العدّاد و markShown يسجّل الوقت', () async {
      final s = RatePromptService.instance;
      await s.markLater();
      await s.markShown(now: now);
      final a = await s.load();
      expect(a.laterCount, 1);
      expect(a.lastShown, now);
    });
  });

  test('روابط Google Play', () {
    expect(playMarketUri().toString(),
        'market://details?id=com.amertimraz.activeclass');
    expect(playWebUri().host, 'play.google.com');
  });
}
