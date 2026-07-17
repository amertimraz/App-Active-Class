// lib/controllers/dashboard_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';

enum ActivityType { attendance, payment }

class DashboardController extends GetxController {
  final DatabaseService _db = DatabaseService();

  // ── إحصائيات عامة ────────────────────────────────────────────────────────
  final RxInt    totalGroups    = 0.obs;
  final RxInt    totalStudents  = 0.obs;
  final RxInt    exemptStudents = 0.obs;

  // ── إحصائيات الشهر الحالي ────────────────────────────────────────────────
  final RxDouble monthExpected       = 0.0.obs;
  final RxDouble monthPaid           = 0.0.obs;
  final RxDouble monthRemaining      = 0.0.obs;
  final RxDouble monthPaymentRate    = 0.0.obs;
  final RxInt    paidStudentsCount   = 0.obs;
  final RxInt    unpaidStudentsCount = 0.obs;

  // ── إحصائيات اليوم ───────────────────────────────────────────────────────
  final RxInt    todayPresent        = 0.obs;
  final RxInt    todayAbsent         = 0.obs;
  final RxInt    todayExpected       = 0.obs;
  final RxDouble todayAttendanceRate = 0.0.obs;

  // ── حالة ─────────────────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final Rx<DateTime> lastUpdated = DateTime.now().obs;

  // ── النشاط الأخير ─────────────────────────────────────────────────────────
  final RxList<RecentActivity> recentActivities = <RecentActivity>[].obs;

  // ── قائمة غير المدفوعين (للشيت) ─────────────────────────────────────────
  RxList<Student> get unpaidList => _unpaidList;
  final RxList<Student> _unpaidList = <Student>[].obs;

  // ── للتوافق مع الكود القديم ───────────────────────────────────────────────
  RxInt    get totalPaymentsInt => paidStudentsCount;
  RxInt    get todayAttendance  => todayPresent;
  RxDouble get attendanceRate   => todayAttendanceRate;
  RxInt    get paidStudents     => paidStudentsCount;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    isLoading(true);
    try {
      await Future.wait([
        _loadGeneralStats(),
        _loadMonthStats(),
        _loadTodayStats(),
        _loadRecentActivities(),
      ]);
      lastUpdated.value = DateTime.now();
    } catch (_) {
      // لا نكشف الخطأ للمستخدم — الـ UI يبقى يعمل بقيم 0
    } finally {
      isLoading(false);
    }
  }

  @override
  void refresh() => loadDashboardData();

  // ── تحميل الإحصائيات العامة ──────────────────────────────────────────────
  Future<void> _loadGeneralStats() async {
    final groups   = await _db.getAllGroups();
    final students = await _db.getAllStudents();

    totalGroups.value   = groups.length;
    totalStudents.value = students.length;
    exemptStudents.value =
        students.where((s) => s.isFullyExempt).length;
  }

  // ── تحميل إحصائيات الشهر ────────────────────────────────────────────────
  Future<void> _loadMonthStats() async {
    final now        = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd   = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1));

    final students = await _db.getAllStudents();
    final payments = await _db.getAllPayments();

    final activeStudents = students.where((s) => !s.isFullyExempt).toList();

    // المدفوعات هذا الشهر فقط
    final monthPayments = payments.where((p) =>
        !p.date.isBefore(monthStart) && !p.date.isAfter(monthEnd)).toList();

    final paidIds = monthPayments.map((p) => p.studentId).toSet();

    double expected = 0;
    double paid     = 0;
    for (final s in activeStudents) {
      if (s.isFullyExempt) continue; // معفى كلياً — لا يُحسب
      expected += s.price;
    }
    for (final p in monthPayments) {
      paid += p.amount;
    }

    monthExpected.value    = expected;
    monthPaid.value        = paid;
    monthRemaining.value   = (expected - paid).clamp(0, double.infinity);
    monthPaymentRate.value = expected > 0 ? (paid / expected).clamp(0, 1) : 0;

    paidStudentsCount.value   = paidIds.length;
    unpaidStudentsCount.value =
        activeStudents.where((s) => !paidIds.contains(s.id)).length;

    _unpaidList.assignAll(
        activeStudents.where((s) => !paidIds.contains(s.id)).toList());
  }

  // ── تحميل إحصائيات اليوم ────────────────────────────────────────────────
  Future<void> _loadTodayStats() async {
    final now        = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd   = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allAtt = await _db.getAllAttendance();
    final todayRecords = allAtt
        .where((a) =>
            !a.date.isBefore(todayStart) && !a.date.isAfter(todayEnd))
        .toList();

    final present = todayRecords
        .where((a) => a.status == ATTENDANCE_PRESENT)
        .length;
    final absent  = todayRecords
        .where((a) => a.status != ATTENDANCE_PRESENT)
        .length;
    final total   = present + absent;

    todayPresent.value        = present;
    todayAbsent.value         = absent;
    todayExpected.value       = total;
    todayAttendanceRate.value = total > 0 ? present / total : 0;
  }

  // ── تحميل النشاط الأخير ─────────────────────────────────────────────────
  Future<void> _loadRecentActivities() async {
    final activities = <RecentActivity>[];

    // آخر 5 دفعات
    final payments = await _db.getAllPayments();
    final sortedPayments = payments.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final p in sortedPayments.take(5)) {
      final student = await _db.getStudent(p.studentId);
      if (student != null) {
        activities.add(RecentActivity(
          type: ActivityType.payment,
          title: student.name,
          subtitle: 'دفع ${p.amount.toStringAsFixed(0)}',
          date: p.date,
          icon: Icons.payments_rounded,
          color: AppTheme.primaryColor,
          amount: p.amount,
        ));
      }
    }

    // آخر 5 سجلات حضور
    final attendance = await _db.getAllAttendance();
    final sortedAtt = attendance.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final a in sortedAtt.take(5)) {
      final student = await _db.getStudent(a.studentId);
      if (student != null) {
        activities.add(RecentActivity(
          type: ActivityType.attendance,
          title: student.name,
          subtitle: a.status == ATTENDANCE_PRESENT ? 'حضر' : 'غاب',
          date: a.date,
          icon: a.status == ATTENDANCE_PRESENT
              ? Icons.check_circle_rounded
              : Icons.cancel_rounded,
          color: a.status == ATTENDANCE_PRESENT
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ));
      }
    }

    // ترتيب حسب التاريخ الفعلي
    activities.sort((a, b) => b.date.compareTo(a.date));
    recentActivities.assignAll(activities.take(10));
  }

  // ── للتوافق مع الكود القديم ───────────────────────────────────────────────
  Future<Map<String, int>> getStudentsPerGroup() async {
    final groups = await _db.getAllGroups();
    final Map<String, int> result = {};
    for (final g in groups) {
      result[g.name] = await _db.getGroupStudentCount(g.id!);
    }
    return result;
  }
}

// ══════════════════════════════════════════════════════════════════
//  RecentActivity model
// ══════════════════════════════════════════════════════════════════
class RecentActivity {
  final ActivityType type;
  final String    title;
  final String    subtitle;
  final DateTime  date;
  final IconData  icon;
  final Color     color;
  final double?   amount;

  RecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.color,
    this.amount,
  });

  /// وقت نسبي مقروء
  String get timeLabel {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1)  return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours   < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays    < 7)  return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}
