// lib/utils/schedule_week.dart
//
// spec 053 — تواريخ جدول الحصص: الأسبوع بيبدأ السبت (فهرس اليوم: السبت=0
// ... الجمعة=6) زي `_kDays` في schedule_page. دوال صرفة على تواريخ تقويمية
// (بدون وقت) عشان تغيّر التوقيت الصيفي ما يكسرش اليوم.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// فهرس اليوم (السبت=0) لتاريخ.
int dayIndexOf(DateTime d) => (d.weekday + 1) % 7;

/// سبت الأسبوع اللي بيحتوي [d].
DateTime weekStartSaturday(DateTime d) {
  final x = _dateOnly(d);
  return DateTime(x.year, x.month, x.day - dayIndexOf(x));
}

/// تاريخ يوم [dayIndex] في الأسبوع بإزاحة [weekOffset] عن أسبوع [anchor].
DateTime dateForDayIndex(DateTime anchor, int weekOffset, int dayIndex) {
  final s = weekStartSaturday(anchor);
  return DateTime(s.year, s.month, s.day + weekOffset * 7 + dayIndex);
}

/// إزاحة الأسبوع (عن أسبوع [anchor]) اللي بيحتوي [target].
int weekOffsetFor(DateTime anchor, DateTime target) {
  final a = weekStartSaturday(anchor);
  final t = weekStartSaturday(target);
  // الفرق بالأيام عبر UTC عشان التوقيت الصيفي (يوم 23 أو 25 ساعة).
  final days = DateTime.utc(t.year, t.month, t.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
  return days ~/ 7;
}
