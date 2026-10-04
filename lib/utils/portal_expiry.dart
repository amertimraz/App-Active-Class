// lib/utils/portal_expiry.dart
//
// تنبيه قرب انتهاء اشتراك "بوابة أولياء الأمور + الامتحانات الإلكترونية"
// (إضافة مدفوعة بتاريخ انتهاء مستقل — LicenseController.parentPortalExpiresAt،
// والامتحانات الإلكترونية متبوّبة على نفس الإضافة). دوال صرفة بلا GetX/DB
// عشان تتختبر مباشرة (test/portal_expiry_test.dart).

enum PortalExpiryStage {
  /// مفيش حاجة تتنبّه عليها (غير مفعّلة، أو مدى الحياة، أو لسه بعيد).
  none,

  /// قريب الانتهاء (من [kPortalWarnDays] يوم فأقل) — تنبيه أصفر.
  warning,

  /// آخر يوم أو أقل من 24 ساعة (أو 3 أيام فأقل) — تنبيه أحمر.
  urgent,

  /// انتهى مؤخرًا ([kPortalExpiredShowDays] يوم فأقل) — البوابة والامتحانات
  /// الإلكترونية موقوفة، فالمدرس لازم يعرف السبب.
  expired,
}

const int kPortalWarnDays = 7;
const int kPortalUrgentDays = 3;
const int kPortalExpiredShowDays = 30;

/// أيام التذكير قبل الانتهاء (إشعارات محلية الساعة 9 صباحًا).
const List<int> kPortalReminderDaysBefore = [7, 3, 1];

class PortalExpiryInfo {
  final PortalExpiryStage stage;

  /// الأيام المتبقية (قص لأسفل، 0 = أقل من 24 ساعة)، أو سالب/صفر بعد الانتهاء
  /// (عدد الأيام اللي فاتت بعد الانتهاء في [daysSinceExpiry]).
  final int daysLeft;
  final int daysSinceExpiry;

  const PortalExpiryInfo(this.stage,
      {this.daysLeft = 0, this.daysSinceExpiry = 0});
}

PortalExpiryInfo portalExpiryInfo({
  required bool enabled,
  required DateTime? expiresAt,
  required DateTime now,
}) {
  if (!enabled || expiresAt == null) {
    return const PortalExpiryInfo(PortalExpiryStage.none);
  }
  final remaining = expiresAt.difference(now);
  if (remaining.isNegative || remaining == Duration.zero) {
    final since = now.difference(expiresAt).inDays;
    if (since <= kPortalExpiredShowDays) {
      return PortalExpiryInfo(PortalExpiryStage.expired, daysSinceExpiry: since);
    }
    return const PortalExpiryInfo(PortalExpiryStage.none);
  }
  final days = remaining.inDays;
  if (days > kPortalWarnDays) {
    return const PortalExpiryInfo(PortalExpiryStage.none);
  }
  return PortalExpiryInfo(
    days <= kPortalUrgentDays
        ? PortalExpiryStage.urgent
        : PortalExpiryStage.warning,
    daysLeft: days,
  );
}

/// نص البانر حسب الحالة.
String portalExpiryBannerText(PortalExpiryInfo info) {
  const name = 'بوابة أولياء الأمور والامتحانات الإلكترونية';
  switch (info.stage) {
    case PortalExpiryStage.none:
      return '';
    case PortalExpiryStage.warning:
    case PortalExpiryStage.urgent:
      if (info.daysLeft == 0) return '⚠️ اشتراك $name ينتهي اليوم — جدّد الآن';
      final d = info.daysLeft == 1
          ? 'يوم واحد'
          : (info.daysLeft == 2 ? 'يومين' : '${info.daysLeft} أيام');
      return '⏳ اشتراك $name ينتهي خلال $d';
    case PortalExpiryStage.expired:
      return '⛔ انتهى اشتراك $name — البوابة والامتحانات الإلكترونية موقوفة';
  }
}

class PortalReminder {
  final DateTime at;
  final String title;
  final String body;
  const PortalReminder(this.at, this.title, this.body);
}

/// مواعيد إشعارات التذكير المستقبلية: الساعة 9 صباحًا قبل الانتهاء بـ7/3/1
/// أيام (حسب تاريخ الانتهاء بالتوقيت المحلي)، + لحظة الانتهاء نفسها. أي
/// ميعاد فات بالفعل بيتشال (البانر هو اللي بيغطّي الحالة الحالية).
List<PortalReminder> portalReminders(DateTime expiresAt, DateTime now) {
  const name = 'بوابة أولياء الأمور والامتحانات الإلكترونية';
  final out = <PortalReminder>[];
  final expDay = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
  for (final n in kPortalReminderDaysBefore) {
    final at = DateTime(expDay.year, expDay.month, expDay.day - n, 9);
    if (!at.isAfter(now) || !at.isBefore(expiresAt)) continue;
    final when = n == 1 ? 'بكرة' : 'بعد $n أيام';
    out.add(PortalReminder(
      at,
      '⏳ اشتراك $name',
      'هينتهي $when — جدّد عشان البوابة والامتحانات الإلكترونية تفضل شغّالة.',
    ));
  }
  if (expiresAt.isAfter(now)) {
    out.add(PortalReminder(
      expiresAt,
      '⛔ انتهى اشتراك $name',
      'البوابة والامتحانات الإلكترونية اتوقفت — جدّد عشان ترجع شغّالة.',
    ));
  }
  return out;
}
