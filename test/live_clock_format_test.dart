import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/live_clock_format.dart';

void main() {
  test('24 ساعة', () {
    expect(formatLiveClock(DateTime(2026, 11, 19, 14, 5, 9), use24h: true), '14:05:09');
    expect(formatLiveClock(DateTime(2026, 11, 19, 0, 0, 0), use24h: true), '00:00:00');
  });

  test('12 ساعة: م بعد الظهر، من غير صفر في أول الساعة', () {
    expect(formatLiveClock(DateTime(2026, 11, 19, 14, 30, 5), use24h: false), '2:30:05 م');
    expect(formatLiveClock(DateTime(2026, 11, 19, 9, 46, 1), use24h: false), '9:46:01 ص');
  });

  test('12 ظهرًا و12 منتصف الليل', () {
    expect(formatLiveClock(DateTime(2026, 11, 19, 12, 0, 0), use24h: false), '12:00:00 م');
    expect(formatLiveClock(DateTime(2026, 11, 19, 0, 7, 0), use24h: false), '12:07:00 ص');
  });
}
