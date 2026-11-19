// lib/utils/reports_overview.dart
//
// حسابات صرفة (بلا DB/GetX) لتبويبات التقارير: الحضور ونظرة عامة. كل رقم هنا
// بيتحسب من نفس بيانات الشهر اللي في ReportController، ومفيش فيها حساب مالي
// (الفلوس بتيجي من computeMonthlyBreakdown/computeIncome زي ما هي).
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/config/constants.dart';

/// طالب + عدد (غيابات أو تأخيرات) في الشهر.
class StudentCount {
  final int studentId;
  final int count;
  const StudentCount(this.studentId, this.count);
}

class GroupAttendance {
  final int present; // شامل المتأخر
  final int absent;
  final int late;
  const GroupAttendance(this.present, this.absent, this.late);

  /// نسبة الحضور = حاضر (شامل متأخر) ÷ (حاضر + غائب). null لو مفيش تسجيل.
  double? get rate => ratio(present, present + absent);
}

class AttendanceReport {
  final int present; // شامل المتأخر
  final int absent;
  final int late; // منهم كام متأخر
  final List<StudentCount> topAbsent;
  final List<StudentCount> topLate;
  final Map<int?, GroupAttendance> byGroup;

  const AttendanceReport({
    required this.present,
    required this.absent,
    required this.late,
    required this.topAbsent,
    required this.topLate,
    required this.byGroup,
  });

  int get total => present + absent;
  double? get rate => ratio(present, present + absent);
}

/// a ÷ b، أو null لو b = 0 (مفيش أساس للنسبة).
double? ratio(num a, num b) => b <= 0 ? null : a / b;

/// تقرير حضور الشهر. [groupOfStudent]: studentId → groupId. لو [groupId] اتحدد،
/// بيتحسب لطلاب المجموعة دي بس.
AttendanceReport computeAttendanceReport({
  required Iterable<Attendance> monthAttendance,
  required Map<int, int> groupOfStudent,
  int? groupId,

  /// نطاق متعدد (كل مجموعات سنتر). لو اتحدد بيتقدّم على [groupId].
  Set<int>? groupIds,
  int top = 5,

  /// طلاب (مؤرشفين مثلًا) بيدخلوا في الإجماليات والمجموعات لكن مش في قوايم
  /// «أكتر غياب/تأخير» لأنها قوايم بتتصرف على أساسها.
  Set<int> rankExclude = const {},
}) {
  var present = 0, absent = 0, late = 0;
  final absentBy = <int, int>{};
  final lateBy = <int, int>{};
  final presentG = <int?, int>{};
  final absentG = <int?, int>{};
  final lateG = <int?, int>{};

  for (final a in monthAttendance) {
    final g = groupOfStudent[a.studentId];
    if (groupIds != null) {
      if (g == null || !groupIds.contains(g)) continue;
    } else if (groupId != null && g != groupId) {
      continue;
    }
    final s = normalizeAttendanceStatus(a.status);
    if (s == null) continue;
    if (s == ATTENDANCE_ABSENT) {
      absent++;
      if (!rankExclude.contains(a.studentId)) {
        absentBy.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
      }
      absentG.update(g, (v) => v + 1, ifAbsent: () => 1);
    } else {
      present++;
      presentG.update(g, (v) => v + 1, ifAbsent: () => 1);
      if (s == ATTENDANCE_LATE) {
        late++;
        if (!rankExclude.contains(a.studentId)) {
          lateBy.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
        }
        lateG.update(g, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }

  List<StudentCount> topOf(Map<int, int> m) {
    final l = [for (final e in m.entries) StudentCount(e.key, e.value)]
      ..sort((x, y) {
        final c = y.count.compareTo(x.count);
        return c != 0 ? c : x.studentId.compareTo(y.studentId);
      });
    return l.take(top).toList();
  }

  final groups = {...presentG.keys, ...absentG.keys};
  return AttendanceReport(
    present: present,
    absent: absent,
    late: late,
    topAbsent: topOf(absentBy),
    topLate: topOf(lateBy),
    byGroup: {
      for (final g in groups)
        g: GroupAttendance(presentG[g] ?? 0, absentG[g] ?? 0, lateG[g] ?? 0)
    },
  );
}
