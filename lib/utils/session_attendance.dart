// lib/utils/session_attendance.dart
//
// spec 053 — الحضور بالحصة: دوال صرفة (بلا DB/GetX) تبني roster الحصة
// (مجموعة + تاريخ)، ملخص الحالات، والتصفية/البحث.
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/arabic_normalize.dart';

enum SessionFilter { all, present, late, absent, unrecorded }

class SessionRow {
  final Student student;

  /// حالة موحّدة (ATTENDANCE_PRESENT/LATE/ABSENT) أو null = لم يُسجَّل.
  final String? status;
  final Attendance? record;
  const SessionRow({required this.student, this.status, this.record});
}

class SessionSummary {
  final int present;
  final int late;
  final int absent;
  final int unrecorded;
  const SessionSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.unrecorded,
  });

  int get total => present + late + absent + unrecorded;

  /// المتأخر يُحتسب حضورًا (زي باقي التطبيق).
  int get attended => present + late;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// roster الحصة: طلاب [students] (المفروض طلاب المجموعة) بحالتهم في [day].
/// - المؤرشف بيظهر بس لو له سجل حضور في اليوم ده (عشان الحصص القديمة
///   تفضل صحيحة).
/// - اللي `attendanceStart` بتاعه بعد [day] بيتستبعد.
/// - [records] أي سجلات (بتتفلتر بـ[day] هنا)، وبترتّب النتيجة بالاسم.
List<SessionRow> buildSessionRows({
  required Iterable<Student> students,
  required Iterable<Attendance> records,
  required DateTime day,
}) {
  final byStudent = <int, Attendance>{};
  for (final a in records) {
    if (_sameDay(a.date, day)) byStudent.putIfAbsent(a.studentId, () => a);
  }
  final dayOnly = DateTime(day.year, day.month, day.day);
  final rows = <SessionRow>[];
  for (final s in students) {
    final rec = s.id == null ? null : byStudent[s.id];
    if (s.isArchived && rec == null) continue;
    final start = s.attendanceStart;
    if (start != null &&
        DateTime(start.year, start.month, start.day).isAfter(dayOnly) &&
        rec == null) {
      continue;
    }
    rows.add(SessionRow(
      student: s,
      status: rec == null ? null : normalizeAttendanceStatus(rec.status),
      record: rec,
    ));
  }
  rows.sort((a, b) => a.student.name.compareTo(b.student.name));
  return rows;
}

SessionSummary summarizeSession(Iterable<SessionRow> rows) {
  var p = 0, l = 0, a = 0, u = 0;
  for (final r in rows) {
    switch (r.status) {
      case ATTENDANCE_PRESENT:
        p++;
      case ATTENDANCE_LATE:
        l++;
      case ATTENDANCE_ABSENT:
        a++;
      default:
        u++;
    }
  }
  return SessionSummary(present: p, late: l, absent: a, unrecorded: u);
}

List<SessionRow> filterSessionRows(
  Iterable<SessionRow> rows,
  SessionFilter filter, {
  String query = '',
}) {
  final q = normalizeArabic(query.trim()).toLowerCase();
  bool matchesFilter(SessionRow r) => switch (filter) {
        SessionFilter.all => true,
        SessionFilter.present => r.status == ATTENDANCE_PRESENT,
        SessionFilter.late => r.status == ATTENDANCE_LATE,
        SessionFilter.absent => r.status == ATTENDANCE_ABSENT,
        SessionFilter.unrecorded => r.status == null,
      };
  bool matchesQuery(SessionRow r) =>
      q.isEmpty ||
      normalizeArabic(r.student.name).toLowerCase().contains(q) ||
      r.student.code.toLowerCase().contains(q);
  return rows.where((r) => matchesFilter(r) && matchesQuery(r)).toList();
}
