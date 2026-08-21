// lib/models/homework_model.dart
//
// تسجيل حالة الواجب بس (عمل / لم يعمل) — نص الواجب نفسه فاضل في
// الكشكول الورقي عمدًا، مش جوه التطبيق.
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
