// lib/models/payment_model.dart

import 'package:active_class/config/constants.dart';

/// نوع الدفعة. «التحصيل» هو الفلوس الفعلية، و«الإسقاط» مسح مديونية بدون فلوس
/// (بيتحسب كرصيد على الطالب بس مش بيدخل في إجمالي التحصيل).
enum PaymentKind { collection, writeOff }

extension PaymentKindX on PaymentKind {
  String get dbValue => this == PaymentKind.writeOff ? 'write_off' : 'collection';

  static PaymentKind? fromDb(String? v) => switch (v) {
        'write_off' => PaymentKind.writeOff,
        'collection' => PaymentKind.collection,
        _ => null,
      };
}

class Payment {
  final int? id;
  final int studentId;
  final DateTime date;
  final double amount;
  final String? note;
  final DateTime? createdAt;

  /// النوع المخزّن (قد يكون null لصفوف قديمة أو جاية من جهاز قديم).
  final PaymentKind? storedKind;

  Payment({
    this.id,
    required this.studentId,
    required this.date,
    required this.amount,
    this.note,
    this.createdAt,
    this.storedKind,
  });

  /// النوع الفعلي: المخزّن، وإلا بيتشتق من الملاحظة (توافق مع الأجهزة القديمة).
  PaymentKind get kind =>
      storedKind ??
      (note == kDebtWriteOffNote ? PaymentKind.writeOff : PaymentKind.collection);

  bool get isWriteOff => kind == PaymentKind.writeOff;

  /// تحصيل فعلي (فلوس دخلت).
  bool get isCollection => kind == PaymentKind.collection;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date.toIso8601String(),
      'amount': amount,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'kind': kind.dbValue,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      studentId: map['student_id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'].toDouble(),
      note: map['note'],
      storedKind: PaymentKindX.fromDb(map['kind'] as String?),
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
    PaymentKind? storedKind,
  }) {
    return Payment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      storedKind: storedKind ?? this.storedKind,
    );
  }

  @override
  String toString() => 'Payment(id: $id, studentId: $studentId, amount: $amount, date: $date)';
}
