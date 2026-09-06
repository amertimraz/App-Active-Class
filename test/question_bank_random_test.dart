// spec 025 — وحدات pickRandom.
import 'dart:math';

import 'package:active_class/models/bank_question_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/services/question_bank_picker.dart';
import 'package:flutter_test/flutter_test.dart';

BankQuestion _q(int i) => BankQuestion(
      id: i,
      type: ExamQuestionType.mcq,
      text: 'سؤال $i',
      options: const ['أ', 'ب', 'ج'],
      correctIndex: 0,
    );

void main() {
  test('n < pool → n أسئلة بلا تكرار', () {
    final pool = List.generate(10, _q);
    final picked = pickRandom(pool, 3, rng: Random(1));
    expect(picked.length, 3);
    expect(picked.map((q) => q.id).toSet().length, 3); // بلا تكرار
    expect(picked.every((q) => pool.contains(q)), isTrue);
  });

  test('n >= pool.length → كل pool', () {
    final pool = List.generate(3, _q);
    expect(pickRandom(pool, 5, rng: Random(1)).length, 3);
    expect(pickRandom(pool, 3, rng: Random(1)).length, 3);
  });

  test('pool فارغ → []', () {
    expect(pickRandom(<BankQuestion>[], 3), isEmpty);
  });

  test('n <= 0 → []', () {
    expect(pickRandom(List.generate(5, _q), 0), isEmpty);
    expect(pickRandom(List.generate(5, _q), -1), isEmpty);
  });

  test('rng ثابت → نفس النتيجة', () {
    final pool = List.generate(20, _q);
    final a = pickRandom(pool, 5, rng: Random(42)).map((q) => q.id).toList();
    final b = pickRandom(pool, 5, rng: Random(42)).map((q) => q.id).toList();
    expect(a, b);
  });

  test('لا يغيّر pool الأصلي', () {
    final pool = List.generate(5, _q);
    final before = pool.map((q) => q.id).toList();
    pickRandom(pool, 3, rng: Random(1));
    expect(pool.map((q) => q.id).toList(), before);
  });
}
