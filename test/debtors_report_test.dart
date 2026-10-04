import 'package:active_class/utils/debtors_report.dart';
import 'package:flutter_test/flutter_test.dart';

DebtorRow r(String name, int g, String gn, double rem) => DebtorRow(
    name: name,
    code: 'c',
    groupId: g,
    groupName: gn,
    guardianPhone: '',
    due: rem + 10,
    remaining: rem);

void main() {
  test('ترتيب بالمجموعة ثم الاسم، وتجاهل غير المدينين', () {
    final out = prepareDebtorRows([
      r('ياسين', 2, 'ب', 50),
      r('أحمد', 2, 'ب', 30),
      r('منى', 1, 'أ', 20),
      r('سارة', 1, 'أ', 0), // مسدّد
    ]);
    expect(out.map((e) => e.name).toList(), ['منى', 'أحمد', 'ياسين']);
  });

  test('فلتر المجموعة والإجمالي', () {
    final rows = [r('أحمد', 2, 'ب', 30), r('منى', 1, 'أ', 20)];
    final out = prepareDebtorRows(rows, groupId: 2);
    expect(out.length, 1);
    expect(debtorsTotal(out), 30);
    expect(debtorsTotal(prepareDebtorRows(rows)), 50);
  });
}
