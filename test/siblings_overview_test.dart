// test/siblings_overview_test.dart — spec 042
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/siblings_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PricingHelper.billingArrears = false;
    PricingHelper.prorateFirstMonth = false;
  });

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final group = Group(id: 1, name: 'ج1', pricingType: GroupPricingType.monthly);

  Student st(int id, String name,
          {int? sib, bool archived = false, String? phone, String? wa}) =>
      Student(
        id: id,
        name: name,
        code: 'C$id',
        groupId: 1,
        price: 200,
        siblingGroupId: sib,
        siblingsTotal: sib == null ? null : 300,
        siblingGroupCommittedCount: sib == null ? null : 2,
        attendanceStart: start,
        isArchived: archived,
        guardianPhone: phone,
        guardianWhatsapp: wa,
      );

  Attendance att(int sid, String status, {int day = 1}) => Attendance(
      studentId: sid, date: DateTime(now.year, now.month, day), status: status);

  List<SiblingFamily> build(List<Student> s,
          {List<Attendance> a = const [], List<Payment> p = const []}) =>
      buildSiblingFamilies(
          activeStudents: s,
          groups: [group],
          attendance: a,
          payments: p,
          now: now);

  test('تجميع: عيلة ≥2 نشط فقط، ومن غير ربط أو عضو واحد لا تظهر', () {
    final f = build([
      st(1, 'أ', sib: 10),
      st(2, 'ب', sib: 10),
      st(3, 'ج', sib: 11), // عضو وحيد
      st(4, 'د'), // غير مربوط
      st(5, 'هـ', sib: 12),
      st(6, 'و', sib: 12),
      st(7, 'ز', sib: 12),
    ]);
    expect(f.length, 2);
    expect(f.map((x) => x.members.length).toList()..sort(), [2, 3]);
  });

  test('المؤرشف لا يظهر، والعيلة تختفي لو نقصت عن 2', () {
    final f = build([
      st(1, 'أ', sib: 10),
      st(2, 'ب', sib: 10, archived: true),
    ]);
    expect(f, isEmpty);
  });

  test('المستحق والمتبقي مطابقين PricingHelper، والمدفوع بدون الإسقاط', () {
    final s1 = st(1, 'أ', sib: 10);
    final s2 = st(2, 'ب', sib: 10);
    final pays = [
      Payment(studentId: 1, date: now, amount: 50),
      Payment(studentId: 2, date: now, amount: 80, note: kDebtWriteOffNote),
    ];
    final fam = build([s1, s2], p: pays).single;
    final m1 = fam.members.firstWhere((m) => m.student.id == 1);
    final m2 = fam.members.firstWhere((m) => m.student.id == 2);

    expect(
        m1.totalDue,
        PricingHelper.totalDueThrough(
            student: s1,
            group: group,
            allAttendance: const [],
            month: now,
            siblingGroupMembers: [s1, s2]));
    expect(
        m1.remaining,
        PricingHelper.accumulatedDebt(
            student: s1,
            group: group,
            allAttendance: const [],
            payments: [pays[0]],
            siblingGroupMembers: [s1, s2]));
    expect(m1.paid, 50);
    expect(m2.paid, 0); // الإسقاط مش مدفوع فعلي
    expect(fam.totalPaid, 50);
  });

  test('الحضور والنسبة وnull لو لا سجلات', () {
    final fam = build([
      st(1, 'أ', sib: 10),
      st(2, 'ب', sib: 10),
    ], a: [
      att(1, ATTENDANCE_PRESENT, day: 1),
      att(1, ATTENDANCE_PRESENT, day: 2),
      att(1, ATTENDANCE_ABSENT, day: 3),
    ]).single;
    final m1 = fam.members.firstWhere((m) => m.student.id == 1);
    final m2 = fam.members.firstWhere((m) => m.student.id == 2);
    expect(m1.monthPresent, 2);
    expect(m1.monthAbsent, 1);
    expect(m1.monthRate!.round(), 67);
    expect(m2.monthRate, isNull);
  });

  test('أرقام ولي الأمر بدون تكرار', () {
    final fam = build([
      st(1, 'أ', sib: 10, phone: '01012345678'),
      st(2, 'ب', sib: 10, phone: '01012345678'),
      st(3, 'ج', sib: 10, phone: '01199999999'),
    ]).single;
    expect(fam.contacts.length, 2);
  });

  test('فلترة: بحث بالاسم/الكود و"عليها متبقي"', () {
    final fams = build([
      st(1, 'أحمد', sib: 10),
      st(2, 'ياسين', sib: 10),
      st(3, 'منى', sib: 11),
      st(4, 'سارة', sib: 11),
    ], p: [
      Payment(studentId: 3, date: now, amount: 1000),
      Payment(studentId: 4, date: now, amount: 1000),
    ]);
    expect(filterFamilies(fams, query: 'أحمد').length, 1);
    expect(filterFamilies(fams, query: 'C3').length, 1);
    expect(filterFamilies(fams, owingOnly: true).every((f) => f.hasBalance),
        true);
    expect(filterFamilies(fams, query: 'غير موجود'), isEmpty);
  });

  test('رسالة العيلة بدون ماليات لا تحتوي أرقامًا مالية', () {
    final fam = build([
      st(1, 'أحمد', sib: 10),
      st(2, 'ياسين', sib: 10),
    ]).single;
    final noFin = buildFamilyMessage(fam, withFinance: false, month: now);
    expect(noFin, contains('أحمد'));
    expect(noFin, contains('ياسين'));
    expect(noFin, isNot(contains('المتبقي')));
    expect(noFin, isNot(contains('💰')));
    final fin = buildFamilyMessage(fam, withFinance: true, month: now);
    expect(fin, contains('المتبقي'));
  });
}
