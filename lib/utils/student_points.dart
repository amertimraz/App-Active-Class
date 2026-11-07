// lib/utils/student_points.dart
//
// نقاط ومكافآت الطلاب — نواة حساب صرفة (بلا Get/DB) بتحسب النقاط من بيانات
// موجودة (حضور، امتحانات، واجب، تسميع، تفاعل) فمفيش أي جدول جديد ولا مزامنة،
// والرقم نفسه على أي جهاز في الفريق. القواعد قابلة للتعديل من المعلم.
import 'dart:convert';

import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/models/exam_grade_model.dart';
import 'package:active_class/models/homework_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/recitation.dart';

const String kPointsRulesPrefsKey = 'student_points_rules';

/// قواعد احتساب النقاط (كلها أعداد صحيحة ≥ 0).
class PointsRules {
  final int present; // حضور
  final int late; // حضور متأخر
  final int streakEvery; // كل كام حصة حضور متتالية = مكافأة
  final int streakBonus; // مكافأة الانتظام
  final int homeworkDone; // واجب كامل
  final int homeworkPartial; // واجب ناقص
  final int interactionActive; // تفاعل «نشيط»
  final int recitationFull; // تسميع بالدرجة الكاملة (نسبيًا)
  final int examFull; // امتحان بنسبة 100% (نسبيًا)
  final int excellenceBonus; // مكافأة التفوّق (امتحان ≥ 90%)

  const PointsRules({
    this.present = 10,
    this.late = 5,
    this.streakEvery = 5,
    this.streakBonus = 15,
    this.homeworkDone = 5,
    this.homeworkPartial = 2,
    this.interactionActive = 3,
    this.recitationFull = 10,
    this.examFull = 50,
    this.excellenceBonus = 20,
  });

  static const defaults = PointsRules();

  /// نسبة الامتحان اللي من عندها تتحسب مكافأة التفوّق.
  static const double excellencePercent = 90;

  PointsRules copyWith({
    int? present,
    int? late,
    int? streakEvery,
    int? streakBonus,
    int? homeworkDone,
    int? homeworkPartial,
    int? interactionActive,
    int? recitationFull,
    int? examFull,
    int? excellenceBonus,
  }) =>
      PointsRules(
        present: present ?? this.present,
        late: late ?? this.late,
        streakEvery: streakEvery ?? this.streakEvery,
        streakBonus: streakBonus ?? this.streakBonus,
        homeworkDone: homeworkDone ?? this.homeworkDone,
        homeworkPartial: homeworkPartial ?? this.homeworkPartial,
        interactionActive: interactionActive ?? this.interactionActive,
        recitationFull: recitationFull ?? this.recitationFull,
        examFull: examFull ?? this.examFull,
        excellenceBonus: excellenceBonus ?? this.excellenceBonus,
      );

  Map<String, int> toMap() => {
        'present': present,
        'late': late,
        'streakEvery': streakEvery,
        'streakBonus': streakBonus,
        'homeworkDone': homeworkDone,
        'homeworkPartial': homeworkPartial,
        'interactionActive': interactionActive,
        'recitationFull': recitationFull,
        'examFull': examFull,
        'excellenceBonus': excellenceBonus,
      };

  String encode() => jsonEncode(toMap());

  /// قراءة متسامحة: أي قيمة ناقصة/غلط ترجع للافتراضي، وأي سالب يتصفّر.
  static PointsRules decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return defaults;
      int v(String k, int d) {
        final x = m[k];
        return x is num && x >= 0 ? x.toInt() : d;
      }

      const d = PointsRules.defaults;
      final every = v('streakEvery', d.streakEvery);
      return PointsRules(
        present: v('present', d.present),
        late: v('late', d.late),
        streakEvery: every < 2 ? d.streakEvery : every,
        streakBonus: v('streakBonus', d.streakBonus),
        homeworkDone: v('homeworkDone', d.homeworkDone),
        homeworkPartial: v('homeworkPartial', d.homeworkPartial),
        interactionActive: v('interactionActive', d.interactionActive),
        recitationFull: v('recitationFull', d.recitationFull),
        examFull: v('examFull', d.examFull),
        excellenceBonus: v('excellenceBonus', d.excellenceBonus),
      );
    } catch (_) {
      return defaults;
    }
  }
}

