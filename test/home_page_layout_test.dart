// ignore_for_file: must_call_super
// test/home_page_layout_test.dart — شكل الرئيسية: بلا overflow على المقاسات
// الصغيرة والخط الكبير والوضعين، والأقسام كلها ظاهرة، ووضع المساعد المقفول.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/at_risk_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/views/home_page.dart';

class _Dash extends DashboardController {
  @override
  void onInit() {}
  @override
  Future<void> loadDashboardData({bool silent = false}) async {}
}

class _Risk extends AtRiskController {
  @override
  void onInit() {}
  @override
  Future<void> refresh() async {}
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

class _License extends LicenseController {
  @override
  void onInit() {}
}

class _Theme extends ThemeController {
  @override
  void onInit() {}
}

void _seed() {
  Get.reset();
  final d = Get.put<DashboardController>(_Dash());
  final now = DateTime.now();
  d.totalGroups.value = 8;
  d.totalStudents.value = 186;
  d.exemptStudents.value = 4;
  d.paymentCardMonth.value = DateTime(now.year, now.month, 1);
  d.paymentCardMinMonth.value = DateTime(now.year, now.month - 2, 1);
  d.paymentCardExpected.value = 1234500;
  d.paymentCardCollected.value = 987600;
  d.paymentCardRate.value = 0.62;
  d.paymentCardUnpaid.value = 123;
  d.todayPresent.value = 141;
  d.todayAbsent.value = 19;
  d.todayExpected.value = 160;
  d.todayAttendanceRate.value = 0.82;
  d.todayPaymentsTotal.value = 123456;
  d.todayPaymentsCount.value = 17;
  d.todaySessionRevenue.value = 900;
  d.todaySessionRevenueCount.value = 6;
  d.todaySessionRevenueExpected.value = 1500;
  d.todaySessionRevenueExpectedCount.value = 10;
  d.recentActivities.assignAll([
    RecentActivity(
        type: ActivityType.attendance,
        title: 'عمر حسن',
        subtitle: 'حضر',
        date: now,
        icon: Icons.how_to_reg_rounded,
        color: AppTheme.successColor),
    RecentActivity(
        type: ActivityType.payment,
        title: 'يوسف أحمد',
        subtitle: '',
        date: now,
        icon: Icons.payments_rounded,
        color: AppTheme.primaryColor,
        amount: 250),
  ]);
  Get.put<AtRiskController>(_Risk()).count.value = 3;
  Get.put<SettingsController>(_Settings()).teacherFullName.value =
      'عبد الرحمن محمد سمير الشرقاوي';
  Get.put<LicenseController>(_License());
  Get.put<ThemeController>(_Theme());
}

Future<void> _pumpHome(WidgetTester t,
    {required Size size, double scale = 1, bool dark = false}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    builder: (c, ch) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(textDirection: TextDirection.rtl, child: ch!),
    ),
    home: const HomePage(),
  ));
  await t.pump(const Duration(milliseconds: 300));
}

