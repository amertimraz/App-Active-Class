// test/announcement_banner_test.dart — spec 054
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/widgets/announcement_banner.dart';

Widget host(Widget child, {bool dark = false, double width = 320, double textScale = 1.0}) =>
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(child: SizedBox(width: width - 32, child: child)),
            ),
          ),
        ),
      ),
    );

AnnouncementBanner banner(String design, String color,
        {DateTime Function()? clock, VoidCallback? onExpired, VoidCallback? onCta, VoidCallback? onClose, DateTime? ends}) =>
    AnnouncementBanner(
      title: 'خصم 30% على كل الباقات',
      body: 'اشترك أو جدّد قبل انتهاء العرض ووفّر.',
      badge: '-30%',
      kind: 'deal',
      design: design,
      color: color,
      couponCode: 'BF30',
      showCountdown: true,
      endsAt: ends ?? DateTime(2026, 11, 1),
      ctaLabel: 'تواصل واتساب واحجز الخصم',
      onCta: onCta ?? () {},
      onClose: onClose ?? () {},
      onExpired: onExpired,
      clock: clock ?? () => DateTime(2026, 10, 29, 12),
    );

void main() {
  for (final dark in [false, true]) {
    for (final design in kAnnouncementDesigns) {
      for (final color in kAnnouncementColors) {
        testWidgets('$design/$color/${dark ? "dark" : "light"} بلا overflow على 320 وخط 1.5', (t) async {
          await t.pumpWidget(host(banner(design, color), dark: dark, textScale: 1.5));
          await t.pump();
          expect(tester(t), isNull); // لا استثناءات (overflow بيطلع كاستثناء)
          expect(find.byType(AnnouncementBanner), findsOneWidget);
        });
      }
    }
  }

  testWidgets('العداد ينقص ويستدعي onExpired مرة واحدة عند الصفر', (t) async {
    var now = DateTime(2026, 10, 29, 12);
    var fired = 0;
    await t.pumpWidget(host(banner('classic', 'blue',
        clock: () => now, ends: DateTime(2026, 10, 29, 12, 0, 3), onExpired: () => fired++)));
    await t.pump();
    expect(find.text('03'), findsOneWidget);
    now = now.add(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('01'), findsOneWidget);
    now = now.add(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(fired, 1);
  });

  testWidgets('تصميم/لون مجهول يرسم بدون خطأ', (t) async {
    await t.pumpWidget(host(banner('zzz', 'nope')));
    await t.pump();
    expect(find.byType(AnnouncementBanner), findsOneWidget);
  });

  testWidgets('CTA والإغلاق يستدعيان callbacks', (t) async {
    var cta = 0, close = 0;
    await t.pumpWidget(host(banner('classic', 'teal', onCta: () => cta++, onClose: () => close++)));
    await t.pump();
    await t.tap(find.text('تواصل واتساب واحجز الخصم'));
    await t.tap(find.byIcon(Icons.close_rounded));
    expect(cta, 1);
    expect(close, 1);
  });

  testWidgets('بدون CTA لا يظهر زرار', (t) async {
    await t.pumpWidget(host(const AnnouncementBanner(title: 't', body: 'b')));
    await t.pump();
    expect(find.byType(FilledButton), findsNothing);
  });
}

Object? tester(WidgetTester t) => t.takeException();
