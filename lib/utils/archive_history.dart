// lib/utils/archive_history.dart
//
// spec 047 — دوال صرفة لعرض أحداث أرشفة الطالب داخل سجل الحضور: الصيغة،
// دمج مع سجلات الحضور، وقواعد الظهور/التسجيل.
import 'package:intl/intl.dart';

import 'package:active_class/models/archive_event_model.dart';
import 'package:active_class/models/attendance_model.dart';

export 'package:active_class/models/archive_event_model.dart'
    show ArchiveEvent, kArchiveEventArchived, kArchiveEventRestored;

/// "3:20 م" / "9:05 ص" (بدون intl locale عشان الاختبارات).
String _time(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${d.hour >= 12 ? 'م' : 'ص'}';
}

const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// "تمت أرشفته — اليوم 3:20 م" / "أُعيد من الأرشيف — أمس 9:05 ص" /
/// "تمت أرشفته — 12 سبتمبر 2026 3:20 م".
String archiveEventLabel(ArchiveEvent e, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(e.at.year, e.at.month, e.at.day);
  final diff = today.difference(day).inDays;
  final String when;
  if (diff == 0) {
    when = 'اليوم ${_time(e.at)}';
  } else if (diff == 1) {
    when = 'أمس ${_time(e.at)}';
  } else {
    when = '${e.at.day} ${_months[e.at.month - 1]} ${e.at.year} ${_time(e.at)}';
  }
  final head = e.isArchive ? 'تمت أرشفته' : 'أُعيد من الأرشيف';
  return '$head — $when';
}

sealed class TimelineItem {
  DateTime get at;
}

class AttendanceItem extends TimelineItem {
  final Attendance record;
  AttendanceItem(this.record);
  @override
  DateTime get at => record.date;
}

class ArchiveItem extends TimelineItem {
  final ArchiveEvent event;
  ArchiveItem(this.event);
  @override
  DateTime get at => event.at;
}

/// يدمج السجلات والأحداث تنازليًا بالتاريخ (الأحدث أولًا). عند التساوي
/// بالضبط الحدث يظهر قبل السجل.
List<TimelineItem> mergeAttendanceAndArchive(
    List<Attendance> records, List<ArchiveEvent> events) {
  final items = <TimelineItem>[
    ...records.map(AttendanceItem.new),
    ...events.map(ArchiveItem.new),
  ];
  items.sort((a, b) {
    final c = b.at.compareTo(a.at);
    if (c != 0) return c;
    final aIsEvent = a is ArchiveItem ? 0 : 1;
    final bIsEvent = b is ArchiveItem ? 0 : 1;
    return aIsEvent.compareTo(bIsEvent);
  });
  return items;
}

/// هل يظهر الحدث في قائمة السجلات العامة؟ فقط مع فلتر الحالة "الكل"،
/// ويحترم بحث الاسم وفلتر المجموعة.
bool archiveEventVisible({
  required String statusFilter,
  required String query,
  required String studentName,
  required int? groupFilter,
  required int? studentGroupId,
}) {
  if (statusFilter.isNotEmpty) return false;
  if (groupFilter != null && studentGroupId != groupFilter) return false;
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty && !studentName.toLowerCase().contains(q)) return false;
  return true;
}

/// archived فقط لو الطالب كان نشط، restored فقط لو كان مؤرشف.
bool shouldRecordArchiveEvent(
    {required bool wasArchived, required String type}) {
  if (type == kArchiveEventArchived) return !wasArchived;
  if (type == kArchiveEventRestored) return wasArchived;
  return false;
}

/// مساعد للمجموعات الشهرية في العرض (متاح للاستخدام في الواجهة).
String archiveMonthLabel(DateTime d) => DateFormat('MMMM yyyy', 'ar').format(d);
