// ignore_for_file: must_call_super
// test/attendance_guest_ui_test.dart — طالب ضيف في موديل تسجيل الحضور.
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
import 'package:active_class/utils/session_guest.dart';
import 'package:active_class/views/attendance/attendance_page.dart';

class FakeStudents extends StudentController {
  FakeStudents(this.list);
  final List<Student> list;
  @override
  void onInit() {}
  @override
  Future<void> loadAllStudents() async {
    students.assignAll(list.where((s) => !s.isArchived));
    archivedStudents.assignAll(list.where((s) => s.isArchived));
  }
}

class FakeGroups extends GroupController {
  FakeGroups(this.list);
  final List<Group> list;
  @override
  void onInit() {}
  @override
  Future<void> loadGroups() async => groups.assignAll(list);
}

class FakeHomework extends HomeworkController {
  @override
  Future<void> loadHomework() async {}
}

class FakeAttendance extends AttendanceController {
  @override
  void onInit() {}
  @override
  Future<void> loadAttendance() async {}
  @override
  Future<void> addGuest(int studentId, int groupId, DateTime day) async {
    attendance.add(Attendance(
        id: 900 + studentId,
        studentId: studentId,
        date: day,
        status: ATTENDANCE_PRESENT,
        notes: guestNote(groupId)));
  }

  @override
  Future<void> removeGuest(int studentId, int groupId, DateTime day) async {
    attendance.removeWhere(
        (a) => a.studentId == studentId && isGuestOfGroup(a, groupId));
  }
}

class FakePayments extends PaymentController {
  @override
  void onInit() {}
  @override
  Future<void> loadPayments() async {}
}

class FakeOverrides extends SessionOverrideController {
  @override
  void onInit() {}
  @override
  Future<void> load() async {}
}

class FakeSettings extends SettingsController {
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
  7: 'الأحد'
};

void seed() {
  Get.reset();
  final now = DateTime.now();
  final day = _days[now.weekday]!;
  final nowH = now.hour;
  String sch(int fromH, int toH) =>
      '$day ${fromH.toString().padLeft(2, '0')}:00-${toH.toString().padLeft(2, '0')}:00';
  final groups = [
    Group(
        id: 1,
        name: 'أولى ثانوي — علوم',
        price: 300,
        schedule: sch((nowH - 1).clamp(0, 22), (nowH + 1).clamp(1, 23))),
    Group(
        id: 2,
        name: 'ثانية إعدادي',
        price: 250,
        schedule: sch((nowH + 3).clamp(0, 22), (nowH + 4).clamp(1, 23))),
    Group(
        id: 3,
        name: 'العواسجة — تانية ثانوي علمي رياضة',
        price: 400,
        schedule: sch((nowH - 5).clamp(0, 22), (nowH - 4).clamp(1, 23))),
  ];
  final names = [
    'عمر حسن',
    'مريم خالد',
    'يوسف أحمد',
    'سلمى محمود',
    'آدم علي',
    'جنى ياسر',
    'كريم هشام',
    'نور الدين',
    'هبة سامي',
    'مصطفى عادل'
  ];
  final students = <Student>[];
  var id = 1;
  for (final g in groups) {
    for (var i = 0; i < 8; i++) {
      students.add(Student(
          id: id,
          name: names[(id + i) % names.length],
          code: 'c$id',
          groupId: g.id!,
          price: 0));
      id++;
    }
  }
  final today = DateTime(now.year, now.month, now.day);
  final att = FakeAttendance();
  String st(int k) => [
        ATTENDANCE_PRESENT,
        ATTENDANCE_PRESENT,
        ATTENDANCE_PRESENT,
        ATTENDANCE_LATE,
        ATTENDANCE_ABSENT
      ][k % 5];
  for (final s in students.where((s) => s.groupId == 1)) {
    att.attendance
        .add(Attendance(studentId: s.id!, date: today, status: st(s.id!)));
  }
  for (final s in students.where((s) => s.groupId == 3).take(4)) {
    att.attendance.add(
        Attendance(studentId: s.id!, date: today, status: ATTENDANCE_PRESENT));
  }
  att.attendance.add(Attendance(
      id: 999,
      studentId: 9,
      date: today,
      status: ATTENDANCE_PRESENT,
      notes: guestNote(1)));
  Get.put<SessionOverrideController>(FakeOverrides());
  Get.put<AttendanceController>(att);
  Get.put<StudentController>(FakeStudents(students));
  Get.put<GroupController>(FakeGroups(groups));
  Get.put<HomeworkController>(FakeHomework());
  Get.put<SettingsController>(FakeSettings());
  Get.put<PaymentController>(FakePayments());
}

ThemeData _cairo(ThemeData b) => b.copyWith(
    textTheme: b.textTheme
        .apply(fontFamily: 'Cairo', fontFamilyFallback: const ['SegoeEmoji']));

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

  Future<void> open(WidgetTester t, Size size, {double scale = 1}) async {
    seed();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.reset);
    await t.pumpWidget(GetMaterialApp(
      theme: _cairo(AppTheme.lightTheme),
      locale: const Locale('ar'),
      builder: (c, ch) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: ch!),
      ),
      home: const AttendancePage(),
    ));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('أولى ثانوي — علوم'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('الضيف بيظهر في قسم "ضيوف الحصة" بشارة المجموعة الأصلية',
      (t) async {
    await open(t, const Size(360, 900));
    await t.scrollUntilVisible(find.text('ضيوف الحصة'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('ضيوف الحصة'), findsOneWidget);
    expect(find.textContaining('ضيف من ثانية إعدادي'), findsOneWidget);
    expect(find.text('إزالة'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('إزالة الضيف تشيله من الحصة', (t) async {
    await open(t, const Size(360, 900));
    await t.scrollUntilVisible(find.text('إزالة'), 300,
        scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('إزالة'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('ضيوف الحصة'), findsNothing);
  });

  testWidgets('زر إضافة ضيف بيفتح قايمة الطلاب من المجموعات التانية',
      (t) async {
    await open(t, const Size(360, 900));
    await t.tap(find.text('إضافة ضيف'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('إضافة ضيف للحصة'), findsOneWidget);
    // الضيف الموجود أصلًا (طالب 9) ما يظهرش في الاختيار، وطلاب المجموعة نفسها كمان.
    expect(find.textContaining('ثانية إعدادي'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(360, 740)]) {
    testWidgets('موديل الحضور بضيف بلا overflow ${size.width.toInt()} ×1.6',
        (t) async {
      await open(t, size, scale: 1.6);
      expect(t.takeException(), isNull);
    });
  }
}
