// spec 055 — شاشتا الترحيب والدخول على الويب: ترسم بلا استثناء ولا overflow
// على عرض سطح مكتب وتابلت وموبايل، والنصوص الأساسية موجودة.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/views/web/web_auth_widgets.dart';
import 'package:active_class/views/web/web_login_page.dart';
import 'package:active_class/views/web/web_welcome_page.dart';

Future<void> _pump(WidgetTester t, Widget page, Size size,
    {double textScale = 1.0, bool reduceMotion = false}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Cairo'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: child!,
    ),
    home: page,
  ));
  await t.pump(const Duration(milliseconds: 100));
}

const _sizes = {
  'desktop 1366': Size(1366, 768),
  'desktop 1920': Size(1920, 1080),
  'tablet 800': Size(800, 1000),
  'phone 360': Size(360, 740),
  'phone 320': Size(320, 640),
};

void main() {
  // خط Cairo الحقيقي — من غيره الاختبار بيرسم النص بعرض وهمي ويبالغ في الأبعاد.
  setUpAll(() async {
    final loader = FontLoader('Cairo');
    for (final f in ['Cairo-Regular.ttf', 'Cairo-Bold.ttf']) {
      loader.addFont(File('assets/fonts/$f')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  });

  group('WebWelcomePage', () {
    for (final e in _sizes.entries) {
      testWidgets('تُرسم بلا overflow — ${e.key}', (t) async {
        await _pump(t, const WebWelcomePage(), e.value);
        await t.pump(const Duration(seconds: 4)); // يخلّص كشف الحضور
        expect(t.takeException(), isNull);
        expect(find.text('تسجيل الدخول'), findsOneWidget);
        expect(find.textContaining('كشف حضورك'), findsOneWidget);
      });
    }

    testWidgets('خط كبير (1.5) على موبايل ضيق بلا overflow', (t) async {
      await _pump(t, const WebWelcomePage(), const Size(320, 640),
          textScale: 1.5);
      await t.pump(const Duration(seconds: 4));
      expect(t.takeException(), isNull);
    });

    testWidgets('زر تسجيل الدخول يفتح شاشة الدخول', (t) async {
      await _pump(t, const WebWelcomePage(), const Size(1366, 768));
      await t.pump(const Duration(seconds: 4));
      await t.tap(find.text('تسجيل الدخول'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(WebLoginPage), findsOneWidget);
    });
  });

  group('WebLoginPage', () {
    for (final e in _sizes.entries) {
      testWidgets('تُرسم بلا overflow — ${e.key}', (t) async {
        await _pump(t, const WebLoginPage(), e.value);
        expect(t.takeException(), isNull);
        expect(find.text('سجّل دخولك'), findsOneWidget);
        expect(find.text('رقم التليفون'), findsOneWidget);
        expect(find.text('الباسورد'), findsOneWidget);
        expect(find.text('دخول'), findsOneWidget);
      });
    }

    testWidgets('مفيش أي مسار تسجيل أو تجربة على شاشة الدخول', (t) async {
      await _pump(t, const WebLoginPage(), const Size(1366, 768));
      expect(find.textContaining('تجربة'), findsNothing);
      expect(find.text('إنشاء حساب جديد'), findsNothing);
    });

    testWidgets('خط كبير (1.5) على موبايل ضيق بلا overflow', (t) async {
      await _pump(t, const WebLoginPage(), const Size(320, 640),
          textScale: 1.5);
      expect(t.takeException(), isNull);
    });

    testWidgets('زر إظهار الباسورد يبدّل الإخفاء', (t) async {
      await _pump(t, const WebLoginPage(), const Size(1366, 768));
      TextField pass() => t.widget<TextField>(find.byType(TextField).last);
      expect(pass().obscureText, isTrue);
      await t.tap(find.byTooltip('إظهار الباسورد'));
      await t.pump();
      expect(pass().obscureText, isFalse);
    });
  });

  group('AttendanceRegisterArt', () {
    testWidgets('تقليل الحركة: يظهر مكتمل فورًا بلا انتظار', (t) async {
      await _pump(
          t,
          const Scaffold(body: Center(child: AttendanceRegisterArt())),
          const Size(800, 600),
          reduceMotion: true);
      expect(t.takeException(), isNull);
      expect(find.text('كشف الحضور'), findsOneWidget);
    });
  });
}
