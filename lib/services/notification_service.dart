// lib/services/notification_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final DatabaseService _dbService = DatabaseService();

  bool _initialized = false;

  // فرق ثابت بين مساحات الـ ID لكل نوع إشعار عشان محدش يصطدم بالتاني:
  // أعياد الميلاد = studentId*2 / studentId*2+1 (أرقام صغيرة).
  // إشعارات الحصص بعيدة تمامًا في مساحة أعلى.
  static const int _classNotificationIdBase = 900000000;

  static const Map<String, int> _dayNameToWeekday = {
    'السبت': DateTime.saturday,
    'الأحد': DateTime.sunday,
    'الاثنين': DateTime.monday,
    'الثلاثاء': DateTime.tuesday,
    'الأربعاء': DateTime.wednesday,
    'الخميس': DateTime.thursday,
    'الجمعة': DateTime.friday,
  };

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone));
    } catch (e) {
      // فشل التعرف على توقيت الجهاز (نادر) — نفضّل استخدام UTC بدل
      // توقيت دولة تانية عشوائي يبعد ساعات عن المستخدم الفعلي.
      debugPrint('NotificationService: تعذر تحديد توقيت الجهاز — $e');
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await requestPermission();

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final bool? granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }
    return false;
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  // Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'active_class_channel',
      'Active Class Notifications',
      channelDescription: 'Notifications for Active Class app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  مزامنة شاملة — بتلغي كل الإشعارات المجدولة القديمة وتعيد جدولة
  //  كل شيء من الصفر بناءً على البيانات الحالية (مجموعات + طلاب).
  //  بتتنادى تلقائيًا عند تشغيل التطبيق، وبعد أي إضافة/تعديل/حذف
  //  لمجموعة أو طالب، عشان الإشعارات تفضل متزامنة مع البيانات
  //  الفعلية من غير ما المدرس يعمل أي خطوة يدوية.
  // ─────────────────────────────────────────────────────────────────
  Future<void> syncAllScheduledNotifications() async {
    try {
      await cancelAllNotifications();

      final groups = await _dbService.getAllGroups();
      for (final g in groups) {
        await scheduleGroupClassNotifications(g);
      }

      final students = await _dbService.getAllStudents();
      for (final s in students) {
        if (s.birthDate != null) {
          await scheduleBirthdayNotifications(s);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: فشلت مزامنة الإشعارات — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  إشعارات مواعيد الحصص — تذكير قبل كل حصة بـ 15 دقيقة، متكرر
  //  أسبوعيًا بناءً على جدول المجموعة (نص بصيغة "اليوم HH:MM-HH:MM"
  //  مفصول بفواصل، نفس الصيغة اللي بيكتبها _ScheduleEditor).
  // ─────────────────────────────────────────────────────────────────
  Future<void> scheduleGroupClassNotifications(Group group) async {
    if (group.id == null || group.schedule == null || group.schedule!.trim().isEmpty) {
      return;
    }

    final entries = _parseScheduleEntries(group.schedule!);
    for (var i = 0; i < entries.length; i++) {
      final (weekday, time) = entries[i];
      final reminderTime = _subtractMinutes(time, 15);
      final scheduled = _nextInstanceOfWeekdayTime(weekday, reminderTime);
      final id = _classNotificationIdBase + (group.id! * 10) + i;

      await _scheduleById(
        id: id,
        title: '🔔 حصة ${group.name} بعد 15 دقيقة',
        body: 'الحصة الساعة ${_fmt(time)}',
        scheduledTime: scheduled,
        payload: 'class_${group.id}_$i',
        channelId: 'class_channel',
        channelName: 'مواعيد الحصص',
        channelDescription: 'تذكير قبل موعد كل حصة',
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// يحلّل نص الجدول لقائمة (يوم الأسبوع، وقت البداية).
  List<(int, TimeOfDay)> _parseScheduleEntries(String schedule) {
    final result = <(int, TimeOfDay)>[];
    for (final raw in schedule.split(',')) {
      final s = raw.trim();
      if (s.isEmpty) continue;

      String? matchedDay;
      for (final day in _dayNameToWeekday.keys) {
        if (s.startsWith(day)) {
          matchedDay = day;
          break;
        }
      }
      if (matchedDay == null) continue;

      final timesPart = s.replaceFirst(matchedDay, '').trim();
      final times = timesPart.split('-');
      if (times.isEmpty) continue;

      final from = _parseTime(times[0].trim());
      if (from == null) continue;

      result.add((_dayNameToWeekday[matchedDay]!, from));
    }
    return result;
  }

  TimeOfDay? _parseTime(String v) {
    final p = v.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  TimeOfDay _subtractMinutes(TimeOfDay t, int minutes) {
    final total = (t.hour * 60 + t.minute - minutes) % (24 * 60);
    final normalized = total < 0 ? total + 24 * 60 : total;
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmt(TimeOfDay t) => '${_pad(t.hour)}:${_pad(t.minute)}';

  tz.TZDateTime _nextInstanceOfWeekdayTime(int targetWeekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Schedule birthday notification (legacy - single notification)
  Future<void> scheduleBirthdayNotification(Student student) async {
    await scheduleBirthdayNotifications(student);
  }

  /// جدولة إشعارين لكل طالب:
  /// - إشعار قبل يوم عيد الميلاد الساعة 8 صباحاً
  /// - إشعار في يوم عيد الميلاد نفسه الساعة 8 صباحاً
  Future<void> scheduleBirthdayNotifications(Student student) async {
    if (student.birthDate == null || student.id == null) return;

    final b = student.birthDate!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var nextBirthday = DateTime(now.year, b.month, b.day);
    if (nextBirthday.isBefore(today)) {
      nextBirthday = DateTime(now.year + 1, b.month, b.day);
    }

    final idDayBefore = (student.id! * 2) % 2147483647;
    final idOnDay     = (student.id! * 2 + 1) % 2147483647;

    final dayBefore = DateTime(
      nextBirthday.year, nextBirthday.month, nextBirthday.day - 1, 8, 0,
    );
    if (dayBefore.isAfter(now)) {
      await _scheduleById(
        id: idDayBefore,
        title: '🎂 غداً عيد ميلاد ${student.name}',
        body: 'لا تنسَ تهنئة ${student.name} بعيد ميلاده غداً!',
        scheduledTime: dayBefore,
        payload: 'birthday_before_${student.id}',
        channelId: 'birthday_channel',
        channelName: 'أعياد الميلاد',
        channelDescription: 'إشعارات أعياد ميلاد الطلاب',
      );
    }

    final onDay = DateTime(
      nextBirthday.year, nextBirthday.month, nextBirthday.day, 8, 0,
    );
    if (onDay.isAfter(now)) {
      await _scheduleById(
        id: idOnDay,
        title: '🎉 عيد ميلاد ${student.name} اليوم!',
        body: 'اليوم عيد ميلاد ${student.name} — لا تنسَ تهنئته! 🎂',
        scheduledTime: onDay,
        payload: 'birthday_on_${student.id}',
        channelId: 'birthday_channel',
        channelName: 'أعياد الميلاد',
        channelDescription: 'إشعارات أعياد ميلاد الطلاب',
      );
    }
  }

  /// جدولة إشعار بـ ID محدد (يسمح بإلغائه لاحقاً)
  Future<void> _scheduleById({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime, // DateTime عادي أو tz.TZDateTime (فرعي منه)
    String? payload,
    required String channelId,
    required String channelName,
    required String channelDescription,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}