/// بيفك الشجرة ويعدّي مؤقتات initState عشان الاختبار يخلص نضيف.
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 12));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // خط الاختبار الافتراضي حروفه مربعة وأعرض بكتير، فالقياسات بيه مش حقيقية.
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf')))
        .load();
  });

  tearDown(() {
    final team = TeamModeService();
    team.isEnabled.value = false;
    team.isOwner.value = false;
  });

  const sizes = [
    Size(320, 568),
    Size(360, 740),
    Size(411, 900),
    Size(1100, 800),
  ];
  for (final dark in [false, true]) {
    for (final size in sizes) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'بلا overflow ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
            (t) async {
          _seed();
          await _pumpHome(t, size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
          await _finish(t);
        });
      }
    }
  }

  testWidgets('الأقسام العشرة والإجراءات الثلاثة ظاهرة', (t) async {
    _seed();
    await _pumpHome(t, size: const Size(411, 3000));
    for (final label in [
      'تسجيل حضور',
      'تسجيل دفع',
      'إضافة طالب',
      'جدول الحصص',
      'الملازم',
      'التقارير',
      'مكتبة QR',
      'الامتحانات',
      'الحجوزات',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // بتتكرر في صف الأرقام وشبكة الأقسام.
    expect(find.text('المجموعات'), findsNWidgets(2));
    expect(find.text('الطلاب'), findsNWidgets(2));
    expect(find.text('حضور اليوم'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('اسم التطبيق على 360 مش مقطوع وعلى 320 مخفي', (t) async {
    _seed();
    await _pumpHome(t, size: const Size(360, 740));
    final name = find.text('Active Class');
    expect(name, findsOneWidget);
    expect(t.renderObject<RenderParagraph>(name).didExceedMaxLines, isFalse);
    await _finish(t);

    await _pumpHome(t, size: const Size(320, 568));
    expect(find.text('Active Class'), findsNothing);
    await _finish(t);
  });

  testWidgets('إخفاء الأرقام بيخفي المبالغ', (t) async {
    _seed();
    await _pumpHome(t, size: const Size(411, 3000));
    expect(find.text('186'), findsOneWidget);
    await t.tap(find.byTooltip('إخفاء الأرقام'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('186'), findsNothing);
    expect(find.textContaining('EGP'), findsNothing);
    await _finish(t);
  });

  testWidgets('المساعد من غير صلاحية مالية: المبالغ مخفية', (t) async {
    _seed();
    final team = TeamModeService();
    team.isEnabled.value = true;
    team.isOwner.value = false;
    team.canViewFinancials.value = false;
    await _pumpHome(t, size: const Size(360, 3000));
    expect(t.takeException(), isNull);
    expect(find.textContaining('EGP'), findsNothing);
    expect(find.text('آخر المدفوعات'), findsOneWidget);
    await t.tap(find.text('آخر المدفوعات'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('يوسف أحمد'), findsNothing);
    await _finish(t);
  });

  testWidgets('الأسماء مخفية وبتظهر في قائمة عند ضغط الزرار', (t) async {
    _seed();
    await _pumpHome(t, size: const Size(360, 3000));
    expect(find.text('عمر حسن'), findsNothing);
    expect(find.text('يوسف أحمد'), findsNothing);

    await t.tap(find.text('آخر الحضور'));
    await t.pumpAndSettle();
    expect(find.text('عمر حسن'), findsOneWidget);
    expect(find.text('يوسف أحمد'), findsNothing);
    expect(find.text('عرض الكل'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tapAt(const Offset(180, 10));
    await t.pumpAndSettle();
    await t.tap(find.text('آخر المدفوعات'));
    await t.pumpAndSettle();
    expect(find.text('يوسف أحمد'), findsOneWidget);
    expect(find.text('عمر حسن'), findsNothing);
    await _finish(t);
  });

  testWidgets('قسم الدفعات بيجمع الشهر ومدفوعات اليوم والإيراد', (t) async {
    _seed();
    await _pumpHome(t, size: const Size(360, 3000));
    double top(String text) => t.getTopLeft(find.text(text)).dy;
    expect(top('حضور اليوم'), lessThan(top('الدفعات')));
    expect(top('الدفعات'), lessThan(top('مدفوعات اليوم')));
    expect(top('مدفوعات اليوم'),
        lessThan(top('إيراد اليوم من المجموعات بالحصة')));
    expect(top('إيراد اليوم من المجموعات بالحصة'),
        lessThan(top('الأقسام الرئيسية')));
    await _finish(t);
  });

  testWidgets('زرار فاضي مش بيفتح قائمة', (t) async {
    _seed();
    Get.find<DashboardController>()
        .recentActivities
        .removeWhere((a) => a.type == ActivityType.payment);
    await _pumpHome(t, size: const Size(360, 3000));
    await t.tap(find.text('آخر المدفوعات'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('عرض الكل'), findsNothing);
    await _finish(t);
  });

  testWidgets('أزرار السبورة الثلاثة في صف واحد وبنفس العرض', (t) async {
    _seed();
    await _pumpHome(t, size: const Size(360, 740));
    final a = t.getRect(find.ancestor(
        of: find.text('تسجيل حضور'), matching: find.byType(InkWell)).first);
    final b = t.getRect(find.ancestor(
        of: find.text('تسجيل دفع'), matching: find.byType(InkWell)).first);
    final c = t.getRect(find.ancestor(
        of: find.text('إضافة طالب'), matching: find.byType(InkWell)).first);
    expect(a.top, b.top);
    expect(b.top, c.top);
    expect(a.width, closeTo(b.width, 0.5));
    expect(b.width, closeTo(c.width, 0.5));
    expect(a.height, greaterThanOrEqualTo(48));
    await _finish(t);
  });

  test('ألوان التوكنز بتعدّي تباين 4.5:1 للنص', () {
    double ratio(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final t in [AppTokens.light, AppTokens.dark]) {
      for (final fg in [
        t.ink,
        t.inkSoft,
        t.inkFaint,
        t.brand,
        t.positive,
        t.caution,
        t.danger,
      ]) {
        expect(ratio(fg, t.surface), greaterThanOrEqualTo(4.5), reason: '$fg');
      }
      expect(ratio(t.positive, t.positiveSoft), greaterThanOrEqualTo(4.5));
      // ألوان الأقسام: النصوص اللي بتترسم فوق كل خلفية.
      expect(ratio(t.rosterInk, t.rosterTint), greaterThanOrEqualTo(4.5));
      expect(ratio(t.rosterInk, t.surface), greaterThanOrEqualTo(4.5));
      expect(ratio(t.moneyInk, t.moneyTint), greaterThanOrEqualTo(4.5));
      expect(ratio(t.moneyInk, t.surface), greaterThanOrEqualTo(4.5));
      expect(ratio(t.ink, t.dangerSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.inkSoft, t.dangerSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.danger, t.dangerSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.boardInk, t.board), greaterThanOrEqualTo(4.5));
      expect(ratio(t.boardInkSoft, t.board), greaterThanOrEqualTo(4.5));
      expect(ratio(t.onChalk, t.chalk), greaterThanOrEqualTo(4.5));
    }
  });
}
