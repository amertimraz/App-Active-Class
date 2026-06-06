// lib/models/payment_model.dart

class Payment {
  final int? id;
  final int studentId;
  final DateTime date;
  final double amount;
  final String? note;
  final DateTime? createdAt;

  Payment({
    this.id,
    required this.studentId,
    required this.date,
    required this.amount,
    this.note,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date.toIso8601String(),
      'amount': amount,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      studentId: map['student_id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'].toDouble(),
      note: map['note'],
      createdAt: map['created_at'] != null 
        ? DateTime.parse(map['created_at'])
        : null,
    );
  }

  Payment copyWith({
    int? id,
    int? studentId,
    DateTime? date,
    double? amount,
    String? note,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Payment(id: $id, studentId: $studentId, amount: $amount, date: $date)';
}
