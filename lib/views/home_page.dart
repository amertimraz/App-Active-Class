import 'dart:async';
import 'dart:io';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/views/license/trial_banner.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/locked_feature.dart';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/update_dialog.dart';
import 'package:active_class/services/in_app_update_service.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final DashboardController _dashboardController =
      Get.put(DashboardController());
  final SettingsController _settingsController = Get.find<SettingsController>();
  bool _statsVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // DashboardController مسجّل كـ singleton — Get.put() فوق بيرجع نفس
    // النسخة القديمة (بأرقامها المحفوظة في الذاكرة) لو الصفحة اتفتحت
    // قبل كده، مش نسخة جديدة تعيد التحميل من قاعدة البيانات تلقائيًا.
    // من غير السطر ده، أي حاجة بتغيّر قاعدة البيانات من بره الصفحة دي
    // (زي مسح بيانات الفريق عند تعطيله) هتفضل مش ظاهرة في الأرقام لحد
    // ما حد يضغط زرار التحديث يدويًا.
    _dashboardController.loadDashboardData();
    // فحص التحديث بهدوء بعد ما الداشبورد يخلص رسم — ميتقفلش استخدام
    // التطبيق ولا يظهر أي حاجة لو مفيش تحديث أو لو الفحص فشل.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        checkAndShowUpdateDialog(context);
        InAppUpdateService.checkAndPrompt(context);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند العودة من الخلفية → تحديث تلقائي
    if (state == AppLifecycleState.resumed) {
      _dashboardController.loadDashboardData();
    }
  }

  List<_DashboardMenuItem> get _menuEntries {
    final team = TeamModeService();
    return [
      _DashboardMenuItem(
        icon: Icons.groups_rounded,
        label: 'المجموعات',
        color: const Color(0xFFFF4D7A),
        onTap: () => Get.toNamed(ROUTE_GROUPS),
      ),
      _DashboardMenuItem(
        icon: Icons.person_rounded,
        label: 'الطلاب',
        color: const Color(0xFF23A6F0),
        onTap: () => Get.toNamed(ROUTE_STUDENTS),
      ),
      _DashboardMenuItem(
        icon: Icons.how_to_reg_rounded,
        label: 'الحضور',
        color: const Color(0xFFFFA31A),
        onTap: () => Get.toNamed(ROUTE_ATTENDANCE),
      ),
      _DashboardMenuItem(
        icon: Icons.calendar_month_rounded,
        label: 'جدول الحصص',
        color: const Color(0xFF14B8A6),
        onTap: () => Get.toNamed(ROUTE_SCHEDULE),
      ),
      _DashboardMenuItem(
        icon: Icons.payments_rounded,
        label: 'المدفوعات',
        color: const Color(0xFF5B67F1),
        locked: !team.canSeeFinancials,
        onTap: () => team.canSeeFinancials
            ? Get.toNamed(ROUTE_PAYMENTS)
            : showLockedPermissionHint(),
      ),
      _DashboardMenuItem(
        icon: Icons.receipt_long_rounded,
        label: 'التقارير',
        color: const Color(0xFF8B5CF6),
        locked: !team.canSeeFinancials,
        onTap: () => team.canSeeFinancials
            ? Get.toNamed(ROUTE_REPORTS)
            : showLockedPermissionHint(),
      ),
      _DashboardMenuItem(
        icon: Icons.qr_code_2_rounded,
        label: 'مكتبة QR',
        color: const Color(0xFF10B981),
        onTap: () => Get.toNamed(ROUTE_QR_GALLERY),
      ),
      _DashboardMenuItem(
        icon: Icons.assignment_rounded,
        label: 'الامتحانات',
        color: const Color(0xFFEF4444),
        locked: !team.canSeeAcademics,
        onTap: () => team.canSeeAcademics
            ? Get.toNamed(ROUTE_EXAMS)
            : showLockedPermissionHint(),
      ),
      _DashboardMenuItem(
        icon: Icons.event_available_rounded,
        label: 'الحجوزات',
        color: const Color(0xFF0EA5E9),
        onTap: () => Get.toNamed(ROUTE_BOOKINGS),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF08101F),
                          Color(0xFF10192F),
                          Color(0xFF121A2D),
                        ]
                      : const [
                          Color(0xFFFDFDFF),
                          Color(0xFFF7F8FF),
                          Color(0xFFEEF4FF),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          _buildBackgroundGlow(
            top: -110,
            right: -80,
            size: 250,
            colors: isDark
                ? const [Color(0x334F46E5), Color(0x004F46E5)]
                : const [Color(0x55F9A8D4), Color(0x00F9A8D4)],
          ),
          _buildBackgroundGlow(
            top: 260,
            left: -100,
            size: 220,
            colors: isDark
                ? const [Color(0x3322C55E), Color(0x0022C55E)]
                : const [Color(0x55BFDBFE), Color(0x00BFDBFE)],
          ),
          _buildBackgroundGlow(
            bottom: 120,
            right: -90,
            size: 280,
            colors: isDark
                ? const [Color(0x33E879F9), Color(0x00E879F9)]
                : const [Color(0x55DDD6FE), Color(0x00DDD6FE)],
          ),
          SafeArea(
            child: Column(
              children: [
                const TrialBanner(),
                _buildAppBar(),
                _buildQuickActionsPinned(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _dashboardController.loadDashboardData(),
                    color: AppTheme.primaryColor,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildStatsGrid()),
                        SliverToBoxAdapter(child: _buildMainMenuGrid()),
                        SliverToBoxAdapter(child: _buildRecentActivity()),
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => _AppBarIcon(
              icon: Icons.menu_rounded,
              isDark: isDark,
              onTap: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset('assets/icon/logo.png',
                          width: 22, height: 22),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      APP_NAME,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _AppBarIcon(
                icon: Icons.search_rounded,
                isDark: isDark,
                onTap: () => showSearch(
                  context: context,
                  delegate: StudentSearchDelegate(),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final tc = Get.find<ThemeController>();
                return _AppBarIcon(
                  icon: tc.isDarkMode.value
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  isDark: isDark,
                  onTap: () => tc.setTheme(!tc.isDarkMode.value),
                );
              }),
              const SizedBox(width: 8),
              _AppBarIcon(
                icon: Icons.settings_rounded,
                isDark: isDark,
                onTap: () => Get.toNamed(ROUTE_SETTINGS),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenuGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'الأقسام الرئيسية',
            isDark: isDark,
          ),
          Obx(() {
            final entries = _menuEntries;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final item = entries[index];
                return _MenuGridItem(
                  icon: item.icon,
                  label: item.label,
                  color: item.color,
                  onTap: item.onTap,
                  locked: item.locked,
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPinned() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Obx(() {
        final team = TeamModeService();
        final isAssistant = team.isEnabled.value && !team.isOwner.value;

        // المساعد بيشتغل على بروفايل المدرس نفسه محليًا (نفس بيانات
        // الحساب اللي هو داخل عليه)، فمينفعش نوريه "أهلا مستر [اسمه
        // هو]" وكأنه المدرس — نستخدم بدل كده اسم/جنس المدرس الحقيقي
        // اللي وصلنا من الفريق، ونوضح إنه مساعد.
        final ownerName = team.ownerTeacherName.value?.trim() ?? '';
        final teacherName = isAssistant
            ? ownerName
            : _settingsController.teacherFullName.value.trim();
        final teacherAvatar =
            _settingsController.teacherAvatarPath.value.trim();
        final genderSource = isAssistant
            ? team.ownerTeacherGender.value
            : _settingsController.teacherGender.value;
        final title = genderSource == 'female' ? 'مس' : 'مستر';
        final isFemale = genderSource == 'female';
        final displayName = teacherName.isNotEmpty ? teacherName : 'المعلم';

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131D31).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.92),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFFD8E0F0).withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── بطاقة المعلم ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    // الصورة الرمزية
                    _buildTeacherAvatar(
                      radius: 22,
                      isDark: isDark,
                      avatarPath: teacherAvatar,
                      isFemale: isFemale,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAssistant
                                ? 'مساعد $title $displayName'
                                : 'أهلا $title $displayName',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : const Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatFullDate(DateTime.now()),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_rounded,
                                  size: 11,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : const Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              _LiveClock(isDark: isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // إشارة الجنس
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isFemale
                                ? const Color(0xFFE91E8C)
                                : const Color(0xFF4F46E5))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isFemale ? Icons.female_rounded : Icons.male_rounded,
                        size: 18,
                        color: isFemale
                            ? const Color(0xFFE91E8C)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
              // فاصل
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF1F3F9),
              ),
              // ── أزرار الإجراءات السريعة ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'تسجيل حضور',
                        color: AppTheme.successColor,
                        onTap: () => Get.toNamed(ROUTE_QR_SCANNER_ATTENDANCE),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LockBadge(
                        locked: !team.canSeeFinancials,
                        child: _QuickActionButton(
                          icon: Icons.payment_rounded,
                          label: 'تسجيل دفع',
                          color: const Color(0xFFF59E0B),
                          onTap: () => team.canSeeFinancials
                              ? Get.toNamed(ROUTE_QR_SCANNER_PAYMENT)
                              : showLockedPermissionHint(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.person_add_rounded,
                        label: 'إضافة طالب',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => showAddStudentSheet(
                          context,
                          controller: Get.put(StudentController()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStatsGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeader(title: 'ملخص سريع', isDark: isDark),
              ),
              // زر تحديث
              Obx(() => _dashboardController.isLoading.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: _dashboardController.loadDashboardData,
                      child: Icon(Icons.refresh_rounded,
                          size: 18,
                          color:
                              isDark ? Colors.white38 : Colors.grey.shade500),
                    )),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _statsVisible = !_statsVisible),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _statsVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    key: ValueKey(_statsVisible),
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Obx(() {
            final canSeeFinancials = TeamModeService().canSeeFinancials;
            final currency = _settingsController.currencyCode.value;
            final paid = _dashboardController.monthPaid.value;
            final expected = _dashboardController.monthExpected.value;
            final rate = _dashboardController.monthPaymentRate.value;
            final paidCount = _dashboardController.paidStudentsCount.value;
            final unpaidCount = _dashboardController.unpaidStudentsCount.value;
            final exempt = _dashboardController.exemptStudents.value;
            final present = _dashboardController.todayPresent.value;
            final absent = _dashboardController.todayAbsent.value;
            final todayExpected = _dashboardController.todayExpected.value;
            final attRate = _dashboardController.todayAttendanceRate.value;
            final sessionRevenue =
                _dashboardController.todaySessionRevenue.value;
            final sessionRevenueCount =
                _dashboardController.todaySessionRevenueCount.value;
            final sessionRevenueExpected =
                _dashboardController.todaySessionRevenueExpected.value;
            final sessionRevenueExpectedCount =
                _dashboardController.todaySessionRevenueExpectedCount.value;
            final todayPaymentsTotal =
                _dashboardController.todayPaymentsTotal.value;
            final todayPaymentsCount =
                _dashboardController.todayPaymentsCount.value;

            String fmtMoney(double v) => v >= 1000
                ? '${(v / 1000).toStringAsFixed(1)}k $currency'
                : '${v.toStringAsFixed(0)} $currency';

            return Column(
              children: [
                // ── صف 1: مجموعات / طلاب / معفيين ──
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.groups_rounded,
                        value: _statsVisible
                            ? _dashboardController.totalGroups.value.toString()
                            : '••',
                        label: 'المجموعات',
                        gradient: const [Color(0xFFFF4D7A), Color(0xFFFF6B9D)],
                        onTap: () => Get.toNamed(ROUTE_GROUPS),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_rounded,
                        value: _statsVisible
                            ? _dashboardController.totalStudents.value
                                .toString()
                            : '••',
                        label: 'الطلاب',
                        gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        onTap: () => Get.toNamed(ROUTE_STUDENTS),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.card_giftcard_rounded,
                        value: _statsVisible ? '$exempt' : '••',
                        label: 'معفيون',
                        gradient: const [Color(0xFF2E7D32), Color(0xFF43A047)],
                        onTap: () => _showStudentsListDialog(context, isDark,
                            exemptOnly: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── صف 2: بار الدفع الشهري ──
                LockBadge(
                  locked: !canSeeFinancials,
                  child: _PaymentProgressCard(
                    paid: paid,
                    expected: expected,
                    rate: rate,
                    paidCount: paidCount,
                    unpaidCount: unpaidCount,
                    locked: !canSeeFinancials,
                    fmtPaid: !canSeeFinancials
                        ? '🔒'
                        : (_statsVisible ? fmtMoney(paid) : '••••'),
                    fmtExpected: !canSeeFinancials
                        ? '🔒'
                        : (_statsVisible ? fmtMoney(expected) : '••••'),
                    onTapUnpaid: canSeeFinancials
                        ? () => _showUnpaidSheet(context)
                        : showLockedPermissionHint,
                  ),
                ),
                const SizedBox(height: 8),
                // ── صف 3: حضور اليوم + مدفوعات اليوم جنب بعض ──
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _AttendanceCard(
                          present: present,
                          absent: absent,
                          expected: todayExpected,
                          rate: attRate,
                          visible: _statsVisible,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LockBadge(
                          locked: !canSeeFinancials,
                          child: _TodayPaymentsCard(
                            total: todayPaymentsTotal,
                            count: todayPaymentsCount,
                            locked: !canSeeFinancials,
                            fmtTotal: !canSeeFinancials
                                ? '🔒'
                                : (_statsVisible
                                    ? fmtMoney(todayPaymentsTotal)
                                    : '••••'),
                            onTap: !canSeeFinancials
                                ? showLockedPermissionHint
                                : (todayPaymentsCount == 0
                                    ? null
                                    : () => _showTodayPaymentsSheet(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (sessionRevenue > 0 || sessionRevenueExpected > 0) ...[
                  const SizedBox(height: 8),
                  // ── هنت: إيراد اليوم من المجموعات بالحصة (فعلي + متوقع) ──
                  LockBadge(
                    locked: !canSeeFinancials,
                    child: _SessionRevenueHint(
                      locked: !canSeeFinancials,
                      actualLabel: !canSeeFinancials
                          ? '🔒'
                          : (_statsVisible ? fmtMoney(sessionRevenue) : '••••'),
                      actualCount: sessionRevenueCount,
                      expectedLabel: !canSeeFinancials
                          ? '🔒'
                          : (_statsVisible
                              ? fmtMoney(sessionRevenueExpected)
                              : '••••'),
                      expectedCount: sessionRevenueExpectedCount,
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final all = _dashboardController.recentActivities;
      final isLoading = _dashboardController.isLoading.value;
      final lastUpdate = _dashboardController.lastUpdated.value;

      if (isLoading && all.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildActivitySkeleton(isDark),
        );
      }

      if (all.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildEmptyState(),
        );
      }

      final canSeeFinancials = TeamModeService().canSeeFinancials;
      final attendance =
          all.where((a) => a.type == ActivityType.attendance).take(3).toList();
      final payments =
          all.where((a) => a.type == ActivityType.payment).take(3).toList();

      // وقت آخر تحديث
      final diff = DateTime.now().difference(lastUpdate);
      final updLabel = diff.inSeconds < 60
          ? 'الآن'
          : diff.inMinutes < 60
              ? 'منذ ${diff.inMinutes} د'
              : 'منذ ${diff.inHours} س';

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header مع "آخر تحديث"
            Row(children: [
              _SectionHeader(title: 'النشاط الأخير', isDark: isDark),
              const Spacer(),
              Icon(Icons.update_rounded,
                  size: 12,
                  color: isDark ? Colors.white30 : Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(updLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white30 : Colors.grey.shade400)),
            ]),
            if (attendance.isNotEmpty) ...[
              _buildActivityGroup(
                isDark,
                title: 'آخر الحضور',
                icon: Icons.how_to_reg_rounded,
                color: AppTheme.successColor,
                items: attendance,
                onMore: () => Get.toNamed(ROUTE_ATTENDANCE),
              ),
              const SizedBox(height: 14),
            ],
            if (payments.isNotEmpty)
              canSeeFinancials
                  ? _buildActivityGroup(
                      isDark,
                      title: 'آخر المدفوعات',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF4F46E5),
                      items: payments,
                      onMore: () => Get.toNamed(ROUTE_PAYMENTS),
                    )
                  : _buildLockedActivityGroup(
                      isDark,
                      title: 'آخر المدفوعات',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF4F46E5),
                    ),
          ],
        ),
      );
    });
  }

  Widget _buildActivitySkeleton(bool isDark) {
    final base = isDark ? const Color(0xFF1E2D45) : const Color(0xFFEEF0F5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
          3,
          (i) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 64,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(22),
                ),
              )),
    );
  }

  Widget _buildActivityGroup(
    bool isDark, {
    required String title,
    required IconData icon,
    required Color color,
    required List<RecentActivity> items,
    required VoidCallback onMore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'عرض الكل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((a) => _ActivityItem(activity: a)),
      ],
    );
  }

  /// نفس شكل _buildActivityGroup (العنوان بارز)، بس بدل عرض الصفوف
  /// الحقيقية (اسم الطالب + المبلغ) بنعرض كارت مقفول واحد — القسم يفضل
  /// موجود وواضح إنه فيه نشاط، بس التفاصيل الفعلية مخفية.
  Widget _buildLockedActivityGroup(
    bool isDark, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: showLockedPermissionHint,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF131D31).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الصلاحية دي مقفولة من المدرس',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131D31).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.92),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0xFFD8E0F0).withValues(alpha: 0.5),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 34,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد عمليات حديثة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      child: Column(
        children: [
          Obx(() {
            final team = TeamModeService();
            final isAssistant = team.isEnabled.value && !team.isOwner.value;
            final ownerName = team.ownerTeacherName.value?.trim() ?? '';
            final teacherName = isAssistant
                ? ownerName
                : _settingsController.teacherFullName.value.trim();
            final teacherAvatar =
                _settingsController.teacherAvatarPath.value.trim();
            final genderSource = isAssistant
                ? team.ownerTeacherGender.value
                : _settingsController.teacherGender.value;
            final isFemale = genderSource == 'female';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                bottom: 24,
                left: 18,
                right: 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
                      : const [Color(0xFFEEF2FF), Color(0xFFF8FAFF)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeacherAvatar(
                    radius: 34,
                    isDark: isDark,
                    avatarPath: teacherAvatar,
                    isFemale: isFemale,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    teacherName.isNotEmpty ? teacherName : 'المعلم',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAssistant
                        ? 'مساعد في تطبيق المدرس'
                        : 'تنقل سريع بين أهم صفحات التطبيق',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.62)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            );
          }),
          Expanded(
            child: Obx(() {
              final team = TeamModeService();
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    title: 'الرئيسية',
                    isSelected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: Icons.groups_rounded,
                    title: 'المجموعات',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_GROUPS);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_rounded,
                    title: 'الطلاب',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_STUDENTS);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.payments_rounded,
                    title: 'المدفوعات',
                    locked: !team.canSeeFinancials,
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_PAYMENTS);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.how_to_reg_rounded,
                    title: 'الحضور',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_ATTENDANCE);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'جدول الحصص',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_SCHEDULE);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.assessment_rounded,
                    title: 'التقارير',
                    locked: !team.canSeeFinancials,
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_REPORTS);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.qr_code_2_rounded,
                    title: 'مكتبة QR',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_QR_GALLERY);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.event_available_rounded,
                    title: 'الحجوزات',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_BOOKINGS);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'الإعدادات',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_SETTINGS);
                    },
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherAvatar({
    required double radius,
    required bool isDark,
    required String avatarPath,
    bool isFemale = false,
  }) {
    if (avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : (isFemale
                    ? const Color(0xFFFCE4F0)
                    : const Color(0xFFEEF2FF)),
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundImage: FileImage(file),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : (isFemale ? const Color(0xFFFCE4F0) : const Color(0xFFEEF2FF)),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: isDark ? const Color(0xFF1F2A44) : Colors.white,
        child: Icon(
          isFemale ? Icons.face_3_rounded : Icons.face_rounded,
          size: radius * 1.1,
          color: isFemale ? const Color(0xFFE91E8C) : const Color(0xFF4F46E5),
        ),
      ),
    );
  }

  void _showUnpaidSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = _dashboardController.unpaidList;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'لم يدفعوا هذا الشهر (${students.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: students.length,
                itemBuilder: (_, i) {
                  final entry = students[i];
                  final s = entry.student;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFFEF4444).withValues(alpha: 0.1),
                      child: Text(
                        s.name.trim().isNotEmpty ? s.name.trim()[0] : '?',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.code),
                    trailing: Text(
                      entry.amountDue.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: s);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTodayPaymentsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = _settingsController.currencyCode.value;
    final entries = _dashboardController.todayPaymentsList;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'مدفوعات اليوم (${entries.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF10B981).withValues(alpha: 0.1),
                      child: Text(
                        e.studentName.trim().isNotEmpty
                            ? e.studentName.trim()[0]
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(e.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e.studentCode} • ${e.groupName}'),
                    trailing: Text(
                      '${e.amount.toStringAsFixed(0)} $currency',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double size,
    required List<Color> colors,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'إبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const weekdays = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];

    return '${weekdays[date.weekday % 7]}، ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _AppBarIcon({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131D31).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.16)
                    : const Color(0xFFD9E1F2).withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : const Color(0xFF111827),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131D31).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.88),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.16)
                    : color.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════
