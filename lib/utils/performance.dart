// lib/utils/performance.dart
//
// spec 050 — تقرير أداء ومستوى الطالب: نواة حساب صرفة (بلا Get/DB) تبني
// مؤشرات الأداء (امتحانات/حضور/واجب/تسميع) ونسبها واتجاهها وسلسلة آخر 6
// شهور من بيانات موجودة. كل مخرج (شاشة، رسالة، كارت، PDF، بوابة، ترتيب)
// بيتبني من نفس النتيجة فالأرقام متطابقة في كل مكان.
import 'package:intl/intl.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/recitation.dart';

/// فرق (بالنقاط) أقل منه يُعتبر "ثابت".
const double kTrendSteadyBand = 3.0;

/// عدد الشهور في رسم الاتجاه.
const int kPerfMonths = 6;

enum PerfKind { exams, attendance, homework, recitation }

enum PerfTrend { up, steady, down, none }

extension PerfKindX on PerfKind {
  String get label {
    switch (this) {
      case PerfKind.exams:
        return 'الامتحانات';
      case PerfKind.attendance:
        return 'الحضور';
      case PerfKind.homework:
        return 'الواجب';
      case PerfKind.recitation:
        return 'التسميع';
    }
  }

  String get emoji {
    switch (this) {
      case PerfKind.exams:
        return '📝';
      case PerfKind.attendance:
        return '📅';
      case PerfKind.homework:
        return '📖';
      case PerfKind.recitation:
        return '🎤';
    }
  }

  /// مفتاح ثابت للبوابة/التخزين.
  String get key => name;

  /// الوحدة اللي بتتعد (للعرض: "3 امتحانات" ...).
  String samplesLabel(int n) {
    switch (this) {
      case PerfKind.exams:
        return n == 1 ? 'امتحان واحد' : '$n امتحانات';
      case PerfKind.attendance:
      case PerfKind.homework:
        return n == 1 ? 'يوم واحد' : '$n أيام';
      case PerfKind.recitation:
        return n == 1 ? 'مرة واحدة' : '$n مرات';
    }
  }
}

String trendArrow(PerfTrend t) {
  switch (t) {
    case PerfTrend.up:
      return '↑';
    case PerfTrend.down:
      return '↓';
    case PerfTrend.steady:
      return '➖';
    case PerfTrend.none:
      return '';
  }
}

String trendWord(PerfTrend t) {
  switch (t) {
    case PerfTrend.up:
      return 'تحسّن';
    case PerfTrend.down:
      return 'تراجع';
    case PerfTrend.steady:
      return 'ثابت';
    case PerfTrend.none:
      return '';
  }
}

DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

