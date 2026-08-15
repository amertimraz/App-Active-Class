// lib/views/team/team_mode_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/auth/login_screen.dart';
import 'package:active_class/views/team/join_team_screen.dart';
import 'package:active_class/views/team/manage_members_screen.dart';

class TeamModeScreen extends StatelessWidget {
  const TeamModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final team = TeamModeService();
    final auth = AuthController.to;
    final plan = LicenseController.to.plan.value;
    final planAllowed =
        plan == AppPlan.pro || plan == AppPlan.lifetime;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('وضع الفريق',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      // ملحوظة مهمة: الباقة الاحترافية شرط للمدرس (صاحب الفريق) اللي
      // بيفعّل الميزة لأول مرة — مش شرط للمساعد اللي بينضم بكود دعوة.
      // المساعد ممكن يكون لسه في التجربة المجانية على جهازه، وده
      // طبيعي لأنه مش هو اللي بيدفع في الترخيص.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Obx(() {
            if (!auth.isLoggedIn.value) {
              return _NeedLoginCard(isDark: isDark);
            }
            if (team.isEnabled.value) {
              return _EnabledCard(isDark: isDark, team: team);
            }
            return _DisabledCard(
                isDark: isDark, team: team, ownerPlanAllowed: planAllowed);
          }),
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
    return _Card(
      isDark: isDark,
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
        Text('وضع الفريق محتاج حساب مسجّل دخول (رقم تليفون وباسورد).',
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
    );
  }
}

class _DisabledCard extends StatelessWidget {
  final bool isDark;
  final TeamModeService team;
  final bool ownerPlanAllowed;
  const _DisabledCard(
      {required this.isDark, required this.team, required this.ownerPlanAllowed});

  Future<void> _enable(BuildContext context) async {
    if (!ownerPlanAllowed) {
      ToastHelper.error(
          'تفعيل وضع الفريق كمدرس متاح في الباقة الاحترافية أو مدى الحياة فقط');
      return;
    }
    final err = await team.enableAsOwner();
    if (!context.mounted) return;
    if (err != null) {
      ToastHelper.error(err);
    } else {
      ToastHelper.success('تم تفعيل وضع الفريق');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Card(
          isDark: isDark,
          children: [
            const Icon(Icons.groups_rounded, size: 42, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text('أنا المدرس — عايز أشارك بياناتي مع مساعدين',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            Obx(() => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: team.loading.value ? null : () => _enable(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: team.loading.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('تفعيل وضع الفريق',
                            style: TextStyle(
                                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                  ),
                )),
            if (!ownerPlanAllowed) ...[
              const SizedBox(height: 8),
              Text('يحتاج باقة احترافية أو مدى الحياة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _Card(
          isDark: isDark,
          children: [
            const Icon(Icons.person_add_alt_1_rounded, size: 42, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            Text('أنا مساعد — عندي كود دعوة من مدرسي',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Get.to(() => const JoinTeamScreen()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('الانضمام بكود دعوة',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EnabledCard extends StatelessWidget {
  final bool isDark;
  final TeamModeService team;
  const _EnabledCard({required this.isDark, required this.team});

  @override
  Widget build(BuildContext context) {
    return _Card(
      isDark: isDark,
      children: [
        const Icon(Icons.check_circle_rounded, size: 42, color: Color(0xFF10B981)),
        const SizedBox(height: 12),
        Text('وضع الفريق مفعّل',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Obx(() => Text(
              team.isOwner.value ? 'أنت المدرس (صاحب الفريق)' : 'أنت مساعد في الفريق',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black45),
            )),
        const SizedBox(height: 20),
        Obx(() {
          if (!team.isOwner.value && !team.canManageMembers.value) {
            return const SizedBox.shrink();
          }
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => const ManageMembersScreen()),
              icon: const Icon(Icons.people_alt_rounded, size: 18),
              label: const Text('إدارة الأعضاء',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await team.disable();
              if (context.mounted) ToastHelper.info('تم تعطيل وضع الفريق على الجهاز ده');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تعطيل وضع الفريق',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _Card({required this.isDark, required this.children});
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
