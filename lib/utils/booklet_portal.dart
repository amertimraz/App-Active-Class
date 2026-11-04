// lib/utils/booklet_portal.dart
//
// مذكرات الطالب لبوابة ولي الأمر — دوال صرفة (بلا DB ولا Firestore). نفس
// قواعد BookletController.linesForStudent: الملزمة بتظهر لو مجموعة الطالب
// مربوطة بيها، والطالب مؤهَّل (مش مؤرشف ولا مستثنى) أو عنده تسليم/دفعة.
import 'package:active_class/models/booklet_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/booklet_math.dart';

class BookletPortalLine {
  final String name;
  final double price;
  final double paid;
  final double remaining;
  final bool delivered;
  const BookletPortalLine({
    required this.name,
    required this.price,
    required this.paid,
    required this.remaining,
    required this.delivered,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'paid': paid,
        'remaining': remaining,
        'delivered': delivered,
      };
}

List<BookletPortalLine> studentBookletPortalLines({
  required Student student,
  required List<Booklet> booklets,
  required List<BookletGroupLink> links,
  required List<BookletRecord> records,
  required List<BookletPayment> payments,
}) {
  final sid = student.id;
  if (sid == null) return const [];
  final out = <BookletPortalLine>[];
  for (final b in booklets) {
    final bid = b.id;
    if (bid == null) continue;
    final linked =
        links.any((l) => l.bookletId == bid && l.groupId == student.groupId);
    if (!linked) continue;
    BookletRecord? rec;
    for (final r in records) {
      if (r.bookletId == bid && r.studentId == sid) {
        rec = r;
        break;
      }
    }
    final paid = bookletPaid(
        payments.where((p) => p.bookletId == bid && p.studentId == sid));
    final eligible = !student.isArchived && !(rec?.excluded ?? false);
    final delivered = rec?.delivered ?? false;
    if (!eligible && !delivered && paid <= 0) continue;
    out.add(BookletPortalLine(
      name: b.name,
      price: b.price,
      paid: paid,
      remaining: eligible ? bookletRemaining(b.price, paid) : 0,
      delivered: delivered,
    ));
  }
  return out;
}

/// حقول ملخص الطالب للبوابة. فاضية لو مفيش مذكرات (فالصفحة ما تعرضش بطاقة).
Map<String, dynamic> bookletPortalFields(List<BookletPortalLine> lines) {
  if (lines.isEmpty) return const {};
  return {
    'booklets': lines.map((l) => l.toMap()).toList(),
    'bookletsRemaining': lines.fold<double>(0, (s, l) => s + l.remaining),
  };
}
