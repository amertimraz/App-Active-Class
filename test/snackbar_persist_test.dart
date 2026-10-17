// test/snackbar_persist_test.dart
//
// Flutter ≥ 3.29: SnackBar فيه action مابيختفيش لوحده (persist افتراضيًا
// true) — الـhint "تراجع" بتاع الملازم كان بيفضل ظاهر. كل SnackBar فيه
// زرار في التطبيق لازم يحدّد persist: false.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester t, {required bool? persist}) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: const Text('دفع 10.00 جنيه'),
              duration: const Duration(seconds: 2),
              persist: persist,
              action: SnackBarAction(label: 'تراجع', onPressed: () {}),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('دفع 10.00 جنيه'), findsOneWidget);
  }

  testWidgets('بدون persist: الـSnackBar اللي فيه action بيفضل ظاهر (الباج)',
      (t) async {
    await show(t, persist: null);
    await t.pump(const Duration(seconds: 10));
    expect(find.text('دفع 10.00 جنيه'), findsOneWidget);
  });

  testWidgets('persist: false: بيختفي بعد مدته (الإصلاح)', (t) async {
    await show(t, persist: false);
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('دفع 10.00 جنيه'), findsNothing);
  });
}
