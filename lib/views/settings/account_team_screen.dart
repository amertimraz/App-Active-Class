// lib/views/settings/account_team_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';
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
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final auth = AuthController.to;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('المساعدين والحسابات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Obx(() {
                if (!auth.isLoggedIn.value) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SectionLabel(isDark: isDark, text: 'الحساب'),
                      const SizedBox(height: 10),
                      _NeedLoginCard(isDark: isDark),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLabel(isDark: isDark, text: 'الحساب'),
                    const SizedBox(height: 10),
                    const AccountSection(),
                    const SizedBox(height: 28),
                    _SectionLabel(isDark: isDark, text: 'وضع الفريق'),
                    const SizedBox(height: 10),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.login_rounded, size: 42, color: AppTheme.primaryColor),
          const SizedBox(height: 12),
          Text('سجّل الدخول الأول',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('محتاج حساب مسجّل دخول (رقم تليفون وباسورد) عشان تدير حسابك أو وضع الفريق.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black45)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Get.to(() => const LoginScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('تسجيل الدخول',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
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
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
