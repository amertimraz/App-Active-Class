// lib/utils/auto_absent.dart
//
// spec 046 — الغياب التلقائي بعد انتهاء الحصة: دوال صرفة (بمعامل now) بتحدد
// امتى الحصة "تقفل" ومين الطلاب اللي يتسجّل لهم غياب. الخدمة
// (auto_absent_service.dart) بتنفّذ والدوال دي بتتختبر لوحدها.
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/student_model.dart';

/// الملاحظة اللي بتميّز سجل الغياب التلقائي عن اليدوي.
const String kAutoAbsentNote = 'غياب تلقائي';

/// أقصى عدد أيام للتعويض بأثر رجعي لو التطبيق كان مقفول.
const int kAutoAbsentLookbackDays = 3;

/// أقصى مهلة مسموحة بعد نهاية الحصة (دقايق).
const int kAutoAbsentMaxGrace = 180;

int clampAutoAbsentGrace(int? v) {
  if (v == null) return 15;
  return v.clamp(0, kAutoAbsentMaxGrace);
}

({int h, int m})? _parseHm(String text) {
  final p = text.trim().split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return (h: h, m: m);
}

/// "HH:mm - HH:mm" → نهاية الحصة كاملة بتاريخ [day]. null لو مفيش وقت
/// نهاية أو الصيغة غير صالحة. نهاية ≤ بداية → حصة عابرة لمنتصف الليل (+1 يوم).
DateTime? sessionEndFor(DateTime day, String? sessionTime) {
  if (sessionTime == null) return null;
  final parts = sessionTime.split('-');
  if (parts.length != 2) return null;
  final start = _parseHm(parts[0]);
  final end = _parseHm(parts[1]);
  if (start == null || end == null) return null;
  var result = DateTime(day.year, day.month, day.day, end.h, end.m);
  if (end.h * 60 + end.m <= start.h * 60 + start.m) {
    result = result.add(const Duration(days: 1));
  }
  return result;
}

/// الحصة "مقفولة" للغياب: now >= نهاية + مهلة.
bool isSessionClosed({
  required DateTime end,
  required DateTime now,
  required int graceMinutes,
}) {
  final closeAt = end.add(Duration(minutes: graceMinutes));
  return !now.isBefore(closeAt);
}

/// الأيام المرشّحة للفحص (بالتاريخ فقط): من now−3 أيام لحد now، الأقدم أولًا.
List<DateTime> lookbackDays(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = kAutoAbsentLookbackDays; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
}

String autoAbsentKey(int groupId, DateTime day) =>
    '$groupId|${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// الحصة مؤهَّلة للمعالجة: مقفولة، ووقت إغلاقها بعد لحظة التفعيل، ومش
/// معالَجة قبل كده.
bool sessionEligible({
  required DateTime end,
  required DateTime now,
  required int graceMinutes,
  required DateTime enabledAt,
  required String key,
  required Set<String> processed,
}) {
  if (processed.contains(key)) return false;
  if (!isSessionClosed(end: end, now: now, graceMinutes: graceMinutes)) {
    return false;
  }
  final closeAt = end.add(Duration(minutes: graceMinutes));
  return closeAt.isAfter(enabledAt);
}

/// طلاب المجموعة اللي يتسجّل لهم غياب: غير مؤرشفين، بدأ حضورهم في أو قبل
/// [day]، ومالهمش سجل حضور في اليوم.
List<Student> studentsToMarkAbsent({
  required List<Student> groupStudents,
  required DateTime day,
  required Set<int> studentIdsWithRecord,
}) {
  final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
  return groupStudents.where((s) {
    if (s.id == null || s.isArchived) return false;
    if (studentIdsWithRecord.contains(s.id)) return false;
    final start = s.attendanceStart ?? s.createdAt;
    if (start != null && start.isAfter(dayEnd)) return false;
    return true;
  }).toList();
}

/// الغياب تلقائي؟ (غائب + الملاحظة).
bool isAutoAbsent(Attendance a) =>
    normalizeAttendanceStatus(a.status) == ATTENDANCE_ABSENT &&
    a.notes == kAutoAbsentNote;

/// يقلّم مفاتيح الحصص المعالَجة لنافذة التعويض.
Set<String> pruneProcessed(Set<String> keys, DateTime now) {
  final oldest = lookbackDays(now).first;
  return keys.where((k) {
    final i = k.indexOf('|');
    if (i < 0) return false;
    final d = DateTime.tryParse(k.substring(i + 1));
    return d != null && !d.isBefore(oldest);
  }).toSet();
}