/// آخر [count] شهور مرتبة من الأقدم للأحدث، وآخرها [month].
List<DateTime> monthsBack(DateTime month, {int count = kPerfMonths}) {
  final m = monthStart(month);
  return [
    for (var i = count - 1; i >= 0; i--) DateTime(m.year, m.month - i, 1),
  ];
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

double _round1(double v) => (v * 10).round() / 10;

// ── النسب والعدّادات ───────────────────────────────────────────────────

Iterable<double> _examRatios(Iterable<StudentExamRecord> r, DateTime month) sync* {
  for (final e in r) {
    if (!_sameMonth(e.reportMonth, month)) continue;
    if (e.isAbsent || e.grade == null || e.maxGrade <= 0) continue;
    yield (e.grade! / e.maxGrade) * 100.0;
  }
}

double? examsPercent(Iterable<StudentExamRecord> r, DateTime month) {
  final v = _examRatios(r, month).toList();
  if (v.isEmpty) return null;
  return _round1(v.reduce((a, b) => a + b) / v.length);
}

int examsCount(Iterable<StudentExamRecord> r, DateTime month) =>
    _examRatios(r, month).length;

double? attendancePercent(Iterable<Attendance> a, DateTime month) {
  var present = 0, absent = 0;
  for (final x in a) {
    if (!_sameMonth(x.date, month)) continue;
    final s = normalizeAttendanceStatus(x.status);
    if (s == ATTENDANCE_ABSENT) {
      absent++;
    } else if (s == ATTENDANCE_PRESENT || s == ATTENDANCE_LATE) {
      present++;
    }
  }
  final total = present + absent;
  if (total == 0) return null;
  return _round1(present / total * 100.0);
}

int attendanceCount(Iterable<Attendance> a, DateTime month) {
  var n = 0;
  for (final x in a) {
    if (!_sameMonth(x.date, month)) continue;
    final s = normalizeAttendanceStatus(x.status);
    if (s == ATTENDANCE_ABSENT ||
        s == ATTENDANCE_PRESENT ||
        s == ATTENDANCE_LATE) {
      n++;
    }
  }
  return n;
}

double? homeworkPercent(Iterable<Homework> h, DateTime month) {
  var done = 0, partial = 0, total = 0;
  for (final x in h) {
    if (!_sameMonth(x.date, month)) continue;
    switch (normalizeHomeworkStatus(x.status)) {
      case HOMEWORK_DONE:
        done++;
        total++;
        break;
      case HOMEWORK_PARTIAL:
        partial++;
        total++;
        break;
      case HOMEWORK_NOT_DONE:
        total++;
        break;
      default:
        break;
    }
  }
  if (total == 0) return null;
  return _round1((done + 0.5 * partial) / total * 100.0);
}

int homeworkCount(Iterable<Homework> h, DateTime month) {
  var n = 0;
  for (final x in h) {
    if (_sameMonth(x.date, month) && normalizeHomeworkStatus(x.status) != null) {
      n++;
    }
  }
  return n;
}

double? recitationPercent(Iterable<Attendance> a, DateTime month) {
  final avg = recitationAverage(a, month: month);
  if (avg == null) return null;
  return _round1(avg * 10.0);
}

int recitationMonthCount(Iterable<Attendance> a, DateTime month) =>
    recitationCount(a, month: month);

// ── الاتجاه والتقييم ───────────────────────────────────────────────────

PerfTrend trendOf(double? cur, double? prev, {double band = kTrendSteadyBand}) {
  if (cur == null || prev == null) return PerfTrend.none;
  final d = cur - prev;
  if (d >= band) return PerfTrend.up;
  if (d <= -band) return PerfTrend.down;
  return PerfTrend.steady;
}

String levelOf(double? pct) {
  if (pct == null) return '';
  if (pct >= 85) return 'ممتاز';
  if (pct >= 75) return 'جيد جدًا';
  if (pct >= 65) return 'جيد';
  if (pct >= 50) return 'مقبول';
  return 'يحتاج دعمًا';
}

// ── النماذج ──────────────────────────────────────────────────────────

class PerfIndicator {
  final PerfKind kind;
  final double? current;
  final double? previous;
  final int currentSamples;
  final double? delta;
  final PerfTrend trend;
  final String level;
  final List<double?> series;

  const PerfIndicator({
    required this.kind,
    required this.current,
    required this.previous,
    required this.currentSamples,
    required this.delta,
    required this.trend,
    required this.level,
    required this.series,
  });

  bool get hasData => current != null;
  bool get hasAnyData => series.any((v) => v != null);
}

class StudentPerformance {
  final int studentId;
  final String name;
  final String groupName;
  final DateTime month;
  final List<DateTime> months;
  final List<PerfIndicator> indicators;
  final double? overall;
  final double? overallDelta;
  final PerfTrend overallTrend;

  /// ملاحظات توضيحية (مثلًا امتحان تاريخه في شهر ومحسوب على شهر تقرير تاني).
  final List<String> notes;

  const StudentPerformance({
    required this.studentId,
    required this.name,
    required this.groupName,
    required this.month,
    required this.months,
    required this.indicators,
    required this.overall,
    required this.overallDelta,
    required this.overallTrend,
    this.notes = const [],
  });

  /// فيه أي بيانات للشهر المختار.
  bool get hasData => indicators.any((i) => i.hasData);

  /// فيه أي بيانات في أي شهر من السلسلة (الشهر الحالي أو السابق أو الأقدم).
  bool get hasAnyData => indicators.any((i) => i.hasAnyData);

  PerfIndicator? indicator(PerfKind k) {
    for (final i in indicators) {
      if (i.kind == k) return i;
    }
    return null;
  }

  /// متراجع: الاتجاه العام هابط أو أي مؤشر أساسي (امتحانات/حضور) هابط.
  bool get isDeclining {
    if (overallTrend == PerfTrend.down) return true;
    for (final k in [PerfKind.exams, PerfKind.attendance]) {
      if (indicator(k)?.trend == PerfTrend.down) return true;
    }
    return false;
  }
}

/// يبني تقرير أداء طالب لشهر [month] (المقارنة بالشهر اللي قبله، والسلسلة
/// آخر [kPerfMonths] شهور). [enabled] = المؤشرات المفعّلة (المخفي من
/// الإعدادات ما بيتبنيش خالص).
StudentPerformance buildPerformance({
  required Student student,
  required String groupName,
  required DateTime month,
  required List<Attendance> attendance,
  required List<Homework> homework,
  required List<StudentExamRecord> exams,
  Set<PerfKind> enabled = const {
    PerfKind.exams,
    PerfKind.attendance,
    PerfKind.homework,
    PerfKind.recitation,
  },
}) {
  final m = monthStart(month);
  final prev = DateTime(m.year, m.month - 1, 1);
  final months = monthsBack(m);

  double? pct(PerfKind k, DateTime mm) {
    switch (k) {
      case PerfKind.exams:
        return examsPercent(exams, mm);
      case PerfKind.attendance:
        return attendancePercent(attendance, mm);
      case PerfKind.homework:
        return homeworkPercent(homework, mm);
      case PerfKind.recitation:
        return recitationPercent(attendance, mm);
    }
  }

  int samples(PerfKind k, DateTime mm) {
    switch (k) {
      case PerfKind.exams:
        return examsCount(exams, mm);
      case PerfKind.attendance:
        return attendanceCount(attendance, mm);
      case PerfKind.homework:
        return homeworkCount(homework, mm);
      case PerfKind.recitation:
        return recitationMonthCount(attendance, mm);
    }
  }

  final indicators = <PerfIndicator>[];
  for (final k in PerfKind.values) {
    if (!enabled.contains(k)) continue;
    final cur = pct(k, m);
    final pv = pct(k, prev);
    final d = (cur != null && pv != null) ? _round1(cur - pv) : null;
    indicators.add(PerfIndicator(
      kind: k,
      current: cur,
      previous: pv,
      currentSamples: samples(k, m),
      delta: d,
      trend: trendOf(cur, pv),
      level: levelOf(cur),
      series: [for (final mm in months) pct(k, mm)],
    ));
  }

  final currents =
      indicators.where((i) => i.current != null).map((i) => i.current!).toList();
  final deltas =
      indicators.where((i) => i.delta != null).map((i) => i.delta!).toList();
  final overall = currents.isEmpty
      ? null
      : _round1(currents.reduce((a, b) => a + b) / currents.length);
  final overallDelta = deltas.isEmpty
      ? null
      : _round1(deltas.reduce((a, b) => a + b) / deltas.length);

  // امتحان تاريخه في شهر لكن "شهر التقرير" بتاعه شهر تاني: نوضّح للمدرس
  // ليه الامتحان ما ظهرش (أو ظهر) في الشهر ده — spec 013.
  final notes = <String>[];
  for (final e in exams) {
    if (e.isAbsent || e.grade == null) continue;
    final em = monthStart(e.examDate);
    final rm = monthStart(e.reportMonth);
    if (em == rm) continue;
    if (em == m) {
      notes.add(
          'امتحان "${e.examName}" (${DateFormat('d MMMM', 'ar').format(e.examDate)}) محسوب على شهر ${DateFormat('MMMM', 'ar').format(rm)}');
    } else if (rm == m) {
      notes.add(
          'امتحان "${e.examName}" (${DateFormat('d MMMM', 'ar').format(e.examDate)}) محسوب على هذا الشهر');
    }
  }

  return StudentPerformance(
    notes: notes,
    studentId: student.id ?? 0,
    name: student.name,
    groupName: groupName,
    month: m,
    months: months,
    indicators: indicators,
    overall: overall,
    overallDelta: overallDelta,
    overallTrend: overallDelta == null
        ? PerfTrend.none
        : trendOf(overallDelta, 0),
  );
}

/// ترتيب تنازلي بالمستوى العام؛ اللي بلا بيانات في الآخر (بالاسم).
/// [onlyDeclining] يفلتر المتراجعين فقط.
List<StudentPerformance> rankPerformances(List<StudentPerformance> list,
    {bool onlyDeclining = false}) {
  final src = onlyDeclining ? list.where((p) => p.isDeclining) : list;
  final out = src.toList();
  out.sort((a, b) {
    final ao = a.overall, bo = b.overall;
    if (ao == null && bo == null) return a.name.compareTo(b.name);
    if (ao == null) return 1;
    if (bo == null) return -1;
    final c = bo.compareTo(ao);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return out;
}

// ── المخرجات ─────────────────────────────────────────────────────────

String _pct(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}%' : '${v.toStringAsFixed(1)}%';

String _delta(double d) {
  final r = d.abs() == d.abs().roundToDouble()
      ? d.abs().toInt().toString()
      : d.abs().toStringAsFixed(1);
  return d >= 0 ? '+$r' : '-$r';
}

/// سطر مؤشر واحد للرسالة/الـPDF.
String indicatorLine(PerfIndicator i) {
  final head = '${i.kind.emoji} ${i.kind.label}:';
  final cur = i.current;
  final prev = i.previous;
  if (cur == null) {
    return prev == null
        ? '$head لا توجد بيانات'
        : '$head لا بيانات هذا الشهر (الشهر السابق ${_pct(prev)})';
  }
  final lvl = i.level.isEmpty ? '' : ' — ${i.level}';
  if (prev == null || i.delta == null) {
    return '$head ${_pct(cur)}$lvl (لا يوجد شهر سابق للمقارنة)';
  }
  final word = trendWord(i.trend);
  final arrow = trendArrow(i.trend);
  return '$head ${_pct(cur)}$lvl\n   $arrow $word (${_delta(i.delta!)} عن الشهر السابق ${_pct(prev)})';
}

/// رسالة واتساب لولي الأمر — بلا أي بيانات مالية.
String performanceMessage(StudentPerformance p,
    {String teacherName = '', String teacherSpecialization = ''}) {
  final monthLabel = DateFormat('MMMM yyyy', 'ar').format(p.month);
  final b = StringBuffer()
    ..writeln('📊 تقرير مستوى الطالب — $monthLabel')
    ..writeln('👤 الاسم: ${p.name}')
    ..writeln('👥 المجموعة: ${p.groupName}')
    ..writeln('');
  for (final i in p.indicators) {
    b.writeln(indicatorLine(i));
  }
  final tn = teacherName.trim();
  final ts = teacherSpecialization.trim();
  if (tn.isNotEmpty || ts.isNotEmpty) {
    b
      ..writeln('')
      ..writeln('👨‍🏫 المعلم: ${tn.isNotEmpty ? tn : '-'}')
      ..writeln('📘 التخصص: ${ts.isNotEmpty ? ts : '-'}');
  }
  b
    ..writeln('')
    ..writeln('تم الإرسال من تطبيق Active Class');
  return b.toString();
}

/// حقل `performance` لملخص بوابة أولياء الأمور. null لو مفيش بيانات خالص.
Map<String, dynamic>? performancePortalFields(StudentPerformance p) {
  if (!p.hasAnyData) return null;
  return {
    'month': DateFormat('yyyy-MM-dd').format(p.month),
    'indicators': [
      for (final i in p.indicators)
        if (i.hasAnyData)
          {
            'kind': i.kind.key,
            'label': i.kind.label,
            'percent': i.current,
            'prev': i.previous,
            'trend': i.trend.name,
            'level': i.level,
          }
    ],
    'series': {
      for (final i in p.indicators)
        if (i.hasAnyData) i.kind.key: i.series,
    },
  };
}
