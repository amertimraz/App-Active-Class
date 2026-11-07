// lib/services/bulk_send_service.dart
//
// تحميل بيانات الإرسال الجماعي وبناء عناصر الطابور لكل نوع: تذكير الدفع،
// الغياب، تقرير الشهر (نص)، وبطاقة الطالب الشهرية (PDF).
import 'package:intl/intl.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/student_card_pdf.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/booklet_message.dart';
import 'package:active_class/utils/bulk_send_builders.dart';
import 'package:active_class/utils/debts_overview.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/monthly_report_message.dart';
import 'package:active_class/utils/send_queue.dart';
import 'package:active_class/utils/student_points.dart';

enum BulkKind { payments, absence, monthlyReport, monthlyCard }

extension BulkKindX on BulkKind {
  String get title => switch (this) {
        BulkKind.payments => 'تذكير الدفع',
        BulkKind.absence => 'إبلاغ الغياب',
        BulkKind.monthlyReport => 'تقرير الشهر',
        BulkKind.monthlyCard => 'بطاقة الشهر (PDF)',
      };

  String get hint => switch (this) {
        BulkKind.payments => 'لكل طالب عليه متبقي',
        BulkKind.absence => 'لكل غايب في يوم',
        BulkKind.monthlyReport => 'رسالة بحضور وواجب ودرجات الشهر',
        BulkKind.monthlyCard => 'بطاقة بتصميم السبورة تتبعت PDF',
      };

  bool get needsMonth =>
      this == BulkKind.monthlyReport || this == BulkKind.monthlyCard;
  bool get needsDay => this == BulkKind.absence;
}

class BulkSendData {
  final List<Student> students;
  final List<Group> groups;
  final List<Attendance> attendance;
  final List<Payment> payments;
  final List<Homework> homework;
  final Map<int, List<StudentExamRecord>> exams;

  const BulkSendData({
    required this.students,
    required this.groups,
    required this.attendance,
    required this.payments,
    required this.homework,
    required this.exams,
  });
}

class BulkSendService {
  BulkSendService._();

  static Future<BulkSendData> load() async {
    final db = DatabaseService();
    final students =
        (await db.getAllStudents()).where((s) => !s.isArchived).toList();
    return BulkSendData(
      students: students,
      groups: await db.getAllGroups(),
      attendance: await db.getAllAttendance(),
      payments: await db.getAllPayments(),
      homework: await db.getAllHomework(),
      exams: await db.getAllStudentExamHistories(),
    );
  }

  static List<QueueItem> payments(
    BulkSendData d, {
    int? groupId,
    required String teacherName,
    required String teacherSpecialization,
  }) {
    final rows = computeDebtRows(
      students: d.students,
      groups: d.groups,
      allAttendance: d.attendance,
      payments: d.payments,
    );
    return buildPaymentReminderItems(
      rows: rows,
      money: FormatHelper.formatCurrency,
      teacherName: teacherName,
      teacherSpecialization: teacherSpecialization,
      groupId: groupId,
    );
  }

  static List<QueueItem> absences(
    BulkSendData d, {
    required DateTime day,
    int? groupId,
    required String teacherName,
    required String teacherSpecialization,
  }) =>
      buildAbsenceItems(
        students: d.students,
        groups: d.groups,
        attendance: d.attendance,
        date: day,
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization,
        groupId: groupId,
      );

  static bool _inMonth(DateTime x, DateTime month) =>
      x.year == month.year && x.month == month.month;

