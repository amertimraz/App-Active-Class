// lib/views/help/getting_started_card.dart
//
// كارت "ابدأ من هنا" في الرئيسية: تقدّم المدرس الجديد وأول خطوة ناقصة، وبيختفي
// لما يخلّص كل الخطوات أو يضغط إخفاء.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/getting_started_controller.dart';
import 'package:active_class/help/getting_started.dart';
import 'package:active_class/widgets/app_panel.dart';

class GettingStartedCard extends StatelessWidget {
  const GettingStartedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<GettingStartedController>()
        ? Get.find<GettingStartedController>()
        : Get.put(GettingStartedController());
    return Obx(() {
      if (!c.visible) return const SizedBox.shrink();
      final t = context.tokens;
      final steps = c.steps.toList();
      final done = gettingStartedDoneCount(steps);
      final next = gettingStartedNext(steps)!;

      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
        child: AppPanel(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.sm),
              child: Row(children: [
                Icon(Icons.rocket_launch_rounded, color: t.brand),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text('ابدأ من هنا',
                      style: AppType.title.copyWith(color: t.ink)),
                ),
                Text('$done من ${steps.length}',
                    style: AppType.label.copyWith(color: t.inkSoft)),
                IconButton(
                  tooltip: 'إخفاء القايمة',
                  onPressed: c.dismiss,
                  icon: Icon(Icons.close_rounded, color: t.inkSoft),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: LinearProgressIndicator(
                  value: steps.isEmpty ? 0 : done / steps.length,
                  minHeight: 6,
                  backgroundColor: t.line,
                  color: t.positive,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            for (final s in steps) _StepRow(step: s, isNext: s.id == next.id),
            Divider(height: 1, thickness: 1, color: t.line),
            TextButton.icon(
              onPressed: () =>
                  Get.toNamed(ROUTE_HELP_TOPIC, arguments: 'start'),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('اقرا دليل البداية'),
              style: TextButton.styleFrom(
                  foregroundColor: t.brand, minimumSize: const Size(44, 44)),
            ),
          ]),
        ),
      );
    });
  }
}

class _StepRow extends StatelessWidget {
  final GettingStartedStep step;
  final bool isNext;
  const _StepRow({required this.step, required this.isNext});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => Get.toNamed(step.route),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        color: isNext ? t.brand.withValues(alpha: 0.07) : null,
        child: Row(children: [
          Icon(
            step.done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: step.done ? t.positive : t.inkFaint,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: AppType.label.copyWith(
                        color: step.done ? t.inkSoft : t.ink)),
                if (!step.done)
                  Text(step.hint,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
              ],
            ),
          ),
          if (isNext)
            Icon(Icons.arrow_back_rounded, color: t.brand, size: 20),
        ]),
      ),
    );
  }
}
