// ignore_for_file: must_call_super
// test/students_screens_test.dart — شاشات الطالب بتصميم السبورة والطباشير:
// تفاصيل الطالب، الأرشيف، الإخوة، ونافذتا إضافة وتعديل الطالب.
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
import 'package:active_class/views/students/archived_students_page.dart';
import 'package:active_class/views/students/siblings_page.dart';
import 'package:active_class/views/students/student_details_page.dart';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/edit_student_sheet.dart';

final _groups = [
  Group(id: 1, name: 'أولى ثانوي — علوم', code: 'G1', price: 300, color: 0xFF4F46E5),
  Group(id: 2, name: 'العواسجة — تانية ثانوي علمي رياضة', code: 'G2', price: 400, color: 0xFF10B981),
];

Student _s(int id, String name, int g, {bool archived = false, int? sib, double? total, String? phone, double exempt = 0}) =>
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
      Attendance(studentId: 1, date: d, status: ATTENDANCE_PRESENT),
      Attendance(studentId: 1, date: d.subtract(const Duration(days: 2)), status: ATTENDANCE_ABSENT),
      Attendance(studentId: 1, date: d.subtract(const Duration(days: 4)), status: ATTENDANCE_LATE),
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
    {required Size size, double scale = 1, bool dark = false, Object? args}) async {
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
Future<void> _openDialog(WidgetTester t, Future<void> Function(BuildContext) open,
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

        testWidgets('الأرشيف بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, const ArchivedStudentsPage(),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });

        testWidgets('الإخوة بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, const SiblingsPage(),
              size: size, scale: scale, dark: dark);
          expect(t.takeException(), isNull);
        });

        testWidgets('تفاصيل الطالب بلا overflow $tag', (t) async {
          _seed();
          await _pump(t, const StudentDetailsPage(),
              size: size, scale: scale, dark: dark, args: _active.first);
          expect(t.takeException(), isNull);
          // نلف على التابات (من غير "الأداء": بيقرا من قاعدة البيانات الحقيقية).
          for (final tab in ['واجب وتسميع', 'المدفوعات', 'سجل الحضور']) {
            if (find.text(tab).evaluate().isNotEmpty) {
              await t.tap(find.text(tab).first);
              await t.pump(const Duration(milliseconds: 400));
              await t.pump(const Duration(milliseconds: 400));
            }
          }
          expect(t.takeException(), isNull);
        });

        testWidgets('نافذة إضافة طالب بلا overflow $tag', (t) async {
          _seed();
          await _openDialog(
              t,
              (ctx) => showAddStudentSheet(ctx,
                  controller: Get.find<StudentController>()),
              size: size,
              scale: scale,
              dark: dark);
          expect(t.takeException(), isNull);
          expect(find.text('إضافة طالب جديد'), findsOneWidget);
        });

        testWidgets('نافذة تعديل طالب بلا overflow $tag', (t) async {
          _seed();
          await _openDialog(
              t,
              (ctx) => showEditStudentSheet(ctx,
                  student: _active.first,
                  accentColor: const Color(0xFF4F46E5),
                  controller: Get.find<StudentController>(),
                  groups: _groups),
              size: size,
              scale: scale,
              dark: dark);
          expect(t.takeException(), isNull);
          expect(find.text('تعديل بيانات الطالب'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('الأرشيف: العدد والكروت وقايمة الاستعادة والحذف النهائي', (t) async {
    _seed();
    await _pump(t, const ArchivedStudentsPage(), size: const Size(360, 800));
    expect(find.text('طالب مؤرشف'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('آدم أحمد'), findsOneWidget);
    await t.tap(find.byTooltip('خيارات الطالب المؤرشف').first);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('استعادة'), findsOneWidget);
    expect(find.text('حذف نهائي'), findsOneWidget);
  });

  testWidgets('الأرشيف: الحالة الفاضية', (t) async {
    _seed(archived: const []);
    await _pump(t, const ArchivedStudentsPage(), size: const Size(360, 800));
    expect(find.text('لا يوجد طلاب مؤرشفين'), findsOneWidget);
  });

  testWidgets('الإخوة: السبورة وكارت العيلة والبحث', (t) async {
    _seed();
    await _pump(t, const SiblingsPage(), size: const Size(360, 900));
    expect(find.text('عيلة'), findsOneWidget);
    expect(find.text('رسالة واتساب للعيلة'), findsOneWidget);
    expect(find.text('2 إخوة'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'مفيش حد بالاسم ده');
    await t.pump();
    expect(find.text('مفيش عيلات مطابقة'), findsOneWidget);
  });

  testWidgets('تفاصيل الطالب: الأرقام والتابات وأزرار الإجراءات', (t) async {
    _seed();
    await _pump(t, const StudentDetailsPage(),
        size: const Size(360, 900), args: _active.first);
    expect(find.text('بيانات الطالب'), findsOneWidget);
    expect(find.text('إسراء محمد إبراهيم سعد'), findsWidgets);
    expect(find.text('نسبة الحضور'), findsOneWidget);
    for (final tab in ['سجل الحضور', 'الأداء', 'المدفوعات']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
    expect(find.text('تقرير واتساب'), findsOneWidget);
    expect(find.text('QR Code'), findsOneWidget);
    expect(find.text('الامتحانات'), findsOneWidget);
    // حضور 2 من 3 → 67%
    expect(find.text('67%'), findsWidgets);
    // قايمة النقط التلاتة فيها QR والحذف.
    await t.tap(find.byTooltip('المزيد'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('عرض QR'), findsOneWidget);
    expect(find.text('حذف الطالب'), findsOneWidget);
  });

  testWidgets('نافذة الإضافة: العنوان والحقول والأزرار', (t) async {
    _seed();
    await _openDialog(
        t,
        (ctx) =>
            showAddStudentSheet(ctx, controller: Get.find<StudentController>()),
        size: const Size(360, 900));
    expect(find.text('اسم الطالب *'), findsOneWidget);
    expect(find.text('رقم ولي الأمر'), findsOneWidget);
    expect(find.text('إضافة الطالب'), findsOneWidget);
    expect(find.text('إغلاق'), findsWidgets);
    // الكود التلقائي اتولّد من بادئة المجموعة.
    expect(find.textContaining('G1-05'), findsOneWidget);
  });

  testWidgets('نافذة التعديل: اسم الطالب في الهيدر وزر الحفظ', (t) async {
    _seed();
    await _openDialog(
        t,
        (ctx) => showEditStudentSheet(ctx,
            student: _active[2],
            accentColor: const Color(0xFF10B981),
            controller: Get.find<StudentController>(),
            groups: _groups),
        size: const Size(360, 900));
    expect(find.text('تعديل بيانات الطالب'), findsOneWidget);
    expect(find.text('منى'), findsWidgets);
    expect(find.text('حفظ التعديلات'), findsOneWidget);
  });

  for (final size in [Size(320, 568), Size(411, 900)]) {
    for (final edit in [false, true]) {
      testWidgets(
          'النافذة بعد فتح الكود والخيارات الإضافية بلا overflow '
          '${edit ? "تعديل" : "إضافة"} ${size.width.toInt()}', (t) async {
        _seed();
        await _openDialog(
            t,
            (ctx) => edit
                ? showEditStudentSheet(ctx,
                    student: _active.first,
                    accentColor: const Color(0xFF4F46E5),
                    controller: Get.find<StudentController>(),
                    groups: _groups)
                : showAddStudentSheet(ctx,
                    controller: Get.find<StudentController>()),
            size: size,
            scale: 1.6);
        await t.ensureVisible(find.byIcon(Icons.qr_code_rounded).first);
        await t.tap(find.byIcon(Icons.qr_code_rounded).first);
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byType(Switch), findsWidgets); // لوحة الكود اتفتحت
        await t.ensureVisible(find.byTooltip('واتساب مختلف؟ (اختياري)'));
        await t.tap(find.byTooltip('واتساب مختلف؟ (اختياري)'));
        await t.pump(const Duration(milliseconds: 400));
        expect(find.text('واتساب مختلف؟ (اختياري)'), findsWidgets);
        await t.ensureVisible(find.text('خيارات إضافية'));
        // التعديل بيفتح الخيارات لوحده لو الطالب معفى أو عنده إخوة.
        expect(find.text('تاريخ بداية الحضور'), findsWidgets);
        if (find.text('إعفاء من الرسوم').evaluate().isEmpty) {
          await t.tap(find.text('خيارات إضافية'));
          await t.pump(const Duration(milliseconds: 400));
        }
        expect(find.text('إعفاء من الرسوم'), findsOneWidget);
        expect(find.text('تاريخ الميلاد'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
