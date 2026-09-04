import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';

// نفس أسماء أيام الأسبوع المستخدَمة في NotificationService._dayNameToWeekday.
const List<String> _weekDayNames = [
  'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'
];

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late final TabController _tabController;

  bool _birthdayNotifications = true;
  bool _classNotifications = true;
  bool _latePaymentNotifications = true;

  // Upcoming birthdays state
  List<_BirthdayEntry> _upcomingBirthdays = [];
  bool _loadingBirthdays = true;
  bool _schedulingAll = false;

  // هل صلاحية "الجدولة الدقيقة" (Schedule exact alarms) مفعّلة فعليًا —
  // صلاحية خاصة منفصلة عن إذن الإشعارات العادي، وغيابها كان بيخلي
  // التذكيرات تفشل تظهر من غير أي رسالة خطأ واضحة للمدرس.
  bool? _hasExactAlarm;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // حمّل أعياد الميلاد فور فتح الصفحة
    _loadBirthdays();
    _checkExactAlarmPermission();
    _loadToggles();
    // أعِد التحميل كلما انتقل المستخدم للتاب الثاني (بعد انتهاء الانيميشن فقط)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        _loadBirthdays();
      }
    });
  }

  Future<void> _checkExactAlarmPermission() async {
    final granted = await _notificationService.hasExactAlarmPermission();
    if (mounted) setState(() => _hasExactAlarm = granted);
  }

  /// يحمّل حالة المفاتيح التلاتة المحفوظة فعليًا — كانت قبل كده قيم
  /// محلية بس بترجع true دايمًا من غير أي حفظ حقيقي.
  Future<void> _loadToggles() async {
    final birthday = await _notificationService.isBirthdayEnabled();
    final classes = await _notificationService.isClassEnabled();
    final latePayment = await _notificationService.isLatePaymentEnabled();
    if (mounted) {
      setState(() {
        _birthdayNotifications = birthday;
        _classNotifications = classes;
        _latePaymentNotifications = latePayment;
      });
    }
  }

  /// بيحفظ المفتاح فعليًا وبعدين يعيد مزامنة الإشعارات كلها، عشان
  /// تفعيل/تعطيل نوع معيّن ينعكس فورًا (يجدول أو يلغي على طول)، مش
  /// بس عند أول مرة التطبيق يفتح.
  Future<void> _onToggleChanged(
      {required String type, required bool value}) async {
    setState(() {
      switch (type) {
        case 'birthday':
          _birthdayNotifications = value;
        case 'class':
          _classNotifications = value;
        case 'late_payment':
          _latePaymentNotifications = value;
      }
    });
    switch (type) {
      case 'birthday':
        await _notificationService.setBirthdayEnabled(value);
      case 'class':
        await _notificationService.setClassEnabled(value);
      case 'late_payment':
        await _notificationService.setLatePaymentEnabled(value);
    }
    unawaited(_notificationService.syncAllScheduledNotifications());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Birthdays logic ──────────────────────────────────────────────────────

  Future<void> _loadBirthdays() async {
    if (mounted) setState(() => _loadingBirthdays = true);

    final db = DatabaseService();
    final students =
        (await db.getAllStudents()).where((s) => !s.isArchived).toList();
    final now   = DateTime.now();
    // اليوم بدون وقت
    final today = DateTime(now.year, now.month, now.day);

    final entries = <_BirthdayEntry>[];
    for (final s in students) {
      if (s.birthDate == null) continue;
      final b = s.birthDate!;

      // أحسب تاريخ العيد السنة دي
      var next = DateTime(now.year, b.month, b.day);

      // لو العيد عدى (قبل اليوم الحالي) خليه السنة الجاية
      // نستخدم مقارنة الأيام فقط بدون وقت
      final diff = next.difference(today).inDays;
      if (diff < 0) {
        next = DateTime(now.year + 1, b.month, b.day);
      }

      final daysUntil = next.difference(today).inDays;

      // فقط من 0 لـ 7 أيام قادمة
      if (daysUntil >= 0 && daysUntil <= 7) {
        entries.add(_BirthdayEntry(
          student: s,
          nextBirthday: next,
          daysUntil: daysUntil,
        ));
      }
    }
    entries.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));

    if (mounted) {
      setState(() {
        _upcomingBirthdays = entries;
        _loadingBirthdays  = false;
      });
    }
  }

  Future<void> _scheduleAllBirthdayNotifications() async {
    setState(() => _schedulingAll = true);
    final granted =
        await _notificationService.requestPermission(requestExactAlarm: true);
    if (!granted) {
      if (mounted) {
        ToastHelper.error('صلاحية الإشعارات غير مفعلة', title: 'تنبيه');
      }
      setState(() => _schedulingAll = false);
      return;
    }

    for (final entry in _upcomingBirthdays) {
      await _notificationService.scheduleBirthdayNotifications(entry.student);
    }

    if (mounted) {
      setState(() => _schedulingAll = false);
      ToastHelper.success(
        'تم جدولة إشعارات ${_upcomingBirthdays.length} عيد ميلاد',
        title: '✓ تم الجدولة',
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.notifications_rounded), text: 'الإشعارات'),
            Tab(icon: Icon(Icons.cake_rounded), text: 'أعياد الميلاد'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(isDark),
          _buildBirthdaysTab(isDark),
        ],
      ),
    );
  }

  // ─── Tab 1: Notification settings ─────────────────────────────────────────

  Widget _buildNotificationsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // تحذير لو صلاحية "الجدولة الدقيقة" مش مفعّلة — من غيرها، كل
        // التذكيرات (حصص وأعياد ميلاد) بتفشل تظهر بصمت من غير أي رسالة
        // خطأ، فالمدرس بيفتكر التطبيق عطلان من غير ما يعرف السبب.
        if (_hasExactAlarm == false) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('صلاحية الجدولة الدقيقة غير مفعّلة',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'من غير الصلاحية دي، تذكيرات الحصص وأعياد الميلاد مش هتوصلك في ميعادها — دي صلاحية منفصلة عن إذن الإشعارات العادي.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      await _notificationService.requestPermission(requestExactAlarm: true);
                      await _checkExactAlarmPermission();
                    },
                    child: const Text('تفعيل الصلاحية', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildNotificationToggle(
          title: 'إشعارات أعياد الميلاد',
          subtitle: 'تنبيه يوم قبل عيد الميلاد وفي يوم العيد نفسه',
          value: _birthdayNotifications,
          onChanged: (v) => _onToggleChanged(type: 'birthday', value: v),
          icon: Icons.cake_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildNotificationToggle(
          title: 'إشعارات الحصص',
          subtitle: 'تنبيه بالحصص المجدولة لليوم',
          value: _classNotifications,
          onChanged: (v) => _onToggleChanged(type: 'class', value: v),
          icon: Icons.event_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildNotificationToggle(
          title: 'إشعارات الدفع المتأخر',
          subtitle: 'تنبيه بالطلاب المتأخرين في الدفع',
          value: _latePaymentNotifications,
          onChanged: (v) => _onToggleChanged(type: 'late_payment', value: v),
          icon: Icons.payment_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildAtRiskWeeklyNotifTile(isDark),
        const SizedBox(height: 24),
        _buildSectionTitle('اختبار الإشعارات', isDark),
        const SizedBox(height: 12),
        _buildTestButton(
          title: 'اختبار إشعار أعياد الميلاد',
          isDark: isDark,
          onTap: () async {
            final granted = await _notificationService.requestPermission();
            if (granted) {
              await _notificationService.showNotification(
                title: '🎂 عيد ميلاد تجريبي',
                body: 'هذا إشعار تجريبي لأعياد الميلاد',
              );
            } else {
              ToastHelper.error('صلاحية الإشعارات غير مفعلة', title: 'تنبيه');
            }
          },
          icon: Icons.cake_rounded,
        ),
        const SizedBox(height: 12),
        _buildTestButton(
          title: 'اختبار إشعار الحصص',
          isDark: isDark,
          onTap: () async {
            final granted = await _notificationService.requestPermission();
            if (granted) {
              await _notificationService.showNotification(
                title: '📚 حصة تجريبية',
                body: 'هذا إشعار تجريبي للحصص',
              );
            } else {
              ToastHelper.error('صلاحية الإشعارات غير مفعلة', title: 'تنبيه');
            }
          },
          icon: Icons.event_rounded,
        ),
      ],
    );
  }

  // ─── Tab 2: Upcoming birthdays ─────────────────────────────────────────────

  Widget _buildBirthdaysTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    if (_loadingBirthdays) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('جاري تحميل أعياد الميلاد...',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBirthdays,
      child: _upcomingBirthdays.isEmpty
          ? _buildEmptyBirthdays()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Header info + schedule all button
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFF97316), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_upcomingBirthdays.length} عيد ميلاد خلال الـ 7 أيام القادمة',
                              style: const TextStyle(
                                  color: Color(0xFFF97316),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'سيُرسل إشعار قبل كل عيد ميلاد بيوم والساعة 8 ص، وإشعار آخر في يوم العيد',
                        style: TextStyle(
                            color: Color(0xFFF97316), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _schedulingAll
                              ? null
                              : _scheduleAllBirthdayNotifications,
                          icon: _schedulingAll
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.notifications_active_rounded,
                                  size: 18),
                          label: Text(_schedulingAll
                              ? 'جاري الجدولة...'
                              : 'جدولة إشعارات الكل'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Birthday cards
                ...(_upcomingBirthdays.map((e) =>
                    _BirthdayCard(entry: e, cardBg: cardBg,
                        onSchedule: () async {
                      await _notificationService
                          .scheduleBirthdayNotifications(e.student);
                      if (mounted) {
                        ToastHelper.success(
                          'جُدول إشعار عيد ميلاد ${e.student.name}',
                          title: '✓ تم',
                        );
                      }
                    }))),
              ],
            ),
    );
  }

  Widget _buildEmptyBirthdays() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('لا توجد أعياد ميلاد خلال الأسبوع القادم',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('اسحب للأسفل للتحديث',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(title,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87));
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required bool isDark,
  }) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // spec 021 — إشعار أسبوعي ملخّص بعدد الطلاب المحتاجين متابعة. القيم
  // في SettingsController (Rx) بدل حالة محلية — عشان يوم/وقت الإرسال
  // يبقوا متاحين لـ NotificationService.scheduleWeeklyAtRiskDigest من
  // غير تكرار تخزين.
  Widget _buildAtRiskWeeklyNotifTile(bool isDark) {
    final settings = Get.find<SettingsController>();
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return Obx(() {
      final enabled = settings.atRiskWeeklyNotifEnabled.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إشعار محتاجين متابعة',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text('تذكير أسبوعي بعدد الطلاب المحتاجين متابعة',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (v) => settings.setAtRiskWeeklyNotif(enabled: v),
                  activeThumbColor: AppTheme.primaryColor,
                  activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: settings.atRiskWeeklyNotifDay.value,
                      isDense: true,
                      decoration: const InputDecoration(
                          labelText: 'اليوم', isDense: true),
                      items: _weekDayNames
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (d) {
                        if (d != null) settings.setAtRiskWeeklyNotif(day: d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                          '${settings.atRiskWeeklyNotifHour.value.toString().padLeft(2, '0')}'
                          ':${settings.atRiskWeeklyNotifMinute.value.toString().padLeft(2, '0')}'),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                              hour: settings.atRiskWeeklyNotifHour.value,
                              minute: settings.atRiskWeeklyNotifMinute.value),
                        );
                        if (t != null) {
                          settings.setAtRiskWeeklyNotif(
                              hour: t.hour, minute: t.minute);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildTestButton({
    required String title,
    required VoidCallback onTap,
    required IconData icon,
    required bool isDark,
  }) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.play_circle_rounded,
                color: AppTheme.primaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _BirthdayEntry {
  final Student student;
  final DateTime nextBirthday;
  final int daysUntil;
  const _BirthdayEntry(
      {required this.student,
      required this.nextBirthday,
      required this.daysUntil});
}

// ─── Birthday card widget ─────────────────────────────────────────────────────

class _BirthdayCard extends StatelessWidget {
  final _BirthdayEntry entry;
  final Color cardBg;
  final VoidCallback onSchedule;

  const _BirthdayCard(
      {required this.entry,
      required this.cardBg,
      required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    final isToday = entry.daysUntil == 0;
    final isTomorrow = entry.daysUntil == 1;
    final accent = isToday
        ? const Color(0xFFEF4444)
        : isTomorrow
            ? const Color(0xFFF97316)
            : const Color(0xFF6366F1);

    final dateStr = DateFormat('d MMMM', 'ar').format(entry.nextBirthday);
    final daysLabel = isToday
        ? '🎂 اليوم!'
        : isTomorrow
            ? '🎉 غداً'
            : 'بعد ${entry.daysUntil} أيام';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.student.name.isNotEmpty
                    ? entry.student.name[0]
                    : '?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.student.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(daysLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Schedule button
          IconButton(
            tooltip: 'جدولة الإشعار',
            onPressed: onSchedule,
            icon: Icon(Icons.notification_add_rounded,
                color: accent, size: 22),
          ),
        ],
      ),
    );
  }
}
