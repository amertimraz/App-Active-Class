// lib/models/exam_submission_model.dart
//
// spec 016 — تسليم طالب لامتحان إلكتروني. يُسحب من السحابة ويُصحّح محليًا،
// يبدأ بحالة "بانتظار الاعتماد"؛ عند اعتماد المدرس تُكتب `finalGrade` في
// جدول exam_grades العادي.
import 'dart:convert';

import 'package:active_class/config/constants.dart';

enum SubmissionStatus { pending, approved, notSubmitted, voided }

extension SubmissionStatusX on SubmissionStatus {
  String get dbValue {
    switch (this) {
      case SubmissionStatus.pending:
        return 'pending';
      case SubmissionStatus.approved:
        return 'approved';
      case SubmissionStatus.notSubmitted:
        return 'not_submitted';
      case SubmissionStatus.voided:
        return 'voided';
    }
  }

  static SubmissionStatus fromDb(String? raw) {
    switch (raw) {
      case 'approved':
        return SubmissionStatus.approved;
      case 'not_submitted':
        return SubmissionStatus.notSubmitted;
      case 'voided':
        return SubmissionStatus.voided;
      default:
        return SubmissionStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case SubmissionStatus.pending:
        return 'بانتظار الاعتماد';
      case SubmissionStatus.approved:
        return 'معتمَد';
      case SubmissionStatus.notSubmitted:
        return 'لم يسلّم';
      case SubmissionStatus.voided:
        return 'مُبطَل';
    }
  }
}

class ExamSubmission {
  final int? id;
  final int examId;
  final int studentId;
  final DateTime? startedAt;
  final DateTime? submittedAt;

  /// questionId (المحلي، رقم) → فهرس الاختيار اللي اختاره الطالب.
  final Map<int, int> answers;
  final double? autoScore;
  final double? finalGrade;
  final SubmissionStatus status;
  final bool autoSubmitted;
  final DateTime? pulledAt;

  // JOIN
  final String? studentName;

  const ExamSubmission({
    this.id,
    required this.examId,
    required this.studentId,
    this.startedAt,
    this.submittedAt,
    this.answers = const {},
    this.autoScore,
    this.finalGrade,
    this.status = SubmissionStatus.pending,
    this.autoSubmitted = false,
    this.pulledAt,
    this.studentName,
  });

  bool get didSubmit => submittedAt != null;

  Map<String, dynamic> toMap() => {
        if (id != null) COL_ES_ID: id,
        COL_ES_EXAM_ID: examId,
        COL_ES_STUDENT_ID: studentId,
        COL_ES_STARTED_AT: startedAt?.toIso8601String(),
        COL_ES_SUBMITTED_AT: submittedAt?.toIso8601String(),
        COL_ES_ANSWERS_JSON:
            jsonEncode(answers.map((k, v) => MapEntry(k.toString(), v))),
        COL_ES_AUTO_SCORE: autoScore,
        COL_ES_FINAL_GRADE: finalGrade,
        COL_ES_STATUS: status.dbValue,
        COL_ES_AUTO_SUBMITTED: autoSubmitted ? 1 : 0,
        COL_ES_PULLED_AT: pulledAt?.toIso8601String(),
      };

  factory ExamSubmission.fromMap(Map<String, dynamic> m) {
    final rawAnswers = m[COL_ES_ANSWERS_JSON] as String?;
    final answers = <int, int>{};
    if (rawAnswers != null && rawAnswers.isNotEmpty) {
      final decoded = jsonDecode(rawAnswers) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        final qid = int.tryParse(k);
        if (qid != null && v is int) answers[qid] = v;
      });
    }
    return ExamSubmission(
      id: m[COL_ES_ID] as int?,
      examId: m[COL_ES_EXAM_ID] as int,
      studentId: m[COL_ES_STUDENT_ID] as int,
      startedAt: _parse(m[COL_ES_STARTED_AT]),
      submittedAt: _parse(m[COL_ES_SUBMITTED_AT]),
      answers: answers,
      autoScore: (m[COL_ES_AUTO_SCORE] as num?)?.toDouble(),
      finalGrade: (m[COL_ES_FINAL_GRADE] as num?)?.toDouble(),
      status: SubmissionStatusX.fromDb(m[COL_ES_STATUS] as String?),
      autoSubmitted: (m[COL_ES_AUTO_SUBMITTED] as int? ?? 0) == 1,
      pulledAt: _parse(m[COL_ES_PULLED_AT]),
      studentName: m['student_name'] as String?,
    );
  }

  static DateTime? _parse(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  ExamSubmission copyWith({
    double? finalGrade,
    SubmissionStatus? status,
  }) =>
      ExamSubmission(
        id: id,
        examId: examId,
        studentId: studentId,
        startedAt: startedAt,
        submittedAt: submittedAt,
        answers: answers,
        autoScore: autoScore,
        finalGrade: finalGrade ?? this.finalGrade,
        status: status ?? this.status,
        autoSubmitted: autoSubmitted,
        pulledAt: pulledAt,
        studentName: studentName,
      );
}

/// طالب مسموح له بامتحان إلكتروني (لبناء allowedCodes وضمان نشر ملخصه).
class AllowedExamStudent {
  final int id;
  final String code;
  final String last4;
  const AllowedExamStudent(
      {required this.id, required this.code, required this.last4});
}

/// نتيجة سؤال واحد للطالب (للعرض في تفاصيل التسليم).
class QuestionResult {
  final int questionId;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final int? chosenIndex;
  final double points;
  final String? imageUrl;

  const QuestionResult({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.chosenIndex,
    required this.points,
    this.imageUrl,
  });

  bool get answered => chosenIndex != null;
  bool get isCorrect => answered && chosenIndex == correctIndex;
  double get earned => isCorrect ? points : 0;
}
