// lib/views/settings/account_team_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/views/auth/account_screen.dart';
import 'package:active_class/views/auth/login_screen.dart';
import 'package:active_class/views/team/team_mode_screen.dart';

/// شاشة موحدة تجمع بيانات الحساب (تسجيل دخول/خروج) مع وضع الفريق
/// (مشاركة البيانات مع مساعدين)، بدل ما يكونوا شاشتين منفصلتين.
class AccountTeamScreen extends StatelessWidget {
  const AccountTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tk = isDark ? AppTokens.dark : AppTokens.light;
    final auth = AuthController.to;

    return Scaffold(
      backgroundColor: tk.page,
      appBar: buildBoardAppBar(context, title: 'المساعدين والحسابات'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Obx(() {
                if (!auth.isLoggedIn.value) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SectionLabel(isDark: isDark, text: 'الحساب'),
                      const SizedBox(height: AppSpace.sm),
                      _NeedLoginCard(isDark: isDark),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLabel(isDark: isDark, text: 'الحساب'),
                    const SizedBox(height: AppSpace.sm),
                    const AccountSection(),
                    const SizedBox(height: AppSpace.xl),
                    _SectionLabel(isDark: isDark, text: 'وضع الفريق'),
                    const SizedBox(height: AppSpace.sm),
                    const TeamModeSection(),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeedLoginCard extends StatelessWidget {
  final bool isDark;
  const _NeedLoginCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tk = isDark ? AppTokens.dark : AppTokens.light;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.login_rounded, size: 42, color: tk.brand),
          const SizedBox(height: AppSpace.md),
          Text('سجّل الدخول الأول',
              style: AppType.title.copyWith(color: tk.ink)),
          const SizedBox(height: AppSpace.sm),
          Text(
              'محتاج حساب مسجّل دخول (رقم تليفون وباسورد) عشان تدير حسابك أو وضع الفريق.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: tk.inkSoft)),
          const SizedBox(height: AppSpace.xl - 4),
          ElevatedButton(
            onPressed: () => Get.to(() => const LoginScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: tk.brand,
              foregroundColor: isDark ? tk.board : Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: Text('تسجيل الدخول',
                style: AppType.label.copyWith(
                    color: isDark ? tk.board : Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final bool isDark;
  final String text;
  const _SectionLabel({required this.isDark, required this.text});

  @override
  Widget build(BuildContext context) {
    final tk = isDark ? AppTokens.dark : AppTokens.light;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: AppType.label.copyWith(color: tk.ink)),
    );
  }
}
