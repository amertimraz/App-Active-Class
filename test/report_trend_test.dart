import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/report_trend.dart';

void main() {
  test('pointsDelta: فرق بالنقط، وnull لو طرف مجهول', () {
    expect(pointsDelta(0.80, 0.75), closeTo(5, 1e-9));
    expect(pointsDelta(0.5, 0.6), closeTo(-10, 1e-9));
    expect(pointsDelta(null, 0.6), isNull);
    expect(pointsDelta(0.6, null), isNull);
  });

  test('lastMonths: ٦ شهور الأقدم أولًا وبتعدّي حدود السنة', () {
    final m = lastMonths(DateTime(2026, 2, 1));
    expect(m.length, 6);
    expect(m.first, DateTime(2025, 9, 1));
    expect(m.last, DateTime(2026, 2, 1));
  });

  test('isEmpty', () {
    expect(TrendPoint(month: DateTime(2026, 1)).isEmpty, isTrue);
    expect(TrendPoint(month: DateTime(2026, 1), exams: 0).isEmpty, isFalse);
  });
}
