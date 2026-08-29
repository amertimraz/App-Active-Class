// lib/utils/student_sort_helper.dart
//
// ترتيب قوائم الطلاب (صفحة الطلاب الرئيسية + تفاصيل المجموعة) بمعيار
// واحد من أربعة، بدل ما كل شاشة تعمل منطق ترتيب خاص بيها لوحدها.
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/pricing_helper.dart';

enum StudentSort { name, paymentStatus, attendanceRate, joinDate }

extension StudentSortExt on StudentSort {
  String get label {
    switch (this) {
      case StudentSort.name:
        return 'الاسم';
      case StudentSort.paymentStatus:
        return 'حالة الدفع';
      case StudentSort.attendanceRate:
        return 'نسبة الحضور';
      case StudentSort.joinDate:
        return 'تاريخ الانضمام';
    }
  }
}

/// بيرتّب نسخة جديدة من القائمة — القائمة الأصلية متتلمسش. [ascending] بيحدد
/// الاتجاه؛ الترتيب الطبيعي (تصاعدي) لكل معيار: الاسم أ-ي، الأقدم انضمامًا
/// الأول، الأقل مديونية الأول، الأقل نسبة حضور الأول (عشان الطالب اللي
/// محتاج متابعة يبان بسرعة لو ضغط "تنازلي" بدل كده لو حابب).
List<Student> sortStudents({
  required List<Student> students,
  required StudentSort sortBy,
  required bool ascending,
  required Group? Function(Student) groupOf,
  required List<Attendance> allAttendance,
  required List<Payment> allPayments,
}) {
  final list = List<Student>.from(students);

  if (sortBy == StudentSort.name) {
    list.sort((a, b) => a.name.compareTo(b.name));
    return ascending ? list : list.reversed.toList();
  }

  if (sortBy == StudentSort.joinDate) {
    DateTime dateOf(Student s) =>
        s.attendanceStart ?? s.createdAt ?? DateTime(1970);
    list.sort((a, b) => dateOf(a).compareTo(dateOf(b)));
    return ascending ? list : list.reversed.toList();
  }

  if (sortBy == StudentSort.paymentStatus) {
    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in allPayments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }
    final debtOf = <int?, double>{
      for (final s in list)
        s.id: PricingHelper.accumulatedDebt(
          student: s,
          group: groupOf(s),
          allAttendance: allAttendance,
          payments: paymentsByStudent[s.id] ?? const [],
        siblingGroupMembers: students,
        ),
    };
    list.sort((a, b) => (debtOf[a.id] ?? 0).compareTo(debtOf[b.id] ?? 0));
    return ascending ? list : list.reversed.toList();
  }

  // attendanceRate
  final attByStudent = <int?, List<Attendance>>{};
  for (final a in allAttendance) {
    attByStudent.putIfAbsent(a.studentId, () => []).add(a);
  }
  double rateOf(Student s) {
    final att = attByStudent[s.id];
    if (att == null || att.isEmpty) return 2.0; // مفيش سجل حضور — آخر الترتيب التصاعدي
    final present = att.where((a) => a.status == ATTENDANCE_PRESENT).length;
    return present / att.length;
  }
  final rateMap = {for (final s in list) s.id: rateOf(s)};
  list.sort((a, b) => (rateMap[a.id] ?? 2.0).compareTo(rateMap[b.id] ?? 2.0));
  return ascending ? list : list.reversed.toList();
}
