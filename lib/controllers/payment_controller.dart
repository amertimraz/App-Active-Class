// lib/controllers/payment_controller.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/session_log_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/pricing_helper.dart';

// spec 038 — دالة صرفة (بلا DB/GetX) بتحضّر عملية إسقاط مديونية: بتعيد
// حساب accumulatedDebt لحظة الاستدعاء وتقرر هل ممكن ينفّذ الإسقاط ولا
// لأ. مستخرَجة عشان تتاختبر مباشرة بدون لمس قاعدة البيانات (زي
// computeMonthlyBreakdown في dashboard_controller.dart).
class DebtWriteOffResult {
  final double amount;
  final String? errorMessage;

  const DebtWriteOffResult({required this.amount, this.errorMessage});

  bool get canProceed => errorMessage == null;
}

DebtWriteOffResult prepareDebtWriteOff({
  required Student student,
  required Group? group,
  required List<Attendance> allAttendance,
  required List<Payment> payments,
  List<Student>? siblingGroupMembers,
}) {
  final debt = PricingHelper.accumulatedDebt(
    student: student,
    group: group,
    allAttendance: allAttendance,
    payments: payments,
    siblingGroupMembers: siblingGroupMembers,
  );
  if (debt <= 0) {
    return const DebtWriteOffResult(
      amount: 0,
      errorMessage: 'لا توجد مديونية متبقية على هذا الطالب حاليًا',
    );
  }
  return DebtWriteOffResult(amount: debt);
}

class PaymentController extends GetxController {
  final DatabaseService _dbService = DatabaseService();

  // Data
  final RxList<Payment> payments = <Payment>[].obs;
  final RxList<Payment> filteredPayments = <Payment>[].obs;

  // State
  final RxBool isLoading = false.obs;
  // صار true بعد أول تحميل ناجح — عشان أي واجهة تعتمد على المديونية
  // (تنبيه المتأخر spec 029) متعرضش أرقام غلط قبل ما الدفعات تتحمّل.
  final RxBool loadedOnce = false.obs;
  final RxDouble totalPayments = 0.0.obs;
  // spec 038 — يمنع تنفيذ إسقاط مديونية متكرر لنفس الطالب بضغطة
  // متكررة سريعة على الزرار قبل ما العملية الأولى تخلص (FR-009).
  final RxBool writeOffBusy = false.obs;

  // Filters & Sorting
  final Rx<DateTimeRange?> dateRange = Rx<DateTimeRange?>(null);
  final RxBool sortByDateDesc = true.obs;
  final RxBool sortByAmountAsc = false.obs;
  final RxString searchName = ''.obs;

  // Extra UI filters (used by view)
  final Rxn<int> selectedGroupId = Rxn<int>();
  final Rx<DateTime?> selectedMonth = Rx<DateTime?>(null);
  final RxString statusFilter = 'الكل'.obs;

  String? Function(int)? _studentNameById;

  Future<void> loadPayments() async {
    isLoading(true);
    try {
      final loadedPayments = await _dbService.getAllPayments();
      payments.assignAll(loadedPayments);
      _applyFilter();
      calculateTotalPayments();
      loadedOnce.value = true;
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل المدفوعات');
    } finally {
      isLoading(false);
    }
  }

