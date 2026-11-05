// lib/services/promo_background.dart
//
// إشعار حملة «شهر مجانًا» على التليفون والتطبيق مقفول. بيركب على نفس فحص
// الإعلانات الدوري (WorkManager كل ~3 ساعات، spec 054): قراءة REST عامة
// لمستند app_config/free_month_promo بدون Firebase في الـisolate، وبيقرا حالة
// المدرس (جمهوره + محجوب؟) من SharedPreferences اللي التطبيق بيحدّثها.
// الإشعار مرة واحدة لكل «إصدار حملة» (أي حفظ جديد من الأدمن = إشعار جديد).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/models/free_month_promo.dart';

const String kPromoAudiencePrefsKey = 'promo_audience'; // new | expired | ''
const String kPromoBlockedPrefsKey = 'promo_blocked'; // طلب/استخدم/مساعد
const String kPromoNotifiedPrefsKey = 'promo_notified_key';
const int kPromoNotificationId = 990000101;
const String kPromoNotificationPayload = 'promo_free_month';

const String _kProjectId = 'active-class-72e0f';

/// يقرا مستند الحملة بـREST. null لو مش موجود/فشل.
Future<FreeMonthPromo?> fetchPromoViaRest(
    {Duration timeout = const Duration(seconds: 15)}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_kProjectId/databases/(default)/documents/app_config/$kFreeMonthPromoDocId');
    final req = await client.getUrl(uri).timeout(timeout);
    final res = await req.close().timeout(timeout);
    if (res.statusCode != 200) return null;
    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    final json = jsonDecode(body);
    return json is Map<String, dynamic>
        ? FreeMonthPromo.fromRestDocument(json)
        : null;
  } catch (e) {
    debugPrint('fetchPromoViaRest فشل: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

/// المهمة الخلفية. الدوال الخارجية قابلة للاستبدال للاختبار. بترجّع true
/// دايمًا تقريبًا (مفيش إعادة محاولة مستمرة).
Future<bool> runPromoBackgroundCheck({
  Future<FreeMonthPromo?> Function()? fetch,
  Future<void> Function(FreeMonthPromo)? show,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final audience = prefs.getString(kPromoAudiencePrefsKey);
    // مفيش جمهور معروف (مفعّل/لسه ماتحمّلش) → ما نقراش الشبكة أصلًا.
    if (audience == null || audience.isEmpty) return true;
    final promo = await (fetch ?? fetchPromoViaRest)();
    if (promo == null) return true;
    final ok = shouldNotifyFreeMonthPromo(
      promo: promo,
      audience: audience,
      blocked: prefs.getBool(kPromoBlockedPrefsKey) ?? false,
      lastNotifiedKey: prefs.getString(kPromoNotifiedPrefsKey),
    );
    if (!ok) return true;
    // نحجز المفتاح قبل الإظهار (المقدمة بتعيد قراءته فمفيش إشعار مزدوج).
    await prefs.setString(kPromoNotifiedPrefsKey, promo.campaignKey!);
    await (show ?? _showViaPlugin)(promo);
  } catch (e) {
    debugPrint('runPromoBackgroundCheck فشل: $e');
  }
  return true;
}

Future<void> _showViaPlugin(FreeMonthPromo p) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_notify'),
  ));
  await plugin.show(
    kPromoNotificationId,
    '🎁 ${p.title}',
    p.subtitle,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        icon: 'ic_stat_notify',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
        color: Color(0xFF4F46E5),
        'active_class_announcements',
        'عروض وإعلانات',
        channelDescription: 'عروض وخصومات من Active Class',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
      ),
    ),
    payload: kPromoNotificationPayload,
  );
}
