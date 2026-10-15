// test/reports_academic_columns_test.dart — الواجب والتسميع في تقارير الـPDF.
// بيولّد الـPDFs فعليًا (Cairo + مسار حفظ مؤقت) ويتأكد إنها بتتبني بلا خطأ
// بكل تركيبات البيانات (الخدمة بتلتقط الاستثناء وترجّع fail).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    tmp = await Directory.systemTemp.createTemp('ac_reports_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });

  final month = DateTime(2026, 10, 1);
  final groups = [
    Group(id: 1, name: 'Grade 2', price: 100),
    Group(id: 2, name: 'Grade 3', price: 100),
  ];
  Student st(int id, String name, int g) => Student(
        id: id,
        name: name,
        code: 'S$id',
        groupId: g,
        price: 100,
        createdAt: DateTime(2026, 9, 1),
        attendanceStart: DateTime(2026, 9, 1),
      );
  final students = [
    st(1, 'منى أحمد', 1),
    st(2, 'علي حسن', 1),
    st(3, 'ياسمين', 2)
  ];

  Attendance att(int s, int day, String status, {int? rec, int? max}) =>
      Attendance(
          studentId: s,
          date: DateTime(2026, 10, day),
          status: status,
          recitation: rec,
          recitationMax: max);

  final attendance = [
    att(1, 1, ATTENDANCE_PRESENT, rec: 8, max: 10),
    att(1, 2, ATTENDANCE_PRESENT, rec: 15, max: 20),
    att(2, 1, ATTENDANCE_ABSENT),
    att(2, 2, ATTENDANCE_PRESENT),
    att(3, 1, ATTENDANCE_PRESENT, rec: 9, max: 10),
  ];
  Homework hw(int s, int day, String status) =>
      Homework(studentId: s, date: DateTime(2026, 10, day), status: status);
  final homework = [
    hw(1, 1, 'عمل'),
    hw(1, 2, 'لم يعمل'),
    hw(2, 2, 'عمل'),
    hw(3, 1, 'عمل'),
  ];

  void expectOk(ExportResult r) {
    expect(r.success, true, reason: r.error);
    expect(r.path, isNotNull);
    expect(File(r.path!).lengthSync(), greaterThan(1000));
  }

  final svc = ExportService();

  test('تقرير الحضور مع الواجب والتسميع', () async {
    expectOk(await svc.exportAttendancePDF(
      month: month,
      students: students,
      attendance: attendance,
      groups: groups,
      homework: homework,
    ));
  });

  test('تقرير الحضور بدون واجب (سلوك قديم)', () async {
    expectOk(await svc.exportAttendancePDF(
      month: month,
      students: students,
      attendance: attendance,
      groups: groups,
    ));
  });

  test('تقرير الحضور لفترة مخصّصة بالواجب', () async {
    expectOk(await svc.exportAttendancePDF(
      month: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 2),
      students: students,
      attendance: attendance,
      groups: groups,
      homework: homework,
    ));
  });

  test('تقرير الواجب مع التسميع', () async {
    expectOk(await svc.exportHomeworkPDF(
      month: month,
      students: students,
      homework: homework,
      groups: groups,
      attendance: attendance,
    ));
  });

  test('تقرير الواجب بدون حضور (سلوك قديم)', () async {
    expectOk(await svc.exportHomeworkPDF(
      month: month,
      students: students,
      homework: homework,
      groups: groups,
    ));
  });

  test('تقرير الواجب: فيه تسميع ومفيش واجب في الشهر', () async {
    expectOk(await svc.exportHomeworkPDF(
      month: month,
      students: students,
      homework: const [],
      groups: groups,
      attendance: attendance,
    ));
  });

  test('ملخص المجموعات مع الواجب والتسميع', () async {
    expectOk(await svc.exportGroupsSummaryPDF(
      month: month,
      students: students,
      payments: [
        Payment(studentId: 1, date: DateTime(2026, 10, 3), amount: 100),
      ],
      attendance: attendance,
      groups: groups,
      homework: homework,
    ));
  });

  test('ملخص المجموعات بدون واجب ولا تسميع', () async {
    expectOk(await svc.exportGroupsSummaryPDF(
      month: month,
      students: students,
      payments: const [],
      attendance: [
        att(1, 1, ATTENDANCE_PRESENT),
        att(2, 1, ATTENDANCE_ABSENT),
      ],
      groups: groups,
    ));
  });
}
