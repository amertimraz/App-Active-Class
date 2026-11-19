// lib/utils/live_clock_format.dart
//
// صيغة الساعة الحيّة في الرئيسية (بالثواني). بتحترم إعداد «نظام الساعة 24».
// صرف (بلا GetX) عشان يتختبر.

/// 24 ساعة: «14:30:05». 12 ساعة: «2:30:05 م» (ص/م زي باقي التطبيق، من غير صفر في الأول).
String formatLiveClock(DateTime t, {required bool use24h}) {
  final m = t.minute.toString().padLeft(2, '0');
  final s = t.second.toString().padLeft(2, '0');
  if (use24h) return '${t.hour.toString().padLeft(2, '0')}:$m:$s';
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12:$m:$s ${t.hour < 12 ? 'ص' : 'م'}';
}
