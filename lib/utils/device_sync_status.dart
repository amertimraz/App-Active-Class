// lib/utils/device_sync_status.dart
//
// «حالة المزامنة» لجهاز: تصنيف صحّته (متزامن / بينتظر / عالق / مش بيتصل) ونصوص
// عربية للأوقات. منطق صرف بلا Get/DB عشان يتختبر، وبيتستخدم في سحابة وضع
// الفريق وفي قايمة أجهزة الفريق عند المدرّس.

enum SyncHealth { ok, pending, stuck, stale }

/// صحّة المزامنة من الأرقام:
/// - [stuck]: فيه معلّق/ناقص وفيه خطأ حقيقي (مش شبكة)، أو فيه صفوف ناقصة
///   (اتشالت من الطابور) — مش هتتحل لوحدها من غير تدخّل أو علاج.
/// - [pending]: فيه معلّق في الطابور بيتصفّى (أو خطأ شبكة مؤقت).
/// - [stale]: مفيش اتصال من وقت طويل (الجهاز مقفول/أوفلاين).
/// - [ok]: مفيش معلّق ولا ناقص.
SyncHealth classifySyncHealth({
  required int pending,
  required int unsynced,
  String? lastError,
  bool errorTransient = false,
  Duration? sinceLastContact,
  Duration staleAfter = const Duration(hours: 1),
}) {
  if (sinceLastContact != null && sinceLastContact > staleAfter) {
    return SyncHealth.stale;
  }
  final hasError = (lastError ?? '').isNotEmpty && !errorTransient;
  if (hasError && (pending > 0 || unsynced > 0)) return SyncHealth.stuck;
  if (unsynced > 0) return SyncHealth.stuck;
  if (pending > 0 || ((lastError ?? '').isNotEmpty && errorTransient)) {
    return SyncHealth.pending;
  }
  return SyncHealth.ok;
}

/// "قبل 3 دقايق" / "من ساعتين" … بالعربي المصري.
String agoText(Duration d) {
  final s = d.inSeconds;
  if (s < 45) return 'دلوقتي';
  final m = d.inMinutes;
  if (m < 60) {
    if (m <= 1) return 'من دقيقة';
    if (m == 2) return 'من دقيقتين';
    return 'من $m دقايق';
  }
  final h = d.inHours;
  if (h < 24) {
    if (h == 1) return 'من ساعة';
    if (h == 2) return 'من ساعتين';
    return 'من $h ساعات';
  }
  final days = d.inDays;
  return days == 1 ? 'من يوم' : (days == 2 ? 'من يومين' : 'من $days أيام');
}

/// صف حالة جهاز من السيرفر (list_device_status).
class DeviceSyncStatus {
  final String deviceId;
  final String name;
  final bool isOwner;
  final int pending;
  final int unsynced;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  final String? lastError;
  final String? appVersion;

  /// من قد إيه الجهاز بعت نبضة (بوقت السيرفر).
  final Duration sinceUpdate;

  /// من قد إيه آخر رفع/سحب ناجح (بوقت السيرفر)، أو null لو عمره ما حصل.
  final Duration? sincePush;
  final Duration? sincePull;

  const DeviceSyncStatus({
    required this.deviceId,
    required this.name,
    required this.isOwner,
    required this.pending,
    required this.unsynced,
    required this.lastPushAt,
    required this.lastPullAt,
    required this.lastError,
    required this.appVersion,
    required this.sinceUpdate,
    this.sincePush,
    this.sincePull,
  });

  SyncHealth get health => classifySyncHealth(
        pending: pending,
        unsynced: unsynced,
        lastError: lastError,
        sinceLastContact: sinceUpdate,
      );

  factory DeviceSyncStatus.fromRow(Map<String, dynamic> r) {
    DateTime? t(String k) => DateTime.tryParse('${r[k] ?? ''}');
    final updated = t('updated_at');
    final now = t('server_now');
    final name = ((r['display_name'] as String?) ?? '').trim();
    return DeviceSyncStatus(
      deviceId: (r['device_id'] as String?) ?? '',
      name: name.isEmpty ? 'عضو' : name,
      isOwner: r['is_owner'] == true,
      pending: (r['pending'] as num?)?.toInt() ?? 0,
      unsynced: (r['unsynced'] as num?)?.toInt() ?? 0,
      lastPushAt: t('last_push_at'),
      lastPullAt: t('last_pull_at'),
      lastError: r['last_error'] as String?,
      appVersion: r['app_version'] as String?,
      sinceUpdate: (updated != null && now != null)
          ? now.difference(updated)
          : Duration.zero,
      sincePush: (t('last_push_at') != null && now != null)
          ? now.difference(t('last_push_at')!)
          : null,
      sincePull: (t('last_pull_at') != null && now != null)
          ? now.difference(t('last_pull_at')!)
          : null,
    );
  }
}
