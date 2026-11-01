// ignore_for_file: must_call_super
// test/session_detail_layout_test.dart — شكل صفحة تفاصيل الحصة: بلا overflow على
// المقاسات الصغيرة والخط الكبير والوضعين، في الحالات: عادي، غايبين، يوم قادم،
// حصة ملغاة وتعويضية.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/session_override_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/session_override_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/attendance/session_detail_page.dart';

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

class _Attendance extends AttendanceController {
  @override
  void onInit() {}
  @override
  Future<void> loadAttendance() async {}
  @override
  Future<void> setAttendanceStatus(
      int studentId, DateTime day, String? status) async {
    attendance.removeWhere((a) =>
        a.studentId == studentId &&
        a.date.year == day.year &&
        a.date.month == day.month &&
        a.date.day == day.day);
    if (status != null) {
      attendance.add(Attendance(studentId: studentId, date: day, status: status));
    }
  }
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

final _group = Group(id: 1, name: 'العواسجة — تانية ثانوي علمي رياضة', price: 100);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

enum _State { normal, absent, future, cancelled, makeup }

ThemeData _cairo(ThemeData b) =>
    b.copyWith(textTheme: b.textTheme.apply(fontFamily: 'Cairo'));

Future<void> _pump(WidgetTester t,
    {required Size size,
    required _State state,
    double scale = 1,
    bool dark = false}) async {
  Get.reset();
  final d = state == _State.future
      ? _today().add(const Duration(days: 3))
      : _today();
  const names = ['عمر حسن', 'مريم خالد', 'يوسف أحمد', 'سلمى محمود', 'آدم علي'];
  final students = [
    for (var i = 1; i <= 12; i++)
      Student(
        id: i,
        name: '${names[i % names.length]} $i',
        code: 'c$i',
        groupId: 1,
        price: 0,
        guardianPhone: i.isEven ? '0100000000$i' : null,
      ),
  ];
  const cycle = [
    ATTENDANCE_PRESENT,
    ATTENDANCE_LATE,
    ATTENDANCE_ABSENT,
    ATTENDANCE_PRESENT,
  ];
  final att = _Attendance();
  for (final s in students.take(10)) {
    att.attendance.add(Attendance(
        studentId: s.id!, date: d, status: cycle[s.id! % cycle.length]));
  }
  final ov = _Overrides();
  if (state == _State.cancelled || state == _State.makeup) {
    ov.overrides.add(SessionOverride(
      groupId: 1,
      date: d,
      type: state == _State.cancelled
          ? SessionOverrideType.cancelled
          : SessionOverrideType.makeup,
    ));
  }
  Get.put<SessionOverrideController>(ov);
  Get.put<AttendanceController>(att);
  Get.put<StudentController>(_Students(students));
  Get.put<SettingsController>(_Settings());

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
    home: SessionDetailPage(group: _group, day: d),
  ));
  await t.pumpAndSettle();
  if (state == _State.absent) {
    await t.tap(find.textContaining('غائب ('));
    await t.pumpAndSettle();
  }
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
        for (final state in _State.values) {
          testWidgets(
              'بلا overflow ${state.name} ${size.width.toInt()}x${size.height.toInt()} ×$scale ${dark ? "dark" : "light"}',
              (t) async {
            await _pump(t, size: size, state: state, scale: scale, dark: dark);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('السبورة: الأرقام والتصفية وأزرار الأسفل باينة', (t) async {
    await _pump(t, size: const Size(360, 740), state: _State.normal);
    for (final l in ['حاضر', 'متأخر', 'غائب', 'لم يُسجَّل']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    for (final l in ['الكل (12)', 'لم يُسجَّل (2)']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    expect(find.text('تحضير غير المسجَّلين (2)'), findsOneWidget);
    expect(find.text('الورقة الكاملة'), findsOneWidget);
  });

  testWidgets('شرائح التصفية كلها جوه الشاشة (من غير سحب)', (t) async {
    await _pump(t, size: const Size(320, 740), state: _State.normal);
    final chips = find.textContaining(RegExp(r'\(\d+\)$'));
    expect(chips, findsWidgets);
    for (final e in chips.evaluate()) {
      final r = t.getRect(find.byWidget(e.widget));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
    }
  });

  testWidgets('حصة ملغاة: بانر وبدون قائمة طلاب ولا أزرار تسجيل', (t) async {
    await _pump(t, size: const Size(360, 740), state: _State.cancelled);
    expect(find.text('الحصة دي ملغاة — مفيش حضور ليها'), findsOneWidget);
    expect(find.text('ملغاة'), findsOneWidget);
    expect(find.textContaining('تحضير غير المسجَّلين'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('حصة تعويضية: الوسم ظاهر ويفضل التسجيل شغال', (t) async {
    await _pump(t, size: const Size(360, 740), state: _State.makeup);
    expect(find.text('تعويضية'), findsOneWidget);
    expect(find.textContaining('تحضير غير المسجَّلين'), findsOneWidget);
  });

  testWidgets('تصفية الغايبين بتظهر الاختيار وزرار واتساب', (t) async {
    await _pump(t, size: const Size(360, 740), state: _State.absent);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('تحديد الكل'), findsOneWidget);
    expect(find.text('واتساب للغايبين (0)'), findsOneWidget);
    await t.tap(find.text('تحديد الكل'));
    await t.pumpAndSettle();
    expect(find.text('واتساب للغايبين (0)'), findsNothing);
    expect(find.textContaining('واتساب للغايبين ('), findsOneWidget);
  });

  test('ألوان وسم الحصة وبانراتها على خلفياتها بتعدّي 4.5:1', () {
    double ratio(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final t in [AppTokens.light, AppTokens.dark]) {
      expect(ratio(t.danger, t.dangerSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.positive, t.positiveSoft), greaterThanOrEqualTo(4.5));
      expect(ratio(t.inkSoft, t.line), greaterThanOrEqualTo(4.5));
    }
  });
}
