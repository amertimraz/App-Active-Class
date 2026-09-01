// lib/models/attendance_model.dart
import 'package:flutter/material.dart' show Color;
import 'package:active_class/config/constants.dart';

/// يطبّع قيمة حالة الحضور المخزَّنة لواحدة من:
/// [ATTENDANCE_PRESENT] / [ATTENDANCE_LATE] / [ATTENDANCE_ABSENT] / null.
/// مصدر الحقيقة الوحيد للتوافق مع البيانات القديمة (spec 011 — نفس نمط
/// normalizeHomeworkStatus في spec 010).
String? normalizeAttendanceStatus(String? raw) {
  final v = raw?.trim();
  if (v == null || v.isEmpty) return null;
  if (v == ATTENDANCE_PRESENT) return ATTENDANCE_PRESENT;
  if (v == ATTENDANCE_ABSENT) return ATTENDANCE_ABSENT;
  if (v == ATTENDANCE_LATE) return ATTENDANCE_LATE;
  return null;
}

/// هل الحالة دي تُحتسب "حضور" (في نسبة الحضور وعدّ الحصص للفوترة بالحصة)؟
/// "متأخر" = حضر فعلاً → تُحتسب زي "حاضر" بالظبط.
bool attendanceCountsAsPresent(String? raw) {
  final s = normalizeAttendanceStatus(raw);
  return s == ATTENDANCE_PRESENT || s == ATTENDANCE_LATE;
}

/// تسمية حالة الحضور للعرض والتقارير — مصدر الحقيقة الوحيد.
String attendanceStatusLabel(String? raw) {
  switch (normalizeAttendanceStatus(raw)) {
    case ATTENDANCE_PRESENT:
      return '✅ حاضر';
    case ATTENDANCE_LATE:
      return '⏰ متأخر';
    case ATTENDANCE_ABSENT:
      return '❌ غائب';
    default:
      return 'لم يُسجَّل';
  }
}

/// لون حالة الحضور للـUI والتقارير — أخضر / كهرماني / أحمر / رمادي.
Color attendanceStatusColor(String? raw) {
  switch (normalizeAttendanceStatus(raw)) {
    case ATTENDANCE_PRESENT:
      return const Color(0xFF10B981);
    case ATTENDANCE_LATE:
      return const Color(0xFFF59E0B);
    case ATTENDANCE_ABSENT:
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF9CA3AF);
  }
}

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
