// lib/services/at_risk_service.dart
//
// spec 021 — محرك رصد "طلاب محتاجين متابعة". منطق Dart نقي (صفر
// Flutter/DB imports) — قراءة/تجميع فوق بيانات محمَّلة بالفعل، صفر
// كتابة، صفر side effects. راجع contracts/at-risk-service.md.
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/at_risk_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_follow_up_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

/// إعدادات الرصد — مبنية وقت الاستدعاء من SettingsController (خارج
/// الملف ده، عشان يفضل نقي). عتبة تأخّر الدفع مش هنا — بتيجي من
/// paymentGraceDays الموجود بالفعل (راجع data-model.md).
class AtRiskSettings {
  final bool absenceEnabled;
  final int absenceThreshold; // K حصص متتالية
  final bool homeworkEnabled;
  final int homeworkM;
  final int homeworkW;
  final bool gradeEnabled;
  final int gradeDropPoints; // P نقطة مئوية
  final bool paymentEnabled;
  final int paymentGraceDays;
  final int cooldownDays;

  const AtRiskSettings({
    this.absenceEnabled = true,
    this.absenceThreshold = 2,
    this.homeworkEnabled = true,
    this.homeworkM = 3,
    this.homeworkW = 5,
    this.gradeEnabled = true,
    this.gradeDropPoints = 15,
    this.paymentEnabled = true,
    this.paymentGraceDays = 0,
    this.cooldownDays = 7,
  });
}

