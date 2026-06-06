// lib/services/notification_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    // Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
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
    // Handle notification tap
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

  // Schedule notification for a specific time
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
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

    await _notificationsPlugin.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Check for upcoming birthdays
  Future<void> checkUpcomingBirthdays() async {
    try {
      final allStudents = await _dbService.getAllStudents();
      final now = DateTime.now();
      final upcomingBirthdays = <Student>[];

      for (final student in allStudents) {
        if (student.birthDate == null) continue;

        final birthDate = student.birthDate!;
        final nextBirthday = DateTime(
          now.year,
          birthDate.month,
          birthDate.day,
        );

        // If birthday already passed this year, check next year
        if (nextBirthday.isBefore(now)) {
          final nextYearBirthday = DateTime(
            now.year + 1,
            birthDate.month,
            birthDate.day,
          );
          final daysUntil = nextYearBirthday.difference(now).inDays;
          if (daysUntil <= 7 && daysUntil >= 0) {
            upcomingBirthdays.add(student);
          }
        } else {
          final daysUntil = nextBirthday.difference(now).inDays;
          if (daysUntil <= 7 && daysUntil >= 0) {
            upcomingBirthdays.add(student);
          }
        }
      }

      // Show notification for upcoming birthdays
      if (upcomingBirthdays.isNotEmpty) {
        final names = upcomingBirthdays.map((s) => s.name).join('، ');
        await showNotification(
          title: 'أعياد ميلاد قريبة',
          body: 'لديك ${upcomingBirthdays.length} طلاب أعياد ميلادهم قريبة: $names',
        );
      }
    } catch (e) {
      debugPrint('Error checking birthdays: $e');
    }
  }

  // Check for upcoming classes
  Future<void> checkUpcomingClasses() async {
    try {
      final allGroups = await _dbService.getAllGroups();
      final now = DateTime.now();
      final currentDay = now.weekday; // 1 = Monday, 7 = Sunday

      final upcomingClasses = <Group>[];

      for (final group in allGroups) {
        if (group.schedule == null) continue;

        // Parse schedule (e.g., "1,3,5" for Monday, Wednesday, Friday)
        final scheduleDays = group.schedule!.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();

        if (scheduleDays.contains(currentDay)) {
          upcomingClasses.add(group);
        }
      }

      // Show notification for upcoming classes today
      if (upcomingClasses.isNotEmpty) {
        final groupNames = upcomingClasses.map((g) => g.name).join('، ');
        await showNotification(
          title: 'حصص اليوم',
          body: 'لديك ${upcomingClasses.length} حصص اليوم: $groupNames',
        );
      }
    } catch (e) {
      debugPrint('Error checking classes: $e');
    }
  }

  // Schedule birthday notification
  Future<void> scheduleBirthdayNotification(Student student) async {
    if (student.birthDate == null) return;

    final birthDate = student.birthDate!;
    final now = DateTime.now();
    final nextBirthday = DateTime(
      now.year,
      birthDate.month,
      birthDate.day,
      9, // 9 AM
      0,
    );

    if (nextBirthday.isBefore(now)) {
      final nextYearBirthday = DateTime(
        now.year + 1,
        birthDate.month,
        birthDate.day,
        9,
      );
      await scheduleNotification(
        title: 'عيد ميلاد ${student.name}',
        body: 'تذكر عيد ميلاد الطالب ${student.name} اليوم!',
        scheduledTime: nextYearBirthday,
        payload: 'birthday_${student.id}',
      );
    } else {
      await scheduleNotification(
        title: 'عيد ميلاد ${student.name}',
        body: 'تذكر عيد ميلاد الطالب ${student.name} اليوم!',
        scheduledTime: nextBirthday,
        payload: 'birthday_${student.id}',
      );
    }
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
