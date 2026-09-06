// lib/models/bank_question_model.dart
//
// spec 025 — سؤال في بنك الأسئلة. نفس محتوى ExamQuestion (نوع/نص/
// اختيارات/إجابة صحيحة/درجة/صورة/شرح) + مادة + وسوم، بلا exam_id/
// position. correct_index/points/explanation محلية + في جدول الفريق
// على Supabase (RLS)، **مش** في مستند Firestore العام (النسخ لامتحان
// يمرّ بـ ExamQuestion.toCloudMap اللي بيستبعدهم).
import 'dart:convert';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/exam_question_model.dart';

const Object _unset = Object();

class BankQuestion {
  final int? id;
  final ExamQuestionType type;
  final String text;
  final List<String> options;
  final int correctIndex;
  final double points;
  final String? imageUrl;
  final String? explanation;
  final String subject;
  final List<String> tags;
  final DateTime? createdAt;

  const BankQuestion({
    this.id,
    required this.type,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.points = 1,
    this.imageUrl,
    this.explanation,
    this.subject = '',
    this.tags = const [],
    this.createdAt,
  });

  /// نفس قواعد ExamQuestion.isValid — المادة **مش** شرط (تُطلب وقت الحفظ).
  bool get isValid =>
      text.trim().isNotEmpty &&
      options.length >= 2 &&
      options.length <= 6 &&
      options.every((o) => o.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      points > 0;

  Map<String, dynamic> toMap() => {
        if (id != null) COL_BQ_ID: id,
        COL_BQ_TYPE: type.dbValue,
        COL_BQ_TEXT: text,
        COL_BQ_OPTIONS: jsonEncode(options),
        COL_BQ_CORRECT_INDEX: correctIndex,
        COL_BQ_POINTS: points,
        COL_BQ_IMAGE_URL: imageUrl,
        COL_BQ_EXPLANATION: explanation,
        COL_BQ_SUBJECT: subject,
        COL_BQ_TAGS: jsonEncode(tags),
        COL_BQ_CREATED_AT: createdAt?.toIso8601String(),
      };

  factory BankQuestion.fromMap(Map<String, dynamic> m) {
    final rawOptions = m[COL_BQ_OPTIONS] as String?;
    final opts = (rawOptions == null || rawOptions.isEmpty)
        ? List<String>.from(kTrueFalseOptions)
        : (jsonDecode(rawOptions) as List).map((e) => e.toString()).toList();
    final rawTags = m[COL_BQ_TAGS] as String?;
    final tags = (rawTags == null || rawTags.isEmpty)
        ? <String>[]
        : (jsonDecode(rawTags) as List).map((e) => e.toString()).toList();
    return BankQuestion(
      id: m[COL_BQ_ID] as int?,
      type: ExamQuestionTypeX.fromDb(m[COL_BQ_TYPE] as String?),
      text: m[COL_BQ_TEXT] as String? ?? '',
      options: opts,
      correctIndex: (m[COL_BQ_CORRECT_INDEX] as int?) ?? 0,
      points: (m[COL_BQ_POINTS] as num?)?.toDouble() ?? 1,
      imageUrl: (m[COL_BQ_IMAGE_URL] as String?)?.isNotEmpty == true
          ? m[COL_BQ_IMAGE_URL] as String
          : null,
      explanation: (m[COL_BQ_EXPLANATION] as String?)?.isNotEmpty == true
          ? m[COL_BQ_EXPLANATION] as String
          : null,
      subject: m[COL_BQ_SUBJECT] as String? ?? '',
      tags: tags,
      createdAt: m[COL_BQ_CREATED_AT] != null
          ? DateTime.tryParse(m[COL_BQ_CREATED_AT] as String)
          : null,
    );
  }

  BankQuestion copyWith({
    int? id,
    ExamQuestionType? type,
    String? text,
    List<String>? options,
    int? correctIndex,
    double? points,
    Object? imageUrl = _unset,
    Object? explanation = _unset,
    String? subject,
    List<String>? tags,
  }) =>
      BankQuestion(
        id: id ?? this.id,
        type: type ?? this.type,
        text: text ?? this.text,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        points: points ?? this.points,
        imageUrl:
            identical(imageUrl, _unset) ? this.imageUrl : imageUrl as String?,
        explanation: identical(explanation, _unset)
            ? this.explanation
            : explanation as String?,
        subject: subject ?? this.subject,
        tags: tags ?? this.tags,
        createdAt: createdAt,
      );

  /// نسخة مستقلة لإدراجها في امتحان (بلا مادة/وسوم — مش جزء من سؤال الامتحان).
  ExamQuestion toExamQuestion({required int examId, required int position}) =>
      ExamQuestion(
        examId: examId,
        position: position,
        type: type,
        text: text,
        options: List<String>.from(options),
        correctIndex: correctIndex,
        points: points,
        imageUrl: imageUrl,
        explanation: explanation,
      );

  factory BankQuestion.fromExamQuestion(
    ExamQuestion q, {
    String subject = '',
    List<String> tags = const [],
  }) =>
      BankQuestion(
        type: q.type,
        text: q.text,
        options: List<String>.from(q.options),
        correctIndex: q.correctIndex,
        points: q.points,
        imageUrl: q.imageUrl,
        explanation: q.explanation,
        subject: subject,
        tags: tags,
      );
}
