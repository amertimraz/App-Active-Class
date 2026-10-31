// test/onboarding_splash_test.dart — واجهة السبلاش والشرح التعريفي
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/views/onboarding/onboarding_page.dart';
import 'package:active_class/views/splash/splash_brand.dart';

Widget host(Widget child, {bool dark = false, double w = 360, double h = 740, double scale = 1}) =>
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OnboardingPage', () {
    for (final dark in [false, true]) {
      for (final size in [const Size(320, 568), const Size(360, 740), const Size(411, 900)]) {
        for (final scale in [1.0, 1.6]) {
          testWidgets('بلا overflow ${size.width}x${size.height} ×$scale ${dark ? "dark" : "light"}', (t) async {
            await t.pumpWidget(host(const OnboardingPage(),
                dark: dark, w: size.width, h: size.height, scale: scale));
            await t.pump();
            for (var i = 0; i < 4; i++) {
              expect(t.takeException(), isNull, reason: 'slide $i');
              if (i < 3) {
                await t.tap(find.text('التالي'));
                await t.pumpAndSettle();
              }
            }
            expect(find.text('ابدأ الآن'), findsOneWidget);
          });
        }
      }
    }

    testWidgets('التالي/رجوع، وتخطّي يختفي في الأخيرة', (t) async {
      await t.pumpWidget(host(const OnboardingPage()));
      await t.pumpAndSettle();
      expect(find.text('نظّم فصولك في مجموعات'), findsOneWidget);
      expect(find.text('تخطّي'), findsOneWidget);
      expect(find.byTooltip('الشريحة السابقة'), findsNothing);
      await t.tap(find.text('التالي'));
      await t.pumpAndSettle();
      expect(find.text('ملف كامل لكل طالب'), findsOneWidget);
      // زرار الرجوع ظهر ويرجّع للشريحة الأولى
      await t.tap(find.bySemanticsLabel('الشريحة السابقة'));
      await t.pumpAndSettle();
      expect(find.text('نظّم فصولك في مجموعات'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('التالي'));
        await t.pumpAndSettle();
      }
      expect(find.text('تخطّي'), findsNothing);
      expect(find.text('ابدأ الآن'), findsOneWidget);
    });
  });

  group('SplashBrand', () {
    testWidgets('يعرض الاسم والشعار النصي وبلا رسالة افتراضيًا', (t) async {
      await t.pumpWidget(host(const SplashBrand(title: 'Active Class', tagline: 'إدارة الفصول')));
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('Active Class'), findsOneWidget);
      expect(find.text('إدارة الفصول'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('رسالة الحالة تظهر عند تمريرها', (t) async {
      await t.pumpWidget(host(const SplashBrand(
          title: 'Active Class', tagline: 'x', status: 'جاري التحقق من الترخيص...')));
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('جاري التحقق من الترخيص...'), findsOneWidget);
    });

    testWidgets('تقليل الحركة: الحالة النهائية فورًا', (t) async {
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const SplashBrand(title: 'Active Class', tagline: 'x'),
        ),
      ));
      final op = t.widget<FadeTransition>(find.byType(FadeTransition).first);
      expect(op.opacity.value, 1.0);
    });

    for (final size in [const Size(320, 480), const Size(360, 740)]) {
      testWidgets('بلا overflow ${size.width}x${size.height} وخط كبير', (t) async {
        await t.pumpWidget(host(
            const SplashBrand(
                title: 'Active Class',
                tagline: 'إدارة الفصول والحضور والمدفوعات',
                status: 'جاري التحقق من الترخيص...'),
            w: size.width,
            h: size.height,
            scale: 1.6));
        await t.pump(const Duration(milliseconds: 800));
        expect(t.takeException(), isNull);
      });
    }
  });
}
