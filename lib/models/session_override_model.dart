// lib/models/session_override_model.dart
//
// spec 032 — إلغاء حصة اليوم وتعويضها.
// استثناء واحد لكل (مجموعة، يوم):
//   cancelled → مفيش حصة النهارده (رغم إن الجدول بيقول فيه)
//   makeup    → فيه حصة تعويضية عن يوم اتلغى قبل كده (compensatesDate)
//   extra     → فيه حصة إضافية مش في الجدول
// الفوترة مبتتأثرش بالجدول ده مباشرةً — كلها من صفوف الحضور.
import 'package:active_class/config/constants.dart';
import 'package:flutter/foundation.dart';

enum SessionOverrideType { cancelled, makeup, extra }

class SessionOverride {
  final int? id;
  final int groupId;
  final DateTime date; // منزوع الوقت (منتصف الليل محلي)
  final SessionOverrideType type;
  final DateTime? compensatesDate; // للـmakeup بس
  final String? note;
  final DateTime? createdAt;

  const SessionOverride({
    this.id,
    required this.groupId,
    required this.date,
    required this.type,
    this.compensatesDate,
    this.note,
    this.createdAt,
  });

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseYmd(String s) {
    final d = DateTime.parse(s.length > 10 ? s.substring(0, 10) : s);
    return DateTime(d.year, d.month, d.day);
  }

  Map<String, dynamic> toMap() {
    return {
      COL_SO_ID: id,
      COL_SO_GROUP_ID: groupId,
      COL_SO_DATE: ymd(date),
      COL_SO_TYPE: type.name,
      COL_SO_COMPENSATES_DATE:
          compensatesDate == null ? null : ymd(compensatesDate!),
      COL_SO_NOTE: note,
      COL_SO_CREATED_AT: (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory SessionOverride.fromMap(Map<String, dynamic> map) {
    final rawType = map[COL_SO_TYPE] as String?;
    SessionOverrideType type;
    switch (rawType) {
      case 'cancelled':
        type = SessionOverrideType.cancelled;
        break;
      case 'makeup':
        type = SessionOverrideType.makeup;
        break;
      case 'extra':
        type = SessionOverrideType.extra;
        break;
      default:
        debugPrint('SessionOverride: نوع غير معروف "$rawType" → cancelled');
        type = SessionOverrideType.cancelled;
    }
    final rawComp = map[COL_SO_COMPENSATES_DATE] as String?;
    final rawCreated = map[COL_SO_CREATED_AT] as String?;
    return SessionOverride(
      id: map[COL_SO_ID] as int?,
      groupId: map[COL_SO_GROUP_ID] as int,
      date: _parseYmd(map[COL_SO_DATE] as String),
      type: type,
      compensatesDate:
          (rawComp == null || rawComp.isEmpty) ? null : _parseYmd(rawComp),
      note: map[COL_SO_NOTE] as String?,
      createdAt: (rawCreated == null || rawCreated.isEmpty)
          ? null
          : DateTime.tryParse(rawCreated),
    );
  }

  SessionOverride copyWith({
    int? id,
    int? groupId,
    DateTime? date,
    SessionOverrideType? type,
    DateTime? compensatesDate,
    String? note,
    DateTime? createdAt,
  }) {
    return SessionOverride(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      date: date ?? this.date,
      type: type ?? this.type,
      compensatesDate: compensatesDate ?? this.compensatesDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'SessionOverride(id: $id, groupId: $groupId, date: ${ymd(date)}, '
      'type: ${type.name}, compensatesDate: '
      '${compensatesDate == null ? null : ymd(compensatesDate!)})';
}
