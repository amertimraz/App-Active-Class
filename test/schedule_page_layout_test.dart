// ignore_for_file: must_call_super
// test/schedule_page_layout_test.dart — شكل جدول الحصص (السبورة والطباشير):
// بلا overflow على المقاسات الصغيرة والخط الكبير والوضعين، والملخص صح،
// وشارة "الآن" وشارات الاستثناء، والأيام الفاضية.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/views/schedule/schedule_page.dart';

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

const _wd = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t,
    {required Size size, double scale = 1, bool dark = false}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    theme: _cairo(dark ? AppTheme.darkTheme : AppTheme.lightTheme),
    locale: const Locale('ar'),
    builder: (c, ch) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(textDirection: TextDirection.rtl, child: ch!),
    ),
    home: const SchedulePage(),
  ));
  await _settle(t);
}

/// الصفحة بتقرا قاعدة SQLite حقيقية (isolate) على خطوات ورا بعض؛ كل خطوة
/// محتاجة وقت حقيقي (runAsync) وبعدها pump عشان الكود اللي بعدها يكمّل.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ac_schedule_');
    await databaseFactory.setDatabasesPath(dir.path);

    // مجموعة شغّالة النهارده طول اليوم (→ "الآن") + مجموعة بموعد بعد بكرة.
    final now = DateTime.now();
    final today = _wd[now.weekday]!;
    final later = _wd[now.add(const Duration(days: 2)).weekday]!;
    final db = DatabaseService();
    final g1 = await db.insertGroup(Group(
        name: 'أولى ثانوي — علوم',
        price: 300,
        color: 0xFF4F46E5,
        schedule: '$today 00:00-23:59, $later 12:00-13:30'));
    final g2 = await db.insertGroup(Group(
        name: 'العواسجة — تانية ثانوي علمي رياضة',
        price: 400,
        color: 0xFF10B981,
        schedule: '$later 10:00-12:00'));
    for (var i = 1; i <= 5; i++) {
      await db.insertStudent(
          Student(name: 'طالب $i', code: 's$i', groupId: g1, price: 0));
    }
    await db.insertStudent(
        Student(name: 'طالب 6', code: 's6', groupId: g2, price: 0));
  });

  setUp(() {
    Get.reset();
    Get.put<SettingsController>(_Settings());
  });
  tearDown(Get.reset);

  for (final dark in [false, true]) {
    for (final size in const [Size(320, 568), Size(360, 740), Size(411, 900)]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'بلا overflow ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
            (t) async {
          await _pump(t, size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
          expect(find.text('جدول الحصص'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('ملخص الأسبوع: 3 حصص، ساعات التدريس، مجموعتين', (t) async {
    await _pump(t, size: const Size(360, 740));
    expect(find.text('حصة أسبوعياً'), findsOneWidget);
    expect(find.text('ساعة تدريس'), findsOneWidget);
    expect(find.text('مجموعة نشطة'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // 3 حصص في الأسبوع
    expect(find.text('2'), findsWidgets); // مجموعتين
  });

  testWidgets('حصة النهارده: الاسم وشارة "الآن" وعدد الطلاب', (t) async {
    await _pump(t, size: const Size(360, 900));
    expect(find.text('أولى ثانوي — علوم'), findsOneWidget);
    expect(find.text('الآن'), findsOneWidget);
    expect(find.text('5 طالب'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('شريط الأيام: 7 شرايح، واليوم الحالي متعلّم', (t) async {
    await _pump(t, size: const Size(360, 740));
    for (final d in _wd.values) {
      expect(find.text(d), findsWidgets);
    }
    expect(find.text('اليوم'), findsOneWidget);
  });

  testWidgets('تنقّل الأسبوع: "الرجوع لليوم" بيظهر بعد التنقل ويختفي بالرجوع',
      (t) async {
    await _pump(t, size: const Size(360, 740));
    expect(find.text('الرجوع لليوم'), findsNothing);
    await t.tap(find.byTooltip('أسبوع بعد'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('الرجوع لليوم'), findsOneWidget);
    await t.tap(find.text('الرجوع لليوم'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('الرجوع لليوم'), findsNothing);
  });

  testWidgets('تقليل الحركة: النقطة النابضة ما بتعملش animation', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(360, 900);
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(
      theme: _cairo(AppTheme.lightTheme),
      locale: const Locale('ar'),
      builder: (c, ch) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: true),
        child: Directionality(textDirection: TextDirection.rtl, child: ch!),
      ),
      home: const SchedulePage(),
    ));
    await _settle(t);
    // لو الـanimation شغّال مفيش pumpAndSettle بينتهي؛ هنا لازم ينتهي.
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
  });
}
