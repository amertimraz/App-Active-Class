// lib/utils/next_session.dart
//
// «الحصة الجاية» على الرئيسية: من حصص اليوم نختار الحصة الشغالة حاليًا، وإلا
// أقرب حصة جاية. منطق صرف (الوقت بيتبعت) عشان يتختبر.
import 'package:active_class/models/group_model.dart';

/// حصة مجموعة النهاردة بميعادها.
class SessionSlot {
  final Group group;
  final DateTime start;
  final DateTime end;
  const SessionSlot(this.group, this.start, this.end);
}

/// "16:00-18:00" أو "16:00 - 18:00" أو "16:00" لتاريخ [day]. لو النهاية مش
/// مكتوبة بنفترض [defaultMinutes]. null لو الصيغة غلط.
({DateTime start, DateTime end})? parseSessionRange(
  String? text,
  DateTime day, {
  int defaultMinutes = 90,
}) {
  if (text == null || text.trim().isEmpty) return null;
  DateTime? at(String s) {
    final p = s.trim().split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return DateTime(day.year, day.month, day.day, h, m);
  }

  final parts = text.split('-');
  final start = at(parts.first);
  if (start == null) return null;
  var end = parts.length > 1 ? at(parts[1]) : null;
  // حصة بتعدّي نص الليل: النهاية قبل البداية → تاني يوم.
  if (end != null && !end.isAfter(start)) {
    end = end.add(const Duration(days: 1));
  }
  return (start: start, end: end ?? start.add(Duration(minutes: defaultMinutes)));
}

class NextSessionInfo {
  final Group group;
  final DateTime start;
  final DateTime end;

  /// الحصة شغالة دلوقتي.
  final bool isLive;
  final int studentCount;
  final int overdueCount;

  const NextSessionInfo({
    required this.group,
    required this.start,
    required this.end,
    required this.isLive,
    required this.studentCount,
    required this.overdueCount,
  });
}

/// الحصة الشغالة دلوقتي لو فيه، وإلا أقرب حصة لسه ما بدأتش. null لو كل
/// حصص النهاردة خلصت.
SessionSlot? pickNextSlot(List<SessionSlot> slots, DateTime now) {
  SessionSlot? live;
  SessionSlot? upcoming;
  for (final s in slots) {
    if (!now.isBefore(s.start) && now.isBefore(s.end)) {
      if (live == null || s.start.isAfter(live.start)) live = s;
    } else if (s.start.isAfter(now)) {
      if (upcoming == null || s.start.isBefore(upcoming.start)) upcoming = s;
    }
  }
  return live ?? upcoming;
}

/// نص "بعد كذا" للحصة الجاية: "بعد 40 دقيقة" / "بعد ساعة و10 دقايق".
String untilText(Duration d) {
  final mins = d.inMinutes;
  if (mins <= 0) return 'دلوقتي';
  if (mins < 60) return 'بعد $mins دقيقة';
  final h = mins ~/ 60;
  final m = mins % 60;
  final hText = h == 1 ? 'ساعة' : (h == 2 ? 'ساعتين' : '$h ساعات');
  return m == 0 ? 'بعد $hText' : 'بعد $hText و$m دقيقة';
}
