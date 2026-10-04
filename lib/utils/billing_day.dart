// lib/utils/billing_day.dart
//
// spec 045 — "يوم نزول المديونية": دوال صرفة (بمعامل now) بتحدد امتى
// اشتراك الشهر الجاري ينزل مديونية على طلاب المجموعات الشهرية. القيمة 1
// (الافتراضي) = السلوك القديم بالظبط. التحصيل المؤخّر يتجاهل اليوم.

const int kBillingDayMin = 1;
const int kBillingDayMax = 28;

/// null أو خارج 1..28 → 1.
int clampBillingDay(int? v) {
  if (v == null || v < kBillingDayMin || v > kBillingDayMax) return 1;
  return v;
}

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// آخر شهر مستحق فعليًا لطلب "لحد شهر [requested]".
/// - مؤخّر: بيتقيّد بآخر شهر مكتمل (الحالي − 1) — زي spec 012.
/// - يوم نزول > 1 واليوم لسه قبله: الشهر الجاري (وأي شهر بعده) مستبعد.
/// - غير كده: الشهر المطلوب نفسه (زي الأول، حتى لو مستقبلي).
DateTime effectiveLastMonthFor({
  required DateTime requested,
  required DateTime now,
  required bool arrears,
  required int billingDay,
}) {
  final req = _firstOfMonth(requested);
  if (arrears) {
    final lastComplete = DateTime(now.year, now.month - 1, 1);
    return req.isBefore(lastComplete) ? req : lastComplete;
  }
  final day = clampBillingDay(billingDay);
  if (day > 1 && now.day < day) {
    final prev = DateTime(now.year, now.month - 1, 1);
    return req.isBefore(prev) ? req : prev;
  }
  return req;
}

int _effectiveDay(bool arrears, int billingDay) =>
    arrears ? 1 : clampBillingDay(billingDay);

/// هل إحنا لسه جوه مهلة السماح؟ يوم النزول هو أول يوم مهلة (عند 1 =
/// أول يوم في الشهر زي الأول).
bool withinGraceWindow({
  required DateTime now,
  required int graceDays,
  required bool arrears,
  required int billingDay,
}) {
  if (graceDays <= 0) return false;
  final day = _effectiveDay(arrears, billingDay);
  // قبل يوم النزول مفيش اشتراك جديد نازل: مهلة الشهر السابق خلصت من زمان.
  if (now.day < day) return false;
  return now.day <= (day - 1) + graceDays;
}

/// هل لسه بدري كفاية إن المدرس بيحصّل الشهر اللي فات (فالشهر الافتراضي
/// للشاشات الشهرية = الشهر السابق)؟
bool isEarlyInMonthForCollection({
  required DateTime now,
  required int graceDays,
  required bool arrears,
  required int billingDay,
}) {
  if (arrears) return true;
  final threshold = graceDays > 5 ? graceDays : 5;
  return now.day <= (clampBillingDay(billingDay) - 1) + threshold;
}

/// هل اشتراك الشهر [month] "نزل" فعليًا دلوقتي؟ شهور قبل الجاري: دايمًا.
/// الجاري: من يوم النزول (وغير مؤخّر). شهور بعده: لأ.
bool monthHasLanded({
  required DateTime month,
  required DateTime now,
  required bool arrears,
  required int billingDay,
}) {
  final m = _firstOfMonth(month);
  final cur = _firstOfMonth(now);
  if (m.isBefore(cur)) return true;
  if (m.isAfter(cur)) return false;
  if (arrears) return false;
  return now.day >= clampBillingDay(billingDay);
}
