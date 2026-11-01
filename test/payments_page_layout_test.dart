// ignore_for_file: must_call_super
// test/payments_page_layout_test.dart — شكل صفحة المدفوعات: بلا overflow على
// المقاسات الصغيرة والخط الكبير والوضعين، والفلاتر والتنقل بين الشهور وفتح السجل.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/payments/payments_page.dart';

class _Students extends StudentController {
  _Students(this.list);
  final List<Student> list;
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async => students.assignAll(list);
}

class _Groups extends GroupController {
  _Groups(this.list);
  final List<Group> list;
  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async => groups.assignAll(list);
}

class _Payments extends PaymentController {
  _Payments(this.list);
  final List<Payment> list;
  @override
  void onInit() {}
  @override
  Future<void> loadPayments() async => payments.assignAll(list);
}

class _Attendance extends AttendanceController {
  @override
  void onInit() {}
  @override
  Future<void> loadAttendance() async {}
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

void _seed() {
  Get.reset();
  final now = DateTime.now();
  final groups = [
    Group(id: 1, name: 'أولى ثانوي — علوم', price: 300),
    Group(id: 2, name: 'العواسجة — تانية ثانوي علمي رياضة', price: 250),
  ];
  const names = [
    'عمر حسن', 'مريم خالد', 'يوسف أحمد', 'سلمى محمود', 'آدم علي',
    'جنى ياسر', 'كريم هشام', 'نور الدين', 'هبة سامي', 'مصطفى عادل',
  ];
  final students = <Student>[];
  var id = 1;
  for (final g in groups) {
    for (var i = 0; i < 5; i++) {
      students.add(Student(
        id: id,
        name: names[(id - 1) % names.length],
        code: 'c$id',
        groupId: g.id!,
        price: g.price!,
        createdAt: DateTime(now.year, now.month - 2, 1),
        attendanceStart: DateTime(now.year, now.month - 2, 1),
      ));
      id++;
    }
  }
  final payments = <Payment>[];
  var pid = 1;
  for (final s in students) {
    final g = groups.firstWhere((g) => g.id == s.groupId);
    final full = g.price! * 3;
    final k = s.id! % 5;
    final amount = k == 1 || k == 0
        ? full
        : (k == 2 ? full * 0.5 : (k == 4 ? full * 0.2 : 0.0));
    if (amount > 0) {
      payments.add(Payment(
          id: pid++,
          studentId: s.id!,
          date: DateTime(now.year, now.month, 1),
          amount: amount));
    }
  }
  Get.put<SettingsController>(_Settings());
  Get.put<AttendanceController>(_Attendance());
  Get.put<StudentController>(_Students(students));
  Get.put<GroupController>(_Groups(groups));
  Get.put<PaymentController>(_Payments(payments));
}

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t,
    {required Size size, double scale = 1, bool dark = false}) async {
  _seed();
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
    home: const PaymentsPage(),
  ));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
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
        testWidgets(
            'بلا overflow ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
            (t) async {
          await _pump(t, size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
          await _finish(t);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    for (final size in sizes) {
      for (final scale in [1.0, 1.6]) {
        for (final sheet in ['history', 'add']) {
          testWidgets(
              'نافذة ${sheet == "add" ? "تسجيل الدفعة" : "السجل"} بلا overflow ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            await _pump(t, size: size, scale: scale, dark: dark);
            if (sheet == 'add') {
              await t.tap(find.byTooltip('تسجيل دفعة').first);
            } else {
              // أول صف مبني (القايمة lazy: على الشاشة الصغيرة مش كل الأسماء بتتبني).
              await t.tap(find.byTooltip('سجل الدفعات').first);
            }
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await _finish(t);
          });
        }
      }
    }
  }

  testWidgets('السبورة: الشهر والمحصّل وأعداد الحالات', (t) async {
    await _pump(t, size: const Size(360, 780));
    final now = DateTime.now();
    expect(find.text(DateFormat('MMMM yyyy', 'ar').format(DateTime(now.year, now.month, 1))),
        findsOneWidget);
    expect(find.text('محصّل الشهر'), findsOneWidget);
    for (final l in ['مدفوع', 'جزئي', 'متأخر', 'الكل']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    // 10 طلاب في النطاق.
    expect(find.text('10'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('شرائح الحالة كلها جوه الشاشة من غير سحب', (t) async {
    await _pump(t, size: const Size(320, 740));
    for (final l in ['الكل', 'متأخر', 'جزئي', 'مدفوع', 'مُعفى']) {
      final f = find.text(l).first;
      final r = t.getRect(f);
      expect(r.left, greaterThanOrEqualTo(0), reason: l);
      expect(r.right, lessThanOrEqualTo(320), reason: l);
    }
    await _finish(t);
  });

  testWidgets('شرائح الحالة الخمسة في سطر واحد على 360', (t) async {
    await _pump(t, size: const Size(360, 780));
    final tops = {
      for (final l in ['متأخر', 'جزئي', 'مُعفى'])
        // الشريحة بس (InkWell)، مش نفس الكلمة في أرقام السبورة.
        l: t.getTopLeft(find.widgetWithText(InkWell, l).first).dy
    };
    expect(tops.values.toSet().length, 1, reason: '$tops');
    await _finish(t);
  });

  testWidgets('فلتر الحالة بيصفّي القايمة', (t) async {
    await _pump(t, size: const Size(411, 3000));
    final before = find.byTooltip('تسجيل دفعة').evaluate().length;
    expect(before, greaterThan(0));
    final c = Get.find<PaymentController>();
    c.setStatusFilter('متأخر');
    await t.pump(const Duration(milliseconds: 400));
    final after = find.byTooltip('تسجيل دفعة').evaluate().length;
    expect(after, lessThan(before));
    expect(after, greaterThan(0));
    await _finish(t);
  });

  testWidgets('التنقل بين الشهور بيغيّر العنوان', (t) async {
    await _pump(t, size: const Size(360, 780));
    final now = DateTime.now();
    final fmt = DateFormat('MMMM yyyy', 'ar');
    final cur = fmt.format(DateTime(now.year, now.month, 1));
    final prev = fmt.format(DateTime(now.year, now.month - 1, 1));
    expect(find.text(cur), findsOneWidget);
    await t.tap(find.byTooltip('الشهر السابق'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(prev), findsOneWidget);
    expect(find.text(cur), findsNothing);
    await _finish(t);
  });

  testWidgets('الضغط على صف الطالب بيفتح سجل دفعاته', (t) async {
    await _pump(t, size: const Size(411, 900));
    final firstName = find.text('جنى ياسر').first;
    await t.tap(firstName);
    await t.pumpAndSettle();
    expect(find.text('دفعات جنى ياسر'), findsOneWidget);
    expect(find.text('إجمالي الشهر'), findsOneWidget);
    expect(find.byTooltip('إغلاق'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('نافذة تسجيل الدفعة: العنوان والمتبقي والحقول والحفظ', (t) async {
    await _pump(t, size: const Size(411, 900));
    // التالت في الترتيب عليه متبقي (جزئي).
    await t.tap(find.byTooltip('تسجيل دفعة').at(2));
    await t.pumpAndSettle();
    expect(find.text('تسجيل دفعة'), findsWidgets);
    expect(find.text('تسجيل الدفعة'), findsOneWidget);
    expect(find.text('المبلغ *'), findsOneWidget);
    expect(find.textContaining('متبقي عليه'), findsOneWidget);
    await t.tap(find.byTooltip('إغلاق'));
    await t.pumpAndSettle();
    expect(find.text('تسجيل الدفعة'), findsNothing);
    await _finish(t);
  });

  testWidgets('زرار التسجيل العائم بلون الطباشير', (t) async {
    await _pump(t, size: const Size(360, 780));
    final fab = t.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab.backgroundColor, AppTokens.light.chalk);
    await _finish(t);
  });

  test('ألوان الحالات على خلفياتها بتعدّي تباين 4.5:1', () {
    double ratio(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final t in [AppTokens.light, AppTokens.dark]) {
      expect(ratio(t.positive, t.positiveSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.caution, t.cautionSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.danger, t.dangerSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.inkSoft, t.line), greaterThanOrEqualTo(4.5));
    }
  });
}
