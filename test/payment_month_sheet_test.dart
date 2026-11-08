// test/payment_month_sheet_test.dart — شيت «ملخص دفعات الشهر» في الرئيسية:
// بلا overflow على شاشة ضيقة وخط كبير والوضعين، وعرض الأرقام والمجموعات والضغط.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/dashboard_controller.dart'
    show GroupPaymentSummaryEntry, StudentMonthLine;
import 'package:active_class/models/student_model.dart';
import 'package:active_class/widgets/payment_month_sheet.dart';

GroupPaymentSummaryEntry _g(int? id, String name, double expected,
        double collected, int late,
        {double wo = 0}) =>
    GroupPaymentSummaryEntry(
        groupId: id,
        groupName: name,
        expected: expected,
        collected: collected,
        writtenOff: wo,
        unpaidStudentsCount: late);

PaymentMonthSheet _sheet(
        {List<GroupPaymentSummaryEntry>? groups, double wo = 0}) =>
    PaymentMonthSheet(
      monthName: 'نوفمبر',
      collected: 2500,
      expected: 4000,
      remaining: 1500,
      writtenOff: wo,
      rate: 0.625,
      groups: groups ??
          [
            _g(1, 'العواسجة — تانية ثانوي علمي رياضة', 2000, 1200, 6),
            _g(2, 'أولى ثانوي', 1500, 1500, 0),
            _g(null, 'طلاب بلا مجموعة', 500, 0, 2),
          ],
    );

Widget _host(Widget sheet, {bool dark = false, double scale = 1.0}) =>
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(
        body: Builder(
            builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet(
                        context: ctx,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => sheet),
                    child: const Text('open'),
                  ),
                )),
      ),
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

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 568), const Size(360, 740)]) {
      testWidgets('بلا overflow dark=$dark ${size.width}x${size.height} ×1.6',
          (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
            _host(_sheet(wo: 120), dark: dark, scale: 1.6));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('ملخص دفعات نوفمبر'), findsOneWidget);
      });
    }
  }

  testWidgets('بيعرض النسبة والأرقام وحالة كل مجموعة', (tester) async {
    await tester.pumpWidget(_host(_sheet(wo: 120)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('63%'), findsOneWidget); // 0.625 → 63
    expect(find.text('8'), findsOneWidget); // 6 + 0 + 2 متأخر
    expect(find.text('طالب متأخر'), findsOneWidget);
    expect(find.text('مُسقَط'), findsOneWidget);
    expect(find.text('مكتملة'), findsOneWidget);
    expect(find.text('6 متأخر'), findsOneWidget);
    expect(find.text('المستحق'), findsNWidgets(3)); // كارت لكل مجموعة
    expect(find.text('2 متأخر'), findsOneWidget);
  });

  testWidgets('من غير إسقاط: مفيش خانة مُسقَط', (tester) async {
    await tester.pumpWidget(_host(_sheet()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('مُسقَط'), findsNothing);
  });

  testWidgets('الضغط على مجموعة بيفتح تابين متأخر ومدفوع', (tester) async {
    final late = Student(
        id: 1, name: 'أحمد', code: 'A1', groupId: 1, price: 100);
    final paid = Student(
        id: 2, name: 'منى', code: 'A2', groupId: 1, price: 100);
    final g = GroupPaymentSummaryEntry(
      groupId: 1,
      groupName: 'سادسة',
      expected: 200,
      collected: 100,
      unpaidStudentsCount: 1,
      lines: [
        StudentMonthLine(
            student: late,
            due: 100,
            paid: 0,
            writtenOff: 0,
            unpaid: true),
        StudentMonthLine(
            student: paid,
            due: 100,
            paid: 100,
            writtenOff: 0,
            unpaid: false),
      ],
    );
    await tester.pumpWidget(_host(_sheet(groups: [g])));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سادسة'));
    await tester.pumpAndSettle();
    expect(find.text('متأخر (1)'), findsOneWidget);
    expect(find.text('مدفوع (1)'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
    await tester.tap(find.text('مدفوع (1)'));
    await tester.pumpAndSettle();
    expect(find.text('منى'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('من غير مجموعات: رسالة فاضية', (tester) async {
    await tester.pumpWidget(_host(_sheet(groups: const [])));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('مفيش مستحقات على أي مجموعة للشهر ده'), findsOneWidget);
  });

  testWidgets('المبلغ والعملة على سطر واحد (مسافة غير قابلة للكسر)',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_sheet(), scale: 1.6));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final w in texts) {
      final s = w.data ?? '';
      // أي نص فيه مبلغ بالعملة: مفيش مسافة عادية بين الرقم والعملة
      expect(RegExp(r'\d [^\d\s]').hasMatch(s) && s.contains('.00'), isFalse,
          reason: s);
    }
  });
}
