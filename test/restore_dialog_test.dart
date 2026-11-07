// test/restore_dialog_test.dart — نافذة استعادة الطالب من الأرشيف:
// بلا overflow على شاشة ضيقة وخط كبير والوضعين، والأزرار بترجّع الاختيار الصح.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/students/archived_students_page.dart';
import 'package:active_class/widgets/chalk_dialog.dart';
import 'package:active_class/widgets/remove_student_dialog.dart';

Widget _host(Widget dialog, {required bool dark, double scale = 1.0}) =>
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(body: Builder(builder: (ctx) {
        return Center(
          child: ElevatedButton(
            onPressed: () => showDialog<RestoreChoice>(
                context: ctx, builder: (_) => dialog),
            child: const Text('open'),
          ),
        );
      })),
    );

RestoreDialog _dialog({double debt = 170, int months = 3}) => RestoreDialog(
      studentName: 'مصطفى عبد الرحمن عبد الله الشاذلي الطويل جدًا',
      groupName: 'العواسجة — تانية ثانوي علمي رياضة',
      debtTotal: debt,
      months: [
        for (var i = 0; i < months; i++)
          RestoreMonth(
              label: 'شهر رقم ${i + 1} 2026',
              remaining: 10.0 + i * 80,
              attendance: i + 2),
      ],
      restoreMonthLabel: 'نوفمبر 2026',
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting('ar');
    // خط Cairo الحقيقي (خط الاختبار الافتراضي عريض ويكبّر العرض وهميًا).
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final dark in [false, true]) {
    for (final size in [const Size(360, 640), const Size(320, 568)]) {
      testWidgets('بلا overflow dark=$dark ${size.width}x${size.height} ×1.6',
          (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(_dialog(months: 8), dark: dark, scale: 1.6));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('استعادة بمديونيته'), findsOneWidget);
        expect(find.textContaining('إسقاط'), findsOneWidget);
        expect(find.text('إلغاء'), findsOneWidget);
      });
    }
  }

  testWidgets('بيوضّح قاعدة شهر الاستعادة والشهور المؤرشفة وعدد الحضور',
      (tester) async {
    await tester.pumpWidget(_host(_dialog(months: 2), dark: false));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('بيتحسب كامل، حتى لو رجع في آخر يوم'),
        findsOneWidget);
    expect(find.textContaining('مش بتتحسب عليه'), findsOneWidget);
    expect(find.text('2 سجل حضور في الشهر ده'), findsOneWidget);
    expect(find.text('3 سجل حضور في الشهر ده'), findsOneWidget);
  });

  testWidgets('من غير مديونية: زر استعادة واحد بس ومفيش إسقاط', (tester) async {
    await tester.pumpWidget(_host(_dialog(debt: 0, months: 0), dark: false));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('استعادة'), findsOneWidget);
    expect(find.textContaining('إسقاط'), findsNothing);
    expect(find.text('مفيش عليه أي مديونية'), findsOneWidget);
  });

  testWidgets('الأزرار بترجّع الاختيار الصح', (tester) async {
    RestoreChoice? got;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
          builder: (ctx) => ElevatedButton(
                onPressed: () async => got = await showDialog<RestoreChoice>(
                    context: ctx, builder: (_) => _dialog()),
                child: const Text('open'),
              )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('إسقاط'));
    await tester.pumpAndSettle();
    expect(got, RestoreChoice.restoreAndWriteOff);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استعادة بمديونيته'));
    await tester.pumpAndSettle();
    expect(got, RestoreChoice.restoreOnly);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  group('نافذة حذف الطالب (أرشفة / حذف نهائي)', () {
    final student = Student(
        id: 1,
        name: 'مصطفى عبد الرحمن عبد الله الشاذلي الطويل جدًا',
        code: 'S1',
        groupId: 1,
        price: 80);

    Widget host(
        {required bool dark,
        double scale = 1.0,
        required List<String> log}) {
      return MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child:
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: Builder(
            builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => showRemoveStudentDialog(ctx,
                        student: student,
                        canDelete: true,
                        onArchive: () async {
                          log.add('archive');
                          return false;
                        },
                        onDeletePermanently: () async {
                          log.add('delete');
                          return false;
                        }),
                    child: const Text('open'),
                  ),
                )),
      );
    }

    for (final dark in [false, true]) {
      testWidgets('بلا overflow dark=$dark 320x568 ×1.6', (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester
            .pumpWidget(host(dark: dark, scale: 1.6, log: []));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('أرشفة'), findsOneWidget);
        expect(find.text('حذف نهائي'), findsOneWidget);
        expect(find.text('إلغاء'), findsOneWidget);
      });
    }

    testWidgets('الأرشفة بتنادي onArchive', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(dark: false, log: log));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أرشفة'));
      await tester.pumpAndSettle();
      expect(log, ['archive']);
    });

    testWidgets('الحذف النهائي: تأكيد تاني، والرجوع ما يمسحش', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(dark: false, log: log));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف نهائي'));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد الحذف النهائي'), findsOneWidget);
      await tester.tap(find.text('رجوع'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف نهائي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف نهائي').last);
      await tester.pumpAndSettle();
      expect(log, ['delete']);
    });
  });

  group('showChalkConfirm', () {
    Widget host(void Function(bool) onResult,
        {bool destructive = false, bool dark = false, double scale = 1.0}) {
      return MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child:
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: Builder(
            builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () async => onResult(await showChalkConfirm(ctx,
                        icon: Icons.delete_rounded,
                        title: 'حذف الملزمة',
                        subtitle: 'ملزمة الفيزياء',
                        message: 'هتتحذف نهائيًا بكل سجلات التسليم والدفعات.',
                        confirmLabel: 'حذف',
                        destructive: destructive)),
                    child: const Text('open'),
                  ),
                )),
      );
    }

    testWidgets('التأكيد بيرجّع true والإلغاء false', (tester) async {
      bool? got;
      await tester.pumpWidget(host((v) => got = v, destructive: true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('حذف الملزمة'), findsOneWidget);
      expect(find.text('ملزمة الفيزياء'), findsOneWidget);
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(got, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(got, isFalse);
    });

    for (final dark in [false, true]) {
      testWidgets('بلا overflow dark=$dark 320x568 ×1.6', (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host((_) {}, dark: dark, scale: 1.6));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
