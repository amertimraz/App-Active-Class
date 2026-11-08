// تقدير «سعر الإخوة يسري من شهر» للإخوة المربوطين قبل ما الميزة دي تتضاف.
//
// القاعدة: أول دفعة تحصيل مبلغها = نصيب الإخوة (الإجمالي المشترك ÷ العدد)
// بتحدد أول شهر بسعر الإخوة. لو مفيش دفعة بالمبلغ ده بيرجع null (يفضل
// السلوك القديم: سعر الإخوة على كل الشهور). دالة صرفة بلا DB.
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';

DateTime? inferSiblingsFrom({
  required Student student,
  required List<Payment> payments,
  required int groupSize,
}) {
  final total = student.siblingsTotal;
  if (total == null || groupSize < 2 || student.siblingsFrom != null) {
    return null;
  }
  final share = total / groupSize;
  final real = payments.where((p) => p.isCollection).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final p in real) {
    if ((p.amount - share).abs() < 0.5) {
      return DateTime(p.date.year, p.date.month, 1);
    }
  }
  return null;
}
