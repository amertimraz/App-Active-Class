// spec 055 (T055) — دوال التجاوب + إطار الشاشات العريضة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/utils/responsive.dart';
import 'package:active_class/widgets/web_responsive_frame.dart';

void main() {
  group('adaptiveColumns', () {
    test('الموبايل يرجع نفس العدد الأصلي', () {
      expect(adaptiveColumns(320, phone: 3), 3);
      expect(adaptiveColumns(411, phone: 2), 2);
      expect(adaptiveColumns(599, phone: 3, minTileWidth: 100), 3);
    });
    test('العريض يزيد الأعمدة بالحد الأقصى', () {
      expect(adaptiveColumns(1068, phone: 3, minTileWidth: 170, max: 6), 6);
      expect(adaptiveColumns(700, phone: 3, minTileWidth: 170), 4);
      expect(adaptiveColumns(1068, phone: 2, minTileWidth: 230, max: 5), 4);
    });
    test('مش بينزل عن عدد الموبايل', () {
      expect(adaptiveColumns(620, phone: 4, minTileWidth: 400), 4);
    });
  });

  group('desktop helpers', () {
    test('تكبير الخط وعرض الإطار', () {
      expect(desktopTextScale(800), 1.0);
      expect(desktopTextScale(1366), 1.12);
      expect(framedWidth(800), 800);
      expect(framedWidth(950), 950);
      expect(framedWidth(1920), kDesktopContentMaxWidth);
    });
  });

  group('WebResponsiveFrame', () {
    Future<double> widthOf(WidgetTester t, Size size,
        {bool enabled = true}) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: WebResponsiveFrame(
          enabled: enabled,
          child: const Scaffold(body: SizedBox.expand(key: Key('c'))),
        ),
      ));
      return t.getSize(find.byKey(const Key('c'))).width;
    }

    testWidgets('شاشة عريضة: المحتوى متوسّط بعرض أقصى', (t) async {
      expect(await widthOf(t, const Size(1920, 1080)), kDesktopContentMaxWidth);
    });
    testWidgets('لابتوب 1366: نفس العرض الأقصى', (t) async {
      expect(await widthOf(t, const Size(1366, 768)), kDesktopContentMaxWidth);
    });
    testWidgets('موبايل: بلا أي تغيير', (t) async {
      expect(await widthOf(t, const Size(390, 800)), 390);
    });
    testWidgets('معطّل (أندرويد): بلا أي تغيير حتى على عرض كبير', (t) async {
      expect(await widthOf(t, const Size(1920, 1080), enabled: false), 1920);
    });
  });
}
