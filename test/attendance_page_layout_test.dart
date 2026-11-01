// ignore_for_file: must_call_super
// test/attendance_page_layout_test.dart — شكل شاشة سجل الحضور: بلا overflow على
// المقاسات الصغيرة والخط الكبير والوضعين، والأرقام صح، وقائمة خيارات السجل.
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
import 'package:active_class/views/attendance/attendance_page.dart';

class _Students extends StudentController {
  _Students(this.list);
  final List<Student> list;
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async {
    students.assignAll(list.where((s) => !s.isArchived));
    archivedStudents.assignAll(list.where((s) => s.isArchived));
  }
}

class _Groups extends GroupController {
  _Groups(this.list);
  final List<Group> list;
  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async => groups.assignAll(list);
}

class _Homework extends HomeworkController {
  @override
  Future<void> loadHomework() async {}
}

class _Attendance extends AttendanceController {
  @override
  void onInit() {}
  @override
  Future<void> loadAttendance() async {}
}

class _Payments extends PaymentController {
  @override
  void onInit() {}
  @override
  Future<void> loadPayments() async {}
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
  final day = _days[now.weekday]!;
  String sch(int from, int to) =>
      '$day ${from.toString().padLeft(2, '0')}:00-${to.toString().padLeft(2, '0')}:00';
  final groups = [
    Group(id: 1, name: 'أولى ثانوي — علوم', price: 300, schedule: sch(8, 10)),
    Group(id: 2, name: 'ثانية إعدادي', price: 250, schedule: sch(12, 13)),
    Group(
        id: 3,
        name: 'العواسجة — تانية ثانوي علمي رياضة',
        price: 400,
        schedule: sch(15, 17)),
  ];
  const names = ['عمر حسن', 'مريم خالد', 'يوسف أحمد', 'سلمى محمود', 'آدم علي'];
  final students = <Student>[];
  var id = 1;
  for (final g in groups) {
    for (var i = 0; i < 8; i++) {
      students.add(Student(
          id: id,
          name: '${names[(id + i) % names.length]} $id',
          code: 'c$id',
          groupId: g.id!,
          price: 0));
      id++;
    }
  }
  final today = DateTime(now.year, now.month, now.day);
  final att = _Attendance();
  const cycle = [
    ATTENDANCE_PRESENT,
    ATTENDANCE_PRESENT,
    ATTENDANCE_PRESENT,
    ATTENDANCE_LATE,
    ATTENDANCE_ABSENT,
  ];
  for (final s in students.where((s) => s.groupId == 1)) {
    att.attendance.add(Attendance(
        studentId: s.id!, date: today, status: cycle[s.id! % cycle.length]));
  }
  Get.put<SessionOverrideController>(_Overrides());
  Get.put<AttendanceController>(att);
  Get.put<StudentController>(_Students(students));
  Get.put<GroupController>(_Groups(groups));
  Get.put<HomeworkController>(_Homework());
  Get.put<SettingsController>(_Settings());
  Get.put<PaymentController>(_Payments());
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
    home: const AttendancePage(),
  ));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
}

