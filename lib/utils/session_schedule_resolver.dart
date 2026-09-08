// lib/utils/session_schedule_resolver.dart
//
// spec 032 — منطق نقي لجعل دوال الجدولة "override-aware". معزول عن GetX
// وعن قاعدة البيانات عشان يتغطّى باختبارات وحدة مباشرة.
import 'package:active_class/models/session_override_model.dart';

/// هل فيه حصة في يوم معيّن لمجموعة معيّنة؟
/// [scheduleSays] = ناتج منطق الجدول الأسبوعي القائم.
/// [overrideType] = نوع الاستثناء لو موجود لهذا (المجموعة، اليوم)، وإلا null.
bool resolveHasSession({
  required bool scheduleSays,
  SessionOverrideType? overrideType,
}) {
  switch (overrideType) {
    case SessionOverrideType.cancelled:
      return false;
    case SessionOverrideType.makeup:
    case SessionOverrideType.extra:
      return true;
    case null:
      return scheduleSays;
  }
}

/// فرق عدد الحصص المتوقّعة ضمن مدى بسبب الاستثناءات.
/// [overridesInRange] = استثناءات هذه المجموعة التي تقع تواريخها داخل المدى.
/// [scheduleHasDay] = هل ذلك التاريخ يوم جدول لهذه المجموعة (المنطق القائم).
///
/// - cancelled على يوم جدول → -1 (شلنا حصة كانت متوقّعة).
/// - cancelled على غير يوم جدول → 0 (ملهاش معنى، ماكانتش متوقّعة أصلًا).
/// - makeup/extra على غير يوم جدول → +1 (حصة زيادة).
/// - makeup/extra على يوم جدول → 0 (الجدول عدّها بالفعل).
int expectedCountDelta({
  required Iterable<SessionOverride> overridesInRange,
  required bool Function(DateTime) scheduleHasDay,
}) {
  var delta = 0;
  for (final o in overridesInRange) {
    switch (o.type) {
      case SessionOverrideType.cancelled:
        if (scheduleHasDay(o.date)) delta -= 1;
        break;
      case SessionOverrideType.makeup:
      case SessionOverrideType.extra:
        if (!scheduleHasDay(o.date)) delta += 1;
        break;
    }
  }
  return delta;
}
