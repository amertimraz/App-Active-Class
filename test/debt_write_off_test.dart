// test/debt_write_off_test.dart
//
// وحدة لـ prepareDebtWriteOff (spec 038) — الدالة الصرفة المستخرَجة من
// PaymentController.writeOffDebt. بتتأكد إن:
// - طالب عليه مديونية → المبلغ المحسوب صحيح وقابل للتنفيذ.
// - طالب مديونيته صفر → العملية تتلغي برسالة واضحة (FR-010).
// - المديونية بتُحسب صح مع الإعفاء الجزئي وحصص الإخوة.
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/payment_controller.dart';
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

  // تاريخ انضمام = أول الشهر الحالي، عشان accumulatedDebt (اللي بتحسب
  // "لحد النهاردة" دايمًا) تحتسب شهر واحد بس، والاختبار يفضل حتمي
  // بغض النظر عن تاريخ تشغيله.
  final now = DateTime.now();
  final joined = DateTime(now.year, now.month, 1);
  final group = Group(id: 1, name: 'مجموعة أ', pricingType: GroupPricingType.monthly);

  Student student(int id, {double price = 200, double exempt = 0}) => Student(
        id: id,
        name: 'طالب $id',
        code: 'S$id',
        groupId: group.id!,
        price: price,
        exemptPercent: exempt,
        attendanceStart: joined,
      );

  test('طالب عليه مديونية 100 جنيه → المبلغ المحسوب صحيح وقابل للتنفيذ', () {
    // شهر واحد مستحق (200) ودفعة 100 → متبقي 100.
    final s = student(1);
    final payments = [
      Payment(studentId: 1, date: joined, amount: 100),
    ];

    final result = prepareDebtWriteOff(
      student: s,
      group: group,
      allAttendance: const [],
      payments: payments,
    );

    expect(result.canProceed, isTrue);
    expect(result.amount, closeTo(100, 0.01));
  });

  test('طالب مديونيته صفر بالفعل → العملية تُلغى برسالة خطأ واضحة', () {
    final s = student(2);
    // دفعة تغطي كل المستحق لحد شهر الانضمام (شهر واحد فقط، بدون تراكم).
    final payments = [
      Payment(studentId: 2, date: joined, amount: 5000),
    ];

    final result = prepareDebtWriteOff(
      student: s,
      group: group,
      allAttendance: const [],
      payments: payments,
    );

    expect(result.canProceed, isFalse);
    expect(result.errorMessage, isNotNull);
    expect(result.errorMessage, isNotEmpty);
    expect(result.amount, 0);
  });

  test('الصف الناتج المفترض من الإسقاط يحمل kDebtWriteOffNote بالضبط', () {
    final s = student(3);
    final payments = <Payment>[];

    final result = prepareDebtWriteOff(
      student: s,
      group: group,
      allAttendance: const [],
      payments: payments,
    );
    expect(result.canProceed, isTrue);

    final writeOffPayment = Payment(
      studentId: s.id!,
      date: DateTime.now(),
      amount: result.amount,
      note: kDebtWriteOffNote,
    );

    expect(writeOffPayment.note, 'إسقاط مديونية');
    expect(writeOffPayment.note, kDebtWriteOffNote);
  });

  test('طالب معفى جزئيًا (50%) → المبلغ المُسقَط بعد تطبيق الإعفاء لا قبله', () {
    // سعر 200 بإعفاء 50% = مستحق فعلي 100 للشهر الحالي بدون دفعات.
    final s = student(4, price: 200, exempt: 50);

    final result = prepareDebtWriteOff(
      student: s,
      group: group,
      allAttendance: const [],
      payments: const [],
    );

    expect(result.canProceed, isTrue);
    expect(result.amount, closeTo(100, 0.01)); // مش 200 (السعر الكامل)
  });
}
