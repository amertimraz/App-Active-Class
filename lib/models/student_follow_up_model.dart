// lib/models/student_follow_up_model.dart
//
// spec 021 — واقعة "تمّت المتابعة": المدرس أقرّ إنه اتواصل مع ولي أمر
// طالب مرصود، فالطالب بيختفي من القائمة الرئيسية مؤقتًا (مدة التهدئة).
// reasonTypes = أنواع إشارات AtRiskService اللي كانت متحقّقة وقت
// الإقرار بالظبط (مش كل الأنواع الممكنة) — بيُستخدم لتحديد "إشارة نوع
// جديد" بعد الإقرار.
import 'dart:convert';

import 'package:active_class/config/constants.dart';

class StudentFollowUp {
  final int? id;
  final int studentId;
  final List<String> reasonTypes;
  final DateTime acknowledgedAt;
  final String? note;

  const StudentFollowUp({
    this.id,
    required this.studentId,
    required this.reasonTypes,
    required this.acknowledgedAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      COL_SFU_ID: id,
      COL_SFU_STUDENT_ID: studentId,
      COL_SFU_REASON_TYPES: jsonEncode(reasonTypes),
      COL_SFU_ACKNOWLEDGED_AT: acknowledgedAt.toIso8601String(),
      COL_SFU_NOTE: note,
    };
  }

  factory StudentFollowUp.fromMap(Map<String, dynamic> map) {
    final rawTypes = map[COL_SFU_REASON_TYPES];
    List<String> types = const [];
    if (rawTypes is String && rawTypes.isNotEmpty) {
      try {
        types = (jsonDecode(rawTypes) as List).cast<String>();
      } catch (_) {
        types = const [];
      }
    }
    return StudentFollowUp(
      id: map[COL_SFU_ID] as int?,
      studentId: map[COL_SFU_STUDENT_ID] as int,
      reasonTypes: types,
      acknowledgedAt: DateTime.parse(map[COL_SFU_ACKNOWLEDGED_AT] as String),
      note: map[COL_SFU_NOTE] as String?,
    );
  }

  @override
  String toString() =>
      'StudentFollowUp(id: $id, studentId: $studentId, reasonTypes: $reasonTypes, '
      'acknowledgedAt: $acknowledgedAt)';
}
