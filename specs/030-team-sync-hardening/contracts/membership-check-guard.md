# Contract: حارس فحص العضوية + السحب الدوري

## `sync_retry_policy.dart` — الدالة النقية

```dart
/// هل نُطلق إجراء الخروج من الفريق (إزالة / فكّ جهاز)؟
/// يتطلب جلسة صالحة **و** [emptyStreak] نتائج فاضية متتالية ≥ [threshold].
bool shouldFireTeamExit({
  required bool sessionUsable,
  required int emptyStreak,
  int threshold = 3,
}) => sessionUsable && emptyStreak >= threshold;
```

## `SyncEngine` — حارس الجلسة

```dart
bool _sessionUsable() {
  final s = client.auth.currentSession;
  if (s == null || s.isExpired) {
    unawaited(client.auth.refreshSession().catchError((_) {
      // فشل التجديد — نحاول الجولة الجاية
    }));
    debugPrint('SyncEngine: تخطّي فحص — جلسة غير صالحة، محاولة تجديد');
    return false;
  }
  return true;
}
```

## `_wasRemovedFromTeam` (معدَّلة)

```dart
Future<bool> _wasRemovedFromTeam() async {
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;
  if (!_sessionUsable()) return false;               // FR-011
  try {
    final rows = await client.from('team_members')
        .select('user_id').eq('team_id', teamId).eq('user_id', uid).limit(1);
    if ((rows as List).isEmpty) {
      _emptyMembershipStreak++;
      if (shouldFireTeamExit(sessionUsable: true,
              emptyStreak: _emptyMembershipStreak)) {   // FR-012
        debugPrint('SyncEngine: تأكّدت الإزالة بعد $_emptyMembershipStreak نتائج فاضية');
        onRemovedFromTeam?.call();
        return true;
      }
      debugPrint('SyncEngine: عضوية فاضية ($_emptyMembershipStreak/3) — بانتظار تأكيد');
      return false;
    }
    _emptyMembershipStreak = 0;                        // أي نتيجة صحيحة تُصفّر
    return false;
  } catch (e) {
    debugPrint('SyncEngine: فشل التحقق من العضوية — $e');
    return false;
  }
}
```

## `_wasDeviceUnbound` (معدَّلة)

نفس النمط: `if (!_sessionUsable()) return false;` أولًا؛ عند `!stillBound` → `_deviceUnboundStreak++`؛ `onDeviceUnbound?.call()` فقط عند `_deviceUnboundStreak >= 3`؛ `stillBound == true` → `_deviceUnboundStreak = 0`. (FR-013)

## `_wasLicenseDeactivated` (معدَّلة بشكل أخف)

`if (!_sessionUsable()) return false;` في البداية فقط. لا streak — الدالة تقرأ `teams` بـ`.single()` (يرمي عند الفشل، لا يرجع فاضيًا)، وحالة `owner_license_active == false` تأكيد صريح من الخادم. (FR-014)

## السحب الدوري + lifecycle

```dart
class SyncEngine with WidgetsBindingObserver {   // إضافة mixin
  Timer? _catchUpTimer;

  void start() {
    // ... الموجود ...
    _catchUpTimer = Timer.periodic(
        const Duration(seconds: 50), (_) => unawaited(catchUpPull()));   // FR-007
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(catchUpPull());                                          // FR-008
    }
  }

  Future<void> stop() async {
    // ... الموجود ...
    _catchUpTimer?.cancel();
    _catchUpTimer = null;
    WidgetsBinding.instance.removeObserver(this);                       // FR-010
    _outboxFails.clear();
    _lastOutboxErr.clear();
    _loggedPoison.clear();
    _emptyMembershipStreak = 0;
    _deviceUnboundStreak = 0;
  }
}
```

## ثوابت لا تُكسر

- إزالة فعلية (فاضٍ دائم + جلسة صالحة) → `onRemovedFromTeam()` خلال ≤ 3 دورات فحص (~45s) (FR-016، SC-005).
- هبّة مؤقتة (فاضٍ 1–2 ثم نتيجة صحيحة) → streak يُصفَّر، **لا خروج** (FR-012، SC-004).
- جلسة منتهية → لا فحص، لا خروج، محاولة تجديد (FR-011).
- `catchUpPull` من (التايمر + Realtime + resume) → `_lastCatchUp` guard (≥3s) يمنع التكرار (FR-009).
- `stop()` يوقف كل شيء ويصفّر كل الحالة (FR-010، SC-007).
- جهاز المدرّس: `_membershipTimer` مش متعمل أصلًا (كولباك null) → صفر أثر من منطق الـstreak (FR-017).
