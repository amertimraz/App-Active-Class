// lib/utils/announcement_logic.dart
//
// spec 054 — منطق الإعلانات الصرف (بلا GetX/Firestore/UI، بمعامل `now`):
// اختيار الإعلان المناسب، الحالة، العداد، روابط آمنة، رسالة واتساب.
import 'package:active_class/models/announcement_model.dart';

enum AnnouncementStatus { draft, scheduled, active, expired }

bool isAnnouncementActive(Announcement a, DateTime now) {
  if (!a.published) return false;
  if (a.startsAt != null && now.isBefore(a.startsAt!)) return false;
  if (a.endsAt != null && !now.isBefore(a.endsAt!)) return false;
  return true;
}

AnnouncementStatus announcementStatus(Announcement a, DateTime now) {
  if (!a.published) return AnnouncementStatus.draft;
  if (a.startsAt != null && now.isBefore(a.startsAt!)) {
    return AnnouncementStatus.scheduled;
  }
  if (a.endsAt != null && !now.isBefore(a.endsAt!)) {
    return AnnouncementStatus.expired;
  }
  return AnnouncementStatus.active;
}

/// الجمهور فاضي = الكل؛ وإلا لازم باقة العميل ضمنه.
bool matchesAudience(Announcement a, String planKey) =>
    a.audience.isEmpty || a.audience.contains(planKey);

/// الإعلان اللي يتعرض في [placement]: الأحدث نشرًا بين اللي ساري ومناسب
/// للجمهور والمكان. null لو مفيش.
Announcement? pickAnnouncement(
  Iterable<Announcement> items, {
  required DateTime now,
  required String planKey,
  required AnnouncementPlacement placement,
}) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final candidates = items
      .where((a) =>
          isAnnouncementActive(a, now) &&
          a.shows(placement) &&
          matchesAudience(a, planKey))
      .toList()
    ..sort((x, y) {
      final c = (y.publishedAt ?? epoch).compareTo(x.publishedAt ?? epoch);
      if (c != 0) return c;
      return (y.updatedAt ?? epoch).compareTo(x.updatedAt ?? epoch);
    });
  return candidates.isEmpty ? null : candidates.first;
}

/// عرض "مرة واحدة" (نافذة/إشعار): نعرض لو المفتاح الحالي غير آخر مفتاح اتعرض.
bool shouldShowOnce(String? lastKey, String currentKey) =>
    lastKey != currentKey;

/// إعلان الإشعار المطلوب إرساله دلوقتي (أو null).
Announcement? announcementToNotify(
  Iterable<Announcement> items, {
  required DateTime now,
  required String planKey,
  String? lastNotifiedKey,
}) {
  final a = pickAnnouncement(items,
      now: now, planKey: planKey, placement: AnnouncementPlacement.notify);
  if (a == null) return null;
  return shouldShowOnce(lastNotifiedKey, a.displayKey) ? a : null;
}

class CountdownParts {
  final int days, hours, minutes, seconds;
  const CountdownParts(this.days, this.hours, this.minutes, this.seconds);
  bool get isZero => days == 0 && hours == 0 && minutes == 0 && seconds == 0;
}

/// الوقت المتبقي لـ[end] (لا يقل عن صفر).
CountdownParts countdownParts(DateTime end, DateTime now) {
  var s = end.difference(now).inSeconds;
  if (s < 0) s = 0;
  return CountdownParts(s ~/ 86400, (s % 86400) ~/ 3600, (s % 3600) ~/ 60, s % 60);
}

/// رابط http/https فقط (غير كده null).
Uri? safeHttpUrl(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  final u = Uri.tryParse(s);
  if (u == null || !u.hasAuthority || u.host.isEmpty) return null;
  if (u.scheme != 'http' && u.scheme != 'https') return null;
  return u;
}

/// أرقام فقط بطول 8–15، وإلا null.
String? cleanWhatsappPhone(String? raw) {
  final d = (raw ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  return d.length >= 8 && d.length <= 15 ? d : null;
}

/// رابط واتساب برسالة الأدمن + بيانات المدرس (الأسطر الفاضية بتتشال).
Uri? announcementWhatsappUri({
  required String phone,
  required String message,
  String name = '',
  String code = '',
  String planName = '',
}) {
  final digits = cleanWhatsappPhone(phone);
  if (digits == null) return null;
  final lines = <String>[
    message.trim(),
    if (name.trim().isNotEmpty) 'الاسم: ${name.trim()}',
    if (code.trim().isNotEmpty) 'الكود: ${code.trim()}',
    if (planName.trim().isNotEmpty) 'الباقة: ${planName.trim()}',
  ].where((l) => l.isNotEmpty).toList();
  final text = lines.join('\n');
  return Uri.parse(
      'https://wa.me/$digits${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
}
