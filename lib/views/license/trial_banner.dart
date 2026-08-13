// lib/views/license/trial_banner.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/views/license/plans_page.dart';

const String _kSupportPhone = '201096066818';

/// يفتح واتساب مباشرة على رقم الدعم — لطلب تجديد الاشتراك أو أي مساعدة
Future<void> openRenewalWhatsApp({bool isRenewal = true}) async {
  final message = StringBuffer();
  if (isRenewal) {
    message.writeln('مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز أجدد اشتراكي.');
  } else {
    message.writeln('مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز مساعدة/دعم فني.');
  }
  final lc = LicenseController.to;
  final code = lc.licenseCode.value;
  if (code != null && code.isNotEmpty) {
    message.writeln('كود الترخيص: $code');
  }
  final uri = Uri.parse(
      'https://wa.me/$_kSupportPhone?text=${Uri.encodeComponent(message.toString())}');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Banner يظهر في أعلى الصفحة الرئيسية
class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lc = LicenseController.to;

      // ── ترخيص نشط — نشوف لو قريب من الانتهاء ──────────────────
      if (lc.state.value == LicenseState.active) {
        final exp = lc.expiresAt.value;
        if (exp != null) {
          final daysLeft = exp.difference(DateTime.now()).inDays;
          if (daysLeft >= 0 && daysLeft <= 7) {
            return _buildBanner(
              context: context,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFF59E0B),
              msg: daysLeft == 0
                  ? '⚠️ ترخيصك ينتهي اليوم — جدد الآن'
                  : '⚠️ ترخيصك ينتهي خلال $daysLeft ${daysLeft == 1 ? "يوم" : "أيام"}',
              onTap: openRenewalWhatsApp,
              ctaLabel: 'واتساب',
            );
          }
        }
        return const SizedBox.shrink();
      }

      // ── حالات أخرى ───────────────────────────────────────────────
      String msg;
      Color color;
      IconData icon;
      VoidCallback onTap;
      String ctaLabel;

      switch (lc.state.value) {
        case LicenseState.trial:
          final days = lc.trialDaysLeft.value;
          msg  = days <= 1
              ? '⚠️ آخر يوم في تجربتك المجانية — قم بالترقية'
              : 'التجربة المجانية: باقي $days ${days == 1 ? "يوم" : "أيام"}';
          color = days <= 2 ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
          icon  = days <= 2 ? Icons.warning_rounded : Icons.timer_outlined;
          onTap = () => Get.to(() => const PlansPage());
          ctaLabel = 'ترقية';
          break;
        case LicenseState.trialExpired:
          msg   = 'انتهت فترة التجربة — فعّل ترخيصك للاستمرار';
          color = const Color(0xFFDC2626);
          icon  = Icons.lock_rounded;
          onTap = openRenewalWhatsApp;
          ctaLabel = 'واتساب';
          break;
        case LicenseState.expired:
          msg   = 'انتهت صلاحية ترخيصك — قم بالتجديد';
          color = const Color(0xFFDC2626);
          icon  = Icons.timer_off_rounded;
          onTap = openRenewalWhatsApp;
          ctaLabel = 'واتساب';
          break;
        case LicenseState.suspended:
          msg   = 'ترخيصك موقوف — تواصل مع الدعم';
          color = const Color(0xFFDC2626);
          icon  = Icons.block_rounded;
          onTap = () => openRenewalWhatsApp(isRenewal: false);
          ctaLabel = 'واتساب';
          break;
        default:
          return const SizedBox.shrink();
      }

      return _buildBanner(
          context: context, icon: icon, color: color, msg: msg,
          onTap: onTap, ctaLabel: ctaLabel);
    });
  }

  Widget _buildBanner({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String msg,
    required VoidCallback onTap,
    required String ctaLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(ctaLabel,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget صغير يُظهر حالة الترخيص الحالية (في قائمة الإعدادات)
class LicenseStatusTile extends StatelessWidget {
  const LicenseStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lc  = LicenseController.to;
      final exp = lc.expiresAt.value;

      // نص تاريخ الانتهاء + عدد الأيام المتبقية (لو الترخيص نشط وليس مدى الحياة)
      String expText = '';
      if (exp != null) {
        final daysLeft = exp.difference(DateTime.now()).inDays;
        final daysText = daysLeft >= 0
            ? 'باقي $daysLeft ${daysLeft == 1 ? "يوم" : "أيام"}'
            : 'منتهي منذ ${-daysLeft} يوم';
        expText = ' — $daysText (ينتهي ${DateFormat('yyyy/MM/dd').format(exp)})';
      } else if (lc.state.value == LicenseState.active) {
        expText = ' — مدى الحياة ♾️';
      }

      final (icon, label, color) = switch (lc.state.value) {
        LicenseState.active       => (Icons.verified_rounded,
            '${lc.plan.value.nameAr}$expText',
            const Color(0xFF10B981)),
        LicenseState.trial        => (Icons.hourglass_top_rounded,
            'تجريبي — باقي ${lc.trialDaysLeft.value} أيام',
            const Color(0xFFF59E0B)),
        LicenseState.trialExpired => (Icons.lock_rounded,
            'انتهت التجربة المجانية — فعّل ترخيصك للاستمرار', const Color(0xFFEF4444)),
        LicenseState.expired      => (Icons.timer_off_rounded,
            'انتهت صلاحية اشتراكك$expText — جدد للاستمرار', const Color(0xFFEF4444)),
        LicenseState.suspended    => (Icons.block_rounded,
            'الترخيص موقوف — تواصل مع الدعم', const Color(0xFFEF4444)),
        _                         => (Icons.hourglass_empty_rounded,
            'جاري التحقق...', Colors.grey),
      };

      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: const Text('حالة الترخيص',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        subtitle: Text(label,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: color)),
        trailing: switch (lc.state.value) {
          LicenseState.trial => TextButton(
              onPressed: () => Get.to(() => const PlansPage()),
              child: const Text('ترقية',
                  style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF4F46E5))),
            ),
          LicenseState.trialExpired ||
          LicenseState.expired ||
          LicenseState.suspended =>
            TextButton(
              onPressed: () =>
                  openRenewalWhatsApp(isRenewal: lc.state.value != LicenseState.suspended),
              child: const Text('واتساب',
                  style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF25D366))),
            ),
          _ => null,
        },
      );
    });
  }
}
