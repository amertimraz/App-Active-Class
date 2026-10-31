// lib/widgets/announcement_slot.dart
//
// spec 054 — مكان عرض الإعلان في شاشة (رئيسية/باقات): بيجيب الإعلان المناسب
// من AnnouncementController ويرسمه ببنر، ويربط الإغلاق والزرار والانتهاء.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/announcement_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/announcement_model.dart';
import 'package:active_class/utils/announcement_logic.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/announcement_banner.dart';
import 'package:active_class/widgets/announcement_popup.dart';

/// بنر الإعلان لمكان معيّن، أو لا شيء لو مفيش إعلان مناسب/اتقفل.
class AnnouncementSlot extends StatelessWidget {
  const AnnouncementSlot({super.key, required this.placement});

  final AnnouncementPlacement placement;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AnnouncementController>()) {
      return const SizedBox.shrink();
    }
    final c = Get.find<AnnouncementController>();
    return Obx(() {
      final a = c.forPlacement(placement);
      if (a == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        // مضغوط (≈64px) عشان ميزاحمش الشاشة؛ الضغط عليه بيفتح التفاصيل الكاملة.
        child: Builder(
          builder: (ctx) => announcementBannerFor(
            a,
            compact: true,
            onTap: () => showAnnouncementDialog(ctx, a),
            onClose: () => c.dismiss(placement, a),
            onExpired: c.reevaluate,
          ),
        ),
      );
    });
  }
}

/// بنر لإعلان (مشترك بين البنر والنافذة).
Widget announcementBannerFor(
  Announcement a, {
  VoidCallback? onClose,
  VoidCallback? onExpired,
  VoidCallback? afterCta,
  bool compact = false,
  VoidCallback? onTap,
}) =>
    AnnouncementBanner(
      key: ValueKey(a.displayKey),
      title: a.title,
      body: a.body,
      kind: a.kind,
      badge: a.badge,
      design: a.design,
      color: a.color,
      couponCode: a.couponCode,
      startsAt: a.startsAt,
      endsAt: a.endsAt,
      showCountdown: a.countdownEnabled,
      ctaLabel: a.cta.isActionable ? a.cta.label : '',
      onCta: a.cta.isActionable
          ? () async {
              await openAnnouncementCta(a);
              afterCta?.call();
            }
          : null,
      onClose: onClose,
      onExpired: onExpired,
      compact: compact,
      onTap: onTap,
    );

/// بيفتح وجهة زرار الإعلان: واتساب (رسالة الأدمن + بيانات المدرس) أو رابط
/// خارجي (http/https فقط) أو شاشة الباقات. أي فشل = رسالة بسيطة بدون كراش.
Future<void> openAnnouncementCta(Announcement a) async {
  try {
    switch (a.cta.type) {
      case 'whatsapp':
        final lc =
            Get.isRegistered<LicenseController>() ? Get.find<LicenseController>() : null;
        final st = Get.isRegistered<SettingsController>()
            ? Get.find<SettingsController>()
            : null;
        final uri = announcementWhatsappUri(
          phone: a.cta.phone,
          message: a.cta.message,
          name: st?.teacherFullName.value ?? '',
          code: lc?.licenseCode.value ?? '',
          planName: lc?.plan.value.nameAr ?? '',
        );
        if (uri == null) return;
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          ToastHelper.error('تعذّر فتح واتساب');
        }
      case 'link':
        final uri = safeHttpUrl(a.cta.url);
        if (uri == null) return;
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          ToastHelper.error('تعذّر فتح الرابط');
        }
      case 'plans':
        Get.toNamed(ROUTE_PLANS);
    }
  } catch (_) {
    ToastHelper.error('تعذّر تنفيذ الإجراء');
  }
}
