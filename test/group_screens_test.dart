// ignore_for_file: must_call_super
// test/group_screens_test.dart — تفاصيل المجموعة ونموذج إضافة/تعديل المجموعة
// وجدول الحصص بتصميم السبورة والطباشير.
// بلا overflow على المقاسات الصغيرة والخط الكبير والوضعين، وسلوك أساسي لكل شاشة.
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
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/groups/group_details_page.dart';
import 'package:active_class/views/groups/group_form/group_form_sheet.dart';

final _groups = [
  Group(
      id: 1,
      name: 'أولى ثانوي — علوم',
      code: 'G1',
      price: 300,
      color: 0xFF4F46E5,
      schedule: 'السبت 18:00-19:00, الثلاثاء 16:30-18:00',
      icon: 'science'),
  Group(
      id: 2,
      name: 'العواسجة — تانية ثانوي علمي رياضة',
      code: 'G2',
      price: 400,
      color: 0xFF10B981,
      pricingType: GroupPricingType.perSession),
];

Student _s(int id, String name, int g,
        {bool archived = false,
        int? sib,
        double? total,
        String? phone,
        double exempt = 0}) =>
    Student(
      id: id,
      name: name,
      code: 'G$g-0$id',
      groupId: g,
      price: g == 1 ? 300 : 400,
      guardianPhone: phone,
      isArchived: archived,
      archivedAt: archived ? DateTime(2026, 10, 1) : null,
      siblingGroupId: sib,
      siblingsTotal: total,
      exemptPercent: exempt,
    );

final _active = [
  _s(1, 'إسراء محمد إبراهيم سعد', 1, phone: '01096693758', sib: 1, total: 500),
  _s(2, 'مصطفى عبد الرحمن عبد الله الشاذلي الطويل جدًا', 1, sib: 1, total: 500),
  _s(3, 'منى', 2, exempt: 100),
];
final _archived = [
  _s(8, 'آدم أحمد', 1, archived: true),
  _s(9, 'سلمى عمر الفاروق عبد العزيز', 2, archived: true),
];

class _Students extends StudentController {
  _Students({List<Student>? active, List<Student>? archived}) {
    final a = active ?? _active;
    students.assignAll(a);
    filteredStudents.assignAll(a);
    archivedStudents.assignAll(archived ?? _archived);
  }
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async {}
  @override
  Future<void> loadArchivedStudents() async {}
  @override
  Future<void> loadStudentsByGroup(int groupId) async {}
  @override
  Future<List<Group>> loadAllGroups() async => _groups;
  @override
  Future<String> generateNextStudentCode(
          {required String groupPrefix, required int groupId}) async =>
      '$groupPrefix-05';
}

class _Groups extends GroupController {
  _Groups() {
    groups.assignAll(_groups);
  }
  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async {}
}

class _Att extends AttendanceController {
  _Att() {
    final d = DateTime.now();
    attendance.addAll([
      Attendance(id: 1, studentId: 1, date: d, status: ATTENDANCE_PRESENT),
      Attendance(
          id: 2,
          studentId: 1,
          date: d.subtract(const Duration(days: 2)),
          status: ATTENDANCE_ABSENT),
      Attendance(
          id: 3,
          studentId: 1,
          date: d.subtract(const Duration(days: 4)),
          status: ATTENDANCE_LATE),
    ]);
  }
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

class _Hw extends HomeworkController {
  @override
  Future<void> loadHomework() async {}
}

class _SO extends SessionOverrideController {
  @override
  void onInit() {}
  @override
  Future<void> load() async {}
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

void _seed({List<Student>? active, List<Student>? archived}) {
  Get.reset();
  Get.put<SettingsController>(_Settings());
  Get.put<SessionOverrideController>(_SO());
  Get.put<AttendanceController>(_Att());
  Get.put<PaymentController>(_Pay());
  Get.put<HomeworkController>(_Hw());
  Get.put<GroupController>(_Groups());
  Get.put<StudentController>(_Students(active: active, archived: archived));
}

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t, Widget home,
    {required Size size,
    double scale = 1,
    bool dark = false,
    Object? args}) async {
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
    home: const Scaffold(body: SizedBox()),
  ));
  Get.to(() => home, arguments: args);
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

/// يفتح نافذة (showDialog) من زرار ويستنى ظهورها.
Future<void> _openDialog(
    WidgetTester t, Future<void> Function(BuildContext) open,
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
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
            child: ElevatedButton(
                onPressed: () => open(ctx), child: const Text('افتح'))),
      ),
    ),
  ));
  await t.tap(find.text('افتح'));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
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

  const sizes = [Size(320, 568), Size(360, 740), Size(411, 900)];

  for (final dark in [false, true]) {
    for (final size in sizes) {
      for (final scale in [1.0, 1.6]) {
        final tag =
            '${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}';

        testWidgets('تفاصيل المجموعة بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, const GroupDetailsPage(),
              size: size, scale: scale, dark: dark, args: _groups.first);
        });

        for (final edit in [false, true]) {
          testWidgets(
              'نموذج المجموعة ${edit ? "تعديل" : "إضافة"} بلا overflow $tag',
              (t) async {
            _seed();
            await _openDialog(
                t,
                (ctx) => showDialog(
                      context: ctx,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: GroupFormSheet(
                          group: edit ? _groups.first : null,
                          existingGroups: _groups,
                          onSave: (_) async => true,
                        ),
                      ),
                    ),
                size: size,
                scale: scale,
                dark: dark);
            // نضيف موعد جديد ونتأكد إن الصفوف الإضافية بلا overflow كمان.
            await t.ensureVisible(find.text('إضافة موعد'));
            await t.tap(find.text('إضافة موعد'));
            await t.pump(const Duration(milliseconds: 300));
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('تفاصيل المجموعة: السبورة والإحصائيات والأزرار والطلاب',
      (t) async {
    _seed();
    await _pump(t, const GroupDetailsPage(),
        size: const Size(360, 800), args: _groups.first);
    expect(find.text('تفاصيل المجموعة'), findsOneWidget);
    expect(find.text('أولى ثانوي — علوم'), findsWidgets);
    expect(find.text('حصص مسجلة'), findsOneWidget);
    expect(find.text('إجمالي الرسوم'), findsOneWidget);
    expect(find.text('تصدير PDF'), findsOneWidget);
    expect(find.text('إضافة طالب'), findsOneWidget);
    expect(find.text('إسراء محمد إبراهيم سعد'), findsOneWidget);
  });

  testWidgets('نموذج المجموعة: الأقسام والتحقق من الحقول', (t) async {
    _seed();
    await _openDialog(
        t,
        (ctx) => showDialog(
              context: ctx,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: GroupFormSheet(
                  group: null,
                  existingGroups: _groups,
                  onSave: (_) async => true,
                ),
              ),
            ),
        size: const Size(360, 800));
    expect(find.text('مجموعة جديدة'), findsOneWidget);
    expect(find.text('اسم المجموعة *'), findsOneWidget);
    expect(find.text('بادئة الكود *'), findsOneWidget);
    expect(find.text('مظهر المجموعة'), findsOneWidget);
    expect(find.text('المواعيد الأسبوعية'), findsOneWidget);
    await t.tap(find.text('إضافة المجموعة'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('مطلوب'), findsWidgets);
  });
}
