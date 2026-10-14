// test/single_flight_test.dart — تجميع إعادة حساب الداشبورد
import 'dart:async';

import 'package:active_class/utils/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('استدعاء واحد → تنفيذ واحد', () async {
    var n = 0;
    final sf = SingleFlight(() async {
      n++;
    });
    await sf.run();
    expect(n, 1);
    expect(sf.isRunning, false);
  });

  test('عاصفة استدعاءات أثناء التنفيذ → تنفيذ + إعادة واحدة بس', () async {
    var n = 0;
    final gate = Completer<void>();
    final sf = SingleFlight(() async {
      n++;
      if (n == 1) await gate.future; // الأولى بطيئة
    });
    final first = sf.run();
    // 20 حدث وصلوا والأولى لسه شغّالة
    final burst = [for (var i = 0; i < 20; i++) sf.run()];
    expect(n, 1); // ولا نسخة موازية
    gate.complete();
    await Future.wait([first, ...burst]);
    expect(n, 2); // الأولى + إعادة واحدة تغطّي الـ20
    expect(sf.isRunning, false);
  });

  test('بعد الانتهاء، استدعاء جديد بيشغّل المهمة تاني', () async {
    var n = 0;
    final sf = SingleFlight(() async {
      n++;
    });
    await sf.run();
    await sf.run();
    expect(n, 2);
  });

  test('الخطأ ما بيعلّقش الحالة', () async {
    var n = 0;
    final sf = SingleFlight(() async {
      n++;
      if (n == 1) throw StateError('boom');
    });
    await expectLater(sf.run(), throwsStateError);
    expect(sf.isRunning, false);
    await sf.run(); // بيشتغل عادي
    expect(n, 2);
  });
}
