// lib/utils/recitation_session.dart
//
// منطق شاشة قائمة التسميع (حصة اليوم لكل مجموعة): تصنيف الدرجة (تراجع / عادي /
// نجمة)، رسالة تنبيه ولي الأمر، والتقرير النصي. نقي بدون Flutter أو قاعدة
// بيانات عشان يتختبر مباشرة.
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/utils/recitation.dart';

/// أقل من النص = تنبيه تراجع مستوى.
const double kRecitationLowFraction = 0.5;

/// 90% فأكثر = نجمة تميّز (وتظهر في قايمة شهادات التقدير).
const double kRecitationStarFraction = 0.9;

enum RecitationLevel { none, low, ok, star }

/// تصنيف [grade] من [max]. null أو خارج النطاق → none.
RecitationLevel recitationLevelOf(int? grade, int max) {
  if (grade == null || max < kRecitationMin) return RecitationLevel.none;
  if (grade < kRecitationMin || grade > max) return RecitationLevel.none;
  final f = grade / max;
  if (f < kRecitationLowFraction) return RecitationLevel.low;
  if (f >= kRecitationStarFraction) return RecitationLevel.star;
  return RecitationLevel.ok;
}

/// مفتاح الإعداد المحلي لآخر درجة عظمى استُخدمت لمجموعة.
String recitationGroupMaxKey(int groupId) => 'recitation_max_g$groupId';

/// الدرجة العظمى المعروضة لمجموعة في يوم: نفس مقياس درجات اليوم المسجّلة
/// لو فيه ([recordMax])، وإلا آخر قيمة محفوظة للمجموعة ([savedMax])، وإلا
/// القيمة العامة من الإعدادات. بتتشارك بين قائمة التسميع وحضور اليوم عشان
/// الاتنين يعرضوا نفس المقياس.
int resolveGroupRecitationMax(
    {int? recordMax, int? savedMax, required int settingsMax}) {
  if (recordMax != null) return currentRecitationMax(recordMax);
  if (savedMax != null) return currentRecitationMax(savedMax);
  return currentRecitationMax(settingsMax);
}

/// الدرجة العظمى بعد ضغط +/-: بين 1 و [kRecitationMaxCap].
int stepRecitationMax(int current, int delta) {
  final v = current + delta;
  if (v < kRecitationMin) return kRecitationMin;
  if (v > kRecitationMaxCap) return kRecitationMaxCap;
  return v;
}

/// نص خانة الدرجة → رقم صالح (1..max) أو null (فاضي/غير صالح).
int? parseRecitationInput(String raw, int max) {
  final digits = raw
      .replaceAllMapped(RegExp(r'[٠-٩]'),
          (m) => (m.group(0)!.codeUnitAt(0) - 0x0660).toString())
      .replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  final v = int.tryParse(digits);
  if (v == null || v < kRecitationMin || v > max) return null;
  return v;
}

/// صف واحد في التقرير (طالب).
class RecitationReportRow {
  final String studentName;

  /// "حاضر" / "متأخر" / "غائب" / "لم يُسجَّل حضوره".
  final String attendanceLabel;
  final int? grade;
  const RecitationReportRow({
    required this.studentName,
    required this.attendanceLabel,
    this.grade,
  });
}

/// مجموعة في تقرير التسميع.
class RecitationReportGroup {
  final String groupName;
  final int max;
  final List<RecitationReportRow> rows;
  const RecitationReportGroup({
    required this.groupName,
    required this.max,
    required this.rows,
  });

  List<RecitationReportRow> get graded =>
      rows.where((r) => recitationLevelOf(r.grade, max) != RecitationLevel.none)
          .toList();

  /// متوسط المجموعة كنسبة 0..1، أو null لو مفيش درجات.
  double? get averageFraction {
    final g = graded;
    if (g.isEmpty) return null;
    return g.map((r) => r.grade! / max).reduce((a, b) => a + b) / g.length;
  }

  int get lowCount =>
      rows.where((r) => recitationLevelOf(r.grade, max) == RecitationLevel.low).length;
  int get starCount =>
      rows.where((r) => recitationLevelOf(r.grade, max) == RecitationLevel.star).length;
}

String _dateLabel(DateTime d) => DateFormat('EEEE d MMMM yyyy', 'ar').format(d);

/// رسالة لولي الأمر لما درجة التسميع أقل من النص. بدون توقيع المعلم —
/// launchGuardianWhatsapp بيضيفه.
String buildRecitationLowAlertMessage({
  required String studentName,
  required int grade,
  required int max,
  required DateTime date,
  String? groupName,
}) {
  final b = StringBuffer()
    ..writeln('📢 تنبيه بخصوص التسميع — ${_dateLabel(date)}')
    ..writeln('👤 الطالب: $studentName');
  if (groupName != null && groupName.trim().isNotEmpty) {
    b.writeln('👥 المجموعة: ${groupName.trim()}');
  }
  b
    ..writeln('')
    ..writeln('🎤 درجة التسميع: $grade من $max')
    ..writeln('')
    ..writeln('مستوى التسميع اليوم أقل من المطلوب، ونحتاج متابعة المراجعة '
        'في البيت للتحسّن في الحصة القادمة بإذن الله.')
    ..writeln('')
    ..write('تم الإرسال من تطبيق Active Class');
  return b.toString();
}

/// رسالة تهنئة لولي الأمر لما الطالب ياخد نجمة.
String buildRecitationStarMessage({
  required String studentName,
  required int grade,
  required int max,
  required DateTime date,
}) {
  return [
    '⭐ تهنئة — ${_dateLabel(date)}',
    '👤 الطالب: $studentName',
    '',
    '🎤 درجة التسميع: $grade من $max',
    '',
    'ما شاء الله، تسميع ممتاز اليوم! نتمنى له دوام التفوق.',
    '',
    'تم الإرسال من تطبيق Active Class',
  ].join('\n');
}

/// تقرير نصي لحصة التسميع (واتساب/مشاركة) لمجموعة واحدة أو أكتر.
String buildRecitationReportText(
    DateTime date, List<RecitationReportGroup> groups) {
  final b = StringBuffer()
    ..writeln('🎤 تقرير التسميع — ${_dateLabel(date)}');
  for (final g in groups) {
    b
      ..writeln('')
      ..writeln('👥 ${g.groupName} (الدرجة من ${g.max})');
    final avg = g.averageFraction;
    if (avg != null) {
      b.writeln('📈 المتوسط: ${(avg * g.max).toStringAsFixed(1)} / ${g.max}'
          ' — سمّع ${g.graded.length} من ${g.rows.length}');
    } else {
      b.writeln('لم تُسجَّل درجات بعد');
    }
    for (final r in g.rows) {
      final lvl = recitationLevelOf(r.grade, g.max);
      if (lvl == RecitationLevel.none) {
        b.writeln('• ${r.studentName}: ${r.attendanceLabel == 'غائب' ? 'غائب' : '—'}');
      } else {
        final mark = lvl == RecitationLevel.star
            ? ' ⭐'
            : lvl == RecitationLevel.low
                ? ' ⚠️'
                : '';
        b.writeln('• ${r.studentName}: ${r.grade}/${g.max}$mark');
      }
    }
  }
  b
    ..writeln('')
    ..write('تم الإرسال من تطبيق Active Class');
  return b.toString();
}