/// المستويات بنسبة **الالتزام** (حضور ÷ الحصص المسجّلة) مش بعدد النقاط:
/// الطالب الجديد اللي ما غابش لازم يقدر يوصل زي القديم. وعلشان النسبة تبقى
/// موثوقة فيه حد أدنى من الحصص لكل مستوى (1 من 1 = 100% مش معناها ماسي).
enum PointsLevel { starter, bronze, silver, gold, diamond }

extension PointsLevelX on PointsLevel {
  String get label => switch (this) {
        PointsLevel.starter => 'مبتدئ',
        PointsLevel.bronze => 'برونزي',
        PointsLevel.silver => 'فضي',
        PointsLevel.gold => 'ذهبي',
        PointsLevel.diamond => 'ماسي',
      };

  /// أقل نسبة التزام (%) للوصول للمستوى ده.
  int get minRate => switch (this) {
        PointsLevel.starter => 0,
        PointsLevel.bronze => 60,
        PointsLevel.silver => 75,
        PointsLevel.gold => 85,
        PointsLevel.diamond => 95,
      };

  /// أقل عدد حصص مسجّلة علشان النسبة تتحسب للمستوى ده.
  int get minSessions => switch (this) {
        PointsLevel.starter => 0,
        PointsLevel.bronze => 4,
        PointsLevel.silver => 6,
        PointsLevel.gold => 8,
        PointsLevel.diamond => 12,
      };

  PointsLevel? get next {
    final i = PointsLevel.values.indexOf(this);
    return i + 1 < PointsLevel.values.length ? PointsLevel.values[i + 1] : null;
  }
}

/// نسبة الالتزام %: الحصص اللي حضرها (حاضر أو متأخر) ÷ كل الحصص المسجّلة.
/// null لو لسه مفيش حصص.
double? commitmentRate({required int attended, required int sessions}) =>
    sessions <= 0 ? null : attended / sessions * 100;

PointsLevel pointsLevelFor({required double? rate, required int sessions}) {
  var level = PointsLevel.starter;
  if (rate == null) return level;
  for (final l in PointsLevel.values) {
    if (rate >= l.minRate && sessions >= l.minSessions) level = l;
  }
  return level;
}

/// تقدّم الطالب نحو المستوى التالي: 0..1 (1 = أعلى مستوى).
double levelProgress({required double? rate, required int sessions}) {
  final cur = pointsLevelFor(rate: rate, sessions: sessions);
  final next = cur.next;
  if (next == null) return 1;
  final r = rate ?? 0;
  final byRate = next.minRate == 0 ? 1.0 : r / next.minRate;
  final bySessions =
      next.minSessions == 0 ? 1.0 : sessions / next.minSessions;
  return (byRate < bySessions ? byRate : bySessions).clamp(0.0, 1.0);
}

/// جملة بتقول ناقص إيه للمستوى التالي (null لو في أعلى مستوى).
String? levelHint({required double? rate, required int sessions}) {
  final cur = pointsLevelFor(rate: rate, sessions: sessions);
  final next = cur.next;
  if (next == null) return null;
  final needSessions = next.minSessions - sessions;
  final rateOk = (rate ?? 0) >= next.minRate;
  if (needSessions > 0 && !rateOk) {
    return 'للمستوى «${next.label}»: لسه $needSessions حصة، '
        'ونسبة التزام ${next.minRate}% أو أكتر';
  }
  if (needSessions > 0) {
    return 'للمستوى «${next.label}»: لسه $needSessions حصة '
        'بنفس الانتظام';
  }
  return 'للمستوى «${next.label}»: ارفع نسبة الالتزام لـ ${next.minRate}% '
      'أو أكتر';
}

/// أوسمة بتتفتح من الأداء.
enum PointsBadge { regular, excellent, active }

extension PointsBadgeX on PointsBadge {
  String get label => switch (this) {
        PointsBadge.regular => 'منتظم',
        PointsBadge.excellent => 'متفوّق',
        PointsBadge.active => 'نشيط',
      };

  String get description => switch (this) {
        PointsBadge.regular => '10 حصص حضور متتالية',
        PointsBadge.excellent => '3 امتحانات بنسبة 90% أو أكتر',
        PointsBadge.active => 'تفاعل «نشيط» في 5 حصص',
      };
}

/// تفصيل النقاط حسب المصدر.
class PointsBreakdown {
  final int attendance;
  final int streak;
  final int exams;
  final int excellence;
  final int homework;
  final int recitation;
  final int interaction;

  const PointsBreakdown({
    this.attendance = 0,
    this.streak = 0,
    this.exams = 0,
    this.excellence = 0,
    this.homework = 0,
    this.recitation = 0,
    this.interaction = 0,
  });

