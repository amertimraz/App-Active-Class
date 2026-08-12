// lib/utils/pricing_helper.dart
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';

/// حساب المستحق الشهري على طالب، مراعيًا نوع تسعير مجموعته:
/// - شهري: سعر ثابت (زي ما كان دايمًا).
/// - بالحصة: سعر الحصة الواحدة × عدد الحصص اللي حضرها الطالب فعليًا
///   في الشهر المطلوب (من سجل الحضور)، ثم تُطبَّق نسبة الإعفاء لو موجودة.
class PricingHelper {
  static double monthlyDue({
    required Student student,
    required Group? group,
    required DateTime month,
    required List<Attendance> allAttendance,
  }) {
    if (student.isFullyExempt) return 0;

    final double base;
    if (group != null && group.isPerSession) {
      final sessionsAttended = allAttendance
          .where((a) =>
              a.studentId == student.id &&
              a.status == ATTENDANCE_PRESENT &&
              a.date.year == month.year &&
              a.date.month == month.month)
          .length;
      base = student.price * sessionsAttended;
    } else {
      base = student.price;
    }

    return base * (1 - student.exemptPercent / 100);
  }
}
