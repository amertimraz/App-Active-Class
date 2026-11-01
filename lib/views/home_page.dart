import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:active_class/views/web/web_session.dart';
import 'package:active_class/utils/responsive.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/controllers/at_risk_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/views/license/trial_banner.dart';
import 'package:active_class/views/license/portal_expiry_banner.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/locked_feature.dart';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/update_dialog.dart';
import 'package:active_class/services/in_app_update_service.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/services/auto_absent_service.dart';
import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/widgets/announcement_slot.dart';
import 'package:active_class/widgets/announcement_popup.dart';
import 'package:active_class/widgets/rate_prompt_dialog.dart';
import 'package:active_class/services/rate_prompt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // spec 021 — مسجّل من هنا (أول شاشة بتتفتح) عشان عدّاد "محتاجين
  // متابعة" يفضل حيّ حتى قبل ما المدرس يفتح الشاشة المخصّصة بنفسه.
  final AtRiskController _atRiskController = Get.put(AtRiskController());
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
    unawaited(RatePromptService.instance.registerLaunch());
    // spec 046 — الغياب التلقائي بعد انتهاء الحصة (بيرجع فورًا لو الإعداد مطفي).
    AutoAbsentService.instance.start();
    // فحص التحديث بهدوء بعد ما الداشبورد يخلص رسم — ميتقفلش استخدام
    // التطبيق ولا يظهر أي حاجة لو مفيش تحديث أو لو الفحص فشل.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        // spec 055: فحص التحديث/المتجر مخصوص لأندرويد — على الويب بيرمي أخطاء.
        if (kIsWeb) return;
        checkAndShowUpdateDialog(context);
        InAppUpdateService.checkAndPrompt(context);
      });
      // spec 054 — نافذة إعلان الأدمن (مرة لكل إصدار)، بعد حوار التحديث.
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        unawaited(maybeShowAnnouncementPopup(context));
      });
      // نافذة تقييم Google Play بعد استخدام فعلي — بتتخطّى لو فيه حوار فوق.
      Future.delayed(const Duration(seconds: 9), () {
        if (!mounted || kIsWeb) return;
        unawaited(maybeShowRatePrompt(context));
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AutoAbsentService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند العودة من الخلفية → تحديث تلقائي
    if (state == AppLifecycleState.resumed) {
      _dashboardController.loadDashboardData();
      _atRiskController.refresh();
      unawaited(AutoAbsentService.instance.runOnce());
    }
  }

  List<_DashboardMenuItem> get _menuEntries {
    final team = TeamModeService();
    return [
      _DashboardMenuItem(
        icon: Icons.groups_rounded,
        label: 'المجموعات',
        onTap: () => Get.toNamed(ROUTE_GROUPS),
      ),
      _DashboardMenuItem(
        icon: Icons.person_rounded,
        label: 'الطلاب',
        onTap: () => Get.toNamed(ROUTE_STUDENTS),
      ),
      _DashboardMenuItem(
        icon: Icons.how_to_reg_rounded,
        label: 'الحضور',
        onTap: () => Get.toNamed(ROUTE_ATTENDANCE),
      ),
      _DashboardMenuItem(
        icon: Icons.calendar_month_rounded,
        label: 'جدول الحصص',
        onTap: () => Get.toNamed(ROUTE_SCHEDULE),
      ),
      _DashboardMenuItem(
        icon: Icons.payments_rounded,
        label: 'المدفوعات',
        locked: !team.canSeeFinancials,
        onTap: () => team.canSeeFinancials
            ? Get.toNamed(ROUTE_PAYMENTS)
            : showLockedPermissionHint(),
      ),
      _DashboardMenuItem(
        icon: Icons.menu_book_rounded,
        label: 'الملازم',
        onTap: () => Get.toNamed(ROUTE_BOOKLETS),
      ),
      _DashboardMenuItem(
        icon: Icons.receipt_long_rounded,
        label: 'التقارير',
        locked: !team.canSeeFinancials,
        onTap: () => team.canSeeFinancials
            ? Get.toNamed(ROUTE_REPORTS)
            : showLockedPermissionHint(),
      ),
      if (Get.find<SettingsController>().showRecitation.value)
        _DashboardMenuItem(
          icon: Icons.record_voice_over_rounded,
          label: 'التسميع',
          onTap: () => Get.toNamed(ROUTE_RECITATION),
        ),
      _DashboardMenuItem(
        icon: Icons.qr_code_2_rounded,
        label: 'مكتبة QR',
        onTap: () => Get.toNamed(ROUTE_QR_GALLERY),
      ),
      _DashboardMenuItem(
        icon: Icons.assignment_rounded,
        label: 'الامتحانات',
        locked: !team.canSeeAcademics,
        onTap: () => team.canSeeAcademics
            ? Get.toNamed(ROUTE_EXAMS)
            : showLockedPermissionHint(),
      ),
      _DashboardMenuItem(
        icon: Icons.event_available_rounded,
        label: 'الحجوزات',
        onTap: () => Get.toNamed(ROUTE_BOOKINGS),
      ),
      // الإضافة دي بتتحكّم في الرابط والنشر على حساب المدرس نفسه، فالمساعد
      // ما يديرهاش.
      _DashboardMenuItem(
        icon: Icons.family_restroom_rounded,
        label: 'بوابة أولياء الأمور',
        locked: team.isEnabled.value && !team.isOwner.value,
        onTap: () => team.isEnabled.value && !team.isOwner.value
            ? showLockedPermissionHint()
            : Get.toNamed(ROUTE_PARENT_PORTAL),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // أيقونات شريط الحالة فاتحة لأنها فوق السبورة في الوضعين.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: t.page,
        drawer: _buildDrawer(),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── السبورة: رأس الشاشة والإجراء الأساسي ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: t.board,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.board),
                  ),
                ),
                child: Column(
                  children: [
                    _buildAppBar(),
                    _buildQuickActionsPinned(),
                  ],
                ),
              ),
              const TrialBanner(),
              const PortalExpiryBanner(),
              const AnnouncementSlot(placement: AnnouncementPlacement.home),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _dashboardController.loadDashboardData(),
                  color: t.brand,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildStatsGrid()),
                      SliverToBoxAdapter(child: _buildMainMenuGrid()),
                      SliverToBoxAdapter(child: _buildRecentActivity()),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpace.xl)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: LayoutBuilder(builder: (context, box) {
        return Row(
          children: [
            Builder(
              builder: (ctx) => _AppBarIcon(
                icon: Icons.menu_rounded,
                label: 'القائمة',
                onTap: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child:
                  Image.asset('assets/icon/logo.png', width: 22, height: 22),
            ),
            // على الشاشات الضيقة الأيقونات مش سايبة مكان للاسم كامل.
            const SizedBox(width: 6),
            Expanded(
              child: box.maxWidth >= 340
                  ? Text(
                      APP_NAME,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(color: t.boardInk),
                    )
                  : const SizedBox.shrink(),
            ),
            _AppBarIcon(
              icon: Icons.search_rounded,
              label: 'بحث',
              onTap: () => showSearch(
                context: context,
                delegate: StudentSearchDelegate(),
              ),
            ),
            // spec 021 — نقطة دخول مؤقتة لشاشة "محتاجين متابعة" (بديل
            // كارت لوحة التحكم الكامل الجاي في US3).
            Obx(() {
              final n = _atRiskController.count.value;
              return Badge(
                label: Text('$n'),
                isLabelVisible: n > 0,
                backgroundColor: t.chalk,
                textColor: t.onChalk,
                offset: const Offset(-2, 2),
                child: _AppBarIcon(
                  icon: Icons.groups_rounded,
                  label: 'محتاجين متابعة',
                  onTap: () => Get.toNamed(ROUTE_AT_RISK_STUDENTS),
                ),
              );
            }),
            Obx(() {
              final tc = Get.find<ThemeController>();
              return _AppBarIcon(
                icon: tc.isDarkMode.value
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                label: tc.isDarkMode.value ? 'الوضع الفاتح' : 'الوضع الداكن',
                onTap: () => tc.setTheme(!tc.isDarkMode.value),
              );
            }),
            _AppBarIcon(
              icon: Icons.settings_rounded,
              label: 'الإعدادات',
              onTap: () => Get.toNamed(ROUTE_SETTINGS),
            ),
            // spec 055: زرار خروج ظاهر على الويب فقط.
            if (kIsWeb)
              _AppBarIcon(
                icon: Icons.logout_rounded,
                label: 'تسجيل الخروج',
                onTap: () => confirmAndSignOutWeb(context),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildMainMenuGrid() {
    // ارتفاع الخلية يكبر مع مقاس خط النظام، عشان سطرين الاسم ما يتقصوش.
    final cellHeight = 58 + MediaQuery.textScalerOf(context).scale(34);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'الأقسام الرئيسية'),
          const SizedBox(height: AppSpace.sm),
          Obx(() {
            final entries = _menuEntries;
            return LayoutBuilder(builder: (context, box) {
              final columns = adaptiveColumns(box.maxWidth,
                  phone: 3, minTileWidth: 170, max: 6);
              return GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpace.sm,
                  crossAxisSpacing: AppSpace.sm,
                  mainAxisExtent: cellHeight,
                ),
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return _MenuGridItem(
                    icon: item.icon,
                    label: item.label,
                    onTap: item.onTap,
                    locked: item.locked,
                  );
                },
              );
            });
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPinned() {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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

        final scan = _BoardAction(
          icon: Icons.qr_code_scanner_rounded,
          label: 'تسجيل حضور',
          primary: true,
          onTap: () => Get.toNamed(ROUTE_QR_SCANNER_ATTENDANCE),
        );
        final pay = LockBadge(
          locked: !team.canSeeFinancials,
          child: _BoardAction(
            icon: Icons.payment_rounded,
            label: 'تسجيل دفع',
            onTap: () => team.canSeeFinancials
                ? Get.toNamed(ROUTE_QR_SCANNER_PAYMENT)
                : showLockedPermissionHint(),
          ),
        );
        final addStudent = _BoardAction(
          icon: Icons.person_add_rounded,
          label: 'إضافة طالب',
          onTap: () => showAddStudentSheet(
            context,
            controller: Get.put(StudentController()),
          ),
        );

        return Column(
          children: [
            // ── بطاقة المعلم ───────────────────────────────────
            Row(
              children: [
                _buildTeacherAvatar(
                  radius: 20,
                  isDark: false,
                  avatarPath: teacherAvatar,
                  isFemale: isFemale,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAssistant
                            ? 'مساعد $title $displayName'
                            : 'أهلا $title $displayName',
                        style: AppType.greeting.copyWith(color: t.boardInk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _formatFullDate(DateTime.now()),
                              style: AppType.caption
                                  .copyWith(color: t.boardInkSoft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          _LiveClock(color: t.boardInkSoft),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            // ── أزرار الإجراءات السريعة ─────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: scan),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: pay),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: addStudent),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryHeader() {
    final faint = context.tokens.inkFaint;
    return Row(
      children: [
        Expanded(
          child: _SectionHeader(
              title: 'ملخص سريع', color: context.tokens.rosterInk),
        ),
        // زر تحديث
        Obx(() => _dashboardController.isLoading.value
            ? const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ))
            : IconButton(
                tooltip: 'تحديث',
                onPressed: _dashboardController.loadDashboardData,
                icon: const Icon(Icons.refresh_rounded),
                iconSize: 20,
                color: faint,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                    width: 44, height: 44),
              )),
        IconButton(
          tooltip: _statsVisible ? 'إخفاء الأرقام' : 'إظهار الأرقام',
          onPressed: () => setState(() => _statsVisible = !_statsVisible),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _statsVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              key: ValueKey(_statsVisible),
            ),
          ),
          iconSize: 20,
          color: faint,
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final canSeeFinancials = TeamModeService().canSeeFinancials;
            final currency = _settingsController.currencyCode.value;
            // كارت الدفعات: الشهر المختار وحده (مش تراكمي)، تنقّل بالسحب
            // الأفقي داخل [أقدم شهر عليه مستحق .. الشهر الحالي] (spec 013/014).
            final paymentCardMonth =
                _dashboardController.paymentCardMonth.value;
            final paymentCardMinMonth =
                _dashboardController.paymentCardMinMonth.value;
            final paid = _dashboardController.paymentCardCollected.value;
            final expected = _dashboardController.paymentCardExpected.value;
            final rate = _dashboardController.paymentCardRate.value;
            final unpaidCount = _dashboardController.paymentCardUnpaid.value;
            final paymentCardBusy = _dashboardController.paymentCardBusy.value;
            final now = DateTime.now();
            final pcCurMonth = DateTime(now.year, now.month, 1);
            final paymentMonthsCount =
                ((pcCurMonth.year - paymentCardMinMonth.year) * 12 +
                    (pcCurMonth.month - paymentCardMinMonth.month) +
                    1);
            final paymentMonthIndex =
                (((paymentCardMonth.year - paymentCardMinMonth.year) * 12 +
                        (paymentCardMonth.month - paymentCardMinMonth.month)))
                    .clamp(0, paymentMonthsCount - 1);
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

            final t = context.tokens;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── ملخص سريع: أعداد + متابعة + حضور اليوم ──
                AppTray(
                  color: t.rosterTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryHeader(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: _statsVisible
                                  ? _dashboardController.totalGroups.value
                                      .toString()
                                  : '••',
                              label: 'المجموعات',
                              onTap: () => Get.toNamed(ROUTE_GROUPS),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: _StatCard(
                              value: _statsVisible
                                  ? _dashboardController.totalStudents.value
                                      .toString()
                                  : '••',
                              label: 'الطلاب',
                              onTap: () => Get.toNamed(ROUTE_STUDENTS),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: _StatCard(
                              value: _statsVisible ? '$exempt' : '••',
                              label: 'معفيون',
                              onTap: () => _showStudentsListDialog(
                                  context, isDark,
                                  exemptOnly: true),
                            ),
                          ),
                        ],
                      ),
                      // spec 021 — كارت "محتاجين متابعة" (FR-012): يظهر بس
                      // لو فيه طلاب مرصودين، ويفتح الشاشة المخصّصة عند الضغط.
                      Obx(() {
                        final n = _atRiskController.count.value;
                        if (n == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpace.sm),
                          child: _AtRiskDashboardCard(
                            count: n,
                            onTap: () => Get.toNamed(ROUTE_AT_RISK_STUDENTS),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpace.sm),
                      _AttendanceCard(
                        present: present,
                        absent: absent,
                        expected: todayExpected,
                        rate: attRate,
                        visible: _statsVisible,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                // ── الدفعات: الشهر + مدفوعات اليوم + إيراد الحصص ──
                AppTray(
                  color: t.moneyTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child:
                            _SectionHeader(title: 'الدفعات', color: t.moneyInk),
                      ),
                      LockBadge(
                        locked: !canSeeFinancials,
                        child: _PaymentProgressCard(
                          paid: paid,
                          expected: expected,
                          rate: rate,
                          unpaidCount: unpaidCount,
                          month: paymentCardMonth,
                          monthIndex: paymentMonthIndex,
                          monthsCount: paymentMonthsCount,
                          busy: paymentCardBusy,
                          onSwipe: (d) =>
                              _dashboardController.shiftPaymentCardMonth(d),
                          locked: !canSeeFinancials,
                          fmtPaid: !canSeeFinancials || !_statsVisible
                              ? '••••'
                              : fmtMoney(paid),
                          fmtExpected: !canSeeFinancials || !_statsVisible
                              ? '••••'
                              : fmtMoney(expected),
                          onTapUnpaid: canSeeFinancials
                              ? () => _showUnpaidSheet(context)
                              : showLockedPermissionHint,
                          onTapSummary: canSeeFinancials
                              ? () => _showPaymentMonthSummarySheet(context)
                              : showLockedPermissionHint,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      LockBadge(
                        locked: !canSeeFinancials,
                        child: _TodayPaymentsCard(
                          total: todayPaymentsTotal,
                          count: todayPaymentsCount,
                          locked: !canSeeFinancials,
                          fmtTotal: !canSeeFinancials || !_statsVisible
                              ? '••••'
                              : fmtMoney(todayPaymentsTotal),
                          onTap: !canSeeFinancials
                              ? showLockedPermissionHint
                              : (todayPaymentsCount == 0
                                  ? null
                                  : () => _showTodayPaymentsSheet(context)),
                        ),
                      ),
                      if (sessionRevenue > 0 || sessionRevenueExpected > 0) ...[
                        const SizedBox(height: AppSpace.sm),
                        // ── هنت: إيراد اليوم من المجموعات بالحصة ──
                        LockBadge(
                          locked: !canSeeFinancials,
                          child: _SessionRevenueHint(
                            locked: !canSeeFinancials,
                            actualLabel: !canSeeFinancials || !_statsVisible
                                ? '••••'
                                : fmtMoney(sessionRevenue),
                            actualCount: sessionRevenueCount,
                            expectedLabel: !canSeeFinancials || !_statsVisible
                                ? '••••'
                                : fmtMoney(sessionRevenueExpected),
                            expectedCount: sessionRevenueExpectedCount,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final t = context.tokens;

    return Obx(() {
      final all = _dashboardController.recentActivities;
      final isLoading = _dashboardController.isLoading.value;
      final lastUpdate = _dashboardController.lastUpdated.value;

      if (isLoading && all.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _buildActivitySkeleton(),
        );
      }

      if (all.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _buildEmptyState(),
        );
      }

      final canSeeFinancials = TeamModeService().canSeeFinancials;
      final attendance =
          all.where((a) => a.type == ActivityType.attendance).toList();
      final payments =
          all.where((a) => a.type == ActivityType.payment).toList();

      // وقت آخر تحديث
      final diff = DateTime.now().difference(lastUpdate);
      final updLabel = diff.inSeconds < 60
          ? 'الآن'
          : diff.inMinutes < 60
              ? 'منذ ${diff.inMinutes} د'
              : 'منذ ${diff.inHours} س';

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header مع "آخر تحديث"
            Row(children: [
              const _SectionHeader(title: 'النشاط الأخير'),
              const Spacer(),
              Text('آخر تحديث: $updLabel',
                  style: AppType.caption.copyWith(color: t.inkFaint)),
            ]),
            const SizedBox(height: AppSpace.sm),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ActivityButton(
                      icon: Icons.how_to_reg_rounded,
                      label: 'آخر الحضور',
                      color: t.positive,
                      background: t.positiveSoft,
                      onTap: attendance.isEmpty
                          ? null
                          : () => _showActivitySheet(
                                title: 'آخر الحضور',
                                items: attendance,
                                route: ROUTE_ATTENDANCE,
                              ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: _ActivityButton(
                      icon: Icons.payments_rounded,
                      label: 'آخر المدفوعات',
                      color: t.brand,
                      background: t.brand.withValues(alpha: 0.12),
                      locked: !canSeeFinancials,
                      onTap: !canSeeFinancials
                          ? showLockedPermissionHint
                          : payments.isEmpty
                              ? null
                              : () => _showActivitySheet(
                                    title: 'آخر المدفوعات',
                                    items: payments,
                                    route: ROUTE_PAYMENTS,
                                  ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActivitySkeleton() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
          3,
          (i) => Container(
                margin: const EdgeInsets.only(bottom: AppSpace.sm),
                height: 60,
                decoration: BoxDecoration(
                  color: t.line,
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                ),
              )),
    );
  }

  void _showActivitySheet({
    required String title,
    required List<RecentActivity> items,
    required String route,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) {
        final t = sheet.tokens;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.board)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: AppSpace.xs),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpace.lg, 0, AppSpace.sm, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: AppType.title.copyWith(color: t.ink)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheet).pop();
                          Get.toNamed(route);
                        },
                        child: Text(
                          'عرض الكل',
                          style: AppType.body.copyWith(
                              color: t.brand, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: t.line),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, thickness: 1, color: t.line),
                    itemBuilder: (_, i) => _ActivityItem(activity: items[i]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final t = context.tokens;

    return AppPanel(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpace.xl, horizontal: AppSpace.lg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 32, color: t.inkFaint),
            const SizedBox(height: AppSpace.sm),
            Text(
              'لا توجد عمليات حديثة',
              style: AppType.label.copyWith(color: t.inkSoft),
            ),
          ],
        ),
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
                  _DrawerItem(
                    icon: Icons.family_restroom_rounded,
                    title: 'بوابة أولياء الأمور',
                    onTap: () {
                      Navigator.pop(context);
                      if (TeamModeService().isEnabled.value &&
                          !TeamModeService().isOwner.value) {
                        showLockedPermissionHint();
                        return;
                      }
                      Get.toNamed(ROUTE_PARENT_PORTAL);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.quiz_rounded,
                    title: 'بنك الأسئلة',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_QUESTION_BANK);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_rounded,
                    title: 'الملازم والكتب',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_BOOKLETS);
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

  // spec 036 — شيت ملخص دفعات الشهر: رأس عام (US2) + تفصيل كل مجموعة
  // (US1) مرتّب تنازليًا حسب الباقي. كل الأرقام مقروءة مباشرة من
  // DashboardController (بلا حساب جديد هنا) عشان تفضل مطابقة للكارت.
  void _showPaymentMonthSummarySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = _dashboardController;
    final cardMonth = d.paymentCardMonth.value;
    final monthName = _PaymentProgressCard._arabicMonth(cardMonth.month);
    final breakdown = d.paymentCardGroupBreakdown;
    final pct = d.paymentCardRate.value * 100;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                  const Icon(Icons.bar_chart_rounded,
                      color: Color(0xFF4F46E5), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'ملخص دفعات $monthName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            // ── US2: رأس الملخص العام — نفس أرقام الكارت بالظبط ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.grey)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              FormatHelper.formatCurrency(
                                  d.paymentCardCollected.value),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                              'من ${FormatHelper.formatCurrency(d.paymentCardExpected.value)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            'الباقي ${FormatHelper.formatCurrency(d.paymentCardRemaining.value)}',
                            style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        Text('${pct.toInt()}% محصّل',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: breakdown.isEmpty
                  // US1 edge case: مفيش أي مجموعة عليها مستحق للشهر ده.
                  ? Center(
                      child: Text(
                        'مفيش مستحقات على أي مجموعة للشهر ده',
                        style: TextStyle(
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: breakdown.length,
                      itemBuilder: (_, i) {
                        final g = breakdown[i];
                        final done = g.remaining <= 0.01;
                        final color = done
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Icon(
                              done
                                  ? Icons.check_circle_rounded
                                  : Icons.groups_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Text(g.groupName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            done
                                ? 'مكتملة الدفع — ${FormatHelper.formatCurrency(g.expected)}'
                                : '${g.unpaidStudentsCount} متأخر • من ${FormatHelper.formatCurrency(g.expected)}',
                          ),
                          trailing: Text(
                            done
                                ? '✓'
                                : FormatHelper.formatCurrency(g.remaining),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                          ),
                          onTap: g.unpaidStudentsCount > 0
                              // US3: drill-down لمتأخري المجموعة دي بس.
                              ? () {
                                  Navigator.of(context).pop();
                                  _showUnpaidSheet(context,
                                      groupIdFilter: g.groupId);
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // spec 036 (US3) — groupIdFilter لو مبعوت، القائمة بتتفلتر على طلاب
  // المجموعة دي بس (drill-down من شيت ملخص المجموعات) — نفس المصدر
  // paymentCardUnpaidList بلا استعلام جديد، عشان يفضل متسق ١٠٠٪.
  void _showUnpaidSheet(BuildContext context, {int? groupIdFilter}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // قائمة "لم يدفع" بتخص الشهر المعروض في الكارت تحديدًا — بالمبلغ
    // الناقص على الشهر ده، مش المديونية الكلية.
    final allUnpaid = _dashboardController.paymentCardUnpaidList;
    final students = groupIdFilter == null
        ? allUnpaid
        : allUnpaid.where((e) => e.student.groupId == groupIdFilter).toList();
    final cardMonth = _dashboardController.paymentCardMonth.value;
    final monthName = _PaymentProgressCard._arabicMonth(cardMonth.month);
    final groupName = groupIdFilter == null
        ? null
        : _dashboardController.paymentCardGroupBreakdown
            .firstWhereOrNull((g) => g.groupId == groupIdFilter)
            ?.groupName;
    final titleText = groupName != null
        ? 'لم يدفعوا $monthName — $groupName (${students.length})'
        : 'لم يدفعوا $monthName (${students.length})';
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
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
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

  Future<void> _exportTodayPaymentsPDF(
      BuildContext context, List<TodayPaymentEntry> entries) async {
    AppToast.info(context, 'جاري إنشاء تقرير مدفوعات اليوم...');
    final svc = ExportService();
    final result = await svc.exportTodayPaymentsPDF(
      date: DateTime.now(),
      entries: entries
          .map((e) => (
                studentName: e.studentName,
                studentCode: e.studentCode,
                groupName: e.groupName,
                amount: e.amount,
                time: e.date,
              ))
          .toList(),
    );
    if (!context.mounted) return;
    if (result.success && result.path != null) {
      AppToast.success(context, 'تم إنشاء التقرير');
      await svc.sharePDF(result.path!);
    } else {
      AppToast.error(context, result.error ?? 'فشل التصدير');
    }
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
                  Expanded(
                    child: Text(
                      'مدفوعات اليوم (${entries.length}) — '
                      '${entries.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0)} $currency',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (entries.isNotEmpty)
                    IconButton(
                      tooltip: 'تصدير PDF',
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Color(0xFF10B981)),
                      onPressed: () =>
                          _exportTodayPaymentsPDF(context, entries),
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

/// رقم كبير بيصغر بدل ما يتقص في الكروت الضيقة.
class _FitFigure extends StatelessWidget {
  final String text;
  final Color color;

  const _FitFigure(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: AppType.figure.copyWith(color: color)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: AppSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpace.xs),
              Text(
                label,
                style: AppType.caption
                    .copyWith(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppType.title.copyWith(color: color ?? context.tokens.ink),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AppBarIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: 22,
      color: context.tokens.boardInk,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      // الافتراضي بيفرض 48؛ الـ44 كفاية للمس وبتسيب مكان لاسم التطبيق.
      style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );
  }
}

/// زرار على السبورة: أيقونة فوق الاسم. [primary] بلون الطباشير للإجراء
/// الأساسي، والباقي بحد رفيع.
class _BoardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _BoardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = primary ? t.onChalk : t.boardInk;

    return Material(
      color: primary ? t.chalk : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: primary ? BorderSide.none : BorderSide(color: t.boardLine),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xs, vertical: AppSpace.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 26),
                const SizedBox(height: AppSpace.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body
                      .copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _LiveClock — ساعة حية تتحدث كل ثانية
// ══════════════════════════════════════════════════════════════════
class _LiveClock extends StatefulWidget {
  final Color color;
  const _LiveClock({required this.color});

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
      style: AppType.caption.copyWith(
        color: widget.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

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
    final t = context.tokens;

    return AppPanel(
      lineColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إيراد اليوم من المجموعات بالحصة',
            style: AppType.label.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RevenueMiniStat(
                  label: locked
                      ? 'محصّل فعليًا'
                      : 'محصّل فعليًا ($actualCount دفعة)',
                  value: actualLabel,
                  color: t.moneyInk,
                ),
              ),
              if (locked || expectedCount > 0) ...[
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _RevenueMiniStat(
                    label: locked
                        ? 'متوقع اليوم'
                        : 'متوقع اليوم ($expectedCount طالب)',
                    value: expectedLabel,
                    color: t.inkSoft,
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
        Text(value, style: AppType.title.copyWith(color: color)),
        Text(label,
            style: AppType.caption.copyWith(color: context.tokens.inkSoft)),
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
    final t = context.tokens;
    final pct = (rate * 100).toInt();

    // لو مفيش مجموعات اليوم يبان باللون المحايد
    final barColor = expected == 0
        ? t.inkFaint
        : rate >= 0.8
            ? t.positive
            : rate >= 0.5
                ? t.caution
                : t.danger;

    return AppPanel(
      onTap: () => Get.toNamed(ROUTE_ATTENDANCE),
      lineColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('حضور اليوم',
                    style: AppType.label.copyWith(color: t.ink)),
              ),
              Text(expected == 0 ? '—' : '$pct%',
                  style: AppType.figure.copyWith(color: barColor)),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicator(
              value: expected == 0 ? 0 : rate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: t.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                  barColor == t.caution ? t.cautionBar : barColor),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AttStat(
                icon: Icons.check_circle_outline_rounded,
                color: t.positive,
                label: visible ? '$present حضر' : '••',
              ),
              _AttStat(
                icon: Icons.cancel_outlined,
                color: t.danger,
                label: visible ? '$absent غاب' : '••',
              ),
              Text(
                expected == 0
                    ? 'لا مجموعات اليوم'
                    : (visible ? 'من $expected طالب' : '••'),
                style: AppType.caption.copyWith(color: t.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// spec 021 — كارت "محتاجين متابعة" في لوحة التحكم (FR-012). ما بيظهرش
/// خالص لو العدّاد صفر (بيتحكّم فيه الـcaller).
class _AtRiskDashboardCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _AtRiskDashboardCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppPanel(
      onTap: onTap,
      lineColor: Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child:
                Icon(Icons.warning_amber_rounded, size: 22, color: t.danger),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'طالب واحد محتاج متابعة'
                      : '$count طلاب محتاجين متابعة',
                  style: AppType.label.copyWith(color: t.ink),
                ),
                Text(
                  'غياب متتالي، واجب ناقص، هبوط درجات، أو تأخّر دفع',
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, size: 20, color: t.inkFaint),
        ],
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
    final t = context.tokens;

    return AppPanel(
      onTap: onTap,
      lineColor: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مدفوعات اليوم',
                  style: AppType.label.copyWith(color: t.ink),
                ),
                Text(
                  locked
                      ? 'مقفول'
                      : (count == 0
                          ? 'لا يوجد مدفوعات بعد'
                          : '$count دفعة اليوم'),
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: _FitFigure(fmtTotal, color: t.moneyInk),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_left_rounded, size: 18, color: t.inkSoft),
          ],
        ],
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: AppSpace.xs),
      Text(label,
          style: AppType.caption
              .copyWith(fontWeight: FontWeight.w700, color: color)),
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
    required this.unpaidCount,
    required this.fmtPaid,
    required this.fmtExpected,
    required this.onTapUnpaid,
    this.onTapSummary,
    required this.month,
    required this.onSwipe,
    required this.monthIndex,
    required this.monthsCount,
    required this.busy,
    this.locked = false,
  });

  final double paid, expected, rate;
  final int unpaidCount;
  final String fmtPaid, fmtExpected;
  final VoidCallback onTapUnpaid;
  // spec 036 — الضغط على جسم الكارت (منفصل عن السحب وعن شريحة "لم يدفع").
  final VoidCallback? onTapSummary;
  final DateTime month;
  // اتجاه: -1 = الشهر السابق، +1 = الشهر التالي
  final void Function(int delta) onSwipe;
  final int monthIndex;
  final int monthsCount;
  // بيتحسب أرقام الشهر الجديد → نعتّم الأرقام لحد ما تجهز
  final bool busy;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = (rate * 100).toInt();

    // لو مقفول، الأرقام كلها (النسبة/البار/عدد اللي لسه ما دفعوش) لازم
    // تتقفل مع بعض — مش بس نص المبلغ. عرض المبلغ مقفول والباقي فاضح
    // نفس المعلومة بطريقة غير مباشرة (شكل البار، لونه، النسبة).
    final barColor = locked
        ? t.inkFaint
        : (rate >= 0.8
            ? t.positive
            : rate >= 0.5
                ? t.caution
                : t.danger);

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -140) {
          onSwipe(1); // سحب لليسار → الشهر التالي (أحدث)
        } else if (v > 140) {
          onSwipe(-1); // سحب لليمين → الشهر السابق (أقدم)
        }
      },
      child: AppPanel(
        onTap: onTapSummary,
        padding: const EdgeInsets.all(AppSpace.lg),
        lineColor: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey('paycard-${month.year}-${month.month}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'دفعات ${_arabicMonth(month.month)}',
                      style: AppType.label.copyWith(color: t.ink),
                    ),
                  ),
                  if (locked)
                    Icon(Icons.lock_rounded, size: 16, color: barColor)
                  else
                    Text(
                      '$pct%',
                      style: AppType.label.copyWith(color: barColor),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: busy ? 0.35 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: LinearProgressIndicator(
                        value: locked ? 0 : rate.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: t.line,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            !locked && barColor == t.caution
                                ? t.cautionBar
                                : barColor),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FitFigure(fmtPaid, color: t.moneyInk),
                              Text(
                                'من $fmtExpected',
                                style:
                                    AppType.caption.copyWith(color: t.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        // "لم يدفع" badge — قابل للضغط
                        if (locked)
                          _StatusChip(
                            icon: Icons.lock_rounded,
                            label: 'مقفول',
                            color: t.inkSoft,
                            background: t.line,
                            onTap: onTapUnpaid,
                          )
                        else if (unpaidCount > 0)
                          _StatusChip(
                            icon: Icons.warning_amber_rounded,
                            label: '$unpaidCount لم يدفع',
                            color: t.danger,
                            background: t.dangerSoft,
                            onTap: onTapUnpaid,
                          )
                        else if (expected <= 0)
                          Text(
                            'لا مستحقات للشهر ده',
                            style: AppType.caption.copyWith(color: t.inkSoft),
                          )
                        else
                          _StatusChip(
                            icon: Icons.check_circle_rounded,
                            label: 'الكل دفع',
                            color: t.positive,
                            background: t.positiveSoft,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (monthsCount > 1) ...[
                const SizedBox(height: AppSpace.md),
                Center(
                  child: _MonthDots(
                    count: monthsCount,
                    index: monthIndex,
                    color: t.moneyInk,
                  ),
                ),
              ],
            ],
          ),
        ),
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

// نقاط تحت كارت الدفعات — بتوري المدرس هو في الشهر الكام من نطاق
// الشهور اللي ليها مستحق فعلي. لو الشهور كتير جدًا نعرض نص مختصر.
class _MonthDots extends StatelessWidget {
  final int count;
  final int index;
  final Color color;
  const _MonthDots({
    required this.count,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dim = context.tokens.line;
    if (count > 12) {
      return Text(
        '${index + 1} / $count',
        style: AppType.caption.copyWith(color: context.tokens.inkSoft),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == index ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i == index ? color : dim,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCard({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppPanel(
      onTap: onTap,
      lineColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs, vertical: AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppType.figure.copyWith(color: t.rosterInk)),
          // بيصغر مع الخط الكبير بدل ما الكلمة تتكسر في نصها.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppType.caption.copyWith(color: t.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  const _MenuGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // القفل جوه البلاطة نفسها بدل شارة LockBadge البارزة عن الحواف.
    return Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: BorderSide(color: t.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Opacity(
                opacity: locked ? 0.5 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: t.brand, size: 26),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (locked)
              PositionedDirectional(
                top: AppSpace.sm,
                end: AppSpace.sm,
                child: Icon(Icons.lock_rounded, size: 14, color: t.inkFaint),
              ),
          ],
        ),
      ),
    );
  }
}

/// زرار "آخر الحضور"/"آخر المدفوعات": الأسماء بتظهر في قائمة عند الضغط.
class _ActivityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onTap;
  final bool locked;

  const _ActivityButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: AppPanel(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(label, style: AppType.label.copyWith(color: t.ink)),
            ),
            if (locked)
              Icon(Icons.lock_rounded, size: 16, color: t.inkFaint),
          ],
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
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(activity.icon, color: activity.color, size: 20),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: AppType.label.copyWith(color: t.ink)),
                if (activity.type == ActivityType.payment &&
                    activity.amount != null)
                  CurrencyText(
                    activity.amount,
                    style: AppType.caption.copyWith(color: t.inkSoft),
                  )
                else
                  Text(
                    activity.subtitle,
                    style: AppType.caption.copyWith(color: t.inkSoft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(
            activity.timeLabel,
            style: AppType.caption.copyWith(color: t.inkFaint),
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
  final VoidCallback onTap;
  final bool locked;

  const _DashboardMenuItem({
    required this.icon,
    required this.label,
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

        // بحث الصفحة الرئيسية شغل يومي نشط — الطلاب المؤرشفين مستبعدين
        // (شوفهم من شاشة الأرشيف بس).
        final results = (snapshot.data ?? [])
            .where((student) => !student.isArchived)
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
                .where((s) => !s.isArchived)
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
