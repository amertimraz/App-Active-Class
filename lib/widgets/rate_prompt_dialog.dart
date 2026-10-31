// lib/widgets/rate_prompt_dialog.dart
//
// نافذة "قيّم Active Class على Google Play" — بتتقفل، ومبتتكررش لو المدرس
// قيّم. بتتخطّى لو فيه شاشة/حوار فوق الرئيسية، وبتحجز وقت العرض قبل ما تظهر.
import 'package:flutter/material.dart';

import 'package:active_class/services/rate_prompt_service.dart';

Future<void> maybeShowRatePrompt(BuildContext context) async {
  final svc = RatePromptService.instance;
  if (ModalRoute.of(context)?.isCurrent != true) return;
  if (!await svc.shouldShow() || !context.mounted) return;
  await svc.markShown();
  if (!context.mounted) return;
  final rate = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 34),
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 34),
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 34),
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 34),
            Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 34),
          ]),
          const SizedBox(height: 14),
          const Text('عجبك Active Class؟',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'تقييمك على Google Play بياخد دقيقة وبيساعدنا نكمّل ونطوّر التطبيق.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
        ]),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text('لاحقًا'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('قيّم الآن'),
          ),
        ],
      ),
    ),
  );
  if (rate == true) {
    await svc.rateNow();
  } else {
    await svc.markLater();
  }
}
