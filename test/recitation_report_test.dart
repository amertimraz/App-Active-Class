// test/recitation_report_test.dart — spec 048: ظهور التسميع في رسائل التقارير
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/monthly_report_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Attendance att(int day, int? rec, {String status = ATTENDANCE_PRESENT}) =>
    Attendance(
        studentId: 1,
        date: DateTime(2026, 10, day),
        status: status,
        recitation: rec);

String msg(List<Attendance> list, {bool? include}) => buildMonthlyReportMessage(
      student: Student(
          id: 1, name: 'أحمد', code: 'c1', groupId: 1, price: 100),
      month: DateTime(2026, 10, 1),
      groupName: 'ش',
      monthAtt: list,
      monthHw: const [],
      monthPays: const [],
      monthExams: const [],
      teacherName: '',
      teacherSpecialization: '',
      canSeeFinancials: false,
      canSeeAcademics: false,
      includeRecitation: include,
    );

void main() {
  setUpAll(() async => initializeDateFormatting('ar'));

  group('رسالة تقرير الشهر', () {
    test('متوسط التسميع وعدد المرات + درجة كل يوم', () {
      final m = msg([att(1, 8), att(2, 6), att(3, null)], include: true);
      expect(m, contains('🎤 التسميع: متوسط 7.0/10 (2 مرة)'));
      expect(m, contains('🎤8/10'));
      expect(m, contains('🎤6/10'));
    });
    test('بلا درجات → لا سطر تسميع', () {
      expect(msg([att(1, null)], include: true), isNot(contains('🎤')));
    });
    test('الإعداد مقفول → لا يظهر حتى لو فيه درجات', () {
      expect(msg([att(1, 9)], include: false), isNot(contains('🎤')));
    });
  });

  group('رسالة تقرير اليوم', () {
    final ctrl = AttendanceController();
    final s = Student(id: 1, name: 'أحمد', code: 'c1', groupId: 1, price: 100);
    String daily({int? rec, bool hw = true, String st = ATTENDANCE_PRESENT}) =>
        ctrl.buildGuardianReportMessage(
            student: s,
            attendanceStatus: st,
            homeworkStatus: null,
            recitation: rec,
            includeHomework: hw);

    test('تسميع ظاهر', () => expect(daily(rec: 8), contains('🎤 التسميع: 8/10')));
    test('بلا تسميع', () => expect(daily(), isNot(contains('🎤'))));
    test('غائب لا تسميع',
        () => expect(daily(rec: 8, st: ATTENDANCE_ABSENT), isNot(contains('🎤'))));
    test('الواجب مخفي', () {
      expect(daily(hw: false), isNot(contains('الواجب')));
      expect(daily(hw: true), contains('الواجب'));
    });
  });
}
