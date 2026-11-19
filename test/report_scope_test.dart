// نطاق التقارير بالسنتر: reportScope + حساب الحضور والامتحانات على مجموعة ids.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/utils/report_scope.dart';
import 'package:active_class/utils/reports_overview.dart';

Attendance _a(int student, String status) =>
    Attendance(studentId: student, date: DateTime(2026, 11, 3), status: status);

void main() {
  final groups = [
    Group(id: 1, name: 'أ1', price: 1, center: 'سنتر أ'),
    Group(id: 2, name: 'أ2', price: 1, center: '  سنتر   أ '),
    Group(id: 3, name: 'ب1', price: 1, center: 'سنتر ب'),
    Group(id: 4, name: 'حرة', price: 1),
  ];

  group('reportScope', () {
    test('بلا اختيار = الكل (null)', () {
      expect(reportScope(groups: groups), isNull);
    });
    test('سنتر = كل مجموعاته (بعد تطبيع المسافات)', () {
      expect(reportScope(center: 'سنتر أ', groups: groups), {1, 2});
      expect(reportScope(center: 'سنتر ب', groups: groups), {3});
    });
    test('«بدون سنتر»', () {
      expect(reportScope(center: GroupController.kNoCenterFilter, groups: groups),
          {4});
    });
    test('مجموعة بعينها ليها الأولوية على السنتر', () {
      expect(reportScope(groupId: 2, center: 'سنتر أ', groups: groups), {2});
    });
    test('سنتر مالوش مجموعات = نطاق فاضي (مش الكل)', () {
      expect(reportScope(center: 'سنتر ج', groups: groups), isEmpty);
    });
    test('inReportScope', () {
      expect(inReportScope(5, null), isTrue);
      expect(inReportScope(1, {1, 2}), isTrue);
      expect(inReportScope(3, {1, 2}), isFalse);
      expect(inReportScope(null, {1}), isFalse);
    });
  });

  group('computeAttendanceReport بنطاق سنتر', () {
    // طلاب 1،2 في مجموعة 1 (سنتر أ)، 3 في مجموعة 2 (سنتر أ)، 4 في مجموعة 3 (سنتر ب).
    final groupOf = {1: 1, 2: 1, 3: 2, 4: 3};
    final att = [
      _a(1, ATTENDANCE_PRESENT),
      _a(2, ATTENDANCE_ABSENT),
      _a(3, ATTENDANCE_PRESENT),
      _a(4, ATTENDANCE_ABSENT),
      _a(4, ATTENDANCE_ABSENT),
    ];

    test('سنتر أ: بس طلاب مجموعتيه', () {
      final r = computeAttendanceReport(
          monthAttendance: att, groupOfStudent: groupOf, groupIds: {1, 2});
      expect(r.present, 2);
      expect(r.absent, 1);
    });

    test('سنتر ب', () {
      final r = computeAttendanceReport(
          monthAttendance: att, groupOfStudent: groupOf, groupIds: {3});
      expect(r.absent, 2);
      expect(r.present, 0);
    });

    test('نطاق فاضي = صفر مش الكل', () {
      final r = computeAttendanceReport(
          monthAttendance: att, groupOfStudent: groupOf, groupIds: <int>{});
      expect(r.total, 0);
    });

    test('groupIds بيتقدّم على groupId، وغيابهم = التوافق القديم', () {
      final one = computeAttendanceReport(
          monthAttendance: att, groupOfStudent: groupOf, groupId: 3);
      expect(one.absent, 2);
      final all = computeAttendanceReport(
          monthAttendance: att, groupOfStudent: groupOf);
      expect(all.total, 5);
    });
  });
}
