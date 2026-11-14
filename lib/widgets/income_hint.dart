// lib/widgets/income_hint.dart
//
// زر «دخلي» + هنت بيوضّح الفرق بينه وبين حسبة التقارير/المدفوعات. بيتحط في
// التقارير والمدفوعات (وفي صفحة «دخلي» نفسها بنص تاني).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/app_panel.dart';

/// يفتح «دخلي»؛ لو [month] اتبعت بيفتح على نفس الشهر (مثلًا شهر شاشة المدفوعات).
void openIncomePage({DateTime? month}) =>
    Get.toNamed(ROUTE_INCOME, arguments: month);

/// كارت قابل للضغط: أيقونة + «دخلي الشهر ده» + سطر الفرق + سهم.
class IncomeLinkTile extends StatelessWidget {
  final String hint;
  final String title;

  /// الشهر اللي «دخلي» يفتح عليه (نفس شهر الشاشة اللي فيها الكارت).
  final DateTime? month;
  const IncomeLinkTile(
      {super.key,
      required this.hint,
      this.month,
      this.title = 'دخلي الشهر ده'});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '$title. $hint',
      child: AppPanel(
        onTap: () => openIncomePage(month: month),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.positiveSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(Icons.payments_rounded, color: t.positive, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text(hint,
                    style: AppType.caption
                        .copyWith(color: t.inkSoft, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child:
                Icon(Icons.chevron_left_rounded, size: 20, color: t.inkSoft),
          ),
        ]),
      ),
    );
  }
}

/// نسخة صغيرة فوق السبورة (خلفية داكنة): سطر توضيح + «افتح دخلي ›».
class IncomeBoardHint extends StatelessWidget {
  final String text;

  /// الشهر اللي «دخلي» يفتح عليه (الافتراضي: الشهر الحالي).
  final DateTime? month;
  const IncomeBoardHint({super.key, required this.text, this.month});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '$text افتح دخلي',
      child: InkWell(
        onTap: () => openIncomePage(month: month),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.xs),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: t.boardInkSoft),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$text ',
                        style: AppType.caption
                            .copyWith(color: t.boardInkSoft, height: 1.5)),
                    TextSpan(
                        text: 'افتح دخلي ›',
                        style: AppType.caption.copyWith(
                            color: t.chalk, fontWeight: FontWeight.w700)),
                  ]),
                  textAlign: TextAlign.center,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
