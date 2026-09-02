// lib/models/exam_grade_model.dart
import 'package:flutter/material.dart';

// ─── تصنيف الدرجة ─────────────────────────────────────────────────────────────
enum GradeCategory {
  excellent,  // ممتاز  ≥ 90%
  veryGood,   // جيد جداً 80-89%
  good,       // جيد    70-79%
  pass,       // مقبول  60-69%
  fail,       // راسب   < 60%
  absent,     // غائب
}

extension GradeCategoryExt on GradeCategory {
  String get label {
    switch (this) {
      case GradeCategory.excellent: return 'ممتاز';
      case GradeCategory.veryGood:  return 'جيد جداً';
      case GradeCategory.good:      return 'جيد';
      case GradeCategory.pass:      return 'مقبول';
      case GradeCategory.fail:      return 'راسب';
      case GradeCategory.absent:    return 'غائب';
    }
  }

  Color get color {
    switch (this) {
      case GradeCategory.excellent: return const Color(0xFF10B981); // أخضر
      case GradeCategory.veryGood:  return const Color(0xFF3B82F6); // أزرق
      case GradeCategory.good:      return const Color(0xFF8B5CF6); // بنفسجي
      case GradeCategory.pass:      return const Color(0xFFF59E0B); // برتقالي
      case GradeCategory.fail:      return const Color(0xFFEF4444); // أحمر
      case GradeCategory.absent:    return const Color(0xFF6B7280); // رمادي
    }
  }

  // passingPct: نسبة درجة النجاح المحددة للامتحان (افتراضي 60% لو مفيش امتحان محدد)
  static GradeCategory fromPercentage(double pct, {double passingPct = 60}) {
    if (pct >= 90) return GradeCategory.excellent;
    if (pct >= 80) return GradeCategory.veryGood;
    if (pct >= 70) return GradeCategory.good;
    if (pct >= passingPct) return GradeCategory.pass;
    return GradeCategory.fail;
  }
}

// ─── درجة طالب ────────────────────────────────────────────────────────────────
class ExamGrade {
  final int?    id;
  final int     examId;
  final int     studentId;
  final double? grade;
  final String? notes;
  final bool    isAbsent;
  final DateTime? createdAt;

  // بيانات مساعدة (JOIN)
  final String? studentName;
  final double? maxGrade;
  final double? passingGrade;

  const ExamGrade({
    this.id,
    required this.examId,
    required this.studentId,
    this.grade,
    this.notes,
    this.isAbsent = false,
    this.createdAt,
    this.studentName,
    this.maxGrade,
    this.passingGrade,
  });

  bool get isEntered => grade != null || isAbsent;

  GradeCategory get category {
    if (isAbsent) return GradeCategory.absent;
    if (grade == null || maxGrade == null || maxGrade! <= 0) return GradeCategory.fail;
    final pct = (grade! / maxGrade!) * 100;
    final passingPct = (passingGrade != null && maxGrade! > 0)
        ? (passingGrade! / maxGrade!) * 100
        : 60.0;
    return GradeCategoryExt.fromPercentage(pct, passingPct: passingPct);
  }

  double get percentage =>
      (grade != null && maxGrade != null && maxGrade! > 0)
          ? (grade! / maxGrade!) * 100
          : 0;

  Map<String, dynamic> toMap() => {
    'id':         id,
    'exam_id':    examId,
    'student_id': studentId,
    'grade':      grade,
    'notes':      notes,
    'is_absent':  isAbsent ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
  };

  factory ExamGrade.fromMap(Map<String, dynamic> m) => ExamGrade(
    id:           m['id'] as int?,
    examId:       m['exam_id'] as int,
    studentId:    m['student_id'] as int,
    grade:        m['grade'] != null ? (m['grade'] as num).toDouble() : null,
    notes:        m['notes'] as String?,
    isAbsent:     (m['is_absent'] as int? ?? 0) == 1,
    createdAt:    m['created_at'] != null
        ? DateTime.parse(m['created_at'] as String) : null,
    studentName:  m['student_name'] as String?,
    maxGrade:     m['max_grade'] != null ? (m['max_grade'] as num).toDouble() : null,
    passingGrade: m['passing_grade'] != null ? (m['passing_grade'] as num).toDouble() : null,
  );

  // sentinel: يفرّق بين "الباراميتر ماتبعتش" و"اتبعت null قصداً" (لمسح
  // الملاحظة، أو لمسح الدرجة — بديل رجوع الطالب عن درجة مُدخلة قبل كده،
  // زي ما بيوضّح tooltip حقل الدرجة بالظبط "امسح الخانة وسيبها فاضية
  // عشان تتراجع عن الدرجة". قبل كده `double? grade` العادي كان بيستخدم
  // `grade ?? this.grade`، فمش قادر يفرّق بين "امسح الدرجة" (null صريح)
  // و"معديش الباراميتر خالص" — فكان بيرجّع الدرجة القديمة بدل ما يمسحها،
  // فتفضل الإحصائيات وشارة التصنيف على الشاشة معروضة بالقيمة القديمة
  // لحد ما الشاشة تتعمل reload، رغم إن قاعدة البيانات نفسها كانت بتتحدث
  // صح (لأن الحفظ الفعلي في DB بيمر من مسار تاني منفصل عن copyWith).
  static const _unsetGrade = Object();
  static const _unsetNotes = Object();

