// lib/models/attendance_model.dart

class Attendance {
  final int? id;
  final int studentId;
  final DateTime date;
  final String status; // 'حاضر' or 'غائب'
  final String? notes;
  final DateTime? createdAt;

  Attendance({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      studentId: map['student_id'],
      date: DateTime.parse(map['date']),
      status: map['status'],
      notes: map['notes'],
      createdAt: map['created_at'] != null 
        ? DateTime.parse(map['created_at'])
        : null,
    );
  }

  Attendance copyWith({
    int? id,
    int? studentId,
    DateTime? date,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Attendance(id: $id, studentId: $studentId, date: $date, status: $status)';
}