  static List<QueueItem> monthlyReports(
    BulkSendData d, {
    required DateTime month,
    int? groupId,
    required String teacherName,
    required String teacherSpecialization,
  }) {
    final team = TeamModeService();
    final groupById = {for (final g in d.groups) g.id: g};
    final att = <int, List<Attendance>>{};
    for (final a in d.attendance) {
      if (_inMonth(a.date, month)) {
        att.putIfAbsent(a.studentId, () => []).add(a);
      }
    }
    final pay = <int, List<Payment>>{};
    for (final p in d.payments) {
      if (_inMonth(p.date, month)) {
        pay.putIfAbsent(p.studentId, () => []).add(p);
      }
    }
    final hw = <int, List<Homework>>{};
    for (final h in d.homework) {
      if (_inMonth(h.date, month)) {
        hw.putIfAbsent(h.studentId, () => []).add(h);
      }
    }
    final out = <QueueItem>[];
    for (final s in d.students) {
      final id = s.id;
      if (id == null) continue;
      if (groupId != null && s.groupId != groupId) continue;
      final exams = (d.exams[id] ?? const <StudentExamRecord>[])
          .where((r) => _inMonth(r.reportMonth, month))
          .toList();
      final msg = buildMonthlyReportMessage(
        student: s,
        month: month,
        groupName: groupById[s.groupId]?.name ?? '-',
        monthAtt: att[id] ?? const [],
        monthHw: hw[id] ?? const [],
        monthPays: pay[id] ?? const [],
        monthExams: exams,
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization,
        canSeeFinancials: team.canSeeFinancials,
        canSeeAcademics: team.canSeeAcademics,
        bookletLines: bookletReportLines(id),
      );
      out.add(QueueItem.forStudent(s,
          message: msg, subtitle: groupById[s.groupId]?.name ?? ''));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// بطاقات الشهر: الـPDF بيتبني وقت الإرسال (lazy) عشان مانبنيش 100 ملف
  /// مرة واحدة.
  static List<QueueItem> monthlyCards(
    BulkSendData d, {
    required DateTime month,
    int? groupId,
    required PointsRules rules,
    required String teacherName,
    required String teacherSpecialization,
  }) {
    final team = TeamModeService();
    final groupById = {for (final g in d.groups) g.id: g};
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(month);
    final debtRows = team.canSeeFinancials
        ? {
            for (final r in computeDebtRows(
              students: d.students,
              groups: d.groups,
              allAttendance: d.attendance,
              payments: d.payments,
            ))
              r.student.id: r
          }
        : const <int?, StudentDebtRow>{};
    final attBy = <int, List<Attendance>>{};
    for (final a in d.attendance) {
      attBy.putIfAbsent(a.studentId, () => []).add(a);
    }
    final hwBy = <int, List<Homework>>{};
    for (final h in d.homework) {
      hwBy.putIfAbsent(h.studentId, () => []).add(h);
    }

    final out = <QueueItem>[];
    for (final s in d.students) {
      final id = s.id;
      if (id == null) continue;
      if (groupId != null && s.groupId != groupId) continue;
      final gName = groupById[s.groupId]?.name ?? '-';
      final all = attBy[id] ?? const <Attendance>[];
      final mAtt = all.where((a) => _inMonth(a.date, month)).toList();
      final present =
          mAtt.where((a) => attendanceCountsAsPresent(a.status)).length;
      final late = mAtt
          .where((a) => normalizeAttendanceStatus(a.status) == ATTENDANCE_LATE)
          .length;
      final absent = mAtt
          .where((a) =>
              normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT)
          .length;
      final mHw = (hwBy[id] ?? const <Homework>[])
          .where((h) => _inMonth(h.date, month))
          .toList();
      final hwDone = mHw
          .where((h) => normalizeHomeworkStatus(h.status) == HOMEWORK_DONE)
          .length;
      final exams = team.canSeeAcademics
          ? (d.exams[id] ?? const <StudentExamRecord>[])
              .where((r) => _inMonth(r.reportMonth, month))
              .toList()
          : <StudentExamRecord>[];
      final pts = computeStudentPoints(
        student: s,
        attendance: all,
        homework: hwBy[id] ?? const [],
        exams: d.exams[id] ?? const [],
        rules: rules,
        month: DateTime(month.year, month.month, 1),
      );
      final debt = debtRows[id];
      final data = StudentCardData(
        studentName: s.name,
        studentCode: s.code,
        groupName: gName,
        monthLabel: monthLabel,
        present: present,
        late: late,
        absent: absent,
        hwDone: hwDone,
        hwTotal: mHw.length,
        exams: [
          for (final e in exams)
            (
              name: e.examName,
              grade: e.isAbsent || e.grade == null
                  ? 'غائب'
                  : '${_n(e.grade!)} / ${_n(e.maxGrade)}',
            )
        ],
        points: pts.points,
        levelLabel: pts.level.label,
        commitment: pts.commitment,
        remainingText: team.canSeeFinancials && debt != null
            ? FormatHelper.formatCurrency(debt.total)
            : null,
        teacherName: teacherName,
        teacherSpecialization: teacherSpecialization,
      );
      final safe = s.name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
      out.add(QueueItem.forStudent(
        s,
        subtitle: gName == '-' ? '' : gName,
        message: '📎 بطاقة ${s.name} — $monthLabel',
        attachment: QueueAttachment(
          fileName: 'بطاقة_${safe}_${month.year}-${month.month}.pdf',
          bytes: () => StudentCardPdf.build(data),
        ),
      ));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
