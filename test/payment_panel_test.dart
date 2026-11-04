// ignore_for_file: must_call_super
// test/payment_panel_test.dart — لوحة تسجيل الدفع (يدوي/QR) بتصميم السبورة:
// بلا overflow على المقاسات والخط الكبير والوضعين، واسم الطالب بيفتح تفاصيله.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/views/qr_scanner/qr_scanner_payment_page.dart';

class _FakeQr extends QRController {
  _FakeQr({this.perSession = false}) {
    upcomingMonths.assignAll([
      DateTime(2026, 11),
      DateTime(2026, 12),
      DateTime(2027, 1),
      DateTime(2027, 2),
    ]);
    selectedMonths.assignAll([DateTime(2026, 11)]);
    totalAmount.value = 450;
  }
  final bool perSession;
  @override
  void onInit() {}
  @override
  bool get isPerSessionGroup => perSession;
  @override
  double get scannedStudentDebt => selectedMonths.length >= 0 ? 450 : 0;
  @override
  int get scannedStudentDebtSessions => 3;
  @override
  bool get scannedStudentOverdue => true;
  @override
  String get lastPaidMonthText => 'أكتوبر 2026';
  @override
  // بيلمس Rx عشان Obx ما يشتكيش (في الحقيقي بيقرا من قيم Rx).
  bool get fullyPaidUp => selectedMonths.length < 0;
  @override
  int get unpaidSessionsCount => 3;
  @override
  int get effectiveSessionsSelected => 2;
  @override
  int get selectedSessionsCount => 2;
  @override
  List<DateTime> get unpaidSessionDates =>
      [DateTime(2026, 11, 1), DateTime(2026, 11, 3), DateTime(2026, 11, 5)];
}

final _student = Student(
  id: 7,
  name: 'آية محمد صلاح عبد المنعم الشاذلي الطويل جدًا',
  code: 'G1-07',
  groupId: 1,
  price: 450,
);

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t, QRController qr,
    {required Size size,
    double scale = 1,
    bool dark = false,
    Object? sink}) async {
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
      GetPage(
          name: ROUTE_STUDENT_DETAILS,
          page: () =>
              Scaffold(body: Text('DETAILS:${(Get.arguments as Student).id}'))),
    ],
    home: Scaffold(
      body: buildPaymentPanelForTest(
        student: _student,
        controller: qr,
        db: DatabaseService(),
      ),
    ),
  ));
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

  const sizes = [Size(320, 568), Size(360, 740), Size(411, 900)];
  for (final perSession in [false, true]) {
    for (final dark in [false, true]) {
      for (final size in sizes) {
        for (final scale in [1.0, 1.6]) {
          testWidgets(
              'لوحة الدفع ${perSession ? "بالحصة" : "شهري"} بلا overflow '
              '${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            await _pump(t, _FakeQr(perSession: perSession),
                size: size, scale: scale, dark: dark);
            expect(t.takeException(), isNull);
            expect(find.text('تأكيد الدفع  (1 شهر)'),
                perSession ? findsNothing : findsOneWidget);
          });
        }
      }
    }
  }

  testWidgets('الضغط على اسم الطالب يفتح صفحة تفاصيل الطالب', (t) async {
    await _pump(t, _FakeQr(), size: const Size(360, 740));
    await t.tap(find.text(_student.name));
    await t.pumpAndSettle();
    expect(find.text('DETAILS:7'), findsOneWidget);
  });

  testWidgets('شريط التأكيد ثابت ومعاه الإجمالي وزر تعديل', (t) async {
    await _pump(t, _FakeQr(), size: const Size(360, 740));
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('اختر الشهور'), findsOneWidget);
    expect(find.text('الأقدم فقط'), findsOneWidget);
  });
}
