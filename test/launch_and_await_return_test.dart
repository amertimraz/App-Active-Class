// launchAndAwaitReturn: ما يعلّقش لو الفتح فشل أو التطبيق ما خرجش، ويستنى الرجوع لو خرج.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/launch_and_await_return.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('الفتح فشل → false فورًا من غير انتظار', () async {
    final r = await launchAndAwaitReturn(() async => false)
        .timeout(const Duration(seconds: 1));
    expect(r, isFalse);
  });

  test('الفتح نجح لكن التطبيق ما خرجش → يكمّل بعد المهلة (مش للأبد)', () async {
    final r = await launchAndAwaitReturn(() async => true,
            leaveGrace: const Duration(milliseconds: 50))
        .timeout(const Duration(seconds: 2));
    expect(r, isTrue);
  });

  test('خرج للخلفية ورجع → يكمّل بعد الرجوع', () async {
    var done = false;
    final f = launchAndAwaitReturn(() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      return true;
    }).then((v) {
      done = true;
      return v;
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(done, isFalse, reason: 'لسه في الخلفية: لازم يستنى');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(await f.timeout(const Duration(seconds: 1)), isTrue);
  });

  test('الرجوع سبق انتهاء الفتح (سباق) → ما يعلّقش', () async {
    final r = await launchAndAwaitReturn(() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      return true;
    }).timeout(const Duration(seconds: 1));
    expect(r, isTrue);
  });

  test('maxWait: لو المستخدم ما رجعش في المهلة يكمّل', () async {
    final r = await launchAndAwaitReturn(() async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      return true;
    }, maxWait: const Duration(milliseconds: 100))
        .timeout(const Duration(seconds: 2));
    expect(r, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
