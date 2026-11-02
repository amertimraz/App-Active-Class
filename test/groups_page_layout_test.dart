// ignore_for_file: must_call_super
// test/groups_page_layout_test.dart — شكل صفحة المجموعات (السبورة والطباشير):
// بلا overflow على المقاسات الصغيرة والخط الكبير والوضعين، والأرقام صح،
// والبحث والحالة الفاضية.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/groups/groups_page.dart';

class _Students extends StudentController {
  _Students(List<Student> list) {
    students.assignAll(list);
  }
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async {}
}

class _Groups extends GroupController {
  _Groups(this.list) {
    groups.assignAll(list);
  }
  final List<Group> list;
  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async {}
}

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

void _seed({bool empty = false}) {
  Get.reset();
  final now = DateTime.now();
  final today = _wd[now.weekday]!;
  final tomorrow = _wd[now.add(const Duration(days: 1)).weekday]!;
  final later = _wd[now.add(const Duration(days: 2)).weekday]!;
  final groups = empty
      ? <Group>[]
      : [
          Group(
              id: 1,
              name: 'أولى ثانوي — علوم',
              code: 'G1',
              price: 300,
              color: 0xFF4F46E5,
              icon: 'science',
              // النهارده طول اليوم → دايمًا "شغّالة دلوقتي" في الاختبار.
              schedule: '$today 08:00-10:00, $later 12:00-13:30'),
          Group(
              id: 2,
              name: 'العواسجة — تانية ثانوي علمي رياضة',
              price: 400,
              color: 0xFF10B981,
              icon: 'math',
              schedule: '$tomorrow 15:00-17:00, $later 10:00-12:00'),
          Group(id: 3, name: 'مجموعة بلا مواعيد', color: 0xFFF59E0B),
          Group(id: 4, name: 'مجموعة فاضية', price: 250, schedule: '$later 09:00-10:00'),
        ];
  final students = <Student>[
    for (var i = 1; i <= 9; i++)
      Student(id: i, name: 'طالب $i', code: 'c$i', groupId: i <= 5 ? 1 : (i <= 8 ? 2 : 3), price: 0),
  ];
  Get.put<StudentController>(_Students(students));
  Get.put<GroupController>(_Groups(groups));
  Get.put<SettingsController>(_Settings());
}

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
    home: const GroupsPage(),
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
  tearDown(Get.reset);

  for (final dark in [false, true]) {
    for (final size in const [Size(320, 568), Size(360, 740), Size(411, 900)]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'بلا overflow ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
            (t) async {
          _seed();
          await _pump(t, size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
          expect(find.text('المجموعات'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('الأرقام فوق السبورة صح (مجموعات / طلاب / بدون طلاب)', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 740));
    expect(find.text('مجموعة'), findsOneWidget);
    expect(find.text('4'), findsWidgets); // 4 مجموعات
    expect(find.text('9'), findsOneWidget); // 9 طلاب
    expect(find.text('بدون طلاب'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // مجموعة واحدة فاضية
  });

  testWidgets('كارت المجموعة: الاسم والكود والمواعيد وعدد الطلاب', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    expect(find.byKey(const ValueKey('group-1')), findsOneWidget);
    expect(find.text('الكود: G1'), findsOneWidget);
    expect(find.text('لا توجد مواعيد'), findsOneWidget);
    expect(find.byTooltip('خيارات المجموعة'), findsWidgets);
  });

  testWidgets('البحث بالاسم بيفلتر، ونتيجة فاضية بتعرض رسالة', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.enterText(find.byType(TextField), 'العواسجة');
    await t.pump();
    expect(find.byKey(const ValueKey('group-1')), findsNothing);
    expect(find.byKey(const ValueKey('group-2')), findsOneWidget);
    await t.enterText(find.byType(TextField), 'مفيش حاجة كده');
    await t.pump();
    expect(find.textContaining('لا نتائج'), findsOneWidget);
  });

  testWidgets('الحالة الفاضية: رسالة وزر إضافة', (t) async {
    _seed(empty: true);
    await _pump(t, size: const Size(360, 740));
    expect(find.text('لا توجد مجموعات'), findsOneWidget);
    expect(find.text('إضافة مجموعة'), findsOneWidget);
    expect(find.text('مجموعة جديدة'), findsOneWidget); // زر الطباشير العائم
  });
}
