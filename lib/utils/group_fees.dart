// lib/utils/group_fees.dart
//
// المستحق الشهري لطلاب مجموعة — مصدر واحد للأرقام اللي بتظهر في رأس «تفاصيل
// المجموعة» (إجمالي الرسوم) وفي موديل «رسوم الشهر». كانوا بيحسبوا كل واحد
// لوحده فكان الرقمين بيختلفوا (شهر مختلف، وفلتر بداية الحضور، وعدد الإخوة).
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

class GroupFees {
  /// المستحق عن شهر [month] لكل طالب في [students] (مفتاح = رقم الطالب).
  ///
  /// - الطالب اللي بدأ حضوره بعد الشهر ده مش بيدخل الحساب.
  /// - [siblingGroupMembers] لازم تكون **كل** طلاب التطبيق (مش مجموعة واحدة)
  ///   عشان نصيب الإخوة يتقسّم على العدد الفعلي حتى لو الأخ في مجموعة تانية.
  static Map<int, double> dueByStudent({
    required List<Student> students,
    required Group group,
    required DateTime month,
    required List<Attendance> attendance,
    required List<Student> siblingGroupMembers,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final result = <int, double>{};
    for (final s in students) {
      final id = s.id;
      if (id == null) continue;
      final st = s.attendanceStart;
      if (st != null && DateTime(st.year, st.month, 1).isAfter(monthStart)) {
        continue;
      }
      result[id] = PricingHelper.monthlyDue(
        student: s,
        group: group,
        month: monthStart,
        allAttendance: attendance,
        siblingGroupMembers: siblingGroupMembers,
      );
    }
    return result;
  }

  static double total(Map<int, double> dueById) =>
      dueById.values.fold<double>(0, (a, b) => a + b);
}
