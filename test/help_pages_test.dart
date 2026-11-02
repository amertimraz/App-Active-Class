// ignore_for_file: must_call_super
// test/help_pages_test.dart — مركز المساعدة وصفحة الموضوع وكارت "ابدأ من هنا":
// بلا overflow على المقاسات الصغيرة والخط الكبير والوضعين، والبحث والتنقل.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/getting_started_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/help/getting_started.dart';
import 'package:active_class/help/help_content.dart';
import 'package:active_class/views/help/getting_started_card.dart';
import 'package:active_class/views/help/help_center_page.dart';
import 'package:active_class/views/help/help_topic_page.dart';
import 'package:active_class/views/help/help_widgets.dart';

class _GS extends GettingStartedController {
  _GS(List<GettingStartedStep> s, {bool dismissed = false}) {
    steps.assignAll(s);
    loaded.value = true;
    this.dismissed.value = dismissed;
  }
  @override
  void onInit() {}
  @override
  Future<void> dismiss() async => dismissed.value = true;
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t, Widget home,
    {Size size = const Size(360, 740), double scale = 1, bool dark = false}) async {
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
    getPages: [
      GetPage(name: '/', page: () => home),
      GetPage(name: ROUTE_HELP_TOPIC, page: () => const HelpTopicPage()),
    ],
  ));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
  });
  setUp(() {
    Get.reset();
    Get.put<SettingsController>(_Settings());
  });
  tearDown(Get.reset);

  for (final dark in [false, true]) {
    for (final size in const [Size(320, 568), Size(360, 740), Size(411, 900)]) {
      for (final scale in [1.0, 1.6]) {
        final tag =
            '${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}';
        testWidgets('مركز المساعدة بلا overflow $tag', (t) async {
          await _pump(t, const HelpCenterPage(),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });
        testWidgets('صفحة الموضوع بلا overflow $tag', (t) async {
          for (final topic in [kHelpTopics.first, helpTopicById('recitation')!]) {
            await _pump(t, HelpTopicPage(topic: topic),
                size: size, scale: scale, dark: dark);
            expect(t.takeException(), isNull, reason: topic.id);
          }
        });
        testWidgets('كارت ابدأ من هنا بلا overflow $tag', (t) async {
          Get.put<GettingStartedController>(_GS(gettingStartedSteps(
              groups: 1, students: 0, attendanceRecords: 0, payments: 0)));
          await _pump(t, const Scaffold(body: GettingStartedCard()),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('كل المواضيع ظاهرة مقسّمة بالفئات', (t) async {
    await _pump(t, const HelpCenterPage(), size: const Size(360, 8000));
    for (final c in HelpCategory.values) {
      expect(find.textContaining(c.title), findsWidgets);
    }
    expect(find.text('الأكثر استخدامًا'), findsOneWidget);
    for (final topic in kHelpTopics) {
      // بعض العناوين بتتكرر كاقتراح بحث (مثلًا بوابة أولياء الأمور).
      expect(find.text(topic.title), findsWidgets, reason: topic.id);
    }
  });

  testWidgets('البحث بيطلّع الموضوع الصح، ونتيجة فاضية بتعرض رسالة ودعم',
      (t) async {
    await _pump(t, const HelpCenterPage());
    await t.enterText(find.byType(TextField), 'إزاي أسجل دفعة؟');
    await t.pump();
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.textContaining('الأساسيات'), findsNothing);
    await t.enterText(find.byType(TextField), 'ززززز');
    await t.pump();
    expect(find.textContaining('ما لقيناش'), findsOneWidget);
    expect(find.text('لسه محتاج مساعدة؟'), findsOneWidget);
  });

  testWidgets('الضغط على اقتراح بيملا البحث', (t) async {
    await _pump(t, const HelpCenterPage());
    await t.tap(find.text(kHelpSuggestions.first));
    await t.pump();
    expect(find.widgetWithText(TextField, kHelpSuggestions.first),
        findsOneWidget);
  });

  testWidgets('الضغط على موضوع بيفتح صفحته بالخطوات والنصايح', (t) async {
    await _pump(t, const HelpCenterPage(), size: const Size(360, 8000));
    await t.tap(find.text('التسميع').first);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    final topic = helpTopicById('recitation')!;
    expect(find.text('الخطوات'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('${topic.steps.length}'), findsOneWidget);
    expect(find.text('نصايح'), findsOneWidget);
    expect(find.text(topic.routeLabel!), findsOneWidget);
  });

  testWidgets('الكلام بين ** بيتعرض بخط عريض من غير النجمتين', (t) async {
    await _pump(t, HelpTopicPage(topic: helpTopicById('start')!));
    expect(find.textContaining('**'), findsNothing);
    final rich = t.widgetList<RichText>(find.byType(RichText));
    final hasBold = rich.any((r) {
      var found = false;
      r.text.visitChildren((s) {
        if (s is TextSpan &&
            s.style?.fontWeight == FontWeight.w700 &&
            (s.text ?? '').contains('المجموعات')) {
          found = true;
        }
        return true;
      });
      return found;
    });
    expect(hasBold, isTrue);
  });

  testWidgets('تحذير المسح ظاهر في موضوع المجموعات', (t) async {
    await _pump(t, HelpTopicPage(topic: helpTopicById('groups')!),
        size: const Size(360, 1400));
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('تصفير الطلاب'), findsWidgets);
  });

  testWidgets('هل ساعدك: أيوه بتشكر، ولأ بتعرض الدعم', (t) async {
    await _pump(t, HelpTopicPage(topic: helpTopicById('attendance')!),
        size: const Size(360, 2400));
    expect(find.text('هل الموضوع ده ساعدك؟'), findsOneWidget);
    await t.tap(find.text('لأ'));
    await t.pump();
    expect(find.textContaining('آسفين'), findsOneWidget);
    expect(find.text('لسه محتاج مساعدة؟'), findsWidgets);
  });

  testWidgets('زر ؟ بيفتح نافذة سريعة بالخطوات وزر الموضوع الكامل', (t) async {
    await _pump(
        t,
        Scaffold(
            appBar: AppBar(actions: const [HelpButton(topicId: 'payments')]),
            body: const SizedBox()),
        size: const Size(360, 900));
    await t.tap(find.byTooltip('مساعدة'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('تسجيل دفعة'), findsWidgets);
    expect(find.text('الخطوات'), findsOneWidget);
    expect(find.text('افتح الموضوع كامل'), findsOneWidget);
  });

  group('كارت ابدأ من هنا', () {
    testWidgets('بيعرض التقدّم وأول خطوة ناقصة', (t) async {
      Get.put<GettingStartedController>(_GS(gettingStartedSteps(
          groups: 2, students: 0, attendanceRecords: 0, payments: 0)));
      await _pump(t, const Scaffold(body: GettingStartedCard()));
      expect(find.text('ابدأ من هنا'), findsOneWidget);
      expect(find.text('1 من 4'), findsOneWidget);
      expect(find.text('ضيف طلابك'), findsOneWidget);
      expect(find.text('اقرا دليل البداية'), findsOneWidget);
    });

    testWidgets('بيختفي لما كل الخطوات تخلص', (t) async {
      Get.put<GettingStartedController>(_GS(gettingStartedSteps(
          groups: 1, students: 5, attendanceRecords: 3, payments: 2)));
      await _pump(t, const Scaffold(body: GettingStartedCard()));
      expect(find.text('ابدأ من هنا'), findsNothing);
    });

    testWidgets('زر الإخفاء بيخفيه', (t) async {
      Get.put<GettingStartedController>(_GS(gettingStartedSteps(
          groups: 0, students: 0, attendanceRecords: 0, payments: 0)));
      await _pump(t, const Scaffold(body: GettingStartedCard()));
      expect(find.text('ابدأ من هنا'), findsOneWidget);
      await t.tap(find.byTooltip('إخفاء القايمة'));
      await t.pump();
      expect(find.text('ابدأ من هنا'), findsNothing);
    });

    testWidgets('لو مخفي من قبل مش بيظهر', (t) async {
      Get.put<GettingStartedController>(_GS(
          gettingStartedSteps(
              groups: 0, students: 0, attendanceRecords: 0, payments: 0),
          dismissed: true));
      await _pump(t, const Scaffold(body: GettingStartedCard()));
      expect(find.text('ابدأ من هنا'), findsNothing);
    });
  });

  group('منطق الخطوات', () {
    test('بيحسب المنجز والتالي', () {
      final s = gettingStartedSteps(
          groups: 1, students: 3, attendanceRecords: 0, payments: 0);
      expect(gettingStartedDoneCount(s), 2);
      expect(gettingStartedNext(s)!.id, 'attendance');
    });
    test('الكل خلص → مفيش تالي', () {
      final s = gettingStartedSteps(
          groups: 1, students: 1, attendanceRecords: 1, payments: 1);
      expect(gettingStartedNext(s), isNull);
    });
  });
}
