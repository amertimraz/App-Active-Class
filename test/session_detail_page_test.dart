// test/session_detail_page_test.dart — spec 053 (widget smoke بدون DB)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/attendance/session_detail_page.dart';

class _FakeStudents extends StudentController {
  _FakeStudents(this._list);
  final List<Student> _list;
  @override
  Future<void> loadAllStudents() async {
    students.assignAll(_list.where((s) => !s.isArchived));
    archivedStudents.assignAll(_list.where((s) => s.isArchived));
  }
}

class _FakeAttendance extends AttendanceController {
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

final _group = Group(id: 1, name: 'العواسجة', price: 100);
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Student _st(int id, String name) =>
    Student(id: id, name: name, code: 'c$id', groupId: 1, price: 0);

Future<_FakeAttendance> _pump(
  WidgetTester t, {
  required List<Student> students,
  List<Attendance> records = const [],
  DateTime? day,
}) async {
  Get.reset();
  final att = _FakeAttendance();
  att.attendance.addAll(records);
  Get.put<AttendanceController>(att);
  Get.put<StudentController>(_FakeStudents(students));
  await t.pumpWidget(GetMaterialApp(
    home: SessionDetailPage(group: _group, day: day ?? _today()),
  ));
  await t.pumpAndSettle();
  return att;
}

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));
  tearDown(Get.reset);

  testWidgets('الملخص يعرض أرقام الحالات الأربع', (t) async {
    final d = _today();
    await _pump(t, students: [
      for (var i = 1; i <= 5; i++) _st(i, 'طالب $i'),
    ], records: [
      Attendance(studentId: 1, date: d, status: ATTENDANCE_PRESENT),
      Attendance(studentId: 2, date: d, status: ATTENDANCE_PRESENT),
      Attendance(studentId: 3, date: d, status: ATTENDANCE_LATE),
      Attendance(studentId: 4, date: d, status: ATTENDANCE_ABSENT),
    ]);
    expect(find.text('الكل (5)'), findsOneWidget);
    expect(find.text('غائب (1)'), findsOneWidget);
    expect(find.text('لم يُسجَّل (1)'), findsOneWidget);
    expect(find.text('حاضر (2)'), findsOneWidget);
    expect(find.text('متأخر (1)'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget); // حضر (حاضر+متأخر) من الإجمالي
  });

  testWidgets('تبويب غائب يعرض الغايبين فقط وبزرار واتساب', (t) async {
    final d = _today();
    await _pump(t, students: [
      _st(1, 'منى'),
      _st(2, 'سارة'),
      _st(3, 'هدى'),
    ], records: [
      Attendance(studentId: 2, date: d, status: ATTENDANCE_ABSENT),
      Attendance(studentId: 3, date: d, status: ATTENDANCE_PRESENT),
    ]);
    await t.tap(find.text('غائب (1)'));
    await t.pumpAndSettle();
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('منى'), findsNothing);
    expect(find.text('هدى'), findsNothing);
    expect(find.textContaining('واتساب للغايبين'), findsOneWidget);
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle();
    expect(find.text('واتساب للغايبين (1)'), findsOneWidget);
  });

  testWidgets('تسجيل غائب لطالب غير مسجَّل ينقله لتبويب غائب فورًا', (t) async {
    await _pump(t, students: [_st(1, 'منى'), _st(2, 'سارة')]);
    expect(find.text('غائب (0)'), findsOneWidget);
    await t.tap(find.text('غائب').at(1)); // أول صف (index 0 = عنوان الملخص)
    await t.pumpAndSettle();
    expect(find.text('غائب (1)'), findsOneWidget);
    expect(find.text('لم يُسجَّل (1)'), findsOneWidget);
    // الضغط على المختار تاني يلغي السجل
    await t.tap(find.text('غائب').at(1));
    await t.pumpAndSettle();
    expect(find.text('غائب (0)'), findsOneWidget);
  });

  testWidgets('مجموعة بلا طلاب: رسالة فاضية', (t) async {
    await _pump(t, students: []);
    expect(find.text('مفيش طلاب'), findsOneWidget);
  });

  testWidgets('يوم مستقبلي: للعرض فقط بدون أزرار تسجيل', (t) async {
    await _pump(t,
        students: [_st(1, 'منى')],
        day: _today().add(const Duration(days: 3)));
    expect(find.text('لسه ما بدأتش — للعرض فقط'), findsOneWidget);
    expect(find.textContaining('تحضير غير المسجَّلين'), findsNothing);
  });

  testWidgets('طالب مؤرشف له سجل في اليوم يظهر، وبدون سجل لا يظهر', (t) async {
    final d = _today();
    final archived1 =
        Student(id: 8, name: 'قديم', code: 'c8', groupId: 1, price: 0, isArchived: true);
    final archived2 =
        Student(id: 9, name: 'اخر', code: 'c9', groupId: 1, price: 0, isArchived: true);
    await _pump(t, students: [
      _st(1, 'منى'),
      archived1,
      archived2,
    ], records: [
      Attendance(studentId: 8, date: d, status: ATTENDANCE_PRESENT),
    ]);
    expect(find.text('قديم'), findsOneWidget);
    expect(find.text('اخر'), findsNothing);
  });
}
