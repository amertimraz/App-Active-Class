// lib/views/groups/group_form/group_schedule_conflict.dart
import 'package:flutter/material.dart';
import 'package:active_class/models/group_model.dart';

/// منطق تحليل/تعارض المواعيد الأسبوعية — موحَّد بين groups_page.dart
/// وgroup_details_page.dart (كانا فيهم نسختان منفصلتان متطابقتان
/// منطقيًا 100%: _findConflictingGroup/_parseDaySlots في الأول،
/// _findConflictingGroupGD/_parseDaySlotsGD في التاني — راجع
/// specs/039-ui-forms-refactor/research.md #4).
Map<String, List<(int, int)>> parseDaySlots(String raw) {
  final byDay = <String, List<(int, int)>>{};
  for (final part in raw.split(',')) {
    final s = part.trim();
    if (s.isEmpty) continue;
    final sp = s.split(' ');
    if (sp.length < 2) continue;
    final day = sp.first;
    final range = s.substring(day.length).trim().split('-');
    if (range.length != 2) continue;
    TimeOfDay? parseT(String v) {
      final p = v.trim().split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final from = parseT(range[0]);
    final to = parseT(range[1]);
    if (from == null || to == null) continue;
    byDay
        .putIfAbsent(day, () => [])
        .add((from.hour * 60 + from.minute, to.hour * 60 + to.minute));
  }
  return byDay;
}

/// يتحقق من وجود مواعيد متداخلة في نفس اليوم داخل نص الجدول نفسه.
bool hasScheduleOverlap(String raw) {
  final byDay = parseDaySlots(raw);
  for (final ranges in byDay.values) {
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < ranges.length; i++) {
      if (ranges[i].$1 < ranges[i - 1].$2) return true;
    }
  }
  return false;
}

bool _rangesOverlap((int, int) a, (int, int) b) => a.$1 < b.$2 && b.$1 < a.$2;

/// يبحث عن مجموعة من [others] بيتعارض ميعادها مع [raw]، ويرجّع أول مجموعة
/// متعارضة أو null لو مفيش تعارض.
Group? findConflictingGroup(String raw, List<Group> others) {
  final mySlots = parseDaySlots(raw);
  for (final other in others) {
    final otherRaw = other.schedule;
    if (otherRaw == null || otherRaw.trim().isEmpty) continue;
    final otherSlots = parseDaySlots(otherRaw);
    for (final entry in mySlots.entries) {
      final otherRanges = otherSlots[entry.key];
      if (otherRanges == null) continue;
      for (final mine in entry.value) {
        for (final theirs in otherRanges) {
          if (_rangesOverlap(mine, theirs)) return other;
        }
      }
    }
  }
  return null;
}

/// يتحقق من صحة نص جدول المواعيد ويرجّع رسالة خطأ عربية واضحة، أو null
/// لو صالح. مستخرَجة من _validateScheduleText في group_details_page.dart
/// (رسائل أوضح من رسالة groups_page العامة — أُبقيت كما هي لأنها لا
/// تخالف أي سلوك في groups_page، فقط تضيف تفصيلًا في group_details_page).
String? validateScheduleText(String raw) {
  final byDay = <String, List<(int, int)>>{};
  for (final part in raw.split(',')) {
    final s = part.trim();
    if (s.isEmpty) continue;
    final sp = s.split(' ');
    final day = sp.first;
    if (sp.length < 2) {
      return 'اليوم "$day" بدون وقت — حدد وقت البداية والنهاية';
    }
    final range = s.substring(day.length).trim().split('-');
    TimeOfDay? parseT(String v) {
      final p = v.trim().split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    final from = range.length == 2 ? parseT(range[0]) : null;
    final to = range.length == 2 ? parseT(range[1]) : null;
    if (from == null || to == null) {
      return 'اليوم "$day" بدون وقت كامل — حدد وقت البداية والنهاية';
    }
    byDay
        .putIfAbsent(day, () => [])
        .add((from.hour * 60 + from.minute, to.hour * 60 + to.minute));
  }
  for (final ranges in byDay.values) {
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < ranges.length; i++) {
      if (ranges[i].$1 < ranges[i - 1].$2) {
        return 'فيه موعدين متداخلين في نفس اليوم';
      }
    }
  }
  return null;
}
