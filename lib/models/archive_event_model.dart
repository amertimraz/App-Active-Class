// lib/models/archive_event_model.dart
//
// spec 047 — حدث أرشفة/استعادة طالب. للقراءة فقط (بيتسجّل تلقائيًا عند
// الأرشفة/الاستعادة) ومش بيدخل في أي حساب حضور أو مديونية.
import 'package:active_class/config/constants.dart';

const String kArchiveEventArchived = 'archived';
const String kArchiveEventRestored = 'restored';

class ArchiveEvent {
  final int? id;
  final int studentId;
  final String type; // kArchiveEventArchived | kArchiveEventRestored
  final DateTime at;

  const ArchiveEvent({
    this.id,
    required this.studentId,
    required this.type,
    required this.at,
  });

  bool get isArchive => type == kArchiveEventArchived;
  bool get isRestore => type == kArchiveEventRestored;

  Map<String, dynamic> toMap() => {
        COL_SAE_ID: id,
        COL_SAE_STUDENT_ID: studentId,
        COL_SAE_TYPE: type,
        COL_SAE_EVENT_AT: at.toIso8601String(),
      };

  factory ArchiveEvent.fromMap(Map<String, dynamic> map) => ArchiveEvent(
        id: map[COL_SAE_ID] as int?,
        studentId: map[COL_SAE_STUDENT_ID] as int,
        type: map[COL_SAE_TYPE] as String,
        at: DateTime.parse(map[COL_SAE_EVENT_AT] as String),
      );
}
