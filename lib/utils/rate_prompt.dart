// lib/utils/rate_prompt.dart
//
// نافذة "قيّم التطبيق على Google Play": قرار العرض (صرف، بمعامل now). بتظهر
// بعد استخدام فعلي (أيام + مرات فتح)، وبتتكرر بفاصل، ومبتتعرضش تاني لو
// المدرس ضغط "قيّم الآن" أو قال "لاحقًا" 3 مرات.
const int kRateMinDays = 3;
const int kRateMinLaunches = 5;
const int kRateGapDays = 14;
const int kRateMaxLater = 3;

/// معرّف التطبيق على Google Play (نفس الـapplicationId للنسختين).
const String kPlayPackageId = 'com.amertimraz.activeclass';

class RatePromptState {
  final DateTime? firstSeen;
  final int launches;
  final DateTime? lastShown;
  final int laterCount;
  final bool done;
  const RatePromptState({
    this.firstSeen,
    this.launches = 0,
    this.lastShown,
    this.laterCount = 0,
    this.done = false,
  });
}

bool shouldShowRatePrompt(RatePromptState s, DateTime now) {
  if (s.done || s.laterCount >= kRateMaxLater) return false;
  final first = s.firstSeen;
  if (first == null) return false;
  if (now.difference(first).inDays < kRateMinDays) return false;
  if (s.launches < kRateMinLaunches) return false;
  final last = s.lastShown;
  if (last != null && now.difference(last).inDays < kRateGapDays) return false;
  return true;
}

Uri playMarketUri() => Uri.parse('market://details?id=$kPlayPackageId');
Uri playWebUri() =>
    Uri.parse('https://play.google.com/store/apps/details?id=$kPlayPackageId');
