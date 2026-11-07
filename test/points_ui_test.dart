// test/points_ui_test.dart — لوحة النقاط وتفاصيل الطالب وقواعد النقاط:
// بلا overflow على شاشة ضيقة وخط كبير والوضعين، وسلوك أساسي لكل واحدة.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/points_service.dart';
import 'package:active_class/utils/student_points.dart';
import 'package:active_class/views/exams/points_board.dart';
import 'package:active_class/widgets/points_rules_sheet.dart';
import 'package:active_class/widgets/student_points_card.dart';
import 'package:active_class/widgets/student_points_sheet.dart';

final _groups = [
  Group(id: 1, name: 'العواسجة — تانية ثانوي علمي رياضة', code: 'G1', price: 300),
  Group(id: 2, name: 'أولى ثانوي', code: 'G2', price: 300),
];

Student _s(int id, String name, int g) =>
    Student(id: id, name: name, code: 'S$id', groupId: g, price: 100);

PointsData _data({int days = 12}) {
  final students = [
    _s(1, 'مصطفى عبد الرحمن عبد الله الشاذلي الطويل جدًا', 1),
    _s(2, 'بسمة', 1),
    _s(3, 'يوسف', 2),
    _s(4, 'ليلى', 2),
    _s(5, 'صفر', 2), // من غير نقاط
  ];
  Map<int, List<Attendance>> att = {};
  final counts = {1: days, 2: 8, 3: 5, 4: 2};
  counts.forEach((id, n) {
    att[id] = [
      for (var i = 1; i <= n; i++)
        Attendance(
            studentId: id,
            date: DateTime.now().subtract(Duration(days: i)),
            status: ATTENDANCE_PRESENT)
    ];
  });
  return PointsData(
    students: students,
    groups: _groups,
    attendance: att,
    homework: const {},
    exams: <int, List<StudentExamRecord>>{},
  );
}

Widget _host(Widget child, {bool dark = false, double scale = 1.0}) =>
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: w!),
      ),
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting('ar');
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  group('لوحة النقاط', () {
    for (final dark in [false, true]) {
      for (final size in [const Size(320, 568), const Size(360, 740)]) {
        testWidgets('بلا overflow dark=$dark ${size.width}x${size.height} ×1.6',
            (tester) async {
          tester.view.physicalSize = size * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_host(
              PointsBoard(initialData: _data()),
              dark: dark,
              scale: 1.6));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('منصّة لأول 3 وباقي القايمة، ومن غير نقاط مش بيظهر',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(PointsBoard(initialData: _data())));
      await tester.pumpAndSettle();
      expect(find.text('4 طالب لهم نقاط'), findsOneWidget);
      expect(find.text('صفر'), findsNothing);
      expect(find.text('ليلى'), findsOneWidget); // الرابع في القايمة
      expect(find.text('باقي الترتيب'), findsOneWidget);
      expect(find.text('التزام 100%'), findsWidgets);
    });

    testWidgets('فلتر المجموعة بيقلّل القايمة', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(PointsBoard(initialData: _data())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('كل المجموعات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أولى ثانوي').last);
      await tester.pumpAndSettle();
      expect(find.text('2 طالب لهم نقاط'), findsOneWidget);
    });

    testWidgets('الضغط على طالب بيفتح تفاصيل نقاطه', (tester) async {
      tester.view.physicalSize = const Size(720, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(PointsBoard(initialData: _data())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ليلى'));
      await tester.pumpAndSettle();
      expect(find.text('من فين جت النقاط؟'), findsOneWidget);
      expect(find.text('سلم المستويات'), findsOneWidget);
      expect(find.text('الأوسمة'), findsOneWidget);
      expect(find.text('الحضور'), findsOneWidget);
    });

    testWidgets('من غير بيانات: رسالة فاضية', (tester) async {
      await tester.pumpWidget(_host(PointsBoard(
          initialData: PointsData(
              students: [_s(1, 'أحمد', 1)],
              groups: _groups,
              attendance: const {},
              homework: const {},
              exams: const {}))));
      await tester.pumpAndSettle();
      expect(find.text('لسه مفيش نقاط في الفترة دي'), findsOneWidget);
    });
  });

  group('شيت تفاصيل الطالب', () {
    testWidgets('بلا overflow ×1.6 في الوضعين', (tester) async {
      final ranked = _data().rank(rules: PointsRules.defaults);
      for (final dark in [false, true]) {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            StudentPointsSheet(
                ranked: ranked.first,
                periodLabel: 'كل الوقت',
                groupName: 'العواسجة — تانية ثانوي علمي رياضة'),
            dark: dark,
            scale: 1.6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('بيعرض المستوى والتقدم والأوسمة المقفولة', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final ranked = _data().rank(rules: PointsRules.defaults);
      await tester.pumpWidget(_host(StudentPointsSheet(
          ranked: ranked.last, periodLabel: 'كل الوقت')));
      await tester.pumpAndSettle();
      expect(find.text('مبتدئ'), findsWidgets);
      expect(find.text('أنت هنا'), findsOneWidget);
      expect(find.textContaining('للمستوى «برونزي»'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));
    });
  });

  studentCardTests();

  group('قواعد النقاط', () {
    testWidgets('بلا overflow ×1.6 في الوضعين', (tester) async {
      for (final dark in [false, true]) {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            const PointsRulesSheet(initial: PointsRules.defaults),
            dark: dark,
            scale: 1.6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('زيادة قيمة وحفظ بيرجّع القواعد الجديدة', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      PointsRules? got;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (c, w) =>
            Directionality(textDirection: TextDirection.rtl, child: w!),
        home: Builder(
            builder: (ctx) => ElevatedButton(
                onPressed: () async =>
                    got = await showPointsRulesSheet(ctx, PointsRules.defaults),
                child: const Text('open'))),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('زوّد').first); // حضور 10 → 11
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(got?.present, 11);
    });

    testWidgets('استرجاع الافتراضي بيرجّع القيم', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      PointsRules? got;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (c, w) =>
            Directionality(textDirection: TextDirection.rtl, child: w!),
        home: Builder(
            builder: (ctx) => ElevatedButton(
                onPressed: () async => got = await showPointsRulesSheet(
                    ctx, const PointsRules(present: 33)),
                child: const Text('open'))),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استرجاع القواعد الافتراضية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(got?.present, 10);
    });
  });
}

// ── كارت الطالب ──────────────────────────────────────────────────────────
void studentCardTests() {
  group('كارت نقاط الطالب', () {
    for (final dark in [false, true]) {
      testWidgets('بيظهر النقاط والالتزام والمركز بلا overflow dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final data = _data();
        await tester.pumpWidget(_host(
            StudentPointsCard(
                student: data.students.first,
                groupName: 'العواسجة',
                initialData: data,
                initialRules: PointsRules.defaults),
            dark: dark,
            scale: 1.6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('نقاطه ومستواه'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // المركز الأول في مجموعته
      });
    }

    testWidgets('الضغط بيفتح تفاصيل النقاط', (tester) async {
      tester.view.physicalSize = const Size(720, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final data = _data();
      await tester.pumpWidget(_host(StudentPointsCard(
          student: data.students[1],
          initialData: data,
          initialRules: PointsRules.defaults)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نقاطه ومستواه'));
      await tester.pumpAndSettle();
      expect(find.text('سلم المستويات'), findsOneWidget);
    });
  });
}