//  _LiveClock — ساعة حية تتحدث كل ثانية
// ══════════════════════════════════════════════════════════════════
class _LiveClock extends StatefulWidget {
  final bool isDark;
  const _LiveClock({required this.isDark});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return Text(
      '$h:$m:$s',
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: widget.isDark ? Colors.grey[400] : const Color(0xFF64748B),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

//  _AttendanceCard — بطاقة حضور اليوم
// ══════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════
//  _SessionRevenueHint — هنت إيراد اليوم من المجموعات المسعّرة بالحصة
// ══════════════════════════════════════════════════════════════════
class _SessionRevenueHint extends StatelessWidget {
  final String actualLabel;
  final int actualCount;
  final String expectedLabel;
  final int expectedCount;
  final bool locked;

  const _SessionRevenueHint({
    required this.actualLabel,
    required this.actualCount,
    required this.expectedLabel,
    required this.expectedCount,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                'إيراد اليوم من المجموعات بالحصة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RevenueMiniStat(
                  label: locked
                      ? 'محصّل فعليًا'
                      : 'محصّل فعليًا ($actualCount دفعة)',
                  value: actualLabel,
                  color: color,
                ),
              ),
              if (locked || expectedCount > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _RevenueMiniStat(
                    label: locked
                        ? 'متوقع اليوم'
                        : 'متوقع اليوم ($expectedCount طالب)',
                    value: expectedLabel,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RevenueMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final int present;
  final int absent;
  final int expected;
  final double rate;
  final bool visible;

  const _AttendanceCard({
    required this.present,
    required this.absent,
    required this.expected,
    required this.rate,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (rate * 100).toInt();

    // لو مفيش مجموعات اليوم يبان باللون المحايد
    final barColor = expected == 0
        ? const Color(0xFF6366F1)
        : rate >= 0.8
            ? const Color(0xFF10B981)
            : rate >= 0.5
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Get.toNamed(ROUTE_ATTENDANCE),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D31) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.how_to_reg_rounded, size: 16, color: barColor),
                  const SizedBox(width: 6),
                  Text(
                    'حضور اليوم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      expected == 0 ? '—' : '$pct%',
                      style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: expected == 0 ? 0 : rate.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _AttStat(
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF10B981),
                    label: visible ? '$present حضر' : '••',
                  ),
                  _AttStat(
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                    label: visible ? '$absent غاب' : '••',
                  ),
                  Text(
                    expected == 0
                        ? 'لا مجموعات اليوم'
                        : (visible ? 'من $expected طالب' : '••'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayPaymentsCard extends StatelessWidget {
  final double total;
  final int count;
  final String fmtTotal;
  final VoidCallback? onTap;
  final bool locked;

  const _TodayPaymentsCard({
    required this.total,
    required this.count,
    required this.fmtTotal,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF10B981);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_rounded, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'مدفوعات اليوم',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_left_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              fmtTotal,
              style: const TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              locked
                  ? 'مقفول'
                  : (count == 0 ? 'لا يوجد مدفوعات بعد' : '$count دفعة اليوم'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _AttStat(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 11, color: color)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  _PaymentProgressCard — بار تقدم الدفع الشهري
// ══════════════════════════════════════════════════════════════════
class _PaymentProgressCard extends StatelessWidget {
  const _PaymentProgressCard({
    required this.paid,
    required this.expected,
    required this.rate,
    required this.paidCount,
    required this.unpaidCount,
    required this.fmtPaid,
    required this.fmtExpected,
    required this.onTapUnpaid,
    this.locked = false,
  });

  final double paid, expected, rate;
  final int paidCount, unpaidCount;
  final String fmtPaid, fmtExpected;
  final VoidCallback onTapUnpaid;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131D31) : Colors.white;
    final pct = (rate * 100).toInt();

    // لو مقفول، الأرقام كلها (النسبة/البار/عدد اللي لسه ما دفعوش) لازم
    // تتقفل مع بعض — مش بس نص المبلغ. عرض المبلغ مقفول والباقي فاضح
    // نفس المعلومة بطريقة غير مباشرة (شكل البار، لونه، النسبة).
    final barColor = locked
        ? (isDark ? Colors.white24 : Colors.grey.shade400)
        : (rate >= 0.8
            ? const Color(0xFF10B981)
            : rate >= 0.5
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: barColor),
              const SizedBox(width: 6),
              Text(
                'دفعات ${_arabicMonth(DateTime.now().month)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  locked ? '🔒' : '$pct%',
                  style: TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: locked ? 0 : rate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtPaid,
                      style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'من $fmtExpected',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // "لم يدفع" badge — قابل للضغط
              if (locked)
                GestureDetector(
                  onTap: onTapUnpaid,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.grey)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: (isDark ? Colors.white24 : Colors.grey)
                              .withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 13,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'مقفول',
                          style: TextStyle(
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (unpaidCount > 0)
                GestureDetector(
                  onTap: onTapUnpaid,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          '$unpaidCount لم يدفع',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'الكل دفع ✓',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _arabicMonth(int month) {
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return months[month.clamp(1, 12)];
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131D31).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.88),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.16)
                : gradient.first.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: gradient.first.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: gradient.first, size: 15),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = LinearGradient(colors: gradient)
                    .createShader(const Rect.fromLTWH(0, 0, 200, 0)),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: card,
    );
  }
}

class _MenuGridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  const _MenuGridItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LockBadge(locked: locked, child: _buildCard(isDark));
  }

  Widget _buildCard(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131D31).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.92),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF101828),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final RecentActivity activity;

  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131D31).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.14)
                : activity.color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(activity.icon, color: activity.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                if (activity.type == ActivityType.payment &&
                    activity.amount != null)
                  CurrencyText(
                    activity.amount,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  )
                else
                  Text(
                    activity.subtitle,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            activity.timeLabel,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final bool locked;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.grey[400] : AppTheme.textSecondary),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark ? Colors.white : AppTheme.textPrimary),
            ),
          ),
          trailing: locked
              ? Icon(Icons.lock_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.grey.shade500)
              : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: locked ? showLockedPermissionHint : onTap,
        ),
      ),
    );
  }
}

