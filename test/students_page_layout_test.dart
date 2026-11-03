// ignore_for_file: must_call_super
// test/students_page_layout_test.dart — صفحة الطلاب (السبورة والطباشير):
// بلا overflow على المقاسات الصغيرة والخط الكبير والوضعين في القايمة والشبكة،
// والأرقام فوق السبورة، وقايمة المزيد، وفلتر المجموعة، والحالة الفاضية.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/students/students_page.dart';

final _groups = [
  Group(id: 1, name: 'أولى ثانوي — علوم', color: 0xFF4F46E5, price: 300),
  Group(id: 2, name: 'العواسجة — تانية ثانوي علمي رياضة', color: 0xFF10B981, price: 400),
];

class _Students extends StudentController {
  _Students(List<Student> list) {
    students.assignAll(list);
    filteredStudents.assignAll(list);
  }
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async {}
  @override
  Future<List<Group>> loadAllGroups() async => _groups;
}

class _Att extends AttendanceController {
  @override
  void onInit() {}
  @override
  Future<void> loadAttendance() async {}
}

class _Pay extends PaymentController {
  @override
  void onInit() {}
  @override
  Future<void> loadPayments() async {}
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

List<Student> _sample() => [
      Student(
          id: 1,
          name: 'إسراء محمد إبراهيم سعد',
          code: 'G1-01',
          groupId: 1,
          price: 300,
          guardianPhone: '01096693758'),
      Student(
          id: 2,
          name: 'مصطفى عبد الرحمن عبد الله الشاذلي الطويل جدًا',
          code: 'G1-02',
          groupId: 1,
          price: 300,
          guardianWhatsapp: '01100421878'),
      Student(
          id: 3,
          name: 'منى',
          code: 'G2-01',
          groupId: 2,
          price: 400,
          exemptPercent: 100),
      Student(id: 4, name: 'آدم', code: 'G2-02', groupId: 2, price: 400),
    ];

void _seed({List<Student>? students}) {
  Get.reset();
  Get.put<SettingsController>(_Settings());
  Get.put<AttendanceController>(_Att());
  Get.put<PaymentController>(_Pay());
  Get.put<StudentController>(_Students(students ?? _sample()));
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
    home: const StudentsPage(),
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
        for (final grid in [false, true]) {
          testWidgets(
              'بلا overflow ${grid ? "شبكة" : "قايمة"} ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            _seed();
            await _pump(t, size: size, scale: scale, dark: dark);
            if (grid) {
              await t.tap(find.byTooltip('عرض شبكة'));
              await t.pump(const Duration(milliseconds: 400));
            }
            expect(t.takeException(), isNull);
            expect(find.text('الطلاب'), findsOneWidget);
          });
        }
      }
    }
  }

  testWidgets('الأرقام فوق السبورة: طلاب / مجموعات / بدون رقم ولي أمر', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    expect(find.text('طالب'), findsOneWidget);
    expect(find.text('مجموعة'), findsOneWidget);
    expect(find.text('بدون رقم ولي أمر'), findsOneWidget);
    expect(find.text('4'), findsWidgets); // 4 طلاب
    expect(find.text('2'), findsWidgets); // مجموعتين / طالبين بلا رقم
  });

  testWidgets('قايمة النقط التلاتة فيها استيراد والإخوة والأرشيف', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.tap(find.byTooltip('المزيد'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('استيراد من إكسل'), findsOneWidget);
    expect(find.text('الإخوة'), findsOneWidget);
    expect(find.text('الأرشيف'), findsOneWidget);
  });

  testWidgets('الكارت: الاسم والمجموعة والكود وشارة المعفي', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    expect(find.text('إسراء محمد إبراهيم سعد'), findsOneWidget);
    expect(find.text('G1-01'), findsOneWidget);
    expect(find.text('معفى'), findsOneWidget);
    expect(find.byTooltip('خيارات الطالب'), findsWidgets);
  });

  testWidgets('فلتر المجموعة بيظهر شرايط، والبحث بيفلتر', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    expect(find.text('الكل'), findsOneWidget);
    expect(find.text('أولى ثانوي — علوم'), findsWidgets);
    await t.enterText(find.byType(TextField), 'آدم');
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
  });

  testWidgets('الحالة الفاضية: رسالة وزر إضافة', (t) async {
    _seed(students: []);
    await _pump(t, size: const Size(360, 740));
    expect(find.text('لا يوجد طلاب'), findsOneWidget);
    expect(find.text('إضافة طالب'), findsWidgets);
  });

  testWidgets('زر ؟ في الشريط بيفتح مساعدة الطلاب', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.tap(find.byTooltip('مساعدة'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('إضافة الطلاب وإدارتهم'), findsOneWidget);
  });
}