  int get total =>
      attendance + streak + exams + excellence + homework + recitation + interaction;
}

class StudentPoints {
  final Student student;

  /// نقاط الفترة المختارة (كل الوقت أو شهر).
  final int points;
  final PointsBreakdown breakdown;

  /// الحصص المسجّلة (حاضر/متأخر/غائب) والحاضرة منها على مدى الوقت كله —
  /// منها بتتحسب نسبة الالتزام اللي بتحدد المستوى.
  final int sessions;
  final int attended;
  final PointsLevel level;
  final int bestStreak;
  final int currentStreak;
  final Set<PointsBadge> badges;

  const StudentPoints({
    required this.student,
    required this.points,
    required this.breakdown,
    required this.sessions,
    required this.attended,
    required this.level,
    required this.bestStreak,
    required this.currentStreak,
    required this.badges,
  });

  /// نسبة الالتزام % (null لو مفيش حصص).
  double? get commitment =>
      commitmentRate(attended: attended, sessions: sessions);
}

bool _inScope(DateTime d, DateTime? month) =>
    month == null || (d.year == month.year && d.month == month.month);

/// يحسب نقاط طالب واحد. [attendance]/[homework]/[exams] بتاعته هو بس.
StudentPoints computeStudentPoints({
  required Student student,
  required List<Attendance> attendance,
  required List<Homework> homework,
  required List<StudentExamRecord> exams,
  PointsRules rules = PointsRules.defaults,
  DateTime? month,
}) {
  var attScope = 0, streakScope = 0, examScope = 0, exclScope = 0;
  var hwScope = 0, recScope = 0, intScope = 0;

  // ── الحضور + الانتظام + التسميع + التفاعل (مرتّبين بالتاريخ) ──────────
  final att = [...attendance]..sort((a, b) => a.date.compareTo(b.date));
  var run = 0, best = 0;
  var activeCount = 0;
  var sessions = 0, attended = 0;
  for (final a in att) {
    final s = normalizeAttendanceStatus(a.status);
    if (s == null) continue;
    sessions++;
    if (s == ATTENDANCE_ABSENT) {
      run = 0;
      continue;
    }
    attended++;
    final base = s == ATTENDANCE_LATE ? rules.late : rules.present;
    final inScope = _inScope(a.date, month);
    if (inScope) attScope += base;

    run++;
    if (run > best) best = run;
    if (rules.streakBonus > 0 && run % rules.streakEvery == 0) {
      if (inScope) streakScope += rules.streakBonus;
    }

    final frac = recitationFractionOf(a);
    if (frac != null && rules.recitationFull > 0) {
      final p = (frac * rules.recitationFull).round();
      if (inScope) recScope += p;
    }
    if (a.interaction == STUDENT_INTERACTION_ACTIVE) {
      activeCount++;
      if (inScope) intScope += rules.interactionActive;
    }
  }

  // ── الواجب ─────────────────────────────────────────────────────────────
  for (final h in homework) {
    final st = normalizeHomeworkStatus(h.status);
    final p = st == HOMEWORK_DONE
        ? rules.homeworkDone
        : st == HOMEWORK_PARTIAL
            ? rules.homeworkPartial
            : 0;
    if (p == 0) continue;
    if (_inScope(h.date, month)) hwScope += p;
  }

  // ── الامتحانات ─────────────────────────────────────────────────────────
  var excellentExams = 0;
  for (final e in exams) {
    if (e.isAbsent || e.grade == null || e.maxGrade <= 0) continue;
    final pct = e.grade! / e.maxGrade * 100;
    final p = (pct.clamp(0, 100) / 100 * rules.examFull).round();
    final excellent = pct >= PointsRules.excellencePercent;
    if (excellent) excellentExams++;
    final bonus = excellent ? rules.excellenceBonus : 0;
    if (_inScope(e.reportMonth, month)) {
      examScope += p;
      exclScope += bonus;
    }
  }

  final breakdown = PointsBreakdown(
    attendance: attScope,
    streak: streakScope,
    exams: examScope,
    excellence: exclScope,
    homework: hwScope,
    recitation: recScope,
    interaction: intScope,
  );
  return StudentPoints(
    student: student,
    points: breakdown.total,
    breakdown: breakdown,
    sessions: sessions,
    attended: attended,
    level: pointsLevelFor(
        rate: commitmentRate(attended: attended, sessions: sessions),
        sessions: sessions),
    bestStreak: best,
    currentStreak: run,
    badges: {
      if (best >= 10) PointsBadge.regular,
      if (excellentExams >= 3) PointsBadge.excellent,
      if (activeCount >= 5) PointsBadge.active,
    },
  );
}