class _DashboardMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  const _DashboardMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.locked = false,
  });
}

class StudentSearchDelegate extends SearchDelegate<Student?> {
  @override
  String get searchFieldLabel => 'ابحث بالاسم أو الكود...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('اكتب اسم الطالب أو الكود للبحث'));
    }

    return FutureBuilder<List<Student>>(
      future: DatabaseService().getAllStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }

        final results = (snapshot.data ?? [])
            .where(
              (student) =>
                  student.name.toLowerCase().contains(query.toLowerCase()) ||
                  student.code.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

        if (results.isEmpty) {
          return const Center(child: Text('لا توجد نتائج مطابقة'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final student = results[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(student.name),
              subtitle: Text('الكود: ${student.code}'),
              onTap: () {
                close(context, student);
                Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: student);
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// كارت "معفيون" في الملخص السريع — قائمة الطلاب المعفيين باسمهم ومجموعتهم
// وكودهم ونسبة إعفائهم. (كارتي "المجموعات" و"الطلاب" بيودّوا لصفحاتهم
// الأصلية مباشرة زي اختصارات الأقسام الرئيسية، مش لازمة لموديل هنا).
// ─────────────────────────────────────────────────────────────────────────────
void _showStudentsListDialog(BuildContext context, bool isDark,
    {required bool exemptOnly}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(exemptOnly ? 'الطلاب المعفيون' : 'كل الطلاب'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder(
          future: Future.wait([
            DatabaseService().getAllStudents(),
            DatabaseService().getAllGroups()
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final allStudents = snapshot.data![0] as List<Student>;
            final groups = snapshot.data![1] as List<Group>;
            final groupNameById = {for (final g in groups) g.id: g.name};
            final students = allStudents
                .where((s) => !exemptOnly || s.isExempt)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            if (students.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Text(exemptOnly ? 'لا يوجد طلاب معفيون' : 'لا يوجد طلاب'),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = students[i];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    s.isExempt
                        ? Icons.volunteer_activism_rounded
                        : Icons.person_outline_rounded,
                    color: s.isExempt ? Colors.orange : const Color(0xFF4F46E5),
                    size: 20,
                  ),
                  title: Text(s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${groupNameById[s.groupId] ?? '—'} • كود: ${s.code}'),
                  trailing: s.isExempt
                      ? Text('إعفاء ${s.exemptPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange))
                      : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ),
  );
}
