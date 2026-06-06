// lib/views/home_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final DashboardController _dashboardController =
      Get.put(DashboardController());
  final SettingsController _settingsController = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _dashboardController.loadDashboardData(),
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildAppBar()),
              SliverToBoxAdapter(child: _buildWelcomeHeader()),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildStatsGrid()),
              SliverToBoxAdapter(child: _buildMainMenuGrid()),
              SliverToBoxAdapter(child: _buildRecentActivity()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ========== APP BAR ==========
  Widget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (ctx) => _AppBarIcon(
              icon: Icons.menu_rounded,
              isDark: isDark,
              onTap: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Row(
            children: [
              _AppBarIcon(
                icon: Icons.search_rounded,
                isDark: isDark,
                onTap: () => showSearch(
                    context: context, delegate: StudentSearchDelegate()),
              ),
              const SizedBox(width: 10),
              _AppBarIcon(
                icon: Icons.notifications_outlined,
                isDark: isDark,
                onTap: () => Get.toNamed(ROUTE_NOTIFICATION_SETTINGS),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== WELCOME HEADER ==========
  Widget _buildWelcomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Obx(() {
        final teacherName = _settingsController.teacherFullName.value;
        final now = DateTime.now();
        String greeting;
        String emoji;
        if (now.hour >= 5 && now.hour < 12) {
          greeting = 'صباح الخير';
          emoji = '☀️';
        } else if (now.hour >= 12 && now.hour < 17) {
          greeting = 'مساء الخير';
          emoji = '🌤️';
        } else {
          greeting = 'مساء الخير';
          emoji = '🌙';
        }
        final nameDisplay = teacherName.isNotEmpty ? teacherName : 'المعلم';

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Obx(() {
                      final path =
                          _settingsController.teacherAvatarPath.value.trim();
                      if (path.isNotEmpty) {
                        final f = File(path);
                        if (f.existsSync()) {
                          return CircleAvatar(
                            radius: 24,
                            backgroundImage: FileImage(f),
                          );
                        }
                      }
                      return const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person_rounded,
                            color: Colors.white, size: 28),
                      );
                    }),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting $emoji',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'أستاذ $nameDisplay',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _formatFullDate(now),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Obx(() => Text(
                          '${_dashboardController.totalStudents.value} طالب',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ========== QUICK ACTIONS ==========
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.payment_rounded,
              label: 'تسجيل دفع',
              color: AppTheme.warningColor,
              onTap: () => Get.toNamed(ROUTE_QR_SCANNER_PAYMENT),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.person_add_rounded,
              label: 'إضافة طالب',
              color: AppTheme.accentColor,
              onTap: () => Get.toNamed(ROUTE_GROUPS),
            ),
          ),
        ],
      ),
    );
  }

  // ========== STATS GRID ==========
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'نظرة سريعة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Obx(() {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  icon: Icons.people_rounded,
                  value: _dashboardController.totalStudents.value.toString(),
                  label: 'الطلاب',
                  gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                ),
                _StatCard(
                  icon: Icons.check_circle_rounded,
                  value: _dashboardController.paidStudents.value.toString(),
                  label: 'دفعوا',
                  gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
                ),
                _StatCard(
                  icon: Icons.pending_rounded,
                  value: _dashboardController.lateStudents.value.toString(),
                  label: 'متأخرين',
                  gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                ),
                _StatCard(
                  icon: Icons.trending_up_rounded,
                  value:
                      '${_dashboardController.attendanceRate.value.toStringAsFixed(0)}%',
                  label: 'نسبة الحضور',
                  gradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ========== MAIN MENU GRID ==========
  Widget _buildMainMenuGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'القائمة الرئيسية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              _MenuGridItem(
                icon: Icons.people_rounded,
                label: 'المجموعات',
                color: const Color(0xFF4F46E5),
                onTap: () => Get.toNamed(ROUTE_GROUPS),
              ),
              _MenuGridItem(
                icon: Icons.payment_rounded,
                label: 'المدفوعات',
                color: const Color(0xFF0891B2),
                onTap: () => Get.toNamed(ROUTE_PAYMENTS),
              ),
              _MenuGridItem(
                icon: Icons.assessment_rounded,
                label: 'التقارير',
                color: const Color(0xFF7C3AED),
                onTap: () => Get.toNamed(ROUTE_REPORTS),
              ),
              _MenuGridItem(
                icon: Icons.qr_code_rounded,
                label: 'مكتبة QR',
                color: const Color(0xFF059669),
                onTap: () => Get.toNamed(ROUTE_QR_GALLERY),
              ),
              _MenuGridItem(
                icon: Icons.how_to_reg_rounded,
                label: 'الحضور',
                color: const Color(0xFFD97706),
                onTap: () => Get.toNamed(ROUTE_ATTENDANCE),
              ),
              _MenuGridItem(
                icon: Icons.settings_rounded,
                label: 'الإعدادات',
                color: const Color(0xFF4B5563),
                onTap: () => Get.toNamed(ROUTE_SETTINGS),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== RECENT ACTIVITY ==========
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'آخر العمليات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Obx(() {
            final activities = _dashboardController.recentActivities;
            if (activities.isEmpty) {
              return _buildEmptyState();
            }
            return Column(
              children:
                  activities.map((a) => _ActivityItem(activity: a)).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded,
              size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'لا توجد عمليات حديثة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ========== BOTTOM NAVIGATION ==========
  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() => _currentIndex = index);
        _handleNavigation(index);
      },
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
        NavigationDestination(
            icon: Icon(Icons.people_rounded), label: 'الطلاب'),
        NavigationDestination(
            icon: Icon(Icons.assessment_rounded), label: 'التقارير'),
        NavigationDestination(
            icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
      ],
    );
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Get.toNamed(ROUTE_GROUPS);
        break;
      case 2:
        Get.toNamed(ROUTE_REPORTS);
        break;
      case 3:
        Get.toNamed(ROUTE_SETTINGS);
        break;
    }
  }

  // ========== DRAWER ==========
  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  final path =
                      _settingsController.teacherAvatarPath.value.trim();
                  if (path.isNotEmpty) {
                    final f = File(path);
                    if (f.existsSync()) {
                      return CircleAvatar(
                          radius: 36, backgroundImage: FileImage(f));
                    }
                  }
                  return const CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        color: AppTheme.primaryColor, size: 36),
                  );
                }),
                const SizedBox(height: 12),
                Obx(() {
                  final name = _settingsController.teacherFullName.value;
                  return Text(
                    name.isNotEmpty ? name : 'المعلم',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                    icon: Icons.home_rounded,
                    title: 'الرئيسية',
                    isSelected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    }),
                _DrawerItem(
                    icon: Icons.people_rounded,
                    title: 'الطلاب والمجموعات',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_GROUPS);
                    }),
                _DrawerItem(
                    icon: Icons.payments_rounded,
                    title: 'المدفوعات',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_PAYMENTS);
                    }),
                _DrawerItem(
                    icon: Icons.assessment_rounded,
                    title: 'التقارير',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_REPORTS);
                    }),
                _DrawerItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'مسح QR',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_QR_GALLERY);
                    }),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider()),
                _DrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'الإعدادات',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(ROUTE_SETTINGS);
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime d) {
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
      'ديسمبر'
    ];
    const weekdays = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    return '${weekdays[d.weekday % 7]}، ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ========== REUSABLE WIDGETS ==========

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _AppBarIcon(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon,
              color: isDark ? Colors.white : const Color(0xFF0F172A), size: 22),
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
  const _QuickActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.gradient});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    gradient[0].withValues(alpha: 0.15),
                    gradient[1].withValues(alpha: 0.1)
                  ]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: gradient[0], size: 20),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: gradient[0].withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 26,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = LinearGradient(colors: gradient)
                    .createShader(const Rect.fromLTWH(0, 0, 200, 0)),
              color: gradient[0],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
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
  final Color color;
  final VoidCallback onTap;
  const _MenuGridItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activity.icon, color: activity.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(activity.subtitle,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF475569))),
              ],
            ),
          ),
          Text(activity.time,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : const Color(0xFF64748B))),
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
  const _DrawerItem(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.grey[400] : AppTheme.textSecondary)),
        title: Text(title,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.white : AppTheme.textPrimary))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}

// ========== SEARCH DELEGATE ==========

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
            }),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.trim().isEmpty)
      return const Center(child: Text('اكتب اسم الطالب أو الكود للبحث'));
    return FutureBuilder<List<Student>>(
      future: DatabaseService().getAllStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        final results = (snapshot.data ?? [])
            .where((s) =>
                s.name.toLowerCase().contains(query.toLowerCase()) ||
                s.code.toLowerCase().contains(query.toLowerCase()))
            .toList();
        if (results.isEmpty)
          return const Center(child: Text('لا توجد نتائج مطابقة'));
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final student = results[index];
            return ListTile(
              leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.person, color: Colors.white)),
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
