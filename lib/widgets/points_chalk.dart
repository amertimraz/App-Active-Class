// lib/widgets/points_chalk.dart
//
// لمسات "السبورة والطباشير" المشتركة بين لوحة النقاط وتفاصيل نقاط الطالب
// وكارت الطالب: خط طباشير متقطّع، وشريحة اختيار فوق السبورة.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';

/// خط متقطّع بلون الطباشير الخافت — فاصل بين أجزاء السبورة.
class ChalkDashedLine extends StatelessWidget {
  final Color? color;
  const ChalkDashedLine({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(color ?? t.boardInkSoft.withValues(alpha: 0.45)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 6.0, gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// شريحة اختيار فوق السبورة: المختارة بطباشيرية صفرا، والباقي بإطار خفيف.
class BoardChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const BoardChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onChalk : t.boardInk;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.chalk : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
              color: selected ? t.chalk : t.boardInkSoft.withValues(alpha: 0.55)),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: AppSpace.xs),
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
