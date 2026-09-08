# Contract: دوال الجدولة override-aware

## دالة نقية — `lib/utils/session_schedule_resolver.dart` (جديد)

```dart
/// scheduleSays = هل الجدول الأسبوعي يقول إن فيه حصة هذا اليوم
bool resolveHasSession({required bool scheduleSays, SessionOverrideType? overrideType}) {
  switch (overrideType) {
    case SessionOverrideType.cancelled: return false;
    case SessionOverrideType.makeup:
    case SessionOverrideType.extra:    return true;
    case null:                         return scheduleSays;
  }
}

/// فرق العدّ المتوقّع ضمن مدى (للـ_countExpectedForGroup)
/// overridesInRange = استثناءات هذه المجموعة التي تقع تواريخها داخل المدى
/// scheduleHasDay(date) = هل ذلك التاريخ يوم جدول لهذه المجموعة
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
```

## `SessionOverrideController` — `lib/controllers/session_override_controller.dart` (جديد)

```dart
class SessionOverrideController extends GetxController {
  final RxList<SessionOverride> overrides = <SessionOverride>[].obs;
  final RxBool loadedOnce = false.obs;

  Future<void> load();                                   // getAllSessionOverrides → overrides
  SessionOverride? overrideFor(int groupId, DateTime day); // مطابقة (groupId, ymd)
  List<SessionOverride> overridesForGroupInRange(int groupId, DateTime from, DateTime to);
  List<SessionOverride> cancelledForGroup(int groupId);

  /// null = نجاح، غير null = رسالة خطأ للعرض
  Future<String?> cancelToday({required Group group, required DateTime day,
      required bool scheduleHasSession, String? note});   // يرفض لو !scheduleHasSession
  Future<String?> addMakeup({required Group group, required DateTime day,
      required DateTime compensatesDate, String? note});
  Future<String?> addExtra({required Group group, required DateTime day, String? note});
  Future<String?> removeOverride(SessionOverride o);       // قواعد قرار 7
}
```

- كل طفرة: `DatabaseService` ثم `load()` (أو تعديل `overrides` مباشرة) — `Obx` في الشاشات يتحدّث.
- `cancelToday` عند وجود حضور: الشاشة (لا الـcontroller) تعرض حوار "هيتمسح N"، ثم تنادي دالة تمسح الحضور + تُنشئ الاستثناء.

## `AttendanceController` — التعديلات

يكتسب `SessionOverrideController` عبر `Get.find` (مع `Get.isRegistered` guard؛ لو غير مسجّل → السلوك القديم بالضبط).

| الدالة (سطر تقريبي) | التغيير |
|---|---|
| `groupHasSessionOnDay(group, day)` (~567) | `final o = so?.overrideFor(group.id!, day); return resolveHasSession(scheduleSays: <المنطق القديم>, overrideType: o?.type);` |
| `_countExpectedForGroup(group, range)` (~499) | بعد حساب العدّ القديم `n`: `n += expectedCountDelta(overridesInRange: so.overridesForGroupInRange(group.id!, range.start, range.end), scheduleHasDay: (d) => <المنطق القديم لليوم d>)` ثم `clamp(0, ...)` |
| `groupsForDay(groups, day)` (~554) | تعتمد على `groupHasSessionOnDay` — تصير override-aware تلقائيًا؛ تأكّد أنها تمرّ عبرها |
| `getExpectedSessionsPerGroup` (~489) | تستدعي `_countExpectedForGroup` — لا تغيير مباشر |

- **منع العدّ المزدوج**: `makeup`/`extra` يزيد العدّ فقط لو تاريخه ليس يوم جدول (لو التعويض صادف يوم جدول، الجدول عدّه أصلًا و`groupHasSessionOnDay` يرجع true لأي من السببين).
- **عدم الانحدار**: بلا استثناءات، `overridesInRange` فارغة → `delta = 0` → سلوك مطابق.

## اختبارات (`test/session_schedule_override_test.dart`)

1. `resolveHasSession`: cancelled→false، makeup→true، extra→true، null+scheduleTrue→true، null+scheduleFalse→false.
2. `expectedCountDelta`: cancelled على يوم جدول → -1؛ cancelled على غير يوم جدول → 0؛ makeup على غير يوم جدول → +1؛ makeup على يوم جدول → 0؛ مزيج → مجموع صحيح؛ فارغ → 0.
