// lib/widgets/announcement_popup.dart
//
// spec 054 — نافذة الإعلان المنبثقة (مرة واحدة لكل إصدار؛ الحجز بيتم في
// AnnouncementController.takePopup قبل العرض).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/controllers/announcement_controller.dart';
import 'package:active_class/widgets/announcement_slot.dart';

/// بتعرض النافذة لو فيه إعلان popup مناسب لم يُعرض بعد. آمنة لو الشاشة اتقفلت
/// أو فيه شاشة/حوار فوقها.
Future<void> maybeShowAnnouncementPopup(BuildContext context) async {
  if (!Get.isRegistered<AnnouncementController>()) return;
  // لو فيه حوار/شاشة أخرى فوق الرئيسية دلوقتي، منزاحمش — هتتعرض المرة الجاية.
  if (ModalRoute.of(context)?.isCurrent != true) return;
  final a = await Get.find<AnnouncementController>().takePopup();
  if (a == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        announcementBannerFor(
          a,
          onClose: () => Navigator.of(ctx).pop(),
          afterCta: () {
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: TextButton.styleFrom(
              foregroundColor: Colors.white, minimumSize: const Size(44, 44)),
          child: const Text('لاحقًا'),
        ),
      ]),
    ),
  );
}
