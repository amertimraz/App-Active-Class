// lib/models/booking_request_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// طلب حجز واصل من صفحة الحجز العامة (ولي أمر/طالب) — مخزّن مؤقتًا في
/// Firestore لحد ما المعلم يقبله (يتحول لطالب محلي) أو يرفضه.
class BookingRequest {
  final String id;
  final String studentName;
  final String guardianPhone;
  final String? gradeLevel;
  final String? classSection;
  final String? preferredTime;
  final String? notes;
  final DateTime? createdAt;
  final List<CustomAnswer> customAnswers;

  BookingRequest({
    required this.id,
    required this.studentName,
    required this.guardianPhone,
    this.gradeLevel,
    this.classSection,
    this.preferredTime,
    this.notes,
    this.createdAt,
    this.customAnswers = const [],
  });

  factory BookingRequest.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    final rawCustom = map['customAnswers'];
    return BookingRequest(
      id: id,
      studentName: map['studentName'] as String? ?? '',
      guardianPhone: map['guardianPhone'] as String? ?? '',
      gradeLevel: (map['gradeLevel'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['gradeLevel'] as String?,
      classSection: (map['classSection'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['classSection'] as String?,
      preferredTime: (map['preferredTime'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['preferredTime'] as String?,
      notes: (map['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['notes'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      customAnswers: rawCustom is List
          ? rawCustom
              .whereType<Map>()
              .map((e) => CustomAnswer(
                    label: (e['label'] as String?) ?? '',
                    value: (e['value'] as String?) ?? '',
                  ))
              .where((a) => a.value.trim().isNotEmpty)
              .toList()
          : const [],
    );
  }
}

/// إجابة حقل مخصص أضافه المعلم بنفسه (اسم الحقل + قيمة الإجابة) — مخزّنة
/// مع الطلب نفسه عشان تفضل ثابتة حتى لو المعلم غيّر/مسح تعريف الحقل لاحقًا.
class CustomAnswer {
  final String label;
  final String value;
  const CustomAnswer({required this.label, required this.value});
}
