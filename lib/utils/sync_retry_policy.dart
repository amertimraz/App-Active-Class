// lib/utils/sync_retry_policy.dart
//
// دوال نقية لسياسة إعادة المحاولة في محرّك المزامنة (spec 030) —
// قابلة للاختبار بمعزل عن أي شبكة أو حالة.

/// عتبة الفشل التي بعدها يُعدّ صف الطابور "مسموم" ويُتخطّى في الجولات
/// العادية.
const int kMaxOutboxFails = 5;

/// كل كام جولة drainOutbox نعيد المحاولة على الصفوف المتخطّاة.
const int kPoisonRetryEvery = 20;

/// كام نتيجة استعلام عضوية فاضية متتالية قبل ما نستنتج الإزالة فعلًا.
const int kTeamExitStreak = 3;

/// هل نحاول إرسال صف طابور عدّاد فشله [fails] في جولة [round]؟
/// - أقل من [maxFails] → دايمًا نحاول.
/// - بلغ/تجاوز [maxFails] (متخطّى) → نحاول فقط كل [poisonRetryEvery] جولة.
bool shouldAttemptOutboxRow(
  int fails,
  int round, {
  int maxFails = kMaxOutboxFails,
  int poisonRetryEvery = kPoisonRetryEvery,
}) {
  if (fails < maxFails) return true;
  return round % poisonRetryEvery == 0;
}

/// هل نُطلق إجراء الخروج من الفريق (إزالة عضو / فكّ جهاز)؟
/// يتطلب جلسة دخول صالحة **و** [emptyStreak] نتائج فاضية متتالية
/// لا تقل عن [threshold].
bool shouldFireTeamExit({
  required bool sessionUsable,
  required int emptyStreak,
  int threshold = kTeamExitStreak,
}) =>
    sessionUsable && emptyStreak >= threshold;