/// يحسب قائمة الطلاب المحتاجين متابعة — غير مؤرشفين، بإشارة واحدة على
/// الأقل متحقّقة، مستبعدين لو مؤجَّلين (تهدئة سارية). النتيجة مرتّبة
/// تنازليًا بدرجة الخطورة.
List<AtRiskStudent> computeAtRiskStudents({
  required List<Student> students,
  required List<Group> groups,
  required List<Attendance> attendance,
  required List<Homework> homework,
  required List<ExamGrade> examGrades,
  required List<Payment> payments,
  required List<StudentFollowUp> recentFollowUps,
  required AtRiskSettings settings,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();

  final groupById = <int, Group>{
    for (final g in groups)
      if (g.id != null) g.id!: g,
  };

  final attendanceByStudent = <int, List<Attendance>>{};
  for (final a in attendance) {
    attendanceByStudent.putIfAbsent(a.studentId, () => []).add(a);
  }
  final homeworkByStudent = <int, List<Homework>>{};
  for (final h in homework) {
    homeworkByStudent.putIfAbsent(h.studentId, () => []).add(h);
  }
  final gradesByStudent = <int, List<ExamGrade>>{};
  for (final g in examGrades) {
    gradesByStudent.putIfAbsent(g.studentId, () => []).add(g);
  }
  final paymentsByStudent = <int, List<Payment>>{};
  for (final p in payments) {
    paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
  }
  final followUpsByStudent = <int, List<StudentFollowUp>>{};
  for (final f in recentFollowUps) {
    followUpsByStudent.putIfAbsent(f.studentId, () => []).add(f);
  }

  final result = <AtRiskStudent>[];

  for (final s in students) {
    if (s.isArchived || s.id == null) continue;
    final signals = <RiskSignal>[];

    if (settings.absenceEnabled) {
      final sig = _checkConsecutiveAbsence(
          attendanceByStudent[s.id] ?? const [], settings.absenceThreshold);
      if (sig != null) signals.add(sig);
    }
    if (settings.homeworkEnabled) {
      final sig = _checkMissingHomework(homeworkByStudent[s.id] ?? const [],
          settings.homeworkM, settings.homeworkW);
      if (sig != null) signals.add(sig);
    }
    if (settings.gradeEnabled) {
      final sig = _checkGradeDrop(
          gradesByStudent[s.id] ?? const [], settings.gradeDropPoints);
      if (sig != null) signals.add(sig);
    }
    if (settings.paymentEnabled) {
      final sig = _checkLatePayment(
        student: s,
        group: groupById[s.groupId],
        allAttendance: attendance,
        studentPayments: paymentsByStudent[s.id] ?? const [],
        graceDays: settings.paymentGraceDays,
        allStudents: students,
      );
      if (sig != null) signals.add(sig);
    }

    if (signals.isEmpty) continue;

    final currentTypes = signals.map((sig) => sig.type).toSet();
    if (_isAcknowledged(currentTypes, followUpsByStudent[s.id] ?? const [],
        settings.cooldownDays, today)) {
      continue;
    }

    result.add(AtRiskStudent(
      student: s,
      group: groupById[s.groupId],
      signals: signals,
    ));
  }

  result.sort((a, b) => b.severityScore.compareTo(a.severityScore));
  return result;
}

// ─────────────────────────────────────────────────────────────────
//  الإشارات الأربعة — كل واحدة دالة خاصة برضو ترجّع RiskSignal? (null
//  = مش متحقّقة أو مفيش بيانات كفاية).
// ─────────────────────────────────────────────────────────────────

RiskSignal? _checkConsecutiveAbsence(
    List<Attendance> studentAttendance, int threshold) {
  if (studentAttendance.isEmpty) return null;
  final sorted = [...studentAttendance]..sort((a, b) => b.date.compareTo(a.date));
  var count = 0;
  for (final a in sorted) {
    if (a.status == ATTENDANCE_ABSENT) {
      count++;
    } else {
      break; // أول حاضر/متأخر بيوقف العدّ
    }
  }
  if (count < threshold) return null;
  return RiskSignal(
    type: RiskSignalType.consecutiveAbsence,
    reasonText: 'غياب متتالي ($count)',
    severityWeight: 2,
  );
}

RiskSignal? _checkMissingHomework(
    List<Homework> studentHomework, int m, int w) {
  if (studentHomework.length < w) return null; // مفيش تاريخ كفاية
  final sorted = [...studentHomework]..sort((a, b) => b.date.compareTo(a.date));
  final window = sorted.take(w);
  final missing = window.where((h) {
    final status = normalizeHomeworkStatus(h.status);
    return status == HOMEWORK_NOT_DONE || status == HOMEWORK_PARTIAL;
  }).length;
  if (missing < m) return null;
  return RiskSignal(
    type: RiskSignalType.missingHomework,
    reasonText: 'واجب ناقص متكرر ($missing/$w)',
    severityWeight: 2,
  );
}

RiskSignal? _checkGradeDrop(List<ExamGrade> studentGrades, int dropPoints) {
  // الأحدث أولاً — الترتيب ده جاي من الاستعلام (getAllExamGradesWithExamInfo)
  // بس بنعيد الفرز هنا كمان عشان الدالة تفضل صحيحة مهما كان ترتيب الإدخال.
  final valid = studentGrades
      .where((g) => !g.isAbsent && g.grade != null && (g.maxGrade ?? 0) > 0)
      .toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  if (valid.isEmpty) return null;

  final latest = valid.first;
  final latestPct = latest.percentage;
  final passingPct = (latest.passingGrade != null && (latest.maxGrade ?? 0) > 0)
      ? (latest.passingGrade! / latest.maxGrade!) * 100
      : 60.0;
  final belowPassing = latestPct < passingPct;

  double? drop;
  if (valid.length >= 2) {
    final prevPcts = valid.skip(1).map((g) => g.percentage);
    final prevAvg = prevPcts.reduce((a, b) => a + b) / (valid.length - 1);
    drop = prevAvg - latestPct;
  }
  final droppedEnough = drop != null && drop >= dropPoints;

  if (!belowPassing && !droppedEnough) return null;

  final parts = <String>[
    if (droppedEnough) 'هبوط ${drop.round()} نقطة',
    if (belowPassing) 'تحت درجة النجاح',
  ];
  return RiskSignal(
    type: RiskSignalType.gradeDrop,
    reasonText: 'هبوط في الدرجات (${parts.join(" · ")})',
    severityWeight: droppedEnough && belowPassing ? 3 : 2,
  );
}

RiskSignal? _checkLatePayment({
  required Student student,
  required Group? group,
  required List<Attendance> allAttendance,
  required List<Payment> studentPayments,
  required int graceDays,
  required List<Student> allStudents,
}) {
  final overdue = PricingHelper.isOverdue(
    student: student,
    group: group,
    allAttendance: allAttendance,
    payments: studentPayments,
    graceDays: graceDays,
    siblingGroupMembers: allStudents,
  );
  if (!overdue) return null;
  final debt = PricingHelper.accumulatedDebt(
    student: student,
    group: group,
    allAttendance: allAttendance,
    payments: studentPayments,
    siblingGroupMembers: allStudents,
  );
  if (debt <= 0) return null; // isOverdue=true بس مديونية صفر (نادر) — تجاهل
  return RiskSignal(
    type: RiskSignalType.latePayment,
    reasonText: 'متأخّر في الدفع — مديونية ${debt.round()}',
    severityWeight: 3,
  );
}

bool _isAcknowledged(
  Set<RiskSignalType> currentTypes,
  List<StudentFollowUp> studentFollowUps,
  int cooldownDays,
  DateTime now,
) {
  if (studentFollowUps.isEmpty) return false;
  final latest = studentFollowUps
      .reduce((a, b) => a.acknowledgedAt.isAfter(b.acknowledgedAt) ? a : b);
  if (now.difference(latest.acknowledgedAt) > Duration(days: cooldownDays)) {
    return false;
  }
  final ackTypes = latest.reasonTypes
      .map(RiskSignalTypeKey.fromStorageKey)
      .whereType<RiskSignalType>()
      .toSet();
  return currentTypes.every(ackTypes.contains);
}
