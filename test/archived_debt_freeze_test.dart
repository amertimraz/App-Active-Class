import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/archive_event_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/archive_periods.dart';
import 'package:active_class/utils/pricing_helper.dart';

// الطالب المؤرشف مديونيته بتتجمّد عند شهر الأرشفة ومتكبرش بعده.
void main() {
  tearDown(() => PricingHelper.archivePeriods = {});
  setUp(() {
    PricingHelper.billingArrears = false;
    PricingHelper.prorateFirstMonth = false;
  });

  final group =
      Group(id: 1, name: 'أ', pricingType: GroupPricingType.monthly);
  Student make({bool archived = false, DateTime? archivedAt}) => Student(
      id: 1,
      name: 'ط',
      code: 'S1',
      groupId: 1,
      price: 80,
      attendanceStart: DateTime(2026, 9, 1),
      isArchived: archived,
      archivedAt: archivedAt);

  double due(Student s, DateTime month) => PricingHelper.totalDueThrough(
      student: s, group: group, allAttendance: const [], month: month);

  test('نشط: المستحق بيكبر مع الشهور', () {
    expect(due(make(), DateTime(2026, 11, 6)), 240);
    expect(due(make(), DateTime(2026, 12, 6)), 320);
  });

  test('مؤرشف في أكتوبر: يتجمّد عند شهرين (سبتمبر وأكتوبر)', () {
    final s = make(archived: true, archivedAt: DateTime(2026, 10, 15));
    expect(due(s, DateTime(2026, 10, 20)), 160);
    expect(due(s, DateTime(2026, 11, 6)), 160);
    expect(due(s, DateTime(2027, 3, 1)), 160);
  });

  test('مؤرشف بلا تاريخ أرشفة (بيانات قديمة): السلوك القديم', () {
    final s = make(archived: true);
    expect(due(s, DateTime(2026, 11, 6)), 240);
  });

  test('رجع نشط (isArchived=false): يكمل يتحسب عادي', () {
    final s = make(archived: false, archivedAt: DateTime(2026, 10, 15));
    expect(due(s, DateTime(2026, 11, 6)), 240);
  });

  ArchiveEvent ev(String type, DateTime at) =>
      ArchiveEvent(studentId: 1, type: type, at: at);

  test('أرشفة أكتوبر واستعادة فبراير: شهور نوفمبر-يناير مش بتتحسب', () {
    PricingHelper.archivePeriods = buildArchivePeriods([
      ev(kArchiveEventArchived, DateTime(2026, 10, 15)),
      ev(kArchiveEventRestored, DateTime(2027, 2, 10)),
    ]);
    final s = make(); // نشط بعد الاستعادة
    // سبتمبر + أكتوبر + فبراير = 3 شهور (نوفمبر/ديسمبر/يناير موقوفين).
    expect(due(s, DateTime(2027, 2, 20)), 240);
    expect(due(s, DateTime(2026, 12, 20)), 160);
  });

  test('استعادة في نص الشهر: الشهر ده بيتحسب كامل', () {
    PricingHelper.archivePeriods = buildArchivePeriods([
      ev(kArchiveEventArchived, DateTime(2026, 10, 15)),
      ev(kArchiveEventRestored, DateTime(2026, 12, 10)),
    ]);
    // سبتمبر + أكتوبر + ديسمبر (نوفمبر موقوف).
    expect(due(make(), DateTime(2026, 12, 20)), 240);
  });

  test('فترات: أحداث مختلطة وبلا ترتيب', () {
    final p = buildArchivePeriods([
      ev(kArchiveEventRestored, DateTime(2026, 5, 1)),
      ev(kArchiveEventArchived, DateTime(2026, 3, 1)),
      ev(kArchiveEventArchived, DateTime(2026, 8, 1)),
    ])[1]!;
    expect(p.length, 2);
    expect(p[0].isOpen, isFalse);
    expect(p[1].isOpen, isTrue);
  });
}
