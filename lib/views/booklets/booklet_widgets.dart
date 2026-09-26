// lib/views/booklets/booklet_widgets.dart
//
// spec 041 — عناصر UI مشتركة للملازم (نفس نمط كروت باقي البرنامج).
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/booklet_math.dart';

bool isDarkOf(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

BoxDecoration bookletCardDecoration(BuildContext c, {Color? accent}) {
  final dark = isDarkOf(c);
  return BoxDecoration(
    color: dark ? const Color(0xFF1E293B) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: accent?.withValues(alpha: 0.35) ??
          (dark ? const Color(0xFF334155) : AppTheme.dividerColor),
    ),
  );
}

Color statusColor(BookletPaymentStatus s) => switch (s) {
      BookletPaymentStatus.full => AppTheme.successColor,
      BookletPaymentStatus.partial => AppTheme.warningColor,
      BookletPaymentStatus.none => AppTheme.errorColor,
    };

String statusLabel(BookletPaymentStatus s) => switch (s) {
      BookletPaymentStatus.full => 'دفع بالكامل',
      BookletPaymentStatus.partial => 'دفع جزء',
      BookletPaymentStatus.none => 'لم يدفع',
    };

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const StatusPill(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

/// شريط تقدّم مع عنوان ونسبة (مثلاً المحصَّل من الإجمالي).
class LabeledProgress extends StatelessWidget {
  final String label;
  final String trailing;
  final double value; // 0..1
  final Color color;
  const LabeledProgress({
    super.key,
    required this.label,
    required this.trailing,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          Text(trailing,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
            minHeight: 7,
            color: color,
            backgroundColor:
                dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
