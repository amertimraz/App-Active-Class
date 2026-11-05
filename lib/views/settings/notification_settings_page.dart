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
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

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

  AppTokens get _t => Theme.of(context).brightness == Brightness.dark
      ? AppTokens.dark
      : AppTokens.light;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final t = _t;

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'مركز الإشعارات',
        bottom: TabBar(
          controller: _tabController,
          labelColor: t.boardInk,
          unselectedLabelColor: t.boardInkSoft,
          indicatorColor: t.chalk,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: AppType.label,
          unselectedLabelStyle: AppType.label,
          tabs: const [
            Tab(icon: Icon(Icons.notifications_rounded), text: 'الإشعارات'),
            Tab(icon: Icon(Icons.cake_rounded), text: 'أعياد الميلاد'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(),
          _buildBirthdaysTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Notification settings ─────────────────────────────────────────

  Widget _buildNotificationsTab() {
    final t = _t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xl + bottom),
      children: [
        // تحذير لو صلاحية "الجدولة الدقيقة" مش مفعّلة — من غيرها، كل
        // التذكيرات (حصص وأعياد ميلاد) بتفشل تظهر بصمت من غير أي رسالة
        // خطأ، فالمدرس بيفتكر التطبيق عطلان من غير ما يعرف السبب.
        if (_hasExactAlarm == false) ...[
          Container(
            padding: const EdgeInsets.all(AppSpace.md + 2),
            margin: const EdgeInsets.only(bottom: AppSpace.lg),
            decoration: BoxDecoration(
              color: t.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(color: t.danger.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_amber_rounded, color: t.danger, size: 22),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text('صلاحية الجدولة الدقيقة غير مفعّلة',
                        style: AppType.label.copyWith(color: t.danger)),
                  ),
                ]),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'من غير الصلاحية دي، تذكيرات الحصص وأعياد الميلاد مش هتوصلك في ميعادها — دي صلاحية منفصلة عن إذن الإشعارات العادي.',
                  // لون النص ثابت غامق: الخلفية الحمرا الفاتحة ثابتة في الوضعين.
                  style: AppType.body.copyWith(color: const Color(0xFF14172B)),
                ),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.control)),
                    ),
                    onPressed: () async {
                      await _notificationService.requestPermission(
                          requestExactAlarm: true);
                      await _checkExactAlarmPermission();
                    },
                    child: Text('تفعيل الصلاحية',
                        style: AppType.label.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
        _sectionTitle('التنبيهات'),
        _card(Column(children: [
          _buildNotificationToggle(
            title: 'إشعارات أعياد الميلاد',
            subtitle: 'تنبيه يوم قبل عيد الميلاد وفي يوم العيد نفسه',
            value: _birthdayNotifications,
            onChanged: (v) => _onToggleChanged(type: 'birthday', value: v),
            icon: Icons.cake_rounded,
            color: const Color(0xFFF97316),
          ),
          _divider(),
          _buildNotificationToggle(
            title: 'إشعارات الحصص',
            subtitle: 'تنبيه بالحصص المجدولة لليوم',
            value: _classNotifications,
            onChanged: (v) => _onToggleChanged(type: 'class', value: v),
            icon: Icons.event_rounded,
            color: const Color(0xFF3B82F6),
          ),
          _divider(),
          _buildNotificationToggle(
            title: 'إشعارات الدفع المتأخر',
            subtitle: 'تنبيه بالطلاب المتأخرين في الدفع',
            value: _latePaymentNotifications,
            onChanged: (v) => _onToggleChanged(type: 'late_payment', value: v),
            icon: Icons.payment_rounded,
            color: const Color(0xFF10B981),
          ),
          _divider(),
          _buildAtRiskWeeklyNotifTile(),
        ])),
        const SizedBox(height: AppSpace.xl - 4),
        _sectionTitle('اختبار الإشعارات'),
        _card(Column(children: [
          _buildTestButton(
            title: 'اختبار إشعار أعياد الميلاد',
            onTap: () async {
              final granted = await _notificationService.requestPermission();
              if (granted) {
                await _notificationService.showNotification(
                  title: '🎂 عيد ميلاد تجريبي',
                  body: 'هذا إشعار تجريبي لأعياد الميلاد',
                );
              } else {
                ToastHelper.error('صلاحية الإشعارات غير مفعلة',
                    title: 'تنبيه');
              }
            },
            icon: Icons.cake_rounded,
          ),
          _divider(),
          _buildTestButton(
            title: 'اختبار إشعار الحصص',
            onTap: () async {
              final granted = await _notificationService.requestPermission();
              if (granted) {
                await _notificationService.showNotification(
                  title: '📚 حصة تجريبية',
                  body: 'هذا إشعار تجريبي للحصص',
                );
              } else {
                ToastHelper.error('صلاحية الإشعارات غير مفعلة',
                    title: 'تنبيه');
              }
            },
            icon: Icons.event_rounded,
          ),
        ])),
      ],
    );
  }

  // ─── Tab 2: Upcoming birthdays ─────────────────────────────────────────────

  Widget _buildBirthdaysTab() {
    final t = _t;

    if (_loadingBirthdays) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: t.brand),
            const SizedBox(height: AppSpace.lg),
            Text('جاري تحميل أعياد الميلاد...',
                style: AppType.body.copyWith(color: t.inkFaint)),
          ],
        ),
      );
    }

    const orange = Color(0xFFF97316);
    return RefreshIndicator(
      onRefresh: _loadBirthdays,
      child: _upcomingBirthdays.isEmpty
          ? _buildEmptyBirthdays()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.xl + MediaQuery.paddingOf(context).bottom),
              children: [
                // ملخّص + زر جدولة الكل
                AppPanel(
                  padding: const EdgeInsets.all(AppSpace.md + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cake_rounded,
                              color: orange, size: 20),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              '${_upcomingBirthdays.length} عيد ميلاد خلال الـ 7 أيام القادمة',
                              style: AppType.label.copyWith(color: t.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xs + 2),
                      Text(
                        'سيُرسل إشعار قبل كل عيد ميلاد بيوم والساعة 8 ص، وإشعار آخر في يوم العيد',
                        style: AppType.body.copyWith(color: t.inkSoft),
                      ),
                      const SizedBox(height: AppSpace.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _schedulingAll
                              ? null
                              : _scheduleAllBirthdayNotifications,
                          icon: _schedulingAll
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.notifications_active_rounded,
                                  size: 18),
                          label: Text(_schedulingAll
                              ? 'جاري الجدولة...'
                              : 'جدولة إشعارات الكل'),
                          style: FilledButton.styleFrom(
                            backgroundColor: t.brand,
                            foregroundColor: _isDark ? t.board : Colors.white,
                            minimumSize: const Size(0, 48),
                            textStyle: AppType.label,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.control)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                ..._upcomingBirthdays.map((e) => _BirthdayCard(
                    entry: e,
                    onSchedule: () async {
                      await _notificationService
                          .scheduleBirthdayNotifications(e.student);
                      if (mounted) {
                        ToastHelper.success(
                          'جُدول إشعار عيد ميلاد ${e.student.name}',
                          title: '✓ تم',
                        );
                      }
                    })),
              ],
            ),
    );
  }

  Widget _buildEmptyBirthdays() {
    final t = _t;
    return ListView(
      // ListView عشان السحب للتحديث يشتغل حتى والقائمة فاضية.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(Icons.cake_rounded, size: 56, color: t.inkFaint),
        const SizedBox(height: AppSpace.lg),
        Text('لا توجد أعياد ميلاد خلال الأسبوع القادم',
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        Text('اسحب للأسفل للتحديث',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: t.inkFaint)),
      ],
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpace.sm),
        child: Text(title, style: AppType.label.copyWith(color: _t.ink)),
      );

  Widget _card(Widget child) {
    final t = _t;
    return Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: BorderSide(color: t.line),
      ),
      child: child,
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        indent: 16 + 36 + 12,
        color: _t.line,
      );

  Widget _icon(IconData icon, Color color) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Icon(icon, size: 20, color: color),
      );

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    final t = _t;
    return SizedBox(
      width: 44,
      height: 28,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStatePropertyAll(_isDark ? t.board : Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? t.brand
                  : t.inkFaint.withValues(alpha: 0.45)),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    final t = _t;
    return InkWell(
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _icon(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.label.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppType.caption.copyWith(color: t.inkFaint)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              _switch(value, onChanged),
            ],
          ),
        ),
      ),
    );
  }

  // spec 021 — إشعار أسبوعي ملخّص بعدد الطلاب المحتاجين متابعة. القيم
  // في SettingsController (Rx) بدل حالة محلية — عشان يوم/وقت الإرسال
  // يبقوا متاحين لـ NotificationService.scheduleWeeklyAtRiskDigest من
  // غير تكرار تخزين.
  Widget _buildAtRiskWeeklyNotifTile() {
    final settings = Get.find<SettingsController>();
    final t = _t;
    return Obx(() {
      final enabled = settings.atRiskWeeklyNotifEnabled.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNotificationToggle(
            title: 'إشعار محتاجين متابعة',
            subtitle: 'تذكير أسبوعي بعدد الطلاب المحتاجين متابعة',
            value: enabled,
            onChanged: (v) => settings.setAtRiskWeeklyNotif(enabled: v),
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444),
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  16 + 36 + 12, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: settings.atRiskWeeklyNotifDay.value,
                      isDense: true,
                      isExpanded: true,
                      style: AppType.label.copyWith(color: t.ink),
                      dropdownColor: t.surface,
                      decoration: const InputDecoration(
                          labelText: 'اليوم', isDense: true),
                      items: _weekDayNames
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (d) {
                        if (d != null) settings.setAtRiskWeeklyNotif(day: d);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: t.ink,
                        side: BorderSide(color: t.line),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.control)),
                      ),
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                          '${settings.atRiskWeeklyNotifHour.value.toString().padLeft(2, '0')}'
                          ':${settings.atRiskWeeklyNotifMinute.value.toString().padLeft(2, '0')}'),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                              hour: settings.atRiskWeeklyNotifHour.value,
                              minute: settings.atRiskWeeklyNotifMinute.value),
                        );
                        if (picked != null) {
                          settings.setAtRiskWeeklyNotif(
                              hour: picked.hour, minute: picked.minute);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _buildTestButton({
    required String title,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final t = _t;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _icon(icon, t.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: AppType.label.copyWith(color: t.ink)),
              ),
              Icon(Icons.play_circle_outline_rounded,
                  color: t.inkSoft, size: 24),
            ],
          ),
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
  final VoidCallback onSchedule;

  const _BirthdayCard({required this.entry, required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isToday = entry.daysUntil == 0;
    final isTomorrow = entry.daysUntil == 1;
    final accent = isToday
        ? t.danger
        : isTomorrow
            ? t.caution
            : t.brand;

    final dateStr = DateFormat('d MMMM', 'ar').format(entry.nextBirthday);
    final daysLabel = isToday
        ? '🎂 اليوم!'
        : isTomorrow
            ? '🎉 غداً'
            : 'بعد ${entry.daysUntil} أيام';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm + 2),
      child: AppPanel(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md + 2, vertical: AppSpace.md),
        lineColor: isToday ? accent.withValues(alpha: 0.5) : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  entry.student.name.isNotEmpty ? entry.student.name[0] : '?',
                  style: AppType.title.copyWith(color: accent),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.student.name,
                      style: AppType.label.copyWith(color: t.ink)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(dateStr,
                          style: AppType.caption.copyWith(color: t.inkFaint)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(daysLabel,
                            style: AppType.caption.copyWith(
                                fontWeight: FontWeight.w700, color: accent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'جدولة الإشعار',
              onPressed: onSchedule,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(Icons.notification_add_rounded,
                  color: t.inkSoft, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
