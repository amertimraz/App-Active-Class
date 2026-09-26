// lib/utils/booklet_math.dart
//
// spec 041 — دوال صرفة لحسابات الملازم (بلا DB ولا GetX).
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/student_model.dart';

enum BookletPaymentStatus { none, partial, full }

const double _eps = 0.005;

double _clean(double v) => v.abs() < _eps ? 0 : v;

double bookletPaid(Iterable<BookletPayment> payments) =>
    payments.fold<double>(0, (s, p) => s + p.amount);

double bookletRemaining(double price, double paid) {
  final r = _clean(price - paid);
  return r < 0 ? 0 : r;
}

double bookletOverpaid(double price, double paid) {
  final r = _clean(paid - price);
  return r < 0 ? 0 : r;
}

BookletPaymentStatus bookletPaymentStatus(double price, double paid) {
  if (price <= 0) return BookletPaymentStatus.full;
  if (paid >= price - _eps) return BookletPaymentStatus.full;
  if (paid > _eps) return BookletPaymentStatus.partial;
  return BookletPaymentStatus.none;
}

/// طلاب مؤهَّلون: بلا المؤرشفين وبلا المستثنَين.
List<Student> eligibleStudents({
  required List<Student> groupStudents,
  required Map<int, BookletRecord> recordsByStudent,
}) {
  return groupStudents.where((s) {
    if (s.isArchived) return false;
    final r = s.id == null ? null : recordsByStudent[s.id!];
    return !(r?.excluded ?? false);
  }).toList();
}

/// السجل التاريخي: المؤهَّلون + أي طالب عنده تسليم أو دفعة مسجّلة.
List<Student> historicalStudents({
  required List<Student> allCandidateStudents,
  required Map<int, BookletRecord> recordsByStudent,
  required Set<int> studentIdsWithPayments,
}) {
  return allCandidateStudents.where((s) {
    final id = s.id;
    if (id == null) return false;
    final r = recordsByStudent[id];
    final eligible = !s.isArchived && !(r?.excluded ?? false);
    return eligible || (r?.delivered ?? false) || studentIdsWithPayments.contains(id);
  }).toList();
}

class BookletRemainingLine {
  final double price;
  final double paid;
  const BookletRemainingLine(this.price, this.paid);
}

double studentBookletsRemaining(Iterable<BookletRemainingLine> lines) =>
    lines.fold<double>(0, (s, l) => s + bookletRemaining(l.price, l.paid));

/// يحوّل نص مبلغ لرقم: أرقام عربية، فاصلة عشرية "," أو "٫"، وفاصل آلاف
/// ("1,500" = 1500 مش 1.5). يرجّع null لو مش رقم.
double? parseAmount(String raw) {
  var s = raw.trim();
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
  }
  s = s.replaceAll('٬', ',').replaceAll('٫', '.').replaceAll(' ', '');
  if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(s)) {
    s = s.replaceAll(',', '');
  } else {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}
