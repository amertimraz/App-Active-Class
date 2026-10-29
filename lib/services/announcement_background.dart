// lib/services/announcement_background.dart
//
// spec 054 — فحص الإعلانات في الخلفية (WorkManager) لإشعار والتطبيق مقفول.
// بدون Firebase في الـisolate: قراءة REST عامة. التوصيل بالفحص الدوري يعني
// تأخير ممكن (ساعات)، وبعض الأجهزة بتقيّد الخلفية — مقبول (راجع spec 054).
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/services/announcement_service.dart';
import 'package:active_class/utils/announcement_logic.dart';

const String kAnnouncementCheckTask = 'announcement_check_task';
const int kAnnouncementNotificationId = 990000100;

/// يرجّع true دايمًا تقريبًا (مفيش إعادة محاولة مستمرة لو فشل). الدوال
/// الخارجية قابلة للاستبدال للاختبار.
Future<bool> runAnnouncementBackgroundCheck({
  Future<List<Announcement>> Function()? fetch,
  Future<void> Function(Announcement)? show,
  DateTime? now,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final items = await (fetch ?? AnnouncementService.instance.fetchViaRest)();
    if (items.isEmpty) return true;
    final a = announcementToNotify(
      items,
      now: now ?? DateTime.now(),
      planKey: prefs.getString(kAnnPlanKey) ?? 'trial',
      lastNotifiedKey: prefs.getString(kAnnNotifiedKey),
    );
    if (a == null) return true;
    // نحجز المفتاح قبل الإظهار (المقدمة بتعيد قراءته فمفيش إشعار مزدوج).
    await prefs.setString(kAnnNotifiedKey, a.displayKey);
    await (show ?? _showViaPlugin)(a);
  } catch (e) {
    debugPrint('runAnnouncementBackgroundCheck فشل: $e');
  }
  return true;
}

Future<void> _showViaPlugin(Announcement a) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));
  await plugin.show(
    kAnnouncementNotificationId,
    a.title,
    a.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'active_class_announcements',
        'عروض وإعلانات',
        channelDescription: 'عروض وخصومات من Active Class',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
      ),
    ),
    payload: a.cta.type == 'plans' ? 'announcement_plans' : 'announcement',
  );
}
