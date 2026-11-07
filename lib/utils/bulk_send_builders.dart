// lib/utils/bulk_send_builders.dart
//
// بناء عناصر طابور الإرسال من البيانات: تذكير دفع للمتأخرين، وإبلاغ غياب
// يوم معيّن. دوال صرفة (المبلغ بيتنسّق عن طريق دالة بتتبعت) عشان تتختبر.
import 'package:intl/intl.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/absence_message.dart';
import 'package:active_class/utils/debts_overview.dart';
import 'package:active_class/utils/payment_reminder_message.dart';
import 'package:active_class/utils/send_queue.dart';

/// تذكير دفع لكل طالب عليه متبقي. لو عليه شهر واحد بنكتب اسمه، ولو أكتر
/// بنكتب المجموع بس.
List<QueueItem> buildPaymentReminderItems({
  required List<StudentDebtRow> rows,
  required String Function(double) money,
  String teacherName = '',
  String teacherSpecialization = '',
  int? groupId,
}) {
  final out = <QueueItem>[];
  for (final r in rows) {
    if (groupId != null && r.student.groupId != groupId) continue;
    if (r.total <= 0.5) continue;
    final single = r.months.length == 1
        ? DateFormat('MMMM yyyy', 'ar').format(r.months.first.month)
        : '';
    final msg = buildPaymentReminderMessage(
      studentName: r.student.name,
      studentCode: r.student.code,
      groupName: r.group?.name ?? '',
      monthLabel: single,
      remainingText: money(r.total),
      teacherName: teacherName,
      teacherSpecialization: teacherSpecialization,
    );
    out.add(QueueItem.forStudent(
      r.student,
      message: msg,
      subtitle: r.months.length > 1
          ? '${money(r.total)} • ${r.months.length} شهور'
          : money(r.total),
    ));
  }
  return out;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// إبلاغ غياب لكل طالب اتسجّل غايب في [date] (المؤرشفين مستبعدين).
List<QueueItem> buildAbsenceItems({
  required List<Student> students,
  required List<Group> groups,
  required List<Attendance> attendance,
  required DateTime date,
  String teacherName = '',
  String teacherSpecialization = '',
  int? groupId,
}) {
  final byId = {for (final s in students) s.id: s};
  final groupById = {for (final g in groups) g.id: g};
  final seen = <int>{};
  final out = <QueueItem>[];
  for (final a in attendance) {
    if (!_sameDay(a.date, date)) continue;
    if (normalizeAttendanceStatus(a.status) != ATTENDANCE_ABSENT) continue;
    final s = byId[a.studentId];
    if (s == null || s.isArchived || !seen.add(a.studentId)) continue;
    if (groupId != null && s.groupId != groupId) continue;
    final gName = groupById[s.groupId]?.name ?? '-';
    out.add(QueueItem.forStudent(
      s,
      message: buildAbsenceMessage(
        studentName: s.name,
        studentCode: s.code,
        groupName: gName,
        date: date,
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization,
      ),
      subtitle: gName == '-' ? '' : gName,
    ));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}