/// بيفك الشجرة عشان مؤقت التحديث (30 ثانية) يتلغي والاختبار يخلص نضيف.
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 35));
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
        for (final tab in ['تسجيل', 'السجل', 'الإحصائيات', 'الغياب']) {
          testWidgets(
              'بلا overflow $tab ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            _seed();
            await _pump(t, size: size, scale: scale, dark: dark);
            if (tab != 'تسجيل') {
              await t.tap(find.text(tab));
              await t.pump(const Duration(milliseconds: 600));
              await t.pump(const Duration(milliseconds: 600));
            }
            expect(t.takeException(), isNull);
            await _finish(t);
          });
        }
      }
    }
  }

  testWidgets('4 تابات ثابتة باينة كلها وزرار QR في الشريط', (t) async {
    _seed();
    for (final w in [320.0, 360.0, 411.0]) {
      await _pump(t, size: Size(w, 740));
      for (final label in ['تسجيل', 'السجل', 'الإحصائيات', 'الغياب']) {
        final r = t.getRect(find.text(label));
        expect(r.left, greaterThanOrEqualTo(0), reason: '$label @$w');
        expect(r.right, lessThanOrEqualTo(w), reason: '$label @$w');
      }
      expect(find.text('QR Scan'), findsNothing);
      expect(find.byTooltip('تسجيل حضور بالـQR'), findsOneWidget);
      await _finish(t);
    }
  });

  testWidgets('التابات الأربعة موزعة بالتساوي', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 740));
    final tabs = find.byType(Tab);
    expect(tabs, findsNWidgets(4));
    // كل تاب نصه في نص خليته، فالمسافات بين المراكز لازم تتساوى.
    final xs = [
      for (final e in tabs.evaluate()) t.getCenter(find.byWidget(e.widget)).dx
    ]..sort();
    final gaps = [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]];
    for (final g in gaps) {
      expect(g, closeTo(gaps.first, 0.5));
    }
    await _finish(t);
  });

  testWidgets('كروت المجموعات والأرقام فوق السبورة', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    expect(find.text('أولى ثانوي — علوم'), findsOneWidget);
    expect(find.text('ثانية إعدادي'), findsOneWidget);
    expect(find.text('العواسجة — تانية ثانوي علمي رياضة'), findsOneWidget);
    // 8 طلاب في المجموعة الأولى: 3+3 حاضر (id%5 = 0,1,2 → 3 حاضر) .. بنقارن بالإجمالي بس.
    expect(find.text('24'), findsOneWidget); // الكل
    expect(find.text('16'), findsOneWidget); // لم يُسجَّل = مجموعتين بلا تسجيل
    expect(find.text('من 8'), findsNWidgets(3));
    expect(find.text('اليوم'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('اليوم التالي مقفول في اليوم الحالي والسابق شغال', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    final next = t.widget<IconButton>(find.widgetWithIcon(
        IconButton, Icons.chevron_left_rounded));
    expect(next.onPressed, isNull);
    final prev = t.widget<IconButton>(find.widgetWithIcon(
        IconButton, Icons.chevron_right_rounded));
    expect(prev.onPressed, isNotNull);
    await t.tap(find.byTooltip('اليوم السابق'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('اليوم'), findsNothing);
    expect(find.byTooltip('وصول سريع لليوم'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('قائمة خيارات السجل: تعديل التاريخ وحذف', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.tap(find.text('السجل'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('خيارات السجل'), findsWidgets);
    await t.tap(find.byTooltip('خيارات السجل').first);
    await t.pumpAndSettle();
    expect(find.text('تعديل التاريخ'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('فلتر الحالة بيقلّل السجلات', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.tap(find.text('السجل'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    final all = find.textContaining(' سجل');
    expect(all, findsOneWidget);
    final before = (t.widget<Text>(all).data!).split(' ').first;
    await t.tap(find.text('غائب').first);
    await t.pump(const Duration(milliseconds: 400));
    final after = (t.widget<Text>(find.textContaining(' سجل')).data!)
        .split(' ')
        .first;
    expect(int.parse(after), lessThan(int.parse(before)));
    await _finish(t);
  });

  testWidgets('تبويب الغياب: غايبين ومتأخرين وتحديد وإرسال', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.tap(find.text('الغياب'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('غياب اليوم (1)'), findsOneWidget);
    expect(find.text('متأخرون (2)'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    // مفيش أرقام أولياء أمور في البيانات: زرار واتساب مقفول وسببه مكتوب.
    expect(find.text('لا يوجد رقم ولي أمر'), findsNWidgets(3));
    await t.tap(find.byType(CheckboxListTile).first);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('إرسال واتساب للمحددين (1)'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _finish(t);
  });

  testWidgets('تبويب الإحصائيات: شرائح الفترة والأرقام', (t) async {
    _seed();
    await _pump(t, size: const Size(360, 900));
    await t.tap(find.text('الإحصائيات'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    for (final l in ['الكل', 'اليوم', 'هذا الأسبوع', 'هذا الشهر', 'نطاق']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    expect(find.text('نسبة الحضور'), findsOneWidget);
    expect(find.text('نسبة الحضور لكل طالب'), findsOneWidget);
    await t.tap(find.text('اليوم'));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    expect(find.text('حضور'), findsOneWidget);
    await _finish(t);
  });

  for (final dark in [false, true]) {
    for (final size in sizes) {
      for (final scale in [1.0, 1.6]) {
        for (final second in [false, true]) {
          testWidgets(
              'نافذة المجموعة ${second ? "الواجب" : "الحضور"} ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            _seed();
            await _pump(t, size: size, scale: scale, dark: dark);
            await t.tap(find.text('أولى ثانوي — علوم'));
            await t.pump(const Duration(milliseconds: 600));
            await t.pump(const Duration(milliseconds: 600));
            if (second) {
              await t.tap(find.text('واجب').first);
              await t.pump(const Duration(milliseconds: 600));
              await t.pump(const Duration(milliseconds: 600));
            }
            expect(t.takeException(), isNull);
            await _finish(t);
          });
        }
      }
    }
  }

  testWidgets('نافذة المجموعة: الأرقام وتسجيل الحالة والمسح', (t) async {
    _seed();
    await _pump(t, size: const Size(411, 900));
    await t.tap(find.text('أولى ثانوي — علوم'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('إغلاق'), findsOneWidget);
    expect(find.text('الكل'), findsWidgets);
    // أول صف في القائمة: ضغطة «حاضر» بتسجّل، والتانية على نفس الخانة بتمسح.
    final att = Get.find<AttendanceController>();
    final before = att.attendance.length;
    // أزرار الحالة أيقونات بـTooltip: آخر زرار «حاضر» في القايمة.
    final present = find.byTooltip('حاضر');
    expect(present, findsWidgets);
    await t.tap(present.last);
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(att.attendance.length, isNot(before - 1));
    await t.tap(find.byTooltip('إغلاق'));
    await t.pumpAndSettle();
    expect(find.byTooltip('إغلاق'), findsNothing);
    await _finish(t);
  });

  testWidgets('نافذة المجموعة: التابين والبحث', (t) async {
    _seed();
    await _pump(t, size: const Size(411, 900));
    await t.tap(find.text('أولى ثانوي — علوم'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('حضور'), findsWidgets);
    expect(find.text('واجب'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'لا يوجد اسم كده');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('لا يوجد طلاب مطابقين في هذه المجموعة'), findsWidgets);
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
    }
    // أرقام الحالات فوق السبورة بدرجات الوضع الداكن، في الوضعين.
    final on = AppTokens.dark;
    for (final b in [AppTokens.light.board, AppTokens.dark.board]) {
      for (final fg in [
        on.positive,
        on.danger,
        AppTokens.light.chalk,
        AppTokens.light.boardInkSoft,
      ]) {
        expect(ratio(fg, b), greaterThanOrEqualTo(4.5), reason: '$fg on $b');
      }
    }
  });
}
