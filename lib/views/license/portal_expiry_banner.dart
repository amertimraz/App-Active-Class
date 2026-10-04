// lib/views/license/portal_expiry_banner.dart
//
// بانر قرب انتهاء (أو انتهاء) اشتراك بوابة أولياء الأمور + الامتحانات
// الإلكترونية. للمدرس بس (مش المساعد في وضع الفريق). المنطق في
// lib/utils/portal_expiry.dart.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/portal_expiry.dart';
import 'package:active_class/views/license/trial_banner.dart';

class PortalExpiryBanner extends StatelessWidget {
  const PortalExpiryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final team = TeamModeService();
      if (team.isEnabled.value && !team.isOwner.value) {
        return const SizedBox.shrink();
      }
      final lc = LicenseController.to;
      // العداد الدوري (كل 5 دقايق) يعيد تقييم الحالة مع الوقت.
      lc.parentPortalRecheckTick.value;
      final info = portalExpiryInfo(
        enabled: lc.parentPortalEnabled.value,
        expiresAt: lc.parentPortalExpiresAt.value,
        now: DateTime.now(),
      );
      if (info.stage == PortalExpiryStage.none) {
        return const SizedBox.shrink();
      }
      final color = info.stage == PortalExpiryStage.warning
          ? const Color(0xFFF59E0B)
          : const Color(0xFFDC2626);
      return GestureDetector(
        onTap: () => openRenewalWhatsApp(portalAddon: true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.3))),
          ),
          child: Row(children: [
            Icon(
                info.stage == PortalExpiryStage.expired
                    ? Icons.lock_clock_rounded
                    : Icons.hourglass_bottom_rounded,
                color: color,
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(portalExpiryBannerText(info),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('تجديد',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ]),
        ),
      );
    });
  }
}
