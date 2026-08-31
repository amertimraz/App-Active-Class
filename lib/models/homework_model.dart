// lib/models/homework_model.dart
//
// تسجيل حالة الواجب (تم الحل / ناقص / لم يُحل) — نص الواجب نفسه فاضل في
// الكشكول الورقي عمدًا، مش جوه التطبيق.
import 'package:active_class/config/constants.dart';

/// يطبّع قيمة حالة الواجب المخزَّنة (بما فيها القيم القديمة 'عمل'/'لم يعمل')
/// لواحدة من: [HOMEWORK_DONE] / [HOMEWORK_PARTIAL] / [HOMEWORK_NOT_DONE] / null.
/// مصدر الحقيقة الوحيد للتوافق مع البيانات القديمة (spec 010).
String? normalizeHomeworkStatus(String? raw) {
  final v = raw?.trim();
  if (v == null || v.isEmpty) return null;
  if (v == HOMEWORK_DONE || v == 'تم الحل') return HOMEWORK_DONE;
  if (v == HOMEWORK_NOT_DONE || v == 'لم يُحل') return HOMEWORK_NOT_DONE;
  if (v == HOMEWORK_PARTIAL) return HOMEWORK_PARTIAL;
  return null;
}

/// تسمية حالة الواجب للعرض والتقارير — مصدر الحقيقة الوحيد.
/// [absent] = الطالب غائب في اليوم ده (يتغلّب على أي حالة واجب).
String homeworkStatusLabel(String? raw, {bool absent = false}) {
  if (absent) return 'غائب (لا واجب)';
  switch (normalizeHomeworkStatus(raw)) {
    case HOMEWORK_DONE:
      return '🟢 تم الحل';
    case HOMEWORK_PARTIAL:
      return '🟡 ناقص';
    case HOMEWORK_NOT_DONE:
      return '🔴 لم يُحل';
    default:
      return 'لم يُسجَّل';
  }
}

class Homework {
  final int? id;
  final int studentId;
  final DateTime date;
  final String status; // 'عمل' or 'لم يعمل'
  final DateTime? createdAt;

  Homework({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date.toIso8601String(),
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Homework.fromMap(Map<String, dynamic> map) {
    return Homework(
      id: map['id'],
      studentId: map['student_id'],
      date: DateTime.parse(map['date']),
      status: map['status'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  Homework copyWith({
    int? id,
    int? studentId,
    DateTime? date,
    String? status,
    DateTime? createdAt,
  }) {
    return Homework(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Homework(id: $id, studentId: $studentId, date: $date, status: $status)';
}