  ExamGrade copyWith({
    Object? grade = _unsetGrade,
    Object? notes = _unsetNotes,
    bool?   isAbsent,
  }) => ExamGrade(
    id:           id,
    examId:       examId,
    studentId:    studentId,
    grade:        isAbsent == true
        ? null
        : (identical(grade, _unsetGrade) ? this.grade : grade as double?),
    notes:        identical(notes, _unsetNotes) ? this.notes : notes as String?,
    isAbsent:     isAbsent     ?? this.isAbsent,
    createdAt:    createdAt,
    studentName:  studentName,
    maxGrade:     maxGrade,
    passingGrade: passingGrade,
  );
}

// ─── توزيع الدرجات ─────────────────────────────────────────────────────────────
class GradeDistribution {
  final int excellent;  // ≥ 90%
  final int veryGood;   // 80-89%
  final int good;       // 70-79%
  final int pass;       // 60-69%
  final int fail;       // < 60%
  final int absent;

  const GradeDistribution({
    this.excellent = 0,
    this.veryGood  = 0,
    this.good      = 0,
    this.pass      = 0,
    this.fail      = 0,
    this.absent    = 0,
  });

  int get total => excellent + veryGood + good + pass + fail + absent;
}

// ─── ملخص نتائج امتحان لمجموعة ────────────────────────────────────────────────
class ExamGroupStats {
  final int    examId;
  final int    groupId;
  final String groupName;
  final int    total;
  final int    entered;
  final int    passed;
  final int    failed;
  final int    absent;
  final double average;
  final double highest;
  final double lowest;
  final GradeDistribution distribution;

  const ExamGroupStats({
    required this.examId,
    required this.groupId,
    required this.groupName,
    required this.total,
    required this.entered,
    required this.passed,
    required this.failed,
    this.absent = 0,
    required this.average,
    required this.highest,
    required this.lowest,
    this.distribution = const GradeDistribution(),
  });

  double get passRate => entered > 0 ? (passed / entered) * 100 : 0;
  int get notEntered => total - entered - absent;
}

// ─── تقدم الإدخال لامتحان (لبطاقة الامتحان) ──────────────────────────────────
class ExamProgress {
  final int examId;
  final int totalStudents;
  final int enteredGrades;
  final int absentStudents;

  const ExamProgress({
    required this.examId,
    required this.totalStudents,
    required this.enteredGrades,
    this.absentStudents = 0,
  });

  int get pending => totalStudents - enteredGrades - absentStudents;
  double get percentage =>
      totalStudents > 0 ? enteredGrades / totalStudents : 0;
}

// ─── سجل أداء طالب في الامتحانات ─────────────────────────────────────────────
class StudentExamRecord {
  final int      examId;
  final String   examName;
  final DateTime examDate;
  /// spec 013 — الشهر اللي يُحسب له الامتحان في التقارير الشهرية
  /// (اليوم 1). مشتقّ وقت البناء من report_month أو شهر examDate.
  final DateTime reportMonth;
  final double   maxGrade;
  final double   passingGrade;
  final double?  grade;
  final bool     isAbsent;
  final String   groupName;

  const StudentExamRecord({
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.reportMonth,
    required this.maxGrade,
    required this.passingGrade,
    this.grade,
    this.isAbsent = false,
    required this.groupName,
  });

  /// يبني قيمة reportMonth من نص report_month (أو شهر التاريخ لو null/غير صالح).
  static DateTime resolveReportMonth(String? raw, DateTime examDate) {
    if (raw != null) {
      final p = raw.split('-');
      if (p.length == 2) {
        final y = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        if (y != null && m != null && m >= 1 && m <= 12) {
          return DateTime(y, m, 1);
        }
      }
    }
    return DateTime(examDate.year, examDate.month, 1);
  }

  double get percentage =>
      (grade != null && maxGrade > 0) ? (grade! / maxGrade) * 100 : 0;

  GradeCategory get category {
    if (isAbsent) return GradeCategory.absent;
    if (grade == null) return GradeCategory.fail;
    final passingPct = maxGrade > 0 ? (passingGrade / maxGrade) * 100 : 60.0;
    return GradeCategoryExt.fromPercentage(percentage, passingPct: passingPct);
  }
}

// ─── طالب في قائمة الأوائل ────────────────────────────────────────────────────
class LeaderboardEntry {
  final int    studentId;
  final String studentName;
  final int    groupId;
  final String groupName;
  final double totalGrade;
  final double totalMax;
  final int    examCount;
  int rank = 0;

  LeaderboardEntry({
    required this.studentId,
    required this.studentName,
    required this.groupId,
    required this.groupName,
    required this.totalGrade,
    required this.totalMax,
    required this.examCount,
    this.rank = 0,
  });

  double get percentage => totalMax > 0 ? (totalGrade / totalMax) * 100 : 0;

  GradeCategory get category =>
      GradeCategoryExt.fromPercentage(percentage);
}
