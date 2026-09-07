// lib/widgets/overdue_warning_badge.dart
//
// شارة/شريط "متأخر في الدفع" يظهر جنب اسم الطالب في شاشات الحضور
// (spec 029). بصري بحت — بلا onTap، بلا سلوك، لا يمنع أي شيء.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/pricing_helper.dart';

class OverdueWarningBadge extends StatelessWidget {
  const OverdueWarningBadge({
    super.key,
    required this.debtAmount,
    this.compact = false,
  });

  /// قيمة المديونية المتراكمة الحقيقية للطالب (تُعرَض في التنبيه).
  final double debtAmount;

  /// نسخة صغيرة لصفوف القوائم (attendance_page).
  final bool compact;

  static const _red = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, size: 11, color: _red),
          const SizedBox(width: 3),
          Text(
            'متأخر ${FormatHelper.formatCurrencyCompact(debtAmount)}',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _red),
          ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: _red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'متأخر في الدفع • مديونية ${FormatHelper.formatCurrency(debtAmount)}',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _red),
          ),
        ),
      ]),
    );
  }
}

/// يحسب قرار "متأخر في الدفع" لطالب (spec 029) عبر PricingHelper
/// ويعرض [OverdueWarningBadge] أو لا شيء. يحلّ كل الاعتماديات عبر Get
/// (SettingsController + PaymentController + AttendanceController +
/// StudentController + GroupController). Obx → يتحدّث لو اتسجّلت دفعة
/// والشاشة مفتوحة. يعتمد على PaymentController.loadPayments وقت فتح
/// الشاشة.
class OverdueWarningFor extends StatelessWidget {
  const OverdueWarningFor({super.key, required this.student, this.compact = false});

  final Student student;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SettingsController>() ||
        !Get.isRegistered<PaymentController>() ||
        !Get.isRegistered<AttendanceController>() ||
        !Get.isRegistered<StudentController>() ||
        !Get.isRegistered<GroupController>()) {
      return const SizedBox.shrink();
    }
    final settings = Get.find<SettingsController>();
    final payCtrl = Get.find<PaymentController>();
    final attCtrl = Get.find<AttendanceController>();
    final students = Get.find<StudentController>().students;
    final groups = Get.find<GroupController>().groups;

    return Obx(() {
      if (!settings.attendanceOverdueWarning.value) {
        return const SizedBox.shrink();
      }
      final group =
          groups.firstWhereOrNull((g) => g.id == student.groupId);
      final show = PricingHelper.showsAttendanceOverdueWarning(
        student: student,
        group: group,
        allAttendance: attCtrl.attendance,
        payments: payCtrl.payments,
        graceDays: settings.paymentGraceDays.value,
        siblingGroupMembers: students,
      );
      if (!show) return const SizedBox.shrink();
      final debt = PricingHelper.accumulatedDebt(
        student: student,
        group: group,
        allAttendance: attCtrl.attendance,
        payments: payCtrl.payments,
        siblingGroupMembers: students,
      );
      return OverdueWarningBadge(debtAmount: debt, compact: compact);
    });
  }
}
