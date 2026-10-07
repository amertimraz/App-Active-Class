# Contract: `lib/utils/archive_history.dart` (دوال صرفة)

```dart
const String kArchiveEventArchived = 'archived';
const String kArchiveEventRestored = 'restored';

/// صيغة العرض: "تمت أرشفته — اليوم 3:20 م" / "أُعيد من الأرشيف — أمس 9:05 ص" / تاريخ كامل.
String archiveEventLabel(ArchiveEvent e, DateTime now);

/// عنصر مدموج لقائمة العرض.
sealed class TimelineItem { DateTime get at; }
class AttendanceItem extends TimelineItem { final Attendance record; }
class ArchiveItem extends TimelineItem { final ArchiveEvent event; }

/// يدمج سجلات الحضور وأحداث الأرشفة مرتبة تنازليًا بالتاريخ (الأحدث أولًا).
/// عند تساوي الوقت بالضبط: الحدث يظهر قبل السجل (الأحدث منطقيًا).
List<TimelineItem> mergeAttendanceAndArchive(
    List<Attendance> records, List<ArchiveEvent> events);

/// هل يظهر الحدث في قائمة السجلات العامة؟ (فلتر الحالة "الكل" + بحث الاسم/المجموعة).
bool archiveEventVisible({
  required String statusFilter,
  required String query,
  required String studentName,
  required int? groupFilter,
  required int? studentGroupId,
});

/// يقرر هل يُسجَّل حدث: archived فقط لو الطالب نشط، restored فقط لو مؤرشف.
bool shouldRecordArchiveEvent({required bool wasArchived, required String type});
```
