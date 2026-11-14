// test/income_summary_test.dart — «دخلي الشهر ده»: الكاش بتاريخ الدفعة، من غير
// توزيع على الشهور ومن غير إسقاط المديونية، + كراسات + مصاريف + مقارنة.
import 'package:flutter_test/flutter_test.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/expense_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/utils/income_summary.dart';

Payment _p(int id, int student, double amount, DateTime date,
        {PaymentKind? kind}) =>
    Payment(
        id: id,
        studentId: student,
        amount: amount,
        date: date,
        storedKind: kind);

BookletPayment _b(int student, double amount, DateTime date) => BookletPayment(
    bookletId: 1, studentId: student, amount: amount, date: date);

void main() {
  final nov = DateTime(2026, 11, 1);
  final groups = {1: 10, 2: 10, 3: 20};

  test('الكاش بتاريخ الدفعة: دفعة نوفمبر بتتحسب في نوفمبر حتى لو غطّت شهر قديم', () {
    final s = computeIncome(
      month: nov,
      payments: [
        _p(1, 1, 300, DateTime(2026, 11, 3)), // نوفمبر
        _p(2, 2, 600, DateTime(2026, 10, 30)), // أكتوبر — مش في نوفمبر
        _p(3, 3, 200, DateTime(2026, 12, 1)), // ديسمبر — مش في نوفمبر
      ],
      bookletPayments: const [],
      groupOfStudent: groups,
    );
    expect(s.tuition, 300);
    expect(s.total, 300);
    expect(s.count, 1);
  });

  test('إسقاط المديونية مش دخل', () {
    final s = computeIncome(
      month: nov,
      payments: [
        _p(1, 1, 300, DateTime(2026, 11, 3)),
        _p(2, 2, 150, DateTime(2026, 11, 4), kind: PaymentKind.writeOff),
        Payment(
            id: 3,
            studentId: 3,
            amount: 99,
            date: DateTime(2026, 11, 5),
            note: kDebtWriteOffNote), // صف قديم نوعه بيتشتق من الملاحظة
      ],
      bookletPayments: const [],
      groupOfStudent: groups,
    );
    expect(s.total, 300);
    expect(s.count, 1);
  });

  test('الكراسات بتتجمع مع الاشتراكات وتتفصل في التفصيل', () {
    final s = computeIncome(
      month: nov,
      payments: [_p(1, 1, 300, DateTime(2026, 11, 3))],
      bookletPayments: [
        _b(2, 50, DateTime(2026, 11, 3)),
        _b(3, 40, DateTime(2026, 10, 31)), // أكتوبر
      ],
      groupOfStudent: groups,
    );
    expect(s.tuition, 300);
    expect(s.booklets, 50);
    expect(s.total, 350);
    expect(s.count, 2);
  });

  test('التوزيع على المجموعات واليوم، وأعلى يوم', () {
    final s = computeIncome(
      month: nov,
      payments: [
        _p(1, 1, 300, DateTime(2026, 11, 3)),
        _p(2, 2, 200, DateTime(2026, 11, 3)),
        _p(3, 3, 100, DateTime(2026, 11, 9)),
      ],
      bookletPayments: [_b(3, 25, DateTime(2026, 11, 9))],
      groupOfStudent: groups,
    );
    expect(s.byGroup[10], 500);
    expect(s.byGroup[20], 125);
    expect(s.byDay.length, 30);
    expect(s.byDay[2], 500); // يوم 3
    expect(s.byDay[8], 125); // يوم 9
    expect(s.bestDay, 3);
    expect(s.bestDayAmount, 500);
  });

  test('طالب بلا مجموعة معروفة بيتجمع تحت null (مؤرشف مثلًا)', () {
    final s = computeIncome(
      month: nov,
      payments: [_p(1, 99, 70, DateTime(2026, 11, 2))],
      bookletPayments: const [],
      groupOfStudent: groups,
    );
    expect(s.byGroup[null], 70);
  });

  test('المقارنة بالشهر اللي فات والتغيّر بالنسبة', () {
    final s = computeIncome(
      month: nov,
      payments: [
        _p(1, 1, 600, DateTime(2026, 11, 3)),
        _p(2, 1, 400, DateTime(2026, 10, 3)),
      ],
      bookletPayments: [_b(1, 100, DateTime(2026, 10, 20))],
      groupOfStudent: groups,
    );
    expect(s.previousTotal, 500);
    expect(s.changePct, closeTo(20, 0.001)); // 600 مقابل 500
  });

  test('الشهر اللي فات صفر → مفيش نسبة تغيّر', () {
    final s = computeIncome(
      month: nov,
      payments: [_p(1, 1, 600, DateTime(2026, 11, 3))],
      bookletPayments: const [],
      groupOfStudent: groups,
    );
    expect(s.previousTotal, 0);
    expect(s.changePct, isNull);
  });

  test('المصاريف بتتطرح لحساب الصافي، ومصاريف شهور تانية ما بتدخلش', () {
    final s = computeIncome(
      month: nov,
      payments: [_p(1, 1, 1000, DateTime(2026, 11, 3))],
      bookletPayments: const [],
      groupOfStudent: groups,
      expenses: [
        Expense(date: DateTime(2026, 11, 5), amount: 300),
        Expense(date: DateTime(2026, 10, 5), amount: 999),
      ],
    );
    expect(s.expenses, 300);
    expect(s.net, 700);
  });

  test('شهر فاضي: كله صفر وبدون أعلى يوم، وعدد الأيام صح (فبراير 2027 = 28)', () {
    final s = computeIncome(
      month: DateTime(2027, 2, 14),
      payments: const [],
      bookletPayments: const [],
      groupOfStudent: groups,
    );
    expect(s.total, 0);
    expect(s.average, 0);
    expect(s.bestDay, isNull);
    expect(s.byDay.length, 28);
    expect(s.month, DateTime(2027, 2, 1));
  });

  test('متوسط الدفعة', () {
    final s = computeIncome(
      month: nov,
      payments: [
        _p(1, 1, 300, DateTime(2026, 11, 3)),
        _p(2, 2, 100, DateTime(2026, 11, 4)),
      ],
      bookletPayments: const [],
      groupOfStudent: groups,
    );
    expect(s.average, 200);
  });
}
