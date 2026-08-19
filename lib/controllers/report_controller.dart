import 'package:get/get.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';

class ReportController extends GetxController {
  final DatabaseService _dbService = DatabaseService();

  // ─── Raw data ───────────────────────────────────────────────────────────────
  final RxList<Payment> allPayments = <Payment>[].obs;
  final RxList<Attendance> allAttendance = <Attendance>[].obs;
  final RxList<Student> allStudents = <Student>[].obs;
  final RxList<Group> allGroups = <Group>[].obs;

  // ─── Selected month ─────────────────────────────────────────────────────────
  final Rx<DateTime> selectedMonth =
      Rx<DateTime>(DateTime(DateTime.now().year, DateTime.now().month, 1));

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadReports();
  }

  Future<void> loadReports() async {
    isLoading(true);
    try {
      final payments = await _dbService.getAllPayments();
      final attendance = await _dbService.getAllAttendance();
      final students = await _dbService.getAllStudents();
      final groups = await _dbService.getAllGroups();
      allPayments.assignAll(payments);
      allAttendance.assignAll(attendance);
      allStudents.assignAll(students);
      allGroups.assignAll(groups);
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل التقارير');
    } finally {
      isLoading(false);
    }
  }

  void setMonth(DateTime month) {
    selectedMonth.value = DateTime(month.year, month.month, 1);
  }

  // ─── Month-scoped helpers ───────────────────────────────────────────────────

  List<Payment> get monthPayments {
    final m = selectedMonth.value;
    return allPayments
        .where((p) => p.date.year == m.year && p.date.month == m.month)
        .toList();
  }

  List<Attendance> get monthAttendance {
    final m = selectedMonth.value;
    final start = DateTime(m.year, m.month, 1);
    final end = DateTime(m.year, m.month + 1, 1)
        .subtract(const Duration(microseconds: 1));
    return allAttendance
        .where((a) => !a.date.isBefore(start) && !a.date.isAfter(end))
        .toList();
  }

  double get monthTotalCollected =>
      monthPayments.fold(0.0, (s, p) => s + p.amount);

  int get monthPresentCount =>
      monthAttendance.where((a) => a.status == 'حاضر').length;

  int get monthAbsentCount =>
      monthAttendance.where((a) => a.status == 'غائب').length;

  // ─── Per-group summary for selected month ──────────────────────────────────

  // الطلاب الذين كانوا مسجّلين قبل نهاية الشهر المحدد
  List<Student> get _studentsActiveInMonth {
    final m = selectedMonth.value;
    final monthEnd = DateTime(m.year, m.month + 1, 1)
        .subtract(const Duration(microseconds: 1));
    return allStudents.where((s) {
      if (s.createdAt == null) return true; // بدون تاريخ → نعدّه دائمًا نشطًا
      return !s.createdAt!.isAfter(monthEnd);
    }).toList();
  }

  List<GroupMonthSummary> get groupSummaries {
    final activeStudents = _studentsActiveInMonth;
    final studentsByGroup = <int, List<Student>>{};
    for (final s in activeStudents) {
      studentsByGroup.putIfAbsent(s.groupId, () => []).add(s);
    }

    final paidByStudent = <int, double>{};
    for (final p in monthPayments) {
      paidByStudent.update(p.studentId, (v) => v + p.amount,
          ifAbsent: () => p.amount);
    }

    final presentByStudent = <int, int>{};
    for (final a in monthAttendance) {
      if (a.status == 'حاضر') {
        presentByStudent.update(a.studentId, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final m = selectedMonth.value;
    // بنستخدم PricingHelper بدل effectivePrice مباشرة عشان مجموعات "بالحصة"
    // تُحسَب بعدد الحصص المحضورة فعليًا الشهر ده، مش بسعر الحصة الواحدة
    // كأنه القيمة الشهرية الكاملة.
    double dueFor(Student st, Group group) => PricingHelper.monthlyDue(
        student: st, group: group, month: m, allAttendance: allAttendance);

    return allGroups.map((g) {
      final students = studentsByGroup[g.id] ?? [];
      final expectedIncome =
          students.fold<double>(0, (s, st) => s + dueFor(st, g));
      final collectedIncome =
          students.fold<double>(0, (s, st) => s + (paidByStudent[st.id] ?? 0));
      final fullyPaid = students.where((s) {
        final due = dueFor(s, g);
        return due > 0 && (paidByStudent[s.id] ?? 0) >= due;
      }).length;
      final totalPresent =
          students.fold<int>(0, (s, st) => s + (presentByStudent[st.id] ?? 0));
      return GroupMonthSummary(
        group: g,
        studentCount: students.length,
        expectedIncome: expectedIncome,
        collectedIncome: collectedIncome,
        fullyPaidCount: fullyPaid,
        totalPresentSessions: totalPresent,
      );
    }).toList();
  }

  // ─── تفصيل الحصص (بس للمجموعات "بالحصة") ────────────────────────────────────
  /// كل تاريخ حضور فيه الشهر ده لطلاب المجموعة دي — سطر لكل حصة، بعدد
  /// الحاضرين والمتوقع منها (سعر كل طالب حاضر × نسبة إعفائه)، عشان
  /// المدرس يتابع أول بأول بدل ما يستنى رقم شهري مجمّع في آخر الشهر.
  List<SessionDay> sessionBreakdownForGroup(int groupId) {
    final group = allGroups.firstWhereOrNull((g) => g.id == groupId);
    if (group == null || !group.isPerSession) return [];

    final students =
        _studentsActiveInMonth.where((s) => s.groupId == groupId).toList();
    final studentById = {for (final s in students) s.id: s};

    final byDate = <DateTime, List<Attendance>>{};
    for (final a in monthAttendance) {
      if (a.status != 'حاضر') continue;
      if (!studentById.containsKey(a.studentId)) continue;
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      byDate.putIfAbsent(d, () => []).add(a);
    }

    final result = byDate.entries.map((e) {
      final amount = e.value.fold<double>(0, (s, a) {
        final st = studentById[a.studentId];
        if (st == null) return s;
        return s + st.price * (1 - st.exemptPercent / 100);
      });
      return SessionDay(
          date: e.key, presentCount: e.value.length, expectedAmount: amount);
    }).toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  // ─── At-risk students (unpaid this month) ──────────────────────────────────

  List<AtRiskStudent> get unpaidStudents {
    final m = selectedMonth.value;
    final paidByStudent = <int, double>{};
    for (final p in monthPayments) {
      paidByStudent.update(p.studentId, (v) => v + p.amount,
          ifAbsent: () => p.amount);
    }
    final groupById = {for (final g in allGroups) g.id: g};
    final result = <AtRiskStudent>[];
    for (final s in _studentsActiveInMonth) {
      final due = PricingHelper.monthlyDue(
          student: s,
          group: groupById[s.groupId],
          month: m,
          allAttendance: allAttendance);
      if (due <= 0) continue;
      final paid = paidByStudent[s.id] ?? 0;
      if (paid < due) {
        result.add(AtRiskStudent(
          student: s,
          group: groupById[s.groupId],
          paid: paid,
          due: due,
          month: m,
        ));
      }
    }
    result.sort((a, b) => a.remaining.compareTo(b.remaining));
    return result;
  }

  // ─── Legacy ─────────────────────────────────────────────────────────────────

  Future<void> generateReport() async => loadReports();

  // ── تصدير PDF ─────────────────────────────────────────────────────────────

  final RxBool isExporting = false.obs;
  final _exportSvc = ExportService();

  /// تصدير تقرير الدفعات PDF
  Future<void> exportPaymentsPDF() async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء تقرير الدفعات...');
    try {
      final result = await _exportSvc.exportPaymentsPDF(
        month: selectedMonth.value,
        students: allStudents,
        payments: allPayments,
        groups: allGroups,
        attendance: allAttendance,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// تصدير تقرير الحضور PDF
  Future<void> exportAttendancePDF() async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء تقرير الحضور...');
    try {
      final result = await _exportSvc.exportAttendancePDF(
        month: selectedMonth.value,
        students: allStudents,
        attendance: allAttendance,
        groups: allGroups,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// تصدير ملخص المجموعات PDF
  Future<void> exportGroupsSummaryPDF() async {
    if (isExporting.value) return;
    isExporting(true);
    ToastHelper.info('جاري إنشاء ملخص المجموعات...');
    try {
      final result = await _exportSvc.exportGroupsSummaryPDF(
        month: selectedMonth.value,
        students: allStudents,
        payments: allPayments,
        attendance: allAttendance,
        groups: allGroups,
      );
      if (result.success && result.path != null) {
        ToastHelper.success('تم إنشاء التقرير بنجاح');
        await _exportSvc.sharePDF(result.path!);
      } else {
        ToastHelper.error(result.error ?? 'فشل إنشاء التقرير');
      }
    } catch (e) {
      ToastHelper.error('خطأ: $e');
    } finally {
      isExporting(false);
    }
  }

  /// للتوافق مع الكود القديم
  Future<void> exportPDF() => exportPaymentsPDF();

  // Keep old observables for backward compatibility
  RxInt get totalAttendance => RxInt(allAttendance.length);
  RxDouble get attendancePercentage => RxDouble(0.0);
  RxDouble get totalPayments =>
      RxDouble(allPayments.fold(0.0, (s, p) => s + p.amount));
  RxInt get paymentCount => RxInt(allPayments.length);
  RxInt get totalStudents => RxInt(allStudents.length);
  RxInt get totalGroups => RxInt(allGroups.length);
  RxList<Payment> get recentPayments => RxList(allPayments.take(10).toList());
  RxList<Attendance> get recentAttendance =>
      RxList(allAttendance.take(10).toList());
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class GroupMonthSummary {
  final Group group;
  final int studentCount;
  final double expectedIncome;
  final double collectedIncome;
  final int fullyPaidCount;
  final int totalPresentSessions;

  GroupMonthSummary({
    required this.group,
    required this.studentCount,
    required this.expectedIncome,
    required this.collectedIncome,
    required this.fullyPaidCount,
    required this.totalPresentSessions,
  });

  double get collectionRate =>
      expectedIncome == 0 ? 1.0 : collectedIncome / expectedIncome;
}

class SessionDay {
  final DateTime date;
  final int presentCount;
  final double expectedAmount;
  const SessionDay({
    required this.date,
    required this.presentCount,
    required this.expectedAmount,
  });
}

class AtRiskStudent {
  final Student student;
  final Group? group;
  final double paid;
  final double due;
  final DateTime month;

  AtRiskStudent({
    required this.student,
    required this.group,
    required this.paid,
    required this.due,
    required this.month,
  });

  double get remaining => due - paid;
}
