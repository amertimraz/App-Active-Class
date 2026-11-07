// lib/utils/archive_periods.dart
//
// فترات أرشفة الطالب (من سجل أحداث الأرشفة/الاستعادة): الشهور اللي كان فيها
// مؤرشف بالكامل مش بتتحسب عليه. دوال صرفة عشان تتختبر.
import 'package:active_class/models/archive_event_model.dart';

class ArchivePeriod {
  final DateTime start;

  /// null = لسه مؤرشف (فترة مفتوحة).
  final DateTime? end;
  const ArchivePeriod(this.start, this.end);

  bool get isOpen => end == null;

  /// الشهر ده (من أوله لأول الشهر اللي بعده) كله جوه الفترة؟
  bool coversMonth(DateTime monthStart) {
    final next = DateTime(monthStart.year, monthStart.month + 1, 1);
    if (start.isAfter(monthStart)) return false;
    final e = end;
    return e == null || !e.isBefore(next);
  }
}

/// يبني فترات كل طالب من الأحداث (بأي ترتيب). حدث «restored» من غير
/// «archived» قبله بيتجاهل؛ و«archived» مكرر قبل استعادة بيتجاهل.
Map<int, List<ArchivePeriod>> buildArchivePeriods(List<ArchiveEvent> events) {
  final byStudent = <int, List<ArchiveEvent>>{};
  for (final e in events) {
    byStudent.putIfAbsent(e.studentId, () => []).add(e);
  }
  final out = <int, List<ArchivePeriod>>{};
  byStudent.forEach((id, list) {
    list.sort((a, b) => a.at.compareTo(b.at));
    final periods = <ArchivePeriod>[];
    DateTime? openStart;
    for (final e in list) {
      if (e.isArchive) {
        openStart ??= e.at;
      } else if (e.isRestore && openStart != null) {
        periods.add(ArchivePeriod(openStart, e.at));
        openStart = null;
      }
    }
    if (openStart != null) periods.add(ArchivePeriod(openStart, null));
    if (periods.isNotEmpty) out[id] = periods;
  });
  return out;
}
