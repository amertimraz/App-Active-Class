// lib/services/notification_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:active_class/config/constants.dart';
import 'package:active_class/services/at_risk_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/utils/pricing_helper.dart';
import 'package:active_class/utils/helpers.dart';

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
  // إشعار ملخص "حصص اليوم" — واحد لكل يوم أسبوع، بمساحة IDs منفصلة.
  static const int _digestNotificationIdBase = 950000000;
  // تذكير الدفع المتأخر — إشعار واحد يومي بعدد الطلاب المتأخرين.
  static const int _latePaymentNotificationId = 990000000;
  // spec 021 — إشعار أسبوعي ملخّص بعدد "محتاجين متابعة".
  static const int _atRiskNotificationId = 991000000;

  // مفاتيح app_settings للتحكم في تفعيل/تعطيل كل نوع إشعار — نفس
  // نمط setting/getSetting الموجود بالفعل (زي payment_grace_days).
  // كل الأنواع مفعّلة افتراضيًا (لو المفتاح مش موجود أصلاً) عشان يطابق
  // سلوك التطبيق الأصلي قبل ما الإعدادات دي تتفعّل فعليًا.
  static const String _keyBirthdayEnabled = 'notif_birthday_enabled';
  static const String _keyClassEnabled = 'notif_class_enabled';
  static const String _keyLatePaymentEnabled = 'notif_late_payment_enabled';
  // ملحوظة: مفتاح تفعيل الإشعار الأسبوعي هو نفسه SETTING_ATRISK_NOTIF_ENABLED
  // (مُعرَّف في constants.dart) — مش مفتاح notif_* منفصل، عشان يتقرا بنفس
  // مفتاح إعدادات "متابعة الطلاب" في SettingsController من غير تكرار.

  Future<bool> _readToggle(String key) async {
    final v = await _dbService.getSetting(key);
    return v == null || v == '1';
  }

  Future<bool> isBirthdayEnabled() => _readToggle(_keyBirthdayEnabled);
  Future<bool> isClassEnabled() => _readToggle(_keyClassEnabled);
  Future<bool> isLatePaymentEnabled() => _readToggle(_keyLatePaymentEnabled);

  Future<void> setBirthdayEnabled(bool v) =>
      _dbService.setSetting(_keyBirthdayEnabled, v ? '1' : '0');
  Future<void> setClassEnabled(bool v) =>
      _dbService.setSetting(_keyClassEnabled, v ? '1' : '0');
  Future<void> setLatePaymentEnabled(bool v) =>
      _dbService.setSetting(_keyLatePaymentEnabled, v ? '1' : '0');

  Future<bool> isAtRiskEnabled() => _readToggle(SETTING_ATRISK_NOTIF_ENABLED);
  Future<void> setAtRiskEnabled(bool v) =>
      _dbService.setSetting(SETTING_ATRISK_NOTIF_ENABLED, v ? '1' : '0');

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

    await requestPermission(requestExactAlarm: true);

    _initialized = true;
  }

  /// [requestExactAlarm] بيفتح شاشة إعدادات النظام على أندرويد 12+ (مش
  /// حوار عادي) — لازم يتطلب بس من فعل مستخدم صريح (زرار في شاشة
  /// الإعدادات)، مش تلقائيًا عند فتح التطبيق، عشان مايخطفش شاشة البداية
  /// بشاشة إعدادات بدل الداشبورد.
  Future<bool> requestPermission({bool requestExactAlarm = false}) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      if (requestExactAlarm) {
        // بدون الصلاحية دي، جدولة الإشعارات (zonedSchedule) بتفشل بصمت على
        // أندرويد 12+ ومفيش أي تذكير بيوصل للمستخدم رغم إن الجدولة "نجحت".
        try {
          await androidImplementation?.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('NotificationService: تعذر طلب صلاحية الجدولة الدقيقة — $e');
        }
      }
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

  /// هل صلاحية "الجدولة الدقيقة" (Schedule exact alarms) مفعّلة فعليًا
  /// دلوقتي — مش بس "طلبناها قبل كده". لازم يتحقق منها *مباشرة قبل*
  /// أي جدولة، لأن دي صلاحية خاصة (مش حوار عادي) بتتفتح كشاشة إعدادات
  /// نظام، والمستخدم ممكن يقفلها من غير ما يفعّلها فعلاً — ولو حصل كده،
  /// كل جدولة exact كانت بتفشل بصمت (زي ما موضّح في requestPermission).
  Future<bool> hasExactAlarmPermission() => _hasExactAlarmPermission();

  Future<bool> _hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      return granted ?? false;
    } catch (e) {
      debugPrint('NotificationService: تعذر التحقق من صلاحية الجدولة الدقيقة — $e');
      return false;
    }
  }

  // spec 021 — أول تنقّل-من-إشعار في المشروع (باقي الأنواع بتفتح
  // التطبيق بس من غير توجيه). GetMaterialApp بيوفّر Get.toNamed من أي
  // مكان من غير navigatorKey يدوي. الحالة دي بتغطّي "التطبيق شغّال في
  // الخلفية" بس — لو التطبيق مقفول تمامًا والإشعار هو اللي فتحه (cold
  // start)، getNotificationAppLaunchDetails() محتاجة معالجة منفصلة وقت
  // initialize() — قيد معروف، لسه مش متنفّذ.
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    if (response.payload == 'at_risk') {
      Get.toNamed(ROUTE_AT_RISK_STUDENTS);
    }
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

      // كل نوع بيتحقق من مفتاحه بتاعه لوحده — تعطيل نوع واحد (زي
      // "الدفع المتأخر") ميأثرش على الأنواع التانية.
      if (await isClassEnabled()) {
        for (final g in groups) {
          // نلف كل مجموعة في try/catch مستقل عشان فشل جدولة مجموعة واحدة
          // (بيانات جدول غير سليمة مثلاً) ما يوقفش جدولة باقي المجموعات.
          try {
            await scheduleGroupClassNotifications(g);
          } catch (e) {
            debugPrint('NotificationService: فشلت جدولة حصص "${g.name}" — $e');
          }
        }

        try {
          await scheduleDailyDigestNotifications(groups);
        } catch (e) {
          debugPrint('NotificationService: فشلت جدولة ملخص حصص اليوم — $e');
        }
      }

      if (await isBirthdayEnabled()) {
        // معنيش نجدول تذكير عيد ميلاد لطالب مؤرشف (سايب المجموعة أصلاً).
        final students =
            (await _dbService.getAllStudents()).where((s) => !s.isArchived);
        for (final s in students) {
          if (s.birthDate != null) {
            try {
              await scheduleBirthdayNotifications(s);
            } catch (e) {
              debugPrint('NotificationService: فشلت جدولة عيد ميلاد "${s.name}" — $e');
            }
          }
        }
      }

      // scheduleLatePaymentReminder بتتحقق من isLatePaymentEnabled بنفسها
      // (عشان تفضل قابلة للنداء المستقل بعد كل دفعة — راجع تعليقها).
      try {
        await scheduleLatePaymentReminder();
      } catch (e) {
        debugPrint('NotificationService: فشلت جدولة تذكير الدفع المتأخر — $e');
      }

      // نفس المنطق — scheduleWeeklyAtRiskDigest بتتحقق من isAtRiskEnabled
      // بنفسها (spec 021).
      try {
        await scheduleWeeklyAtRiskDigest();
      } catch (e) {
        debugPrint('NotificationService: فشلت جدولة إشعار محتاجين متابعة — $e');
      }
    } catch (e) {
      debugPrint('NotificationService: فشلت مزامنة الإشعارات — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  تذكير الدفع المتأخر — إشعار يومي متكرر الساعة 9 صباحًا بعدد
  //  الطلاب المتأخرين حاليًا في الدفع (نفس منطق "لم يدفعوا" في
  //  الداشبورد: PricingHelper.isOverdue بمهلة السماح المحفوظة).
  //
  //  الدالة دي مستقلة تمامًا (مبتعتمدش على cancelAllNotifications من
  //  syncAllScheduledNotifications) — عشان تقدر تتنادى مباشرة بعد أي
  //  دفعة جديدة/محذوفة (PaymentController) وتحدّث العدد فورًا، من غير
  //  ما تلغي/تعيد جدولة الحصص وأعياد الميلاد كلها معاها كل مرة حد يدفع.
  // ─────────────────────────────────────────────────────────────────
  Future<void> scheduleLatePaymentReminder() async {
    if (!await isLatePaymentEnabled()) {
      await cancelNotification(_latePaymentNotificationId);
      return;
    }

    final students =
        (await _dbService.getAllStudents()).where((s) => !s.isArchived).toList();
    if (students.isEmpty) {
      await cancelNotification(_latePaymentNotificationId);
      return;
    }

    final allAttendance = await _dbService.getAllAttendance();
    final allPayments = await _dbService.getAllPayments();
    final groups = await _dbService.getAllGroups();
    final groupById = {for (final g in groups) g.id: g};
    final graceDays =
        int.tryParse(await _dbService.getSetting('payment_grace_days') ?? '') ?? 0;

    int overdueCount = 0;
    for (final s in students) {
      final studentPayments =
          allPayments.where((p) => p.studentId == s.id).toList();
      final isOverdue = PricingHelper.isOverdue(
        student: s,
        group: groupById[s.groupId],
        allAttendance: allAttendance,
        payments: studentPayments,
        graceDays: graceDays,
        siblingGroupMembers: students,
      );
      if (isOverdue) overdueCount++;
    }

    // مفيش حد متأخر — لازم نلغي أي تذكير قديم صراحةً (الدالة دي بقت
    // بتتنادى بره سياق المزامنة الشاملة، فمفيش cancelAllNotifications
    // يمسحه تلقائيًا؛ لو سيّبناه من غير إلغاء، طالب دفع اللي عليه كان
    // هيفضل الإشعار القديم بعدده القديم شغال).
    if (overdueCount == 0) {
      await cancelNotification(_latePaymentNotificationId);
      return;
    }

    final scheduled = _nextInstanceOfTime(const TimeOfDay(hour: 9, minute: 0));
    await _scheduleById(
      id: _latePaymentNotificationId,
      title: '💰 طلاب متأخرين في الدفع',
      body: overdueCount == 1
          ? 'يوجد طالب واحد متأخر في الدفع'
          : 'يوجد $overdueCount طلاب متأخرين في الدفع',
      scheduledTime: scheduled,
      payload: 'late_payment',
      channelId: 'late_payment_channel',
      channelName: 'الدفع المتأخر',
      channelDescription: 'تذكير يومي بعدد الطلاب المتأخرين في الدفع',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  spec 021 — إشعار أسبوعي ملخّص بعدد "محتاجين متابعة". نفس نمط
  //  scheduleLatePaymentReminder بالظبط (يعيد الحساب من الـDB مباشرة
  //  وقت الجدولة) لكن بتكرار أسبوعي (يوم/وقت قابلين للتعديل) بدل يومي.
  // ─────────────────────────────────────────────────────────────────
  Future<AtRiskSettings> _readAtRiskSettings() async {
    Future<bool> flag(String key, bool def) async {
      final v = await _dbService.getSetting(key);
      return v == null ? def : v == '1';
    }

    Future<int> num(String key, int def) async {
      final v = await _dbService.getSetting(key);
      return v == null ? def : (int.tryParse(v) ?? def);
    }

    final paymentGraceDays =
        await num('payment_grace_days', 0); // نفس مفتاح SettingsController
    return AtRiskSettings(
      absenceEnabled: await flag(SETTING_ATRISK_ABSENCE_ENABLED, true),
      absenceThreshold: await num(SETTING_ATRISK_ABSENCE_THRESHOLD, 2),
      homeworkEnabled: await flag(SETTING_ATRISK_HOMEWORK_ENABLED, true),
      homeworkM: await num(SETTING_ATRISK_HOMEWORK_M, 3),
      homeworkW: await num(SETTING_ATRISK_HOMEWORK_W, 5),
      gradeEnabled: await flag(SETTING_ATRISK_GRADE_ENABLED, true),
      gradeDropPoints: await num(SETTING_ATRISK_GRADE_DROP_POINTS, 15),
      paymentEnabled: await flag(SETTING_ATRISK_PAYMENT_ENABLED, true),
      paymentGraceDays: paymentGraceDays,
      cooldownDays: await num(SETTING_ATRISK_COOLDOWN_DAYS, 7),
    );
  }

  Future<void> scheduleWeeklyAtRiskDigest() async {
    if (!await isAtRiskEnabled()) {
      await cancelNotification(_atRiskNotificationId);
      return;
    }

    final settings = await _readAtRiskSettings();
    final students =
        (await _dbService.getAllStudents()).where((s) => !s.isArchived).toList();
    if (students.isEmpty) {
      await cancelNotification(_atRiskNotificationId);
      return;
    }

    final atRisk = computeAtRiskStudents(
      students: students,
      groups: await _dbService.getAllGroups(),
      attendance: await _dbService.getAllAttendance(),
      homework: await _dbService.getAllHomework(),
      examGrades: await _dbService.getAllExamGradesWithExamInfo(),
      payments: await _dbService.getAllPayments(),
      recentFollowUps:
          await _dbService.getRecentFollowUps(sinceDays: settings.cooldownDays),
      settings: settings,
    );

    if (atRisk.isEmpty) {
      await cancelNotification(_atRiskNotificationId);
      return;
    }

    final dayName = await _dbService.getSetting(SETTING_ATRISK_NOTIF_DAY) ?? 'الأحد';
    final hour = int.tryParse(
            await _dbService.getSetting(SETTING_ATRISK_NOTIF_HOUR) ?? '') ??
        9;
    final minute = int.tryParse(
            await _dbService.getSetting(SETTING_ATRISK_NOTIF_MINUTE) ?? '') ??
        0;
    final weekday = _dayNameToWeekday[dayName] ?? DateTime.sunday;

    final scheduled = _nextInstanceOfWeekdayTime(
        weekday, TimeOfDay(hour: hour, minute: minute));
    await _scheduleById(
      id: _atRiskNotificationId,
      title: '📋 طلاب محتاجين متابعة',
      body: atRisk.length == 1
          ? 'فيه طالب واحد محتاج متابعة'
          : 'فيه ${atRisk.length} طلاب محتاجين متابعة',
      scheduledTime: scheduled,
      payload: 'at_risk',
      channelId: 'at_risk_channel',
      channelName: 'محتاجين متابعة',
      channelDescription: 'إشعار أسبوعي ملخّص بعدد الطلاب المحتاجين متابعة',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
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

  // ─────────────────────────────────────────────────────────────────
  //  إشعار ملخص يومي الساعة 12 ص — بيعرض كل مجموعات وأوقات حصص
  //  اليوم ده في إشعار واحد. بيتجدول إشعار مستقل لكل يوم أسبوع فيه
  //  حصص، متكرر أسبوعيًا، عشان المحتوى (أسماء المجموعات) يفضل ثابت
  //  ومحدّث مع كل مزامنة بدل ما يتحسب وقت الإطلاق.
  // ─────────────────────────────────────────────────────────────────
  Future<void> scheduleDailyDigestNotifications(List<Group> groups) async {
    final Map<int, List<String>> byWeekday = {};
    for (final g in groups) {
      if (g.schedule == null || g.schedule!.trim().isEmpty) continue;
      for (final (weekday, time) in _parseScheduleEntries(g.schedule!)) {
        byWeekday.putIfAbsent(weekday, () => []).add('${g.name} الساعة ${_fmt(time)}');
      }
    }

    for (final weekday in _dayNameToWeekday.values) {
      final id = _digestNotificationIdBase + weekday;
      final items = byWeekday[weekday];
      // ملحوظة: المستدعي الوحيد الحالي (syncAllScheduledNotifications) بينادي
      // cancelAllNotifications() قبل الدالة دي مباشرة، فمفيش داعي نلغي id
      // فاضي هنا تاني — لو الدالة اتنادت من مكان تاني مستقبلاً لازم يُعاد النظر.
      if (items == null || items.isEmpty) continue;

      final scheduled = _nextInstanceOfWeekdayTime(weekday, const TimeOfDay(hour: 0, minute: 0));
      await _scheduleById(
        id: id,
        title: '📅 حصص اليوم',
        body: items.join('\n'),
        scheduledTime: scheduled,
        payload: 'digest_$weekday',
        channelId: 'digest_channel',
        channelName: 'ملخص حصص اليوم',
        channelDescription: 'إشعار الساعة 12 صباحاً بكل حصص اليوم',
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

  // وقت الحصة في نصوص الإشعارات يتبع إعداد "نظام الساعة 24" (spec 009).
  String _fmt(TimeOfDay t) => FormatHelper.formatClock(t);

  tz.TZDateTime _nextInstanceOfWeekdayTime(int targetWeekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// أقرب موعد قادم لوقت معيّن كل يوم (بدون قيد يوم أسبوع) — لإشعارات
  /// يومية متكررة زي تذكير الدفع المتأخر.
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
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

    // لو صلاحية "الجدولة الدقيقة" مش مفعّلة، الجدولة exact كانت بتفشل
    // بصمت (تسجّل نجاح ظاهريًا من غير ما الإشعار يظهر فعلاً أبدًا).
    // بدل ما نسيب المستخدم من غير أي تذكير خالص، نرجع لجدولة "غير دقيقة"
    // (ممكن تتأخر شوية عن الميعاد بالظبط، لكن هتوصل فعلاً) — أفضل بكتير
    // من عدم الوصول نهائيًا.
    final hasExact = await _hasExactAlarmPermission();
    final scheduleMode = hasExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        payload: payload,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      // نسجّل الفشل بدل ما نخليه يوقف باقي الجدولة (المستدعيات بره
      // أصلاً بتلف كل عنصر في try/catch مستقل)، لكن كمان بنعيد رميه
      // عشان المستدعي يقدر يحسب عدد الإشعارات اللي فعلاً فشلت لو حابب.
      debugPrint('NotificationService: فشلت جدولة الإشعار id=$id — $e');
      rethrow;
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
