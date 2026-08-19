// lib/views/auth/account_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/auth_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('حسابي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: const AccountSection(),
          ),
        ),
      ),
    );
  }
}

/// محتوى شاشة الحساب (صورة، اسم، تليفون، تسجيل خروج) — بدون Scaffold/AppBar
/// عشان نقدر نضمّه جوه شاشة تانية (زي شاشة "المساعدين والحسابات" الموحدة).
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final auth = AuthController.to;

    return Obx(() {
              final name = auth.currentDisplayName.value;
              final phone = auth.currentPhone.value ?? '';
              final initial = (name != null && name.trim().isNotEmpty)
                  ? name.trim().characters.first
                  : (phone.isNotEmpty ? phone.characters.first : '؟');

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    child: Text(initial,
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 16),
                  if (name != null && name.trim().isNotEmpty)
                    Text(name.trim(),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(phone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black45)),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded, color: Colors.red),
                      title: const Text('تسجيل الخروج',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              color: Colors.red)),
                      onTap: () async {
                        await auth.signOut();
                        if (context.mounted) Get.back();
                      },
                    ),
                  ),
                ],
              );
    });
  }
}
