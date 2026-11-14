// test/reports_overview_test.dart — حسابات تبويب الحضور في التقارير.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/utils/reports_overview.dart';

Attendance _a(int student, String status, [int day = 1]) =>
    Attendance(studentId: student, date: DateTime(2026, 11, day), status: status);

void main() {
  // طلاب 1،2 في مجموعة 10؛ طالب 3 في مجموعة 20.
  final groups = {1: 10, 2: 10, 3: 20};

  test('الحضور شامل المتأخر، والنسبة = حاضر ÷ (حاضر + غائب)', () {
    final r = computeAttendanceReport(
      monthAttendance: [
        _a(1, ATTENDANCE_PRESENT),
        _a(1, ATTENDANCE_LATE, 2),
        _a(2, ATTENDANCE_ABSENT),
        _a(2, ATTENDANCE_PRESENT, 2),
      ],
      groupOfStudent: groups,
    );
    expect(r.present, 3); // حاضر + متأخر + حاضر
    expect(r.late, 1);
    expect(r.absent, 1);
    expect(r.rate, closeTo(0.75, 1e-9));
  });

  test('مفيش تسجيل → النسبة null (مش 0%)', () {
    final r = computeAttendanceReport(
        monthAttendance: const [], groupOfStudent: groups);
    expect(r.rate, isNull);
    expect(r.total, 0);
  });

  test('حالات غير معروفة بتتتخطّى', () {
    final r = computeAttendanceReport(
      monthAttendance: [_a(1, 'حاجة غريبة'), _a(1, ATTENDANCE_PRESENT)],
      groupOfStudent: groups,
    );
    expect(r.present, 1);
    expect(r.absent, 0);
  });

  test('أكتر الغايبين والمتأخرين مرتّبين، ومحدودين بـtop', () {
    final r = computeAttendanceReport(
      monthAttendance: [
        for (var i = 1; i <= 3; i++) _a(1, ATTENDANCE_ABSENT, i),
        _a(2, ATTENDANCE_ABSENT),
        _a(3, ATTENDANCE_ABSENT),
        _a(3, ATTENDANCE_ABSENT, 2),
        _a(2, ATTENDANCE_LATE, 3),
        _a(2, ATTENDANCE_LATE, 4),
        _a(1, ATTENDANCE_LATE, 5),
      ],
      groupOfStudent: groups,
      top: 2,
    );
    expect(r.topAbsent.map((e) => (e.studentId, e.count)).toList(),
        [(1, 3), (3, 2)]); // طالب 2 (1 غياب) خرج برّه top=2
    expect(r.topLate.map((e) => (e.studentId, e.count)).toList(),
        [(2, 2), (1, 1)]);
  });

  test('فلتر المجموعة: طلابها بس', () {
    final all = [
      _a(1, ATTENDANCE_PRESENT),
      _a(2, ATTENDANCE_ABSENT),
      _a(3, ATTENDANCE_PRESENT),
      _a(3, ATTENDANCE_PRESENT, 2),
    ];
    final g10 = computeAttendanceReport(
        monthAttendance: all, groupOfStudent: groups, groupId: 10);
    expect(g10.present, 1);
    expect(g10.absent, 1);
    final g20 = computeAttendanceReport(
        monthAttendance: all, groupOfStudent: groups, groupId: 20);
    expect(g20.present, 2);
    expect(g20.rate, 1.0);
  });

  test('تفصيل كل مجموعة', () {
    final r = computeAttendanceReport(
      monthAttendance: [
        _a(1, ATTENDANCE_PRESENT),
        _a(2, ATTENDANCE_ABSENT),
        _a(3, ATTENDANCE_LATE),
      ],
      groupOfStudent: groups,
    );
    expect(r.byGroup[10]!.present, 1);
    expect(r.byGroup[10]!.absent, 1);
    expect(r.byGroup[10]!.rate, closeTo(0.5, 1e-9));
    expect(r.byGroup[20]!.late, 1);
    expect(r.byGroup[20]!.rate, 1.0);
  });

  test('rankExclude: المؤرشف في الإجماليات والمجموعة، مش في أكتر غياب/تأخير', () {
    final r = computeAttendanceReport(
      monthAttendance: [
        for (var i = 1; i <= 3; i++) _a(1, ATTENDANCE_ABSENT, i), // مؤرشف
        _a(2, ATTENDANCE_ABSENT),
        _a(1, ATTENDANCE_LATE, 5),
      ],
      groupOfStudent: groups,
      rankExclude: {1},
    );
    expect(r.absent, 4); // الإجماليات شاملة طالب 1
    expect(r.byGroup[10]!.absent, 4); // ومجموعته معروفة
    expect(r.topAbsent.map((e) => e.studentId).toList(), [2]); // برّه الترتيب
    expect(r.topLate, isEmpty);
  });

  test('ratio: مقام صفر → null', () {
    expect(ratio(3, 0), isNull);
    expect(ratio(1, 4), 0.25);
  });
}
