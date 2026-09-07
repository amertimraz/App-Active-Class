// test/attendance_overdue_warning_test.dart
//
// وحدة لـ PricingHelper.showsAttendanceOverdueWarning (spec 029):
// شهري → isOverdue بمهلة السماح؛ per-session → مديونية باقية بعد
// استثناء قيمة حصص النهاردة (حصص قديمة غير مدفوعة).
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
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

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final prevMonth = DateTime(now.year, now.month - 1);

  final monthlyGroup =
      Group(id: 1, name: 'شهري', pricingType: GroupPricingType.monthly);
  final perSessionGroup =
      Group(id: 2, name: 'بالحصة', pricingType: GroupPricingType.perSession);

  Student monthly({double exempt = 0}) => Student(
        id: 1,
        name: 'شهري',
        code: 'M1',
        groupId: 1,
        price: 200,
        exemptPercent: exempt,
        attendanceStart: DateTime(prevMonth.year, prevMonth.month, 1),
      );

  Student perSession({double price = 20, double exempt = 0}) => Student(
        id: 2,
        name: 'حصة',
        code: 'P1',
        groupId: 2,
        price: price,
        exemptPercent: exempt,
        attendanceStart: DateTime(prevMonth.year, prevMonth.month, 1),
      );

  Attendance att(int sid, DateTime d) =>
      Attendance(studentId: sid, date: d, status: ATTENDANCE_PRESENT);
  Payment pay(int sid, double amt) =>
      Payment(studentId: sid, date: now, amount: amt);

  // ── شهري ─────────────────────────────────────────────────────────

  test('1. شهري — مديونية شهر سابق، خارج المهلة → true', () {
    final s = monthly();
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: s,
        group: monthlyGroup,
        allAttendance: [att(1, DateTime(prevMonth.year, prevMonth.month, 5))],
        payments: const [],
        graceDays: 0,
      ),
      isTrue,
    );
  });

  test('2. شهري — كل المديونية من الشهر الحالي وضمن المهلة → false', () {
    final s = Student(
      id: 1,
      name: 'شهري',
      code: 'M1',
      groupId: 1,
      price: 200,
      attendanceStart: DateTime(now.year, now.month, 1),
    );
    // مهلة سماح 31 يوم → دايمًا "ضمن المهلة" لأي يوم في الشهر
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: s,
        group: monthlyGroup,
        allAttendance: [att(1, today)],
        payments: const [],
        graceDays: 31,
      ),
      isFalse,
    );
  });

  test('3. شهري — مدفوع بالكامل → false', () {
    final s = monthly();
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: s,
        group: monthlyGroup,
        allAttendance: [att(1, DateTime(prevMonth.year, prevMonth.month, 5))],
        payments: [pay(1, 100000)],
        graceDays: 0,
      ),
      isFalse,
    );
  });

  test('4. معفى بالكامل → false (أي نوع)', () {
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: monthly(exempt: 100),
        group: monthlyGroup,
        allAttendance: [att(1, DateTime(prevMonth.year, prevMonth.month, 5))],
        payments: const [],
        graceDays: 0,
      ),
      isFalse,
    );
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: perSession(exempt: 100),
        group: perSessionGroup,
        allAttendance: [att(2, DateTime(prevMonth.year, prevMonth.month, 5))],
        payments: const [],
        graceDays: 0,
      ),
      isFalse,
    );
  });

  // ── per-session ──────────────────────────────────────────────────

  test('5. per-session — حضر حصة اليوم فقط، صفر دفعات → false', () {
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: perSession(),
        group: perSessionGroup,
        allAttendance: [att(2, today)],
        payments: const [],
        graceDays: 0,
      ),
      isFalse,
    );
  });

  test('6. per-session — حضر حصتين أمس، صفر دفعات → true', () {
    final yesterday = today.subtract(const Duration(days: 1));
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: perSession(),
        group: perSessionGroup,
        allAttendance: [
          att(2, yesterday),
          att(2, yesterday.subtract(const Duration(days: 1))),
        ],
        payments: const [],
        graceDays: 0,
      ),
      isTrue,
    );
  });

  test('7. per-session — قديم مدفوع بالكامل + حصة اليوم غير مدفوعة → false', () {
    final d1 = today.subtract(const Duration(days: 3));
    final d2 = today.subtract(const Duration(days: 2));
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: perSession(price: 20),
        group: perSessionGroup,
        allAttendance: [att(2, d1), att(2, d2), att(2, today)],
        payments: [pay(2, 40)], // غطّى الحصتين القديمتين
        graceDays: 0,
      ),
      isFalse,
    );
  });

  test('8. per-session — قديم 100 دفع 60 + حصة اليوم → true (باقي 40 قديم)', () {
    final old = [
      for (int i = 1; i <= 5; i++)
        att(2, today.subtract(Duration(days: i))),
    ];
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: perSession(price: 20), // 5×20 = 100 قديم
        group: perSessionGroup,
        allAttendance: [...old, att(2, today)],
        payments: [pay(2, 60)],
        graceDays: 0,
      ),
      isTrue,
    );
  });

  test('9. per-session — سعر الحصة الفعلي 0 → false', () {
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: perSession(price: 0),
        group: perSessionGroup,
        allAttendance: [
          att(2, today.subtract(const Duration(days: 2))),
          att(2, today),
        ],
        payments: const [],
        graceDays: 0,
      ),
      isFalse,
    );
  });

  test('10. sessionsAttendedOn يحسب "متأخر" ضمن حضور اليوم', () {
    final s = perSession(price: 20);
    final list = [
      Attendance(studentId: 2, date: today, status: ATTENDANCE_LATE),
      att(2, today.subtract(const Duration(days: 1))),
    ];
    expect(
      PricingHelper.sessionsAttendedOn(
          student: s, day: today, allAttendance: list),
      1,
    );
    // حصة اليوم (متأخر) مستثناة → يبقى حصة أمس فقط غير مدفوعة → true
    expect(
      PricingHelper.showsAttendanceOverdueWarning(
        student: s,
        group: perSessionGroup,
        allAttendance: list,
        payments: const [],
        graceDays: 0,
      ),
      isTrue,
    );
  });
}
