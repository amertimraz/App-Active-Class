import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/booklet_math.dart';
import 'package:active_class/utils/booklet_message.dart';

Student st(int id, {bool archived = false}) =>
    Student(id: id, name: 's$id', code: 'c$id', groupId: 1, price: 0, isArchived: archived);
BookletPayment pay(double a, {int s = 1}) =>
    BookletPayment(bookletId: 1, studentId: s, amount: a, date: DateTime(2026, 1, 1));

void main() {
  test('مدفوع/متبقي/حالة', () {
    var paid = bookletPaid([pay(40)]);
    expect(bookletRemaining(100, paid), 60);
    expect(bookletPaymentStatus(100, paid), BookletPaymentStatus.partial);
    paid = bookletPaid([pay(40), pay(60)]);
    expect(bookletRemaining(100, paid), 0);
    expect(bookletPaymentStatus(100, paid), BookletPaymentStatus.full);
  });

  test('none وسعر صفر', () {
    expect(bookletPaymentStatus(100, 0), BookletPaymentStatus.none);
    expect(bookletPaymentStatus(0, 0), BookletPaymentStatus.full);
  });

  test('زيادة الدفع وتخفيض السعر', () {
    expect(bookletOverpaid(50, 80), 30);
    expect(bookletRemaining(50, 80), 0);
    expect(bookletRemaining(60, 80), 0);
    expect(bookletOverpaid(60, 80), 20);
    expect(bookletPaymentStatus(60, 80), BookletPaymentStatus.full);
  });

  test('eligibleStudents', () {
    final res = eligibleStudents(
      groupStudents: [st(1), st(2, archived: true), st(3), st(4)],
      recordsByStudent: {3: const BookletRecord(bookletId: 1, studentId: 3, excluded: true)},
    );
    expect(res.map((s) => s.id), [1, 4]);
  });

  test('historicalStudents', () {
    final res = historicalStudents(
      allCandidateStudents: [st(1), st(2, archived: true), st(3), st(4, archived: true)],
      recordsByStudent: {
        3: const BookletRecord(bookletId: 1, studentId: 3, excluded: true, delivered: true),
      },
      studentIdsWithPayments: {2},
    );
    expect(res.map((s) => s.id), [1, 2, 3]);
  });

  test('studentBookletsRemaining', () {
    expect(
        studentBookletsRemaining(const [
          BookletRemainingLine(100, 40),
          BookletRemainingLine(50, 80),
          BookletRemainingLine(30, 0),
        ]),
        90);
  });

  test('parseAmount', () {
    expect(parseAmount('1,500'), 1500);
    expect(parseAmount('12,5'), 12.5);
    expect(parseAmount('١٢٠'), 120);
    expect(parseAmount('٧٥٫٥'), 75.5);
    expect(parseAmount('abc'), null);
  });

  test('رسالة التذكير', () {
    final m = buildBookletReminderMessage(
        studentName: 'أحمد',
        bookletName: 'ملزمة 1',
        price: 100,
        paid: 40,
        remaining: 60,
        teacherName: 'أ. سمير');
    expect(m, contains('أحمد'));
    expect(m, contains('ملزمة 1'));
    expect(m, contains('المدفوع'));
    expect(m, contains('المتبقي'));
    expect(m, contains('أ. سمير'));
  });
}
