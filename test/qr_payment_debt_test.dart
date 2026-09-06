import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

/// منطق التحويل المطلوب في QRController.scannedStudentDebtSessions /
/// sessionsCoveredBy — حصص كاملة مغطّاة (floor)، وصفر لو السعر غير صالح.
int debtToSessions(double debt, double price) =>
    price > 0 ? (debt / price).floor() : 0;

/// منطق QRController.debtRemainingAfter — لا يقل عن صفر.
double debtRemainingAfter(double debt, double amount) =>
    (debt - amount).clamp(0.0, double.infinity).toDouble();

/// قاعدة قبول applyDebtAmountPayment.
bool debtAmountAccepted(double amount, double debt) =>
    amount > 0 && amount <= debt + 0.01;

void main() {
  setUp(() {
    PricingHelper.billingArrears = false;
    PricingHelper.prorateFirstMonth = false;
  });

  group('accumulatedDebt — per-session عبر شهرين', () {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final prevMonth = DateTime(now.year, now.month - 1);

    final group = Group(
      id: 1,
      name: 'مجموعة بالحصة',
      pricingType: GroupPricingType.perSession,
    );
    final student = Student(
      id: 10,
      name: 'طالب',
      code: 'S10',
      groupId: 1,
      price: 20,
      attendanceStart: DateTime(prevMonth.year, prevMonth.month, 1),
    );

    List<Attendance> attendance() => [
          for (int d = 1; d <= 6; d++)
            Attendance(
              studentId: 10,
              date: DateTime(prevMonth.year, prevMonth.month, d + 1),
              status: ATTENDANCE_PRESENT,
            ),
          Attendance(
            studentId: 10,
            date: DateTime(thisMonth.year, thisMonth.month, 1),
            status: ATTENDANCE_PRESENT,
          ),
        ];

    test('6 حصص الشهر السابق + 1 الحالي، بلا دفعات → 140', () {
      final debt = PricingHelper.accumulatedDebt(
        student: student,
        group: group,
        allAttendance: attendance(),
        payments: const [],
      );
      expect(debt, 140);
    });

    test('نفس الحالة + دفعة 60 → 80', () {
      final debt = PricingHelper.accumulatedDebt(
        student: student,
        group: group,
        allAttendance: attendance(),
        payments: [Payment(studentId: 10, date: now, amount: 60)],
      );
      expect(debt, 80);
    });
  });

  group('debtToSessions (floor, سعر غير صالح)', () {
    test('140 / 20 = 7', () => expect(debtToSessions(140, 20), 7));
    test('45 / 20 = 2', () => expect(debtToSessions(45, 20), 2));
    test('0 / 20 = 0', () => expect(debtToSessions(0, 20), 0));
    test('140 / 0 = 0 (لا قسمة على صفر)', () => expect(debtToSessions(140, 0), 0));
  });

  group('sessionsCoveredBy / debtRemainingAfter', () {
    test('50 بسعر 20 يغطّي 2 حصة', () => expect(debtToSessions(50, 20), 2));
    test('10 بسعر 20 يغطّي 0 حصة', () => expect(debtToSessions(10, 20), 0));
    test('متبقّي 140 بعد دفع 50 = 90', () {
      expect(debtRemainingAfter(140, 50), 90);
    });
    test('متبقّي 140 بعد دفع 200 = 0 (clamp)', () {
      expect(debtRemainingAfter(140, 200), 0);
    });
  });

  group('debtAmountAccepted', () {
    test('50 ضد مديونية 140 → مقبول', () {
      expect(debtAmountAccepted(50, 140), isTrue);
    });
    test('200 ضد مديونية 140 → مرفوض', () {
      expect(debtAmountAccepted(200, 140), isFalse);
    });
    test('0 → مرفوض', () => expect(debtAmountAccepted(0, 140), isFalse));
    test('140 بالظبط → مقبول', () {
      expect(debtAmountAccepted(140, 140), isTrue);
    });
  });
}
