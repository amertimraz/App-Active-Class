// test/billing_day_test.dart — spec 045 (يوم نزول المديونية)
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/billing_day.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime oct(int d) => DateTime(2026, 10, d, 12);
  final req = DateTime(2026, 10, 1);
  final sep = DateTime(2026, 9, 1);

  group('clampBillingDay', () {
    test('خارج النطاق أو null → 1', () {
      expect(clampBillingDay(null), 1);
      expect(clampBillingDay(0), 1);
      expect(clampBillingDay(29), 1);
      expect(clampBillingDay(-3), 1);
    });
    test('داخل النطاق كما هو', () {
      expect(clampBillingDay(1), 1);
      expect(clampBillingDay(10), 10);
      expect(clampBillingDay(28), 28);
    });
  });

  group('effectiveLastMonthFor', () {
    DateTime eff(DateTime now, int day, {bool arrears = false, DateTime? r}) =>
        effectiveLastMonthFor(
            requested: r ?? req, now: now, arrears: arrears, billingDay: day);

    test('يوم 10: قبله الشهر الجاري مستبعد', () {
      expect(eff(oct(5), 10), sep);
      expect(eff(oct(9), 10), sep);
    });
    test('يوم 10: من اليوم 10 الشهر الجاري محسوب', () {
      expect(eff(oct(10), 10), req);
      expect(eff(oct(20), 10), req);
    });
    test('عند 1 مطابق للقديم في كل الأيام (حتى الشهر المستقبلي)', () {
      for (final d in [1, 2, 15, 31]) {
        expect(eff(oct(d), 1), req);
      }
      final future = DateTime(2026, 12, 1);
      expect(eff(oct(5), 1, r: future), future);
    });
    test('شهر ماضي بالكامل يتحسب دايمًا', () {
      final aug = DateTime(2026, 8, 1);
      expect(eff(oct(5), 10, r: aug), aug);
    });
    test('شهر مستقبلي قبل يوم النزول → الشهر السابق للجاري', () {
      expect(eff(oct(5), 10, r: DateTime(2026, 12, 1)), sep);
    });
    test('المؤخّر يتجاهل اليوم: آخر شهر مكتمل دايمًا', () {
      expect(eff(oct(5), 10, arrears: true), sep);
      expect(eff(oct(20), 10, arrears: true), sep);
      expect(eff(oct(20), 1, arrears: true), sep);
    });
    test('يناير: الشهر السابق = ديسمبر السنة اللي فاتت', () {
      final jan = DateTime(2027, 1, 1);
      expect(
          effectiveLastMonthFor(
              requested: jan,
              now: DateTime(2027, 1, 3),
              arrears: false,
              billingDay: 10),
          DateTime(2026, 12, 1));
    });
  });

  group('withinGraceWindow', () {
    bool w(int day, int grace, int billingDay, {bool arrears = false}) =>
        withinGraceWindow(
            now: oct(day),
            graceDays: grace,
            arrears: arrears,
            billingDay: billingDay);

    test('بدون مهلة → false', () {
      expect(w(5, 0, 10), false);
    });
    test('عند 1: يوم 1..grace داخل المهلة (القديم)', () {
      expect(w(1, 3, 1), true);
      expect(w(3, 3, 1), true);
      expect(w(4, 3, 1), false);
    });
    test('يوم 10 ومهلة 3: 10 و11 و12 داخل، 13 متأخر', () {
      expect(w(10, 3, 10), true);
      expect(w(12, 3, 10), true);
      expect(w(13, 3, 10), false);
    });
    test('قبل يوم النزول لا مهلة (الشهر السابق متأخر فعلًا)', () {
      expect(w(5, 3, 10), false);
      expect(w(9, 3, 10), false);
    });
    test('المؤخّر يتجاهل اليوم', () {
      expect(w(3, 3, 10, arrears: true), true);
      expect(w(4, 3, 10, arrears: true), false);
    });
  });

  group('isEarlyInMonthForCollection', () {
    bool e(int day, int grace, int billingDay, {bool arrears = false}) =>
        isEarlyInMonthForCollection(
            now: oct(day),
            graceDays: grace,
            arrears: arrears,
            billingDay: billingDay);

    test('عند 1 مطابق للقديم: أول max(grace,5) يوم', () {
      expect(e(5, 0, 1), true);
      expect(e(6, 0, 1), false);
      expect(e(7, 7, 1), true);
      expect(e(8, 7, 1), false);
    });
    test('يوم 10: لحد 14 الشهر السابق، من 15 الجاري', () {
      expect(e(14, 0, 10), true);
      expect(e(15, 0, 10), false);
    });
    test('المؤخّر دايمًا الشهر السابق', () {
      expect(e(28, 0, 10, arrears: true), true);
    });
  });

  group('monthHasLanded', () {
    bool l(DateTime m, int day, int billingDay, {bool arrears = false}) =>
        monthHasLanded(
            month: m, now: oct(day), arrears: arrears, billingDay: billingDay);

    test('شهر ماضي نزل، مستقبلي لا', () {
      expect(l(sep, 5, 10), true);
      expect(l(DateTime(2026, 11, 1), 20, 10), false);
    });
    test('الجاري: قبل يوم النزول لا، من يوم النزول نعم', () {
      expect(l(req, 9, 10), false);
      expect(l(req, 10, 10), true);
    });
    test('عند 1 الجاري نزل دايمًا', () {
      expect(l(req, 1, 1), true);
    });
    test('مؤخّر: الجاري لا', () {
      expect(l(req, 20, 1, arrears: true), false);
    });
  });

  // ── تكامل مع PricingHelper (تاريخ اليوم الحقيقي) ──────────────────
  group('PricingHelper مع billingDay', () {
    tearDown(() {
      PricingHelper.billingDay = 1;
      PricingHelper.billingArrears = false;
      PricingHelper.prorateFirstMonth = false;
    });

    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    final monthly =
        Group(id: 1, name: 'ش', pricingType: GroupPricingType.monthly);
    final s = Student(
      id: 1,
      name: 'ط',
      code: 'c',
      groupId: 1,
      price: 100,
      attendanceStart: DateTime(prev.year, prev.month, 1),
    );

    double due() => PricingHelper.totalDueThrough(
        student: s,
        group: monthly,
        allAttendance: const <Attendance>[],
        month: now);

    test('اليوم 1 (افتراضي): الشهرين السابق والجاري = 200', () {
      PricingHelper.billingDay = 1;
      expect(due(), 200);
    });

    test('يوم نزول بعد اليوم الحالي → الشهر الجاري مستبعد (100)', () {
      if (now.day >= 28) return; // مفيش يوم لاحق صالح في آخر الشهر
      PricingHelper.billingDay = now.day + 1;
      expect(due(), 100);
    });

    test('يوم نزول = اليوم الحالي → الشهر الجاري محسوب (200)', () {
      PricingHelper.billingDay = now.day > 28 ? 28 : now.day;
      if (now.day > 28) return;
      expect(due(), 200);
    });

    test('المؤخّر يتجاهل اليوم: دايمًا 100', () {
      PricingHelper.billingArrears = true;
      PricingHelper.billingDay = 1;
      expect(due(), 100);
      PricingHelper.billingDay = 20;
      expect(due(), 100);
    });

    test('isOverdue: دين الشهر الجاري بس قبل يوم النزول → مش متأخر', () {
      if (now.day >= 28) return;
      final sCur = Student(
        id: 2,
        name: 'ج',
        code: 'd',
        groupId: 1,
        price: 100,
        attendanceStart: DateTime(now.year, now.month, 1),
      );
      PricingHelper.billingDay = now.day + 1;
      expect(
          PricingHelper.isOverdue(
              student: sCur,
              group: monthly,
              allAttendance: const [],
              payments: const <Payment>[],
              graceDays: 0),
          false);
      PricingHelper.billingDay = 1;
      expect(
          PricingHelper.isOverdue(
              student: sCur,
              group: monthly,
              allAttendance: const [],
              payments: const <Payment>[],
              graceDays: 0),
          true);
    });
  });
}
