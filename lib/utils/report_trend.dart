// lib/utils/report_trend.dart
//
// اتجاه التقارير عبر الشهور: نقطة لكل شهر (نسب 0..1 أو null لو مفيش أساس)،
// وفرق «نقط مئوية» بين شهرين. صرف بلا DB/GetX.

/// نسب شهر واحد. null = مفيش بيانات تكفي (مش 0%).
class TrendPoint {
  final DateTime month;
  final double? attendance; // نسبة الحضور
  final double? collection; // نسبة التحصيل (محصّل ÷ متوقع)
  final double? homework; // نسبة الالتزام بالواجب
  final double? exams; // متوسط درجات الامتحانات (0..1)
  const TrendPoint({
    required this.month,
    this.attendance,
    this.collection,
    this.homework,
    this.exams,
  });

  bool get isEmpty =>
      attendance == null && collection == null && homework == null && exams == null;
}

/// الفرق بالنقط المئوية (cur − prev)، أو null لو أي طرف مجهول.
/// مثال: 0.80 مقابل 0.75 → 5.
double? pointsDelta(double? cur, double? prev) =>
    cur == null || prev == null ? null : (cur - prev) * 100;

/// آخر [count] شهور تنتهي بـ[last] (الأقدم أولًا).
List<DateTime> lastMonths(DateTime last, {int count = 6}) => [
      for (var i = count - 1; i >= 0; i--) DateTime(last.year, last.month - i, 1)
    ];
