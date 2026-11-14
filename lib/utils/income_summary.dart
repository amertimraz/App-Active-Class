// lib/utils/income_summary.dart
//
// «دخلي الشهر ده»: الكاش اللي دخل فعلًا في الشهر بتاريخ الدفعة — بعيد تمامًا
// عن حساب المستحق والتوزيع على الشهور (computeMonthlyBreakdown). دالة صرفة
// (بلا DB ولا GetX) عشان تتختبر مباشرة.
//
// القواعد:
//  • اشتراكات: دفعات الطلاب اللي نوعها «تحصيل» فقط (إسقاط المديونية مش فلوس).
//  • كراسات: دفعات الكراسات.
//  • الدفعة بتتحسب في الشهر اللي بتاريخه، حتى لو غطّت شهر قديم.
//  • المصاريف (اختياري) بتتطرح لحساب الصافي.
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/expense_model.dart';
import 'package:active_class/models/payment_model.dart';

class IncomeSummary {
  final DateTime month; // أول يوم في الشهر
  final double tuition; // اشتراكات
  final double booklets; // كراسات
  final double expenses;
  final int tuitionCount;
  final int bookletCount;

  /// المجموع لكل مجموعة (اشتراكات + كراسات). المفتاح null = طالب بلا مجموعة
  /// معروفة.
  final Map<int?, double> byGroup;

  /// دخل كل يوم: byDay[0] = يوم 1.
  final List<double> byDay;

  /// إجمالي الشهر اللي قبله (للمقارنة).
  final double previousTotal;

  const IncomeSummary({
    required this.month,
    required this.tuition,
    required this.booklets,
    required this.expenses,
    required this.tuitionCount,
    required this.bookletCount,
    required this.byGroup,
    required this.byDay,
    required this.previousTotal,
  });

  double get total => tuition + booklets;
  int get count => tuitionCount + bookletCount;
  double get net => total - expenses;
  double get average => count == 0 ? 0 : total / count;

  /// التغيّر عن الشهر اللي فات بالنسبة المئوية. null لو الشهر اللي فات صفر
  /// (مفيش أساس للمقارنة).
  double? get changePct =>
      previousTotal <= 0 ? null : (total - previousTotal) * 100 / previousTotal;

  /// أعلى يوم دخلًا (رقم اليوم 1..31) أو null لو مفيش دخل.
  int? get bestDay {
    var best = -1.0;
    int? day;
    for (var i = 0; i < byDay.length; i++) {
      if (byDay[i] > best && byDay[i] > 0) {
        best = byDay[i];
        day = i + 1;
      }
    }
    return day;
  }

  double get bestDayAmount => bestDay == null ? 0 : byDay[bestDay! - 1];
}

DateTime _firstOf(DateTime d) => DateTime(d.year, d.month, 1);

bool _inMonth(DateTime d, DateTime first) =>
    d.year == first.year && d.month == first.month;

double _round2(double v) => (v * 100).round() / 100;

/// إجمالي الدخل في شهر (اشتراكات + كراسات) — للمقارنة بالشهر اللي فات.
double incomeTotalFor({
  required DateTime month,
  required Iterable<Payment> payments,
  required Iterable<BookletPayment> bookletPayments,
}) {
  final first = _firstOf(month);
  var sum = 0.0;
  for (final p in payments) {
    if (p.isCollection && _inMonth(p.date, first)) sum += p.amount;
  }
  for (final b in bookletPayments) {
    if (_inMonth(b.date, first)) sum += b.amount;
  }
  return _round2(sum);
}

/// [groupOfStudent]: studentId → groupId (يشمل المؤرشفين عشان دفعاتهم تفضل
/// منسوبة لمجموعتهم).
IncomeSummary computeIncome({
  required DateTime month,
  required Iterable<Payment> payments,
  required Iterable<BookletPayment> bookletPayments,
  required Map<int, int> groupOfStudent,
  Iterable<Expense> expenses = const [],
}) {
  final first = _firstOf(month);
  final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  final byDay = List<double>.filled(daysInMonth, 0);
  final byGroup = <int?, double>{};
  var tuition = 0.0, booklets = 0.0;
  var tuitionCount = 0, bookletCount = 0;

  void addGroup(int studentId, double amount) {
    final g = groupOfStudent[studentId];
    byGroup[g] = (byGroup[g] ?? 0) + amount;
  }

  for (final p in payments) {
    if (!p.isCollection || !_inMonth(p.date, first)) continue;
    tuition += p.amount;
    tuitionCount++;
    byDay[p.date.day - 1] += p.amount;
    addGroup(p.studentId, p.amount);
  }
  for (final b in bookletPayments) {
    if (!_inMonth(b.date, first)) continue;
    booklets += b.amount;
    bookletCount++;
    byDay[b.date.day - 1] += b.amount;
    addGroup(b.studentId, b.amount);
  }

  var exp = 0.0;
  for (final e in expenses) {
    if (_inMonth(e.date, first)) exp += e.amount;
  }

  final prev = DateTime(first.year, first.month - 1, 1);
  return IncomeSummary(
    month: first,
    tuition: _round2(tuition),
    booklets: _round2(booklets),
    expenses: _round2(exp),
    tuitionCount: tuitionCount,
    bookletCount: bookletCount,
    byGroup: {for (final e in byGroup.entries) e.key: _round2(e.value)},
    byDay: [for (final v in byDay) _round2(v)],
    previousTotal: incomeTotalFor(
        month: prev, payments: payments, bookletPayments: bookletPayments),
  );
}
