// test/report_controller_test.dart — أرقام صفحة التقارير لازم تطابق كارت «دفعات»
// في الرئيسية (computeMonthlyBreakdown): المحصّل بيتوزّع على الشهور بالأقدم
// أولًا مش بتاريخ الدفعة، ودفعة طالب اتأرشف بعد كده ما تختفيش.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/report_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';

class _Settings extends SettingsController {
  @override
  void onInit() {}
}

class _RC extends ReportController {
  @override
  Future<void> loadReports() async {}
}

Student _s(int id, int g, DateTime created,
        {double price = 300, bool archived = false, DateTime? archivedAt}) =>
    Student(
      id: id,
      name: 'ط$id',
      code: 'C$id',
      groupId: g,
      price: price,
      createdAt: created,
      isArchived: archived,
      archivedAt: archivedAt,
    );

_RC _rc() {
  Get.put<SettingsController>(_Settings());
  return _RC();
}

final _g1 = Group(id: 1, name: 'شهري', code: 'G1', price: 300);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  group('نفس حساب الرئيسية', () {
    // أغسطس: ط1 دفع 900 في يوليو (مقدّمًا: يوليو+أغسطس+سبتمبر)، ط2 دفع 300
    // متأخر في سبتمبر (بيغطّي يوليو الأقدم الأول)، ط3 ما دفعش.
    _RC august() {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      final jul = DateTime(2026, 7, 1);
      rc.allStudents.assignAll([_s(1, 1, jul), _s(2, 1, jul), _s(3, 1, jul)]);
      rc.allPayments.assignAll([
        Payment(id: 1, studentId: 1, amount: 900, date: DateTime(2026, 7, 5)),
        Payment(id: 2, studentId: 2, amount: 300, date: DateTime(2026, 9, 2)),
      ]);
      rc.setMonth(DateTime(2026, 8));
      return rc;
    }

    test('المحصّل بالتوزيع مش بتاريخ الدفعة (حالة نسبة 26% الغلط)', () {
      final rc = august();
      // ما فيش ولا دفعة مؤرّخة في أغسطس — لكن ط1 مغطّي أغسطس من دفعة يوليو.
      expect(rc.allPayments.where((p) => p.date.month == 8), isEmpty);
      expect(rc.monthExpected, 900);
      expect(rc.monthTotalCollected, 300); // ط1 بس
      expect(rc.totalOverdue, 600); // ط2 وط3
    });

    test('شهر مدفوع بالكامل = نسبة 100% زي الرئيسية', () {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      rc.allStudents.assignAll([_s(1, 1, DateTime(2026, 7, 1)), _s(2, 1, DateTime(2026, 7, 1))]);
      // دفعوا كلهم أغسطس في سبتمبر، وغطّوا يوليو في يوليو.
      rc.allPayments.assignAll([
        for (final id in [1, 2]) Payment(id: id, studentId: id, amount: 300, date: DateTime(2026, 7, 3)),
        for (final id in [1, 2]) Payment(id: id + 10, studentId: id, amount: 300, date: DateTime(2026, 9, 9)),
      ]);
      rc.setMonth(DateTime(2026, 8));
      expect(rc.monthExpected, 600);
      expect(rc.monthTotalCollected, 600);
      expect(rc.totalOverdue, 0);
      expect(rc.unpaidStudents, isEmpty);
      final gs = rc.groupSummaries.single;
      expect(gs.collectionRate, 1.0);
      expect(gs.fullyPaidCount, 2);
    });

    test('الأرقام بتطابق computeMonthlyBreakdown مباشرة', () {
      final rc = august();
      final b = computeMonthlyBreakdown(
        students: rc.allStudents.toList(),
        paymentsByStudent: {
          for (final p in rc.allPayments) p.studentId: rc.allPayments.where((x) => x.studentId == p.studentId).toList()
        },
        groupById: {1: _g1},
        allAttendance: const [],
        month: DateTime(2026, 8),
        prevMonth: DateTime(2026, 7),
        monthLanded: true,
      );
      expect(rc.monthExpected, b.expected);
      expect(rc.monthTotalCollected, b.collected);
      expect(rc.groupSummaries.single.collectedIncome, b.groupBreakdown.single.collected);
      expect(rc.unpaidStudents.map((u) => u.student.id).toSet(), b.unpaidEntries.map((u) => u.student.id).toSet());
    });

    test('قايمة غير المسددين من الأكبر للأصغر، والمتأخر = مجموعها', () {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      rc.allStudents.assignAll([_s(1, 1, DateTime(2026, 8, 1)), _s(2, 1, DateTime(2026, 8, 1)), _s(3, 1, DateTime(2026, 8, 1))]);
      rc.allPayments.assignAll([
        Payment(id: 1, studentId: 2, amount: 100, date: DateTime(2026, 8, 5)),
        Payment(id: 2, studentId: 3, amount: 250, date: DateTime(2026, 8, 6)),
      ]);
      rc.setMonth(DateTime(2026, 8));
      final r = rc.unpaidStudents.map((u) => u.remaining).toList();
      expect(r, [300, 200, 50]);
      expect(rc.totalOverdue, r.fold<double>(0, (a, b) => a + b));
    });
  });

  group('مدفوع بالكامل X / Y', () {
    test('المعفي مش بيدخل المقام: الاتنين اللي عليهم مستحق دفعوا = 2 / 2', () {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      final aug = DateTime(2026, 8, 1);
      final exempt = Student(
        id: 3,
        name: 'ط3',
        code: 'C3',
        groupId: 1,
        price: 300,
        createdAt: aug,
        exemptPercent: 100,
      );
      rc.allStudents.assignAll([_s(1, 1, aug), _s(2, 1, aug), exempt]);
      rc.allPayments.assignAll([
        Payment(id: 1, studentId: 1, amount: 300, date: DateTime(2026, 8, 3)),
        Payment(id: 2, studentId: 2, amount: 300, date: DateTime(2026, 8, 3)),
      ]);
      rc.setMonth(DateTime(2026, 8));
      final gs = rc.groupSummaries.single;
      expect(gs.studentCount, 3); // كل طلاب المجموعة
      expect(gs.dueStudentCount, 2); // اللي عليهم مستحق
      expect(gs.fullyPaidCount, 2);
    });
  });

  group('المؤرشف: بقدر ما دفعه بس (الأرقام الأساسية زي الرئيسية)', () {
    // أكتوبر: نشط واحد (ط1) ومؤرشف (ط2 اتأرشف في نوفمبر) كانوا شغّالين فيه.
    _RC base(List<Payment> pays) {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      final sep = DateTime(2026, 9, 1);
      rc.allStudents.assignAll([_s(1, 1, sep)]);
      rc.archivedStudents.assignAll([
        _s(2, 1, sep, archived: true, archivedAt: DateTime(2026, 11, 10)),
      ]);
      rc.allPayments.assignAll(pays);
      rc.setMonth(DateTime(2026, 10));
      return rc;
    }

    test('مؤرشف ما دفعش: مش في المتوقع ولا المتأخر ولا قايمة غير المسددين', () {
      final rc = base([
        Payment(id: 1, studentId: 1, amount: 900, date: DateTime(2026, 9, 2)),
      ]);
      expect(rc.monthExpected, 300); // ط1 بس — زي الرئيسية
      expect(rc.monthTotalCollected, 300);
      expect(rc.totalOverdue, 0);
      expect(rc.unpaidStudents, isEmpty);
      expect(rc.archivedPaidIncluded, 0);
    });

    test('مؤرشف دفع جزئي: يدخل اللي دفعه بس في المتوقع والمحصّل، من غير متأخر', () {
      final rc = base([
        Payment(id: 1, studentId: 1, amount: 900, date: DateTime(2026, 9, 2)),
        // ط2 دفع 500: غطّى سبتمبر (300) و200 من أكتوبر
        Payment(id: 2, studentId: 2, amount: 500, date: DateTime(2026, 9, 3)),
      ]);
      expect(rc.archivedPaidIncluded, 200);
      expect(rc.monthExpected, 500); // 300 نشط + 200 مؤرشف (دفعه بس)
      expect(rc.monthTotalCollected, 500);
      expect(rc.totalOverdue, 0);
      expect(rc.unpaidStudents, isEmpty);
      // نسبة التحصيل ما بتعدّيش 100%
      expect(rc.groupSummaries.single.collectionRate, 1.0);
    });

    test('المتأخر بيفضل متأخر النشطين بس حتى لو فيه مؤرشف دافع', () {
      final rc = base([
        Payment(id: 1, studentId: 1, amount: 300, date: DateTime(2026, 9, 2)),
        Payment(id: 2, studentId: 2, amount: 900, date: DateTime(2026, 9, 3)),
      ]);
      // ط1 دفع سبتمبر بس → أكتوبر عليه 300 متأخر
      expect(rc.totalOverdue, 300);
      expect(rc.unpaidStudents.map((u) => u.student.id), [1]);
      expect(rc.archivedPaidIncluded, 300); // أكتوبر بتاع ط2
    });
  });

  group('طالب اتأرشف بعد الدفع', () {
    test('دفعة أكتوبر تفضل في تقرير أكتوبر حتى لو اتأرشف في نوفمبر', () {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      final sep = DateTime(2026, 9, 1);
      rc.allStudents.assignAll([_s(1, 1, sep)]);
      rc.archivedStudents.assignAll([
        _s(2, 1, sep, archived: true, archivedAt: DateTime(2026, 11, 10)),
      ]);
      rc.allPayments.assignAll([
        Payment(id: 1, studentId: 1, amount: 900, date: DateTime(2026, 9, 2)),
        Payment(id: 2, studentId: 2, amount: 900, date: DateTime(2026, 9, 2)),
      ]);
      rc.setMonth(DateTime(2026, 10));
      expect(rc.monthExpected, 600); // الاتنين شغالين في أكتوبر
      expect(rc.monthTotalCollected, 600);
      expect(rc.groupSummaries.single.collectedIncome, 600);
      // لكن بعد أرشفته (ديسمبر) مابقاش محسوب
      rc.setMonth(DateTime(2026, 12));
      expect(rc.monthExpected, 300);
    });
  });

  group('متفرقات', () {
    test('includesOlderMonths: المتبقي أكبر من مستحق الشهر', () {
      final a = AtRiskStudent(
          student: _s(1, 1, DateTime(2026, 9, 1)), group: null, paid: 0, due: 600, month: DateTime(2026, 10), monthDue: 300);
      expect(a.includesOlderMonths, isTrue);
      final b = AtRiskStudent(
          student: _s(1, 1, DateTime(2026, 9, 1)), group: null, paid: 0, due: 300, month: DateTime(2026, 10), monthDue: 300);
      expect(b.includesOlderMonths, isFalse);
    });

    test('الكاش بيتجدد لما الشهر أو البيانات تتغير', () {
      final rc = _rc();
      rc.allGroups.assignAll([_g1]);
      rc.allStudents.assignAll([_s(1, 1, DateTime(2026, 9, 1))]);
      rc.setMonth(DateTime(2026, 9));
      expect(rc.totalOverdue, 300);
      rc.setMonth(DateTime(2026, 10));
      expect(rc.monthExpected, 300); // شهر تاني = حساب جديد
      expect(rc.totalOverdue, 300); // أكتوبر: سبتمبر اتحسب الأول، فالباقي مستحق أكتوبر
      rc.allPayments.add(Payment(id: 1, studentId: 1, amount: 600, date: DateTime(2026, 10, 5)));
      expect(rc.totalOverdue, 0); // دفعة جديدة = حساب جديد
      expect(identical(rc.groupSummaries, rc.groupSummaries), isTrue);
    });
  });

  test('الأداء: 400 طالب بالحصة و20 ألف حضور أقل من ثانية ونص', () {
    final rc = _rc();
    rc.allGroups.assignAll([
      Group(id: 2, name: 'بالحصة', code: 'G2', price: 100, pricingType: GroupPricingType.perSession)
    ]);
    final students = [for (var i = 1; i <= 400; i++) _s(i, 2, DateTime(2026, 5, 1), price: 100)];
    rc.allStudents.assignAll(students);
    final att = <Attendance>[];
    var id = 1;
    for (final st in students) {
      for (var k = 0; k < 50; k++) {
        att.add(Attendance(
            id: id++,
            studentId: st.id!,
            date: DateTime(2026, 5, 1).add(Duration(days: k * 3)),
            status: ATTENDANCE_PRESENT));
      }
    }
    rc.allAttendance.assignAll(att);
    rc.allPayments.assignAll([
      for (final st in students.take(100))
        Payment(id: st.id, studentId: st.id!, amount: 500, date: DateTime(2026, 9, 1))
    ]);
    rc.setMonth(DateTime(2026, 9));
    PricingHelper.archivePeriods = {};
    final sw = Stopwatch()..start();
    final gs = rc.groupSummaries;
    final un = rc.unpaidStudents;
    sw.stop();
    expect(gs, hasLength(1));
    expect(un.length, greaterThan(100));
    expect(sw.elapsedMilliseconds, lessThan(1500),
        reason: 'فعلي: ${sw.elapsedMilliseconds}ms');
  });
}
