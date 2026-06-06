// lib/controllers/dashboard_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/config/theme.dart';

class DashboardController extends GetxController {
  final DatabaseService _dbService = DatabaseService();

  // Statistics
  final RxInt totalGroups = 0.obs;
  final RxInt totalStudents = 0.obs;
  final RxDouble totalPayments = 0.0.obs;
  final RxInt todayAttendance = 0.obs;
  final RxInt todayAbsent = 0.obs;
  final RxDouble attendanceRate = 0.0.obs;
  final RxMap<String, int> studentsPerGroup = <String, int>{}.obs;
  final RxInt lateStudents = 0.obs; // عدد المتأخرين
  final RxInt paidStudents = 0.obs; // عدد من دفعوا
  final RxList<RecentActivity> recentActivities = <RecentActivity>[].obs; // آخر العمليات

  // Today's date
  final Rx<DateTime> todayDate = DateTime.now().obs;

  // Loading state
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    isLoading(true);
    try {
      await Future.wait([
        _loadTotalGroups(),
        _loadTotalStudents(),
        _loadTotalPayments(),
        _loadTodayAttendance(),
        _loadStudentsPerGroup(),
        _loadLateStudents(),
        _loadPaidStudents(),
        _loadRecentActivities(),
      ]);
      _calculateAttendanceRate();
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> _loadTotalGroups() async {
    final groups = await _dbService.getAllGroups();
    totalGroups.value = groups.length;
  }

  Future<void> _loadTotalStudents() async {
    final students = await _dbService.getAllStudents();
    totalStudents.value = students.length;
  }

  Future<void> _loadTotalPayments() async {
    final payments = await _dbService.getAllPayments();
    final total = payments.fold<double>(0.0, (sum, payment) => sum + (payment.amount as double));
    totalPayments.value = total;
  }

  Future<void> _loadTodayAttendance() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allAttendance = await _dbService.getAllAttendance();
    
    final todayRecords = allAttendance.where((att) {
      return !att.date.isBefore(todayStart) && !att.date.isAfter(todayEnd);
    }).toList();

    todayAttendance.value = todayRecords.where((att) => att.status == 'حاضر').length;
    todayAbsent.value = todayRecords.where((att) => att.status == 'غائب').length;
  }

  void _calculateAttendanceRate() {
    final total = todayAttendance.value + todayAbsent.value;
    if (total > 0) {
      attendanceRate.value = (todayAttendance.value / total) * 100;
    } else {
      attendanceRate.value = 0.0;
    }
  }

  Future<void> _loadStudentsPerGroup() async {
    final data = await getStudentsPerGroup();
    studentsPerGroup.value = data;
  }

  Future<Map<String, int>> getStudentsPerGroup() async {
    final groups = await _dbService.getAllGroups();
    final Map<String, int> result = {};
    
    for (final group in groups) {
      final count = await _dbService.getGroupStudentCount(group.id!);
      result[group.name] = count;
    }
    
    return result;
  }

  Future<double> getPaymentsThisMonth() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));

    final allPayments = await _dbService.getAllPayments();
    
    final thisMonthPayments = allPayments.where((payment) {
      return !payment.date.isBefore(monthStart) && !payment.date.isAfter(monthEnd);
    }).toList();

    return thisMonthPayments.fold<double>(0.0, (sum, payment) => sum + (payment.amount as double));
  }

  void refresh() {
    loadDashboardData();
  }

  Future<void> _loadLateStudents() async {
    // حساب عدد الطلاب المتأخرين في الدفع
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    final allStudents = await _dbService.getAllStudents();
    lateStudents.value = allStudents.length;
  }

  Future<void> _loadPaidStudents() async {
    // حساب عدد الطلاب الذين دفعوا هذا الشهر
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));

    final allPayments = await _dbService.getAllPayments();
    final thisMonthPayments = allPayments.where((payment) {
      return !payment.date.isBefore(monthStart) && !payment.date.isAfter(monthEnd);
    }).toList();

    // حساب عدد الطلاب الفريدين الذين دفعوا
    final paidStudentIds = thisMonthPayments.map((p) => p.studentId).toSet();
    paidStudents.value = paidStudentIds.length;
  }

  Future<void> _loadRecentActivities() async {
    // تحميل آخر 10 عمليات
    final activities = <RecentActivity>[];
    
    // آخر الحضور
    final allAttendance = await _dbService.getAllAttendance();
    final recentAttendance = allAttendance.take(5).toList();
    for (final att in recentAttendance) {
      final student = await _dbService.getStudent(att.studentId);
      if (student != null) {
        activities.add(RecentActivity(
          type: 'attendance',
          title: student.name,
          subtitle: att.status == 'حاضر' ? 'حضر اليوم' : 'غاب اليوم',
          time: _formatTime(att.date),
          icon: att.status == 'حاضر' ? Icons.check_circle : Icons.cancel,
          color: att.status == 'حاضر' ? AppTheme.successColor : AppTheme.errorColor,
        ));
      }
    }

    // آخر المدفوعات
    final allPayments = await _dbService.getAllPayments();
    final recentPayments = allPayments.take(5).toList();
    for (final payment in recentPayments) {
      final student = await _dbService.getStudent(payment.studentId);
      if (student != null) {
        activities.add(RecentActivity(
          type: 'payment',
          title: student.name,
          subtitle: 'دفع ${payment.amount.toStringAsFixed(0)} ر.س',
          time: _formatTime(payment.date),
          icon: Icons.payments,
          color: AppTheme.primaryColor,
        ));
      }
    }

    // ترتيب حسب الوقت
    activities.sort((a, b) => b.time.compareTo(a.time));
    recentActivities.value = activities.take(10).toList();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class RecentActivity {
  final String type; // 'attendance' or 'payment'
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  RecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}
