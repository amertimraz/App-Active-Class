// lib/views/settings/notification_settings_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();
  
  bool _birthdayNotifications = true;
  bool _classNotifications = true;
  bool _latePaymentNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الإشعارات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Birthday Notifications
          _buildNotificationToggle(
            title: 'إشعارات أعياد الميلاد',
            subtitle: 'تنبيه قبل أسبوع من عيد ميلاد الطالب',
            value: _birthdayNotifications,
            onChanged: (value) {
              setState(() {
                _birthdayNotifications = value;
              });
            },
            icon: Icons.cake,
          ),
          const SizedBox(height: 16),
          
          // Class Notifications
          _buildNotificationToggle(
            title: 'إشعارات الحصص',
            subtitle: 'تنبيه بالحصص المجدولة لليوم',
            value: _classNotifications,
            onChanged: (value) {
              setState(() {
                _classNotifications = value;
              });
            },
            icon: Icons.event,
          ),
          const SizedBox(height: 16),
          
          // Late Payment Notifications
          _buildNotificationToggle(
            title: 'إشعارات الدفع المتأخر',
            subtitle: 'تنبيه بالطلاب المتأخرين في الدفع',
            value: _latePaymentNotifications,
            onChanged: (value) {
              setState(() {
                _latePaymentNotifications = value;
              });
            },
            icon: Icons.payment,
          ),
          const SizedBox(height: 24),
          
          // Test Notifications
          _buildSectionTitle('اختبار الإشعارات'),
          const SizedBox(height: 12),
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
                Get.snackbar(
                  'تنبيه',
                  'صلاحية الإشعارات غير مفعلة، يرجى تفعيلها من إعدادات الهاتف.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
              }
            },
            icon: Icons.cake,
          ),
          const SizedBox(height: 12),
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
                Get.snackbar(
                  'تنبيه',
                  'صلاحية الإشعارات غير مفعلة، يرجى تفعيلها من إعدادات الهاتف.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.errorColor,
                  colorText: Colors.white,
                );
              }
            },
            icon: Icons.event,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required String title,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.play_arrow,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
