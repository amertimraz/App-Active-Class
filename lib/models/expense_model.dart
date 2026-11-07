// lib/models/expense_model.dart
//
// مصروف للمعلم (إيجار، مواصلات، مطبوعات…). محلي على الجهاز فقط (غير مُزامَن).
import 'package:active_class/config/constants.dart';

/// تصنيفات المصاريف الجاهزة (المفتاح بيتخزّن، والاسم بيتعرض).
const Map<String, String> kExpenseCategories = {
  'rent': 'إيجار',
  'transport': 'مواصلات',
  'print': 'مطبوعات وملازم',
  'salary': 'مرتبات',
  'supplies': 'أدوات ومستلزمات',
  'utilities': 'كهرباء ومياه وإنترنت',
  'ads': 'إعلانات',
  'other': 'أخرى',
};

String expenseCategoryLabel(String key) =>
    kExpenseCategories[key] ?? kExpenseCategories['other']!;

class Expense {
  final int? id;
  final DateTime date;
  final double amount;
  final String category;
  final String? note;

  const Expense({
    this.id,
    required this.date,
    required this.amount,
    this.category = 'other',
    this.note,
  });

  Map<String, Object?> toMap() => {
        if (id != null) COL_EXP_ID: id,
        COL_EXP_DATE: date.toIso8601String(),
        COL_EXP_AMOUNT: amount,
        COL_EXP_CATEGORY: category,
        COL_EXP_NOTE: note,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m[COL_EXP_ID] as int?,
        date: DateTime.tryParse('${m[COL_EXP_DATE]}') ?? DateTime.now(),
        amount: (m[COL_EXP_AMOUNT] as num?)?.toDouble() ?? 0,
        category: (m[COL_EXP_CATEGORY] as String?) ?? 'other',
        note: m[COL_EXP_NOTE] as String?,
      );
}

/// ملخص شهر: التحصيل الفعلي − المصاريف = الصافي، + المصاريف حسب التصنيف.
class NetIncome {
  final double collected;
  final double expenses;
  final Map<String, double> byCategory;

  const NetIncome(this.collected, this.expenses, this.byCategory);

  double get net => collected - expenses;

  static NetIncome compute(double collected, Iterable<Expense> expenses) {
    final by = <String, double>{};
    var total = 0.0;
    for (final e in expenses) {
      total += e.amount;
      by[e.category] = (by[e.category] ?? 0) + e.amount;
    }
    return NetIncome(collected, total, by);
  }
}
