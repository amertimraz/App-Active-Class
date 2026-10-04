// lib/utils/debtors_report.dart
//
// تقرير "الطلاب عليهم مديونية" للطباعة — منطق صرف (بلا PDF/GetX) عشان
// يتختبر: ترتيب (المجموعة ثم الاسم)، فلتر مجموعة، وإجمالي المتبقي.
class DebtorRow {
  final String name;
  final String code;
  final int? groupId;
  final String groupName;
  final String guardianPhone;
  final double due;
  final double remaining;

  const DebtorRow({
    required this.name,
    required this.code,
    required this.groupId,
    required this.groupName,
    required this.guardianPhone,
    required this.due,
    required this.remaining,
  });
}

/// يفلتر (اختياري) بمجموعة ويرتّب: اسم المجموعة ثم اسم الطالب. صفوف
/// المتبقي صفر أو أقل بتتشال (مش مديونية).
List<DebtorRow> prepareDebtorRows(Iterable<DebtorRow> rows, {int? groupId}) {
  final out = rows
      .where((r) => r.remaining > 0.005)
      .where((r) => groupId == null || r.groupId == groupId)
      .toList();
  out.sort((a, b) {
    final g = a.groupName.compareTo(b.groupName);
    return g != 0 ? g : a.name.compareTo(b.name);
  });
  return out;
}

double debtorsTotal(Iterable<DebtorRow> rows) =>
    rows.fold(0.0, (s, r) => s + r.remaining);
