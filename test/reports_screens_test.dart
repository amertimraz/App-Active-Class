// ignore_for_file: must_call_super
// test/reports_screens_test.dart — شاشات التقارير بتصميم السبورة والطباشير:
// الرئيسية، تقرير المدفوعات (شهري/يومي)، وتفصيل الحصص.
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
import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/views/reports/payments_report_page.dart';
import 'package:active_class/views/reports/reports_page.dart';
import 'package:active_class/views/reports/session_breakdown_page.dart';

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

class _Report extends ReportController {
  @override
  void onInit() {}
  @override
  Future<void> loadReports() async {}
  @override
  List<GroupMonthSummary> get groupSummaries => [
        GroupMonthSummary(
            group: _groups[0],
            studentCount: 2,
            expectedIncome: 600,
            collectedIncome: 300,
            fullyPaidCount: 1,
            totalPresentSessions: 14,
            totalHomeworkDone: 9,
            totalHomeworkNotDone: 3),
        GroupMonthSummary(
            group: _groups[1],
            studentCount: 1,
            expectedIncome: 0,
            collectedIncome: 0,
            fullyPaidCount: 0,
            totalPresentSessions: 0),
      ];
  @override
  List<AtRiskStudent> get unpaidStudents => [
        AtRiskStudent(
            student: _active[0],
            group: _groups[0],
            paid: 100,
            due: 300,
            month: DateTime(2026, 10)),
        AtRiskStudent(
            student: _active[1],
            group: _groups[0],
            paid: 0,
            due: 300,
            month: DateTime(2026, 10)),
      ];
  @override
  List<SessionDay> sessionBreakdownForGroup(int groupId) {
    allStudents.length; // يلمس Rx عشان Obx ما يشتكيش
    return [
      SessionDay(
          date: DateTime(2026, 10, 3), presentCount: 8, expectedAmount: 400),
      SessionDay(
          date: DateTime(2026, 10, 10), presentCount: 7, expectedAmount: 350),
    ];
  }

  @override
  double get monthTotalCollected => 300;
  @override
  int get monthPresentCount => 14;
  @override
  int get monthAbsentCount => 3;
}

class _PayWithData extends PaymentController {
  _PayWithData() {
    payments.addAll([
      Payment(id: 1, studentId: 1, amount: 100, date: DateTime.now()),
      Payment(id: 2, studentId: 2, amount: 300, date: DateTime.now()),
    ]);
  }
  @override
  void onInit() {}
  @override
  Future<void> loadPayments() async {}
}

void _seed({List<Student>? active, List<Student>? archived}) {
  Get.reset();
  Get.put<ReportController>(_Report());
  Get.put<SettingsController>(_Settings());
  Get.put<SessionOverrideController>(_SO());
  Get.put<AttendanceController>(_Att());
  Get.put<PaymentController>(_PayWithData());
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

        testWidgets('التقارير بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, const ReportsPage(),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });

        testWidgets('تقرير المدفوعات بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, const PaymentsReportPage(),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
          await t.tap(find.text('تقرير يومي'));
          await t.pump(const Duration(milliseconds: 500));
          await t.pump(const Duration(milliseconds: 500));
          expect(t.takeException(), isNull);
        });

        testWidgets('تفصيل الحصص بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, SessionBreakdownPage(group: _groups[1]),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('التقارير: السبورة والأرقام وكروت المجموعات', (t) async {
    _seed();
    await _pump(t, const ReportsPage(), size: const Size(360, 800));
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('اضغط لتغيير الشهر'), findsOneWidget);
    expect(find.text('حضور الشهر'), findsOneWidget);
    expect(find.text('غياب الشهر'), findsOneWidget);
    expect(find.text('المحصّلات الشهرية'), findsOneWidget);
    expect(find.text('نسبة التحصيل'), findsOneWidget);
    expect(find.text(_groups[0].name), findsWidgets);
    expect(find.text('2 طالب لم يسدد بالكامل'), findsOneWidget);
  });

  testWidgets('تقرير المدفوعات: التابان والملخص', (t) async {
    _seed();
    await _pump(t, const PaymentsReportPage(), size: const Size(360, 800));
    expect(find.text('تقرير المدفوعات'), findsOneWidget);
    expect(find.text('تقرير شهري'), findsOneWidget);
    expect(find.text('تقرير يومي'), findsOneWidget);
    await t.tap(find.text('تقرير يومي'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('مدفوعات اليوم'), findsOneWidget);
  });

  testWidgets('تفصيل الحصص: الإجمالي وصفوف التواريخ', (t) async {
    _seed();
    await _pump(t, SessionBreakdownPage(group: _groups[1]),
        size: const Size(360, 800));
    expect(find.text('إجمالي المتوقع'), findsOneWidget);
    expect(find.textContaining('حاضر'), findsNWidgets(2));
  });
}