  void calculateTotalPayments() {
    totalPayments.value = payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  void bindStudentNameResolver(String? Function(int) resolver) {
    _studentNameById = resolver;
    _applyFilter();
  }

  void setDateRange(DateTimeRange? range) {
    dateRange.value = range;
    _applyFilter();
  }

  void toggleSortByDate() {
    sortByDateDesc.toggle();
    _applyFilter();
  }

  void toggleSortByAmount() {
    sortByAmountAsc.toggle();
    _applyFilter();
  }

  void filterByStudentName(String name) {
    searchName.value = name.trim();
    _applyFilter();
  }

  void setGroupFilter(int? groupId) {
    selectedGroupId.value = groupId;
  }

  void setMonth(DateTime? monthStart) {
    selectedMonth.value = monthStart;
  }

  void setStatusFilter(String status) {
    statusFilter.value = status;
  }

  void _applyFilter() {
    var list = List<Payment>.from(payments);

    final r = dateRange.value;
    if (r != null) {
      list = list.where((p) => !_isBefore(p.date, r.start) && !_isAfter(p.date, r.end)).toList();
    }

    final q = searchName.value;
    if (q.isNotEmpty && _studentNameById != null) {
      final qq = q.toLowerCase();
      list = list.where((p) => (_studentNameById!(p.studentId) ?? '').toLowerCase().contains(qq)).toList();
    }

    list.sort((a, b) => sortByDateDesc.value ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    if (sortByAmountAsc.value) {
      list.sort((a, b) => a.amount.compareTo(b.amount));
    }

    filteredPayments.assignAll(list);
  }

  bool _isBefore(DateTime a, DateTime b) => a.isBefore(b);
  bool _isAfter(DateTime a, DateTime b) => a.isAfter(b);

  Future<void> addPayment(Payment payment) async {
    try {
      await _dbService.insertPayment(payment);
      await loadPayments();
      _refreshDashboard();
      unawaited(ParentPortalService().pushStudentSummary(payment.studentId));
      // بدون كده، تذكير "الدفع المتأخر" كان بيفضل بعدده القديم لحد ما
      // حد يعدّل مجموعة/طالب — دفعة جديدة/محذوفة هي أكتر حدث بيغيّر
      // "مين متأخر" فعليًا، ومكانش بيحصّل تحديث خالص.
      unawaited(NotificationService().scheduleLatePaymentReminder());
      ToastHelper.success('تم إضافة الدفع بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في إضافة الدفع');
    }
  }

  /// يعدّل دفعة موجودة. بيرجّع true لو نجح — الشاشة المستدعية مسؤولة
  /// عن إظهار رسالة النجاح، عشان ميحصلش "تم الحفظ" وهمي لو الحفظ فشل.
  Future<bool> updatePayment(Payment payment) async {
    try {
      await _dbService.updatePayment(payment);
      await loadPayments();
      _refreshDashboard();
      unawaited(ParentPortalService().pushStudentSummary(payment.studentId));
      unawaited(NotificationService().scheduleLatePaymentReminder());
      return true;
    } catch (e) {
      ToastHelper.error('حدث خطأ في تعديل الدفعة');
      return false;
    }
  }

  Future<void> deletePayment(int id) async {
    try {
      final studentId =
          payments.firstWhereOrNull((p) => p.id == id)?.studentId;
      await _dbService.deletePayment(id);
      await loadPayments();
      _refreshDashboard();
      if (studentId != null) {
        unawaited(ParentPortalService().pushStudentSummary(studentId));
      }
      unawaited(NotificationService().scheduleLatePaymentReminder());
      // شيل الدفعة المحذوفة من قايمة "دفعوا اليوم" (شاشة تسجيل الدفع)
      // لو كانت ظاهرة فيها — من غيره تفضل ظاهرة لحد ما التطبيق يتقفل.
      if (Get.isRegistered<SessionLogController>()) {
        Get.find<SessionLogController>().removeByPaymentId(id);
      }
      ToastHelper.success('تم حذف الدفع بنجاح');
    } catch (e) {
      ToastHelper.error('حدث خطأ في حذف الدفع');
    }
  }

  /// spec 038 — يسجّل عملية "إسقاط مديونية" للطالب المُعطى: دفعة بمبلغ
  /// يساوي accumulatedDebt الحالية (مُعادة الحساب هنا لحظة الاستدعاء
  /// نفسها، مش قيمة جاهزة مُمرَّرة من الشاشة — راجع research.md #2)،
  /// موسومة بـ kDebtWriteOffNote عشان تتفرق عن دفعة نقدية فعلية.
  /// بترجع null لو نجحت، أو رسالة خطأ بالعربي لو اتلغت (مديونية صفر
  /// أو أقل وقت التنفيذ — FR-010).
  Future<String?> writeOffDebt({
    required Student student,
    required Group? group,
    required List<Attendance> allAttendance,
    required List<Payment> payments,
    List<Student>? siblingGroupMembers,
  }) async {
    if (writeOffBusy.value) return 'في عملية إسقاط جارية بالفعل';
    writeOffBusy.value = true;
    try {
      final prepared = prepareDebtWriteOff(
        student: student,
        group: group,
        allAttendance: allAttendance,
        payments: payments,
        siblingGroupMembers: siblingGroupMembers,
      );
      if (!prepared.canProceed) {
        return prepared.errorMessage;
      }
      final payment = Payment(
        studentId: student.id!,
        date: DateTime.now(),
        amount: prepared.amount,
        note: kDebtWriteOffNote,
      );
      await _dbService.insertPayment(payment);
      await loadPayments();
      _refreshDashboard();
      unawaited(ParentPortalService().pushStudentSummary(student.id!));
      unawaited(NotificationService().scheduleLatePaymentReminder());
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء إسقاط المديونية';
    } finally {
      writeOffBusy.value = false;
    }
  }

  void _refreshDashboard() {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().loadDashboardData();
    }
  }

  Future<String> getStudentName(int studentId) async {
    final student = await _dbService.getStudent(studentId);
    return student?.name ?? 'طالب غير معروف';
  }
}
