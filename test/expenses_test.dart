import 'package:flutter_test/flutter_test.dart';
import 'package:active_class/models/expense_model.dart';

void main() {
  test('صافي الدخل = المحصّل − المصاريف، وتجميع حسب التصنيف', () {
    final ex = [
      Expense(date: DateTime(2026, 11, 1), amount: 300, category: 'rent'),
      Expense(date: DateTime(2026, 11, 2), amount: 50, category: 'transport'),
      Expense(date: DateTime(2026, 11, 3), amount: 100, category: 'rent'),
    ];
    final n = NetIncome.compute(1000, ex);
    expect(n.expenses, 450);
    expect(n.net, 550);
    expect(n.byCategory['rent'], 400);
    expect(NetIncome.compute(100, ex).net, -350);
  });

  test('toMap/fromMap وتصنيف مجهول يرجّع أخرى', () {
    final e = Expense(
        id: 3, date: DateTime(2026, 11, 5), amount: 75.5, category: 'ads', note: 'x');
    final back = Expense.fromMap(e.toMap());
    expect([back.id, back.amount, back.category, back.note], [3, 75.5, 'ads', 'x']);
    expect(expenseCategoryLabel('???'), 'أخرى');
  });
}
