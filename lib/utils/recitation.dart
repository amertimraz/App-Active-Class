// lib/utils/recitation.dart
//
// spec 048 — درجة التسميع (1..10) على سجل الحضور: تحقق، أهلية، ومتوسط.
// الدرجة اختيارية؛ الفراغ = لم يُسمَّع (مش صفر).
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';

const int kRecitationMin = 1;
const int kRecitationMax = 10;

/// 1..10 → نفسها، غير كده/null → null.
int? normalizeRecitation(int? raw) {
  if (raw == null) return null;
  if (raw < kRecitationMin || raw > kRecitationMax) return null;
  return raw;
}

/// الدرجة تتسجّل لحاضر/متأخر فقط.
bool canRecordRecitation(String? attendanceStatus) {
  final s = normalizeAttendanceStatus(attendanceStatus);
  return s == ATTENDANCE_PRESENT || s == ATTENDANCE_LATE;
}

Iterable<int> _grades(Iterable<Attendance> records, DateTime? month) sync* {
  for (final a in records) {
    if (month != null &&
        (a.date.year != month.year || a.date.month != month.month)) {
      continue;
    }
    final g = normalizeRecitation(a.recitation);
    if (g != null) yield g;
  }
}

/// متوسط الدرجات الصالحة (اختياريًا لشهر معيّن)، مقرّب لعشري واحد؛
/// null لو مفيش درجات.
double? recitationAverage(Iterable<Attendance> records, {DateTime? month}) {
  final g = _grades(records, month).toList();
  if (g.isEmpty) return null;
  final avg = g.reduce((a, b) => a + b) / g.length;
  return (avg * 10).round() / 10;
}

/// عدد الأيام ذات الدرجة الصالحة.
int recitationCount(Iterable<Attendance> records, {DateTime? month}) =>
    _grades(records, month).length;

/// "8.3" / "—".
String recitationAverageLabel(double? avg) =>
    avg == null ? '—' : avg.toStringAsFixed(1);

/// ترتيب طالب بمتوسط تسميعه (spec 048) — للتقارير.
class RecitationStanding {
  final int studentId;
  final double average; // مقرّب لعشري واحد
  final int count;
  const RecitationStanding(this.studentId, this.average, this.count);
}

/// ترتيب الطلاب تنازليًا بمتوسط التسميع (اختياريًا لشهر معيّن). الطلاب
/// بلا درجات صالحة يُستبعدون. التعادل: الأكثر مرات تسميعًا أولًا ثم
/// الاسم/المعرّف للثبات. [limit] لقص القائمة.
List<RecitationStanding> recitationStandings(Iterable<Attendance> records,
    {DateTime? month, int? limit}) {
  final byStudent = <int, List<Attendance>>{};
  for (final a in records) {
    byStudent.putIfAbsent(a.studentId, () => []).add(a);
  }
  final out = <RecitationStanding>[];
  byStudent.forEach((id, list) {
    final avg = recitationAverage(list, month: month);
    if (avg == null) return;
    out.add(RecitationStanding(id, avg, recitationCount(list, month: month)));
  });
  out.sort((a, b) {
    final c = b.average.compareTo(a.average);
    if (c != 0) return c;
    final n = b.count.compareTo(a.count);
    return n != 0 ? n : a.studentId.compareTo(b.studentId);
  });
  return limit == null || out.length <= limit ? out : out.sublist(0, limit);
}

/// حقول التسميع في ملخص بوابة أولياء الأمور (spec 048). فاضية لو الإعداد
/// مقفول أو مفيش درجات — فمفيش أي أثر على المدرس اللي مش بيستخدمها.
Map<String, dynamic> recitationPortalFields(
    Iterable<Attendance> records, {required bool enabled, int historyLimit = 10}) {
  if (!enabled) return const {};
  final graded = records
      .where((a) => normalizeRecitation(a.recitation) != null)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (graded.isEmpty) return const {};
  return {
    'recitationAverage': recitationAverage(graded),
    'recitationCount': graded.length,
    'recitationHistory': graded
        .take(historyLimit)
        .map((a) => {
              'date': a.date.toIso8601String(),
              'grade': a.recitation,
            })
        .toList(),
  };
}
