// ignore_for_file: must_call_super
// test/recitation_page_test.dart — شاشة قائمة التسميع: بلا overflow، وسلوك
// الدرجة العظمى (+/−) لكل مجموعة، وتنبيه التراجع والنجمة، وخانة الغائب.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/attendance/recitation_page.dart';

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
  _Groups(List<Group> list) {
    groups.assignAll(list);
  }
  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async {}
}

class _Attendance extends AttendanceController {
  @override
  void onInit() {}
  @override
  Future<void> loadAttendance() async {}
}

class _Overrides extends SessionOverrideController {
  @override
  void onInit() {}
  @override
  Future<void> load() async {}
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

const _days = {
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

void _seed() {
  Get.reset();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = _days[now.weekday]!;
  final groups = [
    Group(id: 1, name: 'تسميع الكلمات', price: 300, schedule: '$day 08:00-10:00'),
    Group(id: 2, name: 'مجموعة أخرى', price: 250, schedule: '$day 12:00-13:00'),
  ];
  final students = [
    Student(id: 1, name: 'رغد مصطفى', code: 'a', groupId: 1, price: 0),
    Student(id: 2, name: 'آدم أحمد', code: 'b', groupId: 1, price: 0),
    Student(id: 3, name: 'أروى عماد', code: 'c', groupId: 1, price: 0),
    Student(id: 4, name: 'إياد محمود', code: 'd', groupId: 2, price: 0),
  ];
  final att = _Attendance();
  att.attendance.addAll([
    Attendance(studentId: 1, date: today, status: ATTENDANCE_PRESENT),
    Attendance(studentId: 2, date: today, status: ATTENDANCE_LATE),
    Attendance(studentId: 3, date: today, status: ATTENDANCE_ABSENT),
    Attendance(studentId: 4, date: today, status: ATTENDANCE_PRESENT),
  ]);
  Get.put<SessionOverrideController>(_Overrides());
  Get.put<AttendanceController>(att);
  Get.put<StudentController>(_Students(students));
  Get.put<GroupController>(_Groups(groups));
  Get.put<SettingsController>(_Settings());
}

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t,
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
    home: const RecitationPage(),
  ));
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
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
          expect(find.text('حفظ درجات التسميع'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('بيعرض مجموعات اليوم والـ+/− بيغيّر الدرجة العظمى لكل مجموعة',
      (t) async {
    _seed();
    await _pump(t);
    expect(find.text('تسميع الكلمات'), findsOneWidget);
    expect(find.text('مجموعة أخرى'), findsOneWidget);
    // الافتراضي 10 في المجموعتين
    expect(find.text('10'), findsNWidgets(2));
    await t.tap(find.byTooltip('زيادة الدرجة العظمى').first);
    await t.pump();
    await t.tap(find.byTooltip('زيادة الدرجة العظمى').first);
    await t.pump();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    await t.tap(find.byTooltip('تقليل الدرجة العظمى').last);
    await t.pump();
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('5 من 10 عادي (مش تراجع) و4 تراجع', (t) async {
    _seed();
    await _pump(t);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), '5');
    await t.pump();
    expect(find.text('تراجع مستوى'), findsNothing);
    await t.enterText(fields.at(0), '4');
    await t.pump();
    expect(find.text('تراجع مستوى'), findsOneWidget);
    await t.enterText(fields.at(0), '9');
    await t.pump();
    expect(find.text('نجمة تميّز'), findsOneWidget);
  });

  testWidgets('رقم أكبر من الدرجة العظمى بيظهر خطأ، والغائب خانته مقفولة',
      (t) async {
    _seed();
    await _pump(t);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), '11');
    await t.pump();
    expect(find.text('أقصى 10'), findsOneWidget);
    // الترتيب أبجدي: آدم (متأخر)، أروى (غايبة)، رغد — فالغايبة هي الخانة الثانية.
    final absent = t.widget<TextField>(fields.at(1));
    expect(absent.enabled, isFalse);
    expect(find.text('غائب'), findsOneWidget);
  });

  testWidgets('لما تتفتح من حضور اليوم بتعرض المجموعة المطلوبة بس', (t) async {
    _seed();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(360, 740);
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(
      theme: _cairo(AppTheme.lightTheme),
      locale: const Locale('ar'),
      builder: (c, ch) => Directionality(textDirection: TextDirection.rtl, child: ch!),
      home: const Scaffold(body: SizedBox()),
    ));
    final now = DateTime.now();
    Get.to(() => const RecitationPage(),
        arguments: {'groupId': 2, 'day': DateTime(now.year, now.month, now.day)});
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('مجموعة أخرى'), findsWidgets);
    expect(find.text('تسميع الكلمات'), findsNothing);
    // زر "كل المجموعات" بيرجّع باقي المجموعات
    await t.tap(find.text('كل المجموعات'));
    await t.pump();
    expect(find.text('تسميع الكلمات'), findsOneWidget);
  });
}
