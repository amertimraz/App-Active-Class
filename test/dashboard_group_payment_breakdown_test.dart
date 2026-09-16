// test/dashboard_group_payment_breakdown_test.dart
//
// وحدة لـ computeMonthlyBreakdown (spec 036) — الدالة الصرفة المستخرَجة
// من DashboardController._computePaymentCardBody. بتتأكد إن:
// - مجموع remaining لكل مجموعة = remaining الإجمالي (SC-002).
// - الترتيب تنازلي حسب الباقي (FR-005).
// - مجموعة مستحقها صفر (معفيين بالكامل) مُستبعدة (FR-006).
// - طلاب بلا مجموعة حقيقية (groupId مالهوش Group مطابق) يتجمّعوا تحت
//   "بلا مجموعة" (FR-007).
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PricingHelper.billingArrears = false;
    PricingHelper.prorateFirstMonth = false;
  });

  final month = DateTime(2026, 9, 1);
  final prevMonth = DateTime(2026, 8, 1);
  final joined = DateTime(2026, 1, 1);

  final groupA = Group(id: 1, name: 'مجموعة أ', pricingType: GroupPricingType.monthly);
  final groupB = Group(id: 2, name: 'مجموعة ب', pricingType: GroupPricingType.monthly);
  final groupById = {1: groupA, 2: groupB};

  Student student(int id, int groupId, double price, {double exempt = 0}) => Student(
        id: id,
        name: 'طالب $id',
        code: 'S$id',
        groupId: groupId,
        price: price,
        exemptPercent: exempt,
        attendanceStart: joined,
      );

  Payment payment(int studentId, double amount) =>
      Payment(studentId: studentId, date: prevMonth, amount: amount);

  test('مجموع remaining لكل المجموعات = remaining الإجمالي', () {
    final students = [
      student(1, 1, 200), // مجموعة أ — بلا دفعات (200 متأخر)
      student(2, 1, 200), // مجموعة أ — دفع كامل من شهر سابق (متأخر 200 للشهرين معًا لكن هنركّز على الشهر ده)
      student(3, 2, 100), // مجموعة ب — دفع جزئي
    ];
    final payments = [
      payment(2, 400), // يغطي أغسطس + سبتمبر بالكامل لـS2
      payment(3, 50), // يغطي نص سبتمبر لـS3 (بعد تغطية أغسطس... مبسّط هنا لطالب جديد الانضمام)
    ];
    final paymentsByStudent = <int, List<Payment>>{};
    for (final p in payments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    final result = computeMonthlyBreakdown(
      students: students,
      paymentsByStudent: paymentsByStudent,
      groupById: groupById,
      allAttendance: const [],
      month: month,
      prevMonth: prevMonth,
    );

    final sumRemaining =
        result.groupBreakdown.fold<double>(0, (s, g) => s + g.remaining);
    final totalRemaining = (result.expected - result.collected)
        .clamp(0.0, double.infinity)
        .toDouble();
    expect(sumRemaining, closeTo(totalRemaining, 0.01));
  });

  test('الترتيب تنازلي حسب الباقي', () {
    final students = [
      student(1, 1, 100), // مجموعة أ — باقي 100
      student(2, 2, 300), // مجموعة ب — باقي 300
    ];
    final result = computeMonthlyBreakdown(
      students: students,
      paymentsByStudent: const {},
      groupById: groupById,
      allAttendance: const [],
      month: month,
      prevMonth: prevMonth,
    );

    expect(result.groupBreakdown.length, 2);
    expect(result.groupBreakdown.first.groupId, 2); // الأكبر باقي أولاً
    expect(result.groupBreakdown.last.groupId, 1);
  });

  test('مجموعة كل أعضائها معفيين بالكامل مُستبعدة (FR-006)', () {
    final students = [
      student(1, 1, 200, exempt: 100), // معفى بالكامل
      student(2, 2, 150),
    ];
    final result = computeMonthlyBreakdown(
      students: students,
      paymentsByStudent: const {},
      groupById: groupById,
      allAttendance: const [],
      month: month,
      prevMonth: prevMonth,
    );

    expect(result.groupBreakdown.any((g) => g.groupId == 1), isFalse);
    expect(result.groupBreakdown.any((g) => g.groupId == 2), isTrue);
  });

  test('طالب بلا مجموعة حقيقية يتجمّع تحت "بلا مجموعة" (FR-007)', () {
    final students = [
      student(1, 99, 200), // groupId=99 مفيهوش Group مطابق في groupById
    ];
    final result = computeMonthlyBreakdown(
      students: students,
      paymentsByStudent: const {},
      groupById: groupById, // مفيهوش مفتاح 99
      allAttendance: const [],
      month: month,
      prevMonth: prevMonth,
    );

    expect(result.groupBreakdown.length, 1);
    expect(result.groupBreakdown.first.groupName, 'بلا مجموعة');
  });
}
