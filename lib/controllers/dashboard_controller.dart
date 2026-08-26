// lib/controllers/dashboard_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/pricing_helper.dart';

enum ActivityType { attendance, payment }

class UnpaidStudentEntry {
  final Student student;
  final double amountDue; // المديونية المتراكمة الفعلية، مش سعر حصة/شهر واحد بس
  const UnpaidStudentEntry({required this.student, required this.amountDue});
}

class TodayPaymentEntry {
  final String studentName;
  final String studentCode;
  final String groupName;
  final double amount;
  final DateTime date;

  const TodayPaymentEntry({
    required this.studentName,
    required this.studentCode,
    required this.groupName,
    required this.amount,
    required this.date,
  });
}

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

  // ── مدفوعات اليوم (كل الدفعات، أي مجموعة) ───────────────────────────────
  final RxDouble todayPaymentsTotal = 0.0.obs;
  final RxInt    todayPaymentsCount = 0.obs;
  RxList<TodayPaymentEntry> get todayPaymentsList => _todayPaymentsList;
  final RxList<TodayPaymentEntry> _todayPaymentsList = <TodayPaymentEntry>[].obs;

  // ── إيراد اليوم من المجموعات المسعّرة بالحصة ────────────────────────────
  // فعلي: من سجلات الحضور "حاضر" اللي اتسجلت النهاردة بالفعل.
  final RxDouble todaySessionRevenue      = 0.0.obs;
  final RxInt    todaySessionRevenueCount = 0.obs;
  // متوقع: كل طلاب المجموعات المسعّرة بالحصة اللي ليها حصة مجدولة النهاردة
  // (حسب جدول المجموعة الأسبوعي)، بغض النظر عن تسجيل الحضور من عدمه.
  final RxDouble todaySessionRevenueExpected      = 0.0.obs;
  final RxInt    todaySessionRevenueExpectedCount = 0.obs;

  // ── حالة ─────────────────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final Rx<DateTime> lastUpdated = DateTime.now().obs;

  // ── النشاط الأخير ─────────────────────────────────────────────────────────
  final RxList<RecentActivity> recentActivities = <RecentActivity>[].obs;

  // ── قائمة غير المدفوعين (للشيت) ─────────────────────────────────────────
  RxList<UnpaidStudentEntry> get unpaidList => _unpaidList;
  final RxList<UnpaidStudentEntry> _unpaidList = <UnpaidStudentEntry>[].obs;

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
    final groups   = await _db.getAllGroups();
    final groupById = {for (final g in groups) g.id: g};

    final att = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());
    if (att.attendance.isEmpty) await att.loadAttendance();

    final activeStudents = students.where((s) => !s.isFullyExempt).toList();

    // المدفوعات هذا الشهر فقط
    final monthPayments = payments.where((p) =>
        !p.date.isBefore(monthStart) && !p.date.isAfter(monthEnd)).toList();

    // كل مدفوعات كل طالب (بغض النظر عن تاريخها) — عشان قائمة "لم يدفعوا"
    // تعتمد على المديونية المتراكمة الفعلية (PricingHelper.isOverdue)
    // بدل مقارنة مدفوعات الشهر ده بس بمستحق الشهر ده بس، اللي كان بيوهم
    // إن طالب دافع مقدَّمًا الشهر اللي فات "لسه مايدفعش".
    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in payments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    // مهلة السماح — بتأخّر ظهور الطالب في قائمة "لم يدفعوا هذا الشهر"
    // بس (مش حساب الإجمالي المتوقع/المحصّل، اللي المفروض يفضل دقيق).
    final graceDays = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>().paymentGraceDays.value
        : 0;

    double expected = 0;
    double paid     = 0;
    final unpaidStudents = <UnpaidStudentEntry>[];
    for (final s in activeStudents) {
      final group = groupById[s.groupId];
      final due = PricingHelper.monthlyDue(
        student: s,
        group: group,
        month: monthStart,
        allAttendance: att.attendance,
      );
      expected += due;
      final studentPayments = paymentsByStudent[s.id] ?? const [];
      final isOverdue = PricingHelper.isOverdue(
        student: s,
        group: group,
        allAttendance: att.attendance,
        payments: studentPayments,
        graceDays: graceDays,
      );
      if (isOverdue) {
        // المديونية المتراكمة الفعلية (كل الشهور غير المدفوعة)، مش سعر
        // حصة/شهر واحد بس — طالب عليه حصتين أو تلاتة كان بيظهر بنفس
        // مبلغ طالب عليه حصة واحدة بس.
        final accumulatedDebt = PricingHelper.accumulatedDebt(
          student: s,
          group: group,
          allAttendance: att.attendance,
          payments: studentPayments,
        );
        unpaidStudents
            .add(UnpaidStudentEntry(student: s, amountDue: accumulatedDebt));
      }
    }
    for (final p in monthPayments) {
      paid += p.amount;
    }

    monthExpected.value    = expected;
    monthPaid.value        = paid;
    monthRemaining.value   = (expected - paid).clamp(0, double.infinity);
    monthPaymentRate.value = expected > 0 ? (paid / expected).clamp(0, 1) : 0;

    paidStudentsCount.value   = activeStudents.length - unpaidStudents.length;
    unpaidStudentsCount.value = unpaidStudents.length;

    _unpaidList.assignAll(unpaidStudents);
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

    // المتوقع = كل طلاب المجموعات اللي ليها حصة مجدولة النهاردة (بصرف النظر
    // عن سجلات الحضور اللي اتسجلت لحد دلوقتي)، مش عدد السجلات المُدخَلة.
    // ملحوظة: الإعفاء (isFullyExempt) خاص بالرسوم بس ومالوش دعوة بالحضور.
    final groups   = await _db.getAllGroups();
    final students = await _db.getAllStudents();
    final att = Get.isRegistered<AttendanceController>()
        ? Get.find<AttendanceController>()
        : Get.put(AttendanceController());
    final scheduledTodayIds =
        att.groupsForDay(groups, now).map((g) => g.id).toSet();
    final total = scheduledTodayIds.isEmpty
        ? 0
        : students.where((s) => scheduledTodayIds.contains(s.groupId)).length;

    todayPresent.value        = present;
    todayAbsent.value         = absent;
    todayExpected.value       = total;
    todayAttendanceRate.value = total > 0 ? present / total : 0;

    // مدفوعات اليوم — كل الدفعات المسجَّلة النهاردة بصرف النظر عن نوع
    // تسعير مجموعة الطالب (شهري أو بالحصة).
    final payments = await _db.getAllPayments();
    final todayPayments = payments
        .where((p) => !p.date.isBefore(todayStart) && !p.date.isAfter(todayEnd))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    todayPaymentsTotal.value = todayPayments.fold(0.0, (sum, p) => sum + p.amount);
    todayPaymentsCount.value = todayPayments.length;

    final studentsById = {for (final s in students) s.id: s};
    final groupById = {for (final g in groups) g.id: g};
    _todayPaymentsList.assignAll(todayPayments.map((p) {
      final s = studentsById[p.studentId];
      final g = s != null ? groupById[s.groupId] : null;
      return TodayPaymentEntry(
        studentName: s?.name ?? 'طالب محذوف',
        studentCode: s?.code ?? '-',
        groupName: g?.name ?? '-',
        amount: p.amount,
        date: p.date,
      );
    }));

    // إيراد اليوم من المجموعات بالحصة — فعلي (من الدفعات المحصّلة فعلاً
    // النهاردة) ومتوقع (من كل طلاب المجموعات اللي ليها حصة مجدولة النهاردة).
    final perSessionGroups = groups.where((g) => g.isPerSession).toList();
    final perSessionGroupIds = perSessionGroups.map((g) => g.id).toSet();

    double actualRevenue = 0;
    int actualCount = 0;
    double expectedRevenue = 0;
    int expectedCount = 0;

    if (perSessionGroupIds.isNotEmpty) {
      // فعلي: مجموع الدفعات المسجَّلة النهاردة لطلاب المجموعات بالحصة —
      // ده "المحصّل" الحقيقي (كاش دخل)، مش استحقاق نظري من الحضور بس.
      for (final p in todayPayments) {
        final s = studentsById[p.studentId];
        if (s == null || !perSessionGroupIds.contains(s.groupId)) continue;
        actualRevenue += p.amount;
        actualCount += 1;
      }

      final scheduledTodayPerSessionIds = scheduledTodayIds
          .intersection(perSessionGroupIds);
      if (scheduledTodayPerSessionIds.isNotEmpty) {
        for (final s in students) {
          if (!scheduledTodayPerSessionIds.contains(s.groupId)) continue;
          if (s.isFullyExempt) continue;
          expectedRevenue += s.effectivePrice;
          expectedCount += 1;
        }
      }
    }

    todaySessionRevenue.value              = actualRevenue;
    todaySessionRevenueCount.value         = actualCount;
    todaySessionRevenueExpected.value      = expectedRevenue;
    todaySessionRevenueExpectedCount.value = expectedCount;
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
