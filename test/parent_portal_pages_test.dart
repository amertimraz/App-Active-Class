// ignore_for_file: must_call_super
// test/parent_portal_pages_test.dart — قسم "بوابة أولياء الأمور" في تطبيق المدرس:
// الصفحة الرئيسية وصفحة الطلاب. بلا overflow على المقاسات الصغيرة والخط الكبير
// والوضعين، وحالات الإضافة (شغّالة/مقفولة/منتهية)، وسلوك الأزرار.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/parent_portal_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/parent_portal/parent_portal_page.dart';
import 'package:active_class/views/parent_portal/parent_portal_students_page.dart';

class _License extends LicenseController {
  @override
  void onInit() {}
}

class _Portal extends ParentPortalController {
  _Portal() {
    // onInit متعطّل في الاختبار، فنحمّل الرابط مباشرة.
    slug.value = 'abc123';
    loading.value = false;
  }

  int publishCalls = 0;
  @override
  void onInit() {}
  @override
  Future<void> load() async {
    slug.value = 'abc123';
    loading.value = false;
  }

  @override
  Future<int> publishAll() async {
    publishCalls++;
    lastPublishedAt.value = DateTime(2026, 11, 1, 14, 30);
    lastPublishedCount.value = 3;
    return 3;
  }
}

class _Settings extends SettingsController {
  @override
  void onInit() {}
  @override
  Future<bool> setPortalCodeOnly(bool v) async {
    portalCodeOnly.value = v;
    return true;
  }
}

class _Students extends StudentController {
  _Students(this.list) {
    students.assignAll(list);
  }
  final List<Student> list;
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async => students.assignAll(list);
}

class _Groups extends GroupController {
  _Groups() {
    groups.assignAll([Group(id: 1, name: 'أولى ثانوي — علوم', price: 300)]);
  }

  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async =>
      groups.assignAll([Group(id: 1, name: 'أولى ثانوي — علوم', price: 300)]);
}

enum _Lic { active, off, expired, expiringSoon }

late _Portal _portal;

Student _st(int id, String name, {String? phone, String code = ''}) => Student(
    id: id,
    name: name,
    code: code.isEmpty ? 'c$id' : code,
    groupId: 1,
    price: 0,
    guardianPhone: phone);

