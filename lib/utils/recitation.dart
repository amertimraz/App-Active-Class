// lib/utils/recitation.dart
//
// spec 048 — درجة التسميع (1..10) على سجل الحضور: تحقق، أهلية، ومتوسط.
// الدرجة اختيارية؛ الفراغ = لم يُسمَّع (مش صفر).
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/attendance_model.dart';

const int kRecitationMin = 1;

/// الدرجة العظمى للسجلات القديمة (قبل ما تتحدد من الإعدادات) والافتراضي.
const int kRecitationDefaultMax = 10;

/// أقصى درجة عظمى مسموحة في الإعدادات.
const int kRecitationMaxCap = 100;

/// 1..max → نفسها، غير كده/null → null.
int? normalizeRecitation(int? raw, {int max = kRecitationDefaultMax}) {
  if (raw == null) return null;
  if (raw < kRecitationMin || raw > max) return null;
  return raw;
}

/// الدرجة العظمى المحفوظة مع السجل (القديم = 10).
int recitationMaxOf(Attendance a) {
  final m = a.recitationMax;
  if (m == null || m < kRecitationMin || m > kRecitationMaxCap) {
    return kRecitationDefaultMax;
  }
  return m;
}

/// درجة السجل الصالحة (بالنسبة لدرجته العظمى) أو null.
int? recitationGradeOf(Attendance a) =>
    normalizeRecitation(a.recitation, max: recitationMaxOf(a));

/// الدرجة كنسبة 0..1 (null لو مفيش درجة صالحة).
double? recitationFractionOf(Attendance a) {
  final g = recitationGradeOf(a);
  if (g == null) return null;
  return g / recitationMaxOf(a);
}

/// الدرجة العظمى الحالية من الإعدادات (10 لو الإعدادات مش جاهزة).
int currentRecitationMax(int? configured) {
  final m = configured ?? kRecitationDefaultMax;
  if (m < kRecitationMin) return kRecitationDefaultMax;
  return m > kRecitationMaxCap ? kRecitationMaxCap : m;
}

/// الدرجة التسميع تتسجّل لحاضر/متأخر فقط.
bool canRecordRecitation(String? attendanceStatus) {
  final s = normalizeAttendanceStatus(attendanceStatus);
  return s == ATTENDANCE_PRESENT || s == ATTENDANCE_LATE;
}

Iterable<double> _fractions(
    Iterable<Attendance> records, DateTime? month) sync* {
  for (final a in records) {
    if (month != null &&
        (a.date.year != month.year || a.date.month != month.month)) {
      continue;
    }
    final f = recitationFractionOf(a);
    if (f != null) yield f;
  }
}

/// متوسط الدرجات الصالحة (اختياريًا لشهر معيّن) مُعبَّر عنه من [scaleTo]
/// (الافتراضي 10)، مقرّب لعشري واحد؛ null لو مفيش درجات. كل سجل بيتحسب
/// بنسبة درجته لدرجته العظمى، فتغيير الدرجة العظمى لاحقًا ما بيبوّظش القديم.
double? recitationAverage(Iterable<Attendance> records,
    {DateTime? month, int scaleTo = kRecitationDefaultMax}) {
  final f = _fractions(records, month).toList();
  if (f.isEmpty) return null;
  final avg = f.reduce((a, b) => a + b) / f.length * scaleTo;
  return (avg * 10).round() / 10;
}

/// عدد الأيام ذات الدرجة الصالحة.
int recitationCount(Iterable<Attendance> records, {DateTime? month}) =>
    _fractions(records, month).length;

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
    {DateTime? month, int? limit, int scaleTo = kRecitationDefaultMax}) {
  final byStudent = <int, List<Attendance>>{};
  for (final a in records) {
    byStudent.putIfAbsent(a.studentId, () => []).add(a);
  }
  final out = <RecitationStanding>[];
  byStudent.forEach((id, list) {
    final avg = recitationAverage(list, month: month, scaleTo: scaleTo);
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
/// المتوسط مُعبَّر عنه من [scaleTo] (الدرجة العظمى الحالية).
Map<String, dynamic> recitationPortalFields(Iterable<Attendance> records,
    {required bool enabled,
    int historyLimit = 10,
    int scaleTo = kRecitationDefaultMax}) {
  if (!enabled) return const {};
  final graded = records.where((a) => recitationGradeOf(a) != null).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (graded.isEmpty) return const {};
  return {
    'recitationAverage': recitationAverage(graded, scaleTo: scaleTo),
    'recitationMax': scaleTo,
    'recitationCount': graded.length,
    'recitationHistory': graded
        .take(historyLimit)
        .map((a) => {
              'date': a.date.toIso8601String(),
              'grade': recitationGradeOf(a),
              'max': recitationMaxOf(a),
            })
        .toList(),
  };
}
