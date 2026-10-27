// test/session_attendance_test.dart — spec 053
import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/session_attendance.dart';

final day = DateTime(2026, 10, 27);

Student st(int id, String name,
        {bool archived = false, DateTime? start, String? code}) =>
    Student(
      id: id,
      name: name,
      code: code ?? 'c$id',
      groupId: 1,
      price: 0,
      isArchived: archived,
      attendanceStart: start,
    );

Attendance att(int studentId, String status, {DateTime? at}) => Attendance(
    studentId: studentId, date: at ?? DateTime(2026, 10, 27, 9), status: status);

void main() {
  test('الملخص: الأربع حالات مجموعها الإجمالي و"لم يُسجَّل" ≠ غائب', () {
    final rows = buildSessionRows(
      students: [for (var i = 1; i <= 10; i++) st(i, 's$i')],
      records: [
        for (var i = 1; i <= 6; i++) att(i, ATTENDANCE_PRESENT),
        att(7, ATTENDANCE_LATE),
        att(8, ATTENDANCE_ABSENT),
        att(9, ATTENDANCE_ABSENT),
      ],
      day: day,
    );
    final s = summarizeSession(rows);
    expect([s.present, s.late, s.absent, s.unrecorded], [6, 1, 2, 1]);
    expect(s.total, 10);
    expect(s.attended, 7);
  });

  test('سجلات أيام تانية لا تُحتسب', () {
    final rows = buildSessionRows(
      students: [st(1, 'أ')],
      records: [att(1, ATTENDANCE_PRESENT, at: DateTime(2026, 10, 26, 9))],
      day: day,
    );
    expect(rows.single.status, isNull);
  });

  test('مؤرشف بدون سجل يُستبعد، ومعاه سجل يظهر', () {
    final rows = buildSessionRows(
      students: [st(1, 'أ', archived: true), st(2, 'ب', archived: true)],
      records: [att(2, ATTENDANCE_ABSENT)],
      day: day,
    );
    expect(rows.map((r) => r.student.id), [2]);
  });

  test('attendanceStart بعد التاريخ يُستبعد (إلا لو له سجل)', () {
    final rows = buildSessionRows(
      students: [
        st(1, 'أ', start: DateTime(2026, 11, 1)),
        st(2, 'ب', start: DateTime(2026, 10, 27)),
        st(3, 'ج', start: DateTime(2026, 11, 1)),
      ],
      records: [att(3, ATTENDANCE_PRESENT)],
      day: day,
    );
    expect(rows.map((r) => r.student.id), containsAll([2, 3]));
    expect(rows.any((r) => r.student.id == 1), isFalse);
  });

  test('الترتيب بالاسم', () {
    final rows = buildSessionRows(
      students: [st(1, 'ياسر'), st(2, 'أحمد')],
      records: const [],
      day: day,
    );
    expect(rows.map((r) => r.student.name), ['أحمد', 'ياسر']);
  });

  test('التصفية بالحالة والبحث بالاسم/الكود', () {
    final rows = buildSessionRows(
      students: [
        st(1, 'أحمد علي', code: 'A1'),
        st(2, 'منى سعيد', code: 'B2'),
        st(3, 'احمد حسن', code: 'C3'),
      ],
      records: [att(1, ATTENDANCE_ABSENT), att(2, ATTENDANCE_ABSENT)],
      day: day,
    );
    expect(
        filterSessionRows(rows, SessionFilter.absent).map((r) => r.student.id),
        [1, 2]);
    expect(
        filterSessionRows(rows, SessionFilter.unrecorded)
            .map((r) => r.student.id),
        [3]);
    // تطبيع الهمزة: "احمد" تلاقي "أحمد"
    expect(
        filterSessionRows(rows, SessionFilter.all, query: 'احمد')
            .map((r) => r.student.id),
        [1, 3]);
    expect(
        filterSessionRows(rows, SessionFilter.absent, query: 'b2')
            .map((r) => r.student.id),
        [2]);
  });

  test('مجموعة فاضية وحجم كبير', () {
    expect(summarizeSession(const []).total, 0);
    final rows = buildSessionRows(
      students: [for (var i = 1; i <= 200; i++) st(i, 'طالب $i')],
      records: [for (var i = 1; i <= 120; i++) att(i, ATTENDANCE_ABSENT)],
      day: day,
    );
    final s = summarizeSession(rows);
    expect([s.absent, s.unrecorded, s.total], [120, 80, 200]);
  });
}