void _seed(_Lic lic) {
  Get.reset();
  final l = _License();
  final now = DateTime.now();
  switch (lic) {
    case _Lic.active:
      l.parentPortalEnabled.value = true;
      l.parentPortalExpiresAt.value = now.add(const Duration(days: 90));
    case _Lic.expiringSoon:
      l.parentPortalEnabled.value = true;
      l.parentPortalExpiresAt.value = now.add(const Duration(days: 3));
    case _Lic.expired:
      l.parentPortalEnabled.value = false;
      l.parentPortalExpiresAt.value = now.subtract(const Duration(days: 5));
    case _Lic.off:
      l.parentPortalEnabled.value = false;
  }
  Get.put<LicenseController>(l);
  _portal = _Portal();
  Get.put<ParentPortalController>(_portal);
  Get.put<SettingsController>(_Settings());
  Get.put<GroupController>(_Groups());
  Get.put<StudentController>(_Students([
    _st(1, 'عمر حسن', phone: '01012345678'),
    _st(2, 'مريم خالد', phone: '01099998888'),
    _st(3, 'يوسف أحمد', phone: '01077776666'),
    _st(4, 'سلمى محمود'),
    _st(5, 'آدم علي', phone: '12'),
    Student(
        id: 6,
        name: 'جنى ياسر',
        code: '',
        groupId: 1,
        price: 0,
        guardianPhone: '01055554444'),
  ]));
}

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t, Widget home,
    {required Size size,
    _Lic lic = _Lic.active,
    double scale = 1,
    bool dark = false}) async {
  _seed(lic);
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
      GetPage(name: '/home', page: () => home),
      GetPage(
          name: ROUTE_PARENT_PORTAL_STUDENTS,
          page: () => const ParentPortalStudentsPage()),
    ],
    initialRoute: '/home',
  ));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
        for (final lic in _Lic.values) {
          testWidgets(
              'الرئيسية بلا overflow ${lic.name} ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            await _pump(t, const ParentPortalPage(),
                size: size, lic: lic, scale: scale, dark: dark);
            expect(t.takeException(), isNull);
          });
        }
        testWidgets(
            'الطلاب بلا overflow ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
            (t) async {
          await _pump(t, const ParentPortalStudentsPage(),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('الإضافة شغّالة: الرابط والأقسام والأعداد', (t) async {
    await _pump(t, const ParentPortalPage(), size: const Size(411, 1400));
    expect(find.text('رابط المتابعة'), findsOneWidget);
    expect(find.text('https://active-class.online/track/abc123'),
        findsOneWidget);
    expect(find.text('طلاب البوابة'), findsOneWidget);
    expect(find.text('نشر البيانات'), findsOneWidget);
    expect(find.text('الدخول بالكود فقط'), findsOneWidget);
    // 6 طلاب: 3 ظاهرين (عندهم رقم صالح)، 3 لأ (بلا رقم، رقم قصير، بلا كود).
    expect(find.text('3'), findsWidgets);
    expect(find.text('3 ظاهر'), findsOneWidget);
    expect(find.text('3 مش ظاهرين'), findsOneWidget);
    expect(find.text('بوابة أولياء الأمور مقفولة'), findsNothing);
  });

  testWidgets('الدخول بالكود فقط: كل الطلاب اللي ليهم كود يبقوا ظاهرين',
      (t) async {
    await _pump(t, const ParentPortalPage(), size: const Size(411, 1400));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.text('متأكد؟', findRichText: true), findsNothing);
    expect(find.text('تفعيل'), findsOneWidget);
    await t.tap(find.text('تفعيل'));
    await t.pumpAndSettle();
    expect(Get.find<SettingsController>().portalCodeOnly.value, isTrue);
    // بلا كود واحد بس هو اللي فاضل مش ظاهر.
    expect(find.text('5 ظاهر'), findsOneWidget);
    expect(find.text('1 مش ظاهرين'), findsOneWidget);
  });

  testWidgets('إلغاء تأكيد الدخول بالكود فقط ما بيغيّرش الإعداد', (t) async {
    await _pump(t, const ParentPortalPage(), size: const Size(411, 1400));
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(Get.find<SettingsController>().portalCodeOnly.value, isFalse);
  });

  testWidgets('انشر الآن بينادي النشر ويعرض آخر نشر', (t) async {
    await _pump(t, const ParentPortalPage(), size: const Size(411, 1400));
    expect(find.text('لسه ما نشرتش من الشاشة دي'), findsOneWidget);
    await t.tap(find.text('انشر الآن'));
    await t.pumpAndSettle();
    expect(_portal.publishCalls, 1);
    expect(find.textContaining('آخر نشر'), findsOneWidget);
    expect(find.text('لسه ما نشرتش من الشاشة دي'), findsNothing);
  });

  testWidgets('QR: الزرار بيفتح نافذة بالكود والرابط', (t) async {
    await _pump(t, const ParentPortalPage(), size: const Size(411, 1400));
    await t.tap(find.text('QR'));
    await t.pumpAndSettle();
    expect(find.text('امسح الكود لفتح صفحة المتابعة'), findsOneWidget);
    expect(find.text('https://active-class.online/track/abc123'),
        findsWidgets);
    await t.tap(find.text('تمام'));
    await t.pumpAndSettle();
    expect(find.text('امسح الكود لفتح صفحة المتابعة'), findsNothing);
  });

  testWidgets('الإضافة غير مفعّلة: شاشة القفل بدل الأقسام', (t) async {
    await _pump(t, const ParentPortalPage(),
        size: const Size(411, 900), lic: _Lic.off);
    expect(find.text('بوابة أولياء الأمور مقفولة'), findsOneWidget);
    expect(find.text('الإضافة غير مفعّلة'), findsOneWidget);
    expect(find.text('فعّلها عن طريق واتساب'), findsOneWidget);
    expect(find.text('رابط المتابعة'), findsNothing);
    expect(find.text('نشر البيانات'), findsNothing);
  });

  testWidgets('الإضافة منتهية: رسالة التجديد وزرار الشراء', (t) async {
    await _pump(t, const ParentPortalPage(),
        size: const Size(411, 900), lic: _Lic.expired);
    expect(find.text('بوابة أولياء الأمور مقفولة'), findsOneWidget);
    expect(find.textContaining('انتهت الإضافة في'), findsOneWidget);
    expect(find.text('جدّد عن طريق واتساب'), findsOneWidget);
    expect(find.text('رابط المتابعة'), findsNothing);
  });

  testWidgets('قربت تنتهي: تنبيه الأيام وزرار جدّد مع بقاء الأقسام', (t) async {
    await _pump(t, const ParentPortalPage(),
        size: const Size(411, 1400), lic: _Lic.expiringSoon);
    expect(find.textContaining('بتنتهي بعد'), findsOneWidget);
    expect(find.text('جدّد'), findsOneWidget);
    expect(find.text('رابط المتابعة'), findsOneWidget);
  });

  testWidgets('طلاب البوابة بتفتح صفحة الطلاب', (t) async {
    await _pump(t, const ParentPortalPage(), size: const Size(411, 1400));
    await t.tap(find.text('طلاب البوابة'));
    await t.pumpAndSettle();
    expect(find.text('طلاب البوابة'), findsOneWidget);
    expect(find.text('عمر حسن'), findsOneWidget);
    expect(find.text('جنى ياسر'), findsOneWidget);
  });

  testWidgets('صفحة الطلاب: التصفية والحالات وزرار إضافة الرقم', (t) async {
    await _pump(t, const ParentPortalStudentsPage(),
        size: const Size(411, 1400));
    expect(find.text('الكل (6)'), findsOneWidget);
    expect(find.text('ظاهر (3)'), findsOneWidget);
    expect(find.text('مش ظاهر (3)'), findsOneWidget);
    expect(find.text('بلا رقم ولي أمر'), findsNWidgets(2));
    expect(find.text('بلا كود'), findsOneWidget);
    await t.tap(find.text('مش ظاهر (3)'));
    await t.pumpAndSettle();
    expect(find.text('عمر حسن'), findsNothing);
    expect(find.text('سلمى محمود'), findsOneWidget);
    expect(find.text('أضف رقم'), findsNWidgets(2));
    await t.tap(find.text('ظاهر (3)'));
    await t.pumpAndSettle();
    expect(find.text('عمر حسن'), findsOneWidget);
    expect(find.text('سلمى محمود'), findsNothing);
    expect(find.byTooltip('ابعت الرابط والكود لولي الأمر'), findsNWidgets(3));
  });

  testWidgets('صفحة الطلاب: البحث بالاسم وبالكود', (t) async {
    await _pump(t, const ParentPortalStudentsPage(),
        size: const Size(411, 1400));
    await t.enterText(find.byType(TextField).first, 'مريم');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('مريم خالد'), findsOneWidget);
    expect(find.text('عمر حسن'), findsNothing);
    await t.enterText(find.byType(TextField).first, 'c3');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('يوسف أحمد'), findsOneWidget);
    expect(find.text('مريم خالد'), findsNothing);
  });

  testWidgets('صفحة الطلاب: التحديد والإرسال الجماعي بيعدّ المحدّدين',
      (t) async {
    await _pump(t, const ParentPortalStudentsPage(),
        size: const Size(411, 1400));
    expect(find.text('ابعت الرابط والكود (0)'), findsOneWidget);
    await t.tap(find.text('تحديد الكل'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ابعت الرابط والكود (3)'), findsOneWidget);
    expect(find.text('إلغاء التحديد'), findsOneWidget);
    await t.tap(find.text('إلغاء التحديد'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ابعت الرابط والكود (0)'), findsOneWidget);
  });

  testWidgets('طالب ظاهر لكن بلا وسيلة تواصل ما بيتحدّدش للإرسال', (t) async {
    await _pump(t, const ParentPortalStudentsPage(),
        size: const Size(411, 1400));
    // بالكود فقط: سلمى ظاهرة بلا رقم، فمفيش تحديد ليها.
    await Get.find<SettingsController>().setPortalCodeOnly(true);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ظاهر (5)'), findsOneWidget);
    // 3 بس ليهم رقم صالح ومحدّدين (آدم رقمه '12' موجود كوسيلة تواصل).
    await t.tap(find.text('تحديد الكل'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ابعت الرابط والكود (4)'), findsOneWidget);
  });
}