/// ترتيب الطلاب بالنقاط (تنازلي ثم بالاسم). نفس النقاط = نفس المركز.
class RankedPoints {
  final int rank;
  final StudentPoints entry;
  const RankedPoints(this.rank, this.entry);
}

List<RankedPoints> rankPoints(List<StudentPoints> list) {
  final sorted = [...list]..sort((a, b) {
      final c = b.points.compareTo(a.points);
      return c != 0 ? c : a.student.name.compareTo(b.student.name);
    });
  final out = <RankedPoints>[];
  for (var i = 0; i < sorted.length; i++) {
    final rank = i > 0 && sorted[i].points == sorted[i - 1].points
        ? out[i - 1].rank
        : i + 1;
    out.add(RankedPoints(rank, sorted[i]));
  }
  return out;
}

/// يحسب ويرتّب كل الطلاب. البيانات مجمّعة بالـstudentId.
List<RankedPoints> computeLeaderboardPoints({
  required List<Student> students,
  required Map<int, List<Attendance>> attendanceByStudent,
  required Map<int, List<Homework>> homeworkByStudent,
  required Map<int, List<StudentExamRecord>> examsByStudent,
  PointsRules rules = PointsRules.defaults,
  DateTime? month,
  int? groupId,
  bool hideZero = true,
}) {
  final list = <StudentPoints>[];
  for (final s in students) {
    final id = s.id;
    if (id == null || s.isArchived) continue;
    if (groupId != null && s.groupId != groupId) continue;
    final sp = computeStudentPoints(
      student: s,
      attendance: attendanceByStudent[id] ?? const [],
      homework: homeworkByStudent[id] ?? const [],
      exams: examsByStudent[id] ?? const [],
      rules: rules,
      month: month,
    );
    if (hideZero && sp.points <= 0) continue;
    list.add(sp);
  }
  return rankPoints(list);
}

/// سطرين بيشرحوا للقارئ النقاط بتتحسب إزاي (من القواعد الحالية، وبيتخطى
/// أي بند قيمته صفر).
List<String> pointsExplainerLines(PointsRules r) {
  final parts = <String>[
    if (r.present > 0) 'حضور ${r.present}',
    if (r.late > 0) 'متأخر ${r.late}',
    if (r.streakBonus > 0)
      'كل ${r.streakEvery} حصص متتالية +${r.streakBonus}',
    if (r.examFull > 0) 'امتحان لحد ${r.examFull}',
    if (r.excellenceBonus > 0)
      'تفوّق (${PointsRules.excellencePercent.toInt()}%+) +${r.excellenceBonus}',
    if (r.homeworkDone > 0) 'واجب ${r.homeworkDone}',
    if (r.recitationFull > 0) 'تسميع لحد ${r.recitationFull}',
    if (r.interactionActive > 0) 'نشيط ${r.interactionActive}',
  ];
  final levels = [
    for (final l in PointsLevel.values.skip(1)) '${l.label} ${l.minRate}%',
  ];
  return [
    '📌 طريقة حساب النقاط: ${parts.join(' • ')}',
    '🏅 المستوى بنسبة الالتزام (الحضور ÷ الحصص): ${levels.join(' • ')}',
  ];
}

/// نص واتساب لقائمة الأوائل بالنقاط (أعلى 20) + سطر يشرح الحساب.
String buildPointsShareText(
  List<RankedPoints> ranked, {
  required String periodLabel,
  String teacherLine = '',
  PointsRules rules = PointsRules.defaults,
}) {
  final b = StringBuffer()..writeln('⭐ لوحة نقاط الطلاب — $periodLabel')..writeln('');
  for (final r in ranked.take(20)) {
    final medal = switch (r.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '${r.rank}.',
    };
    final c = r.entry.commitment;
    final extra = c == null
        ? r.entry.level.label
        : '${r.entry.level.label} • التزام ${c.round()}%';
    b.writeln('$medal ${r.entry.student.name} — ${r.entry.points} نقطة ($extra)');
  }
  b
    ..writeln('')
    ..writeln('— — —');
  for (final l in pointsExplainerLines(rules)) {
    b.writeln(l);
  }
  if (teacherLine.trim().isNotEmpty) {
    b
      ..writeln('')
      ..writeln('— ${teacherLine.trim()}');
  }
  return b.toString().trimRight();
}
