// lib/services/question_bank_picker.dart
//
// spec 025 — اختيار N سؤال عشوائي من نطاق بنك (لـ"أضف N عشوائي"). منطق
// نقي قابل للاختبار.
import 'dart:math';

import 'package:active_class/models/bank_question_model.dart';

/// يرجّع حتى [n] سؤال عشوائي من [pool] بلا تكرار.
/// - `pool` فارغ أو `n <= 0` → قائمة فارغة.
/// - `n >= pool.length` → كل `pool` مخلوط.
List<BankQuestion> pickRandom(List<BankQuestion> pool, int n, {Random? rng}) {
  if (pool.isEmpty || n <= 0) return [];
  final shuffled = [...pool]..shuffle(rng ?? Random());
  return shuffled.take(n).toList();
}
