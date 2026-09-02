// lib/models/exam_question_model.dart
//
// spec 016 — سؤال امتحان إلكتروني. موضوعي فقط في v1 (صح/خطأ + اختيار من
// متعدد بإجابة واحدة). `correctIndex` و`points` **محليان فقط** — `toCloudMap`
// بيرجّع السؤال بدون أي مفتاح إجابة (التصحيح يتم داخل التطبيق).
import 'dart:convert';

import 'package:active_class/config/constants.dart';

enum ExamQuestionType { trueFalse, mcq }

extension ExamQuestionTypeX on ExamQuestionType {
  String get dbValue =>
      this == ExamQuestionType.trueFalse ? 'true_false' : 'mcq';

  static ExamQuestionType fromDb(String? raw) =>
      raw == 'true_false' ? ExamQuestionType.trueFalse : ExamQuestionType.mcq;

  String get label =>
      this == ExamQuestionType.trueFalse ? 'صح / خطأ' : 'اختيار من متعدد';
}

/// اختيارات "صح / خطأ" الثابتة — تُخزَّن كأي اختيارات عادية عشان التصحيح
/// والعرض يمشوا بنفس المسار.
const List<String> kTrueFalseOptions = ['صح', 'خطأ'];

class ExamQuestion {
  final int? id;
  final int examId;
  final int position;
  final ExamQuestionType type;
  final String text;
  final List<String> options;
  final int correctIndex;
  final double points;
  final DateTime? createdAt;

  const ExamQuestion({
    this.id,
    required this.examId,
    required this.position,
    required this.type,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.points = 1,
    this.createdAt,
  });

  bool get isValid =>
      text.trim().isNotEmpty &&
      options.length >= 2 &&
      options.length <= 6 &&
      options.every((o) => o.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      points > 0;

  Map<String, dynamic> toMap() => {
        if (id != null) COL_EQ_ID: id,
        COL_EQ_EXAM_ID: examId,
        COL_EQ_POSITION: position,
        COL_EQ_TYPE: type.dbValue,
        COL_EQ_TEXT: text,
        COL_EQ_OPTIONS: jsonEncode(options),
        COL_EQ_CORRECT_INDEX: correctIndex,
        COL_EQ_POINTS: points,
        COL_EQ_CREATED_AT: createdAt?.toIso8601String(),
      };

  factory ExamQuestion.fromMap(Map<String, dynamic> m) {
    final rawOptions = m[COL_EQ_OPTIONS] as String?;
    List<String> opts;
    if (rawOptions == null || rawOptions.isEmpty) {
      opts = List<String>.from(kTrueFalseOptions);
    } else {
      opts = (jsonDecode(rawOptions) as List).map((e) => e.toString()).toList();
    }
    return ExamQuestion(
      id: m[COL_EQ_ID] as int?,
      examId: m[COL_EQ_EXAM_ID] as int,
      position: (m[COL_EQ_POSITION] as int?) ?? 0,
      type: ExamQuestionTypeX.fromDb(m[COL_EQ_TYPE] as String?),
      text: m[COL_EQ_TEXT] as String? ?? '',
      options: opts,
      correctIndex: (m[COL_EQ_CORRECT_INDEX] as int?) ?? 0,
      points: (m[COL_EQ_POINTS] as num?)?.toDouble() ?? 1,
      createdAt: m[COL_EQ_CREATED_AT] != null
          ? DateTime.tryParse(m[COL_EQ_CREATED_AT] as String)
          : null,
    );
  }

  ExamQuestion copyWith({
    int? id,
    int? examId,
    int? position,
    ExamQuestionType? type,
    String? text,
    List<String>? options,
    int? correctIndex,
    double? points,
  }) =>
      ExamQuestion(
        id: id ?? this.id,
        examId: examId ?? this.examId,
        position: position ?? this.position,
        type: type ?? this.type,
        text: text ?? this.text,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        points: points ?? this.points,
        createdAt: createdAt,
      );

  /// شكل السؤال المرفوع للسحابة — **بدون** `correctIndex` أو `points`
  /// (FR-034). الـ id بصيغة "q" + رقم السؤال المحلي، عشان إجابة الطالب
  /// تربط بالسؤال المحلي وقت التصحيح.
  Map<String, dynamic> toCloudMap() => {
        'id': 'q$id',
        'type': type.dbValue,
        'text': text,
        'options': options,
      };
}
