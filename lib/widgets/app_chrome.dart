import 'package:active_class/config/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

PreferredSizeWidget buildGradientAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  Widget? leading,
  bool centerTitle = true,
}) {
  final isDark = Get.theme.brightness == Brightness.dark;
  return AppBar(
    centerTitle: centerTitle,
    title: Text(
      title,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
    ),
    actions: actions,
    leading: leading,
    bottom: bottom,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF111827),
                  Color(0xFF172033),
                  Color(0xFF1E1B4B),
                ]
              : const [
                  Color(0xFFFDFDFF),
                  Color(0xFFF6F8FF),
                  Color(0xFFEEF4FF),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0xFFD8E0F0).withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    ),
  );
}

BoxDecoration buildScreenBackground(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      colors: isDark
          ? const [
              Color(0xFF08101F),
              Color(0xFF10192F),
              Color(0xFF121A2D),
            ]
          : const [
              Color(0xFFFDFDFF),
              Color(0xFFF7F8FF),
              Color(0xFFEEF4FF),
            ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

Widget buildSoftBackground({
  required BuildContext context,
  required Widget child,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Stack(
    children: [
      Positioned.fill(
        child: DecoratedBox(decoration: buildScreenBackground(context)),
      ),
      _BackgroundGlow(
        top: -110,
        right: -80,
        size: 250,
        colors: isDark
            ? const [Color(0x334F46E5), Color(0x004F46E5)]
            : const [Color(0x55F9A8D4), Color(0x00F9A8D4)],
      ),
      _BackgroundGlow(
        top: 260,
        left: -100,
        size: 220,
        colors: isDark
            ? const [Color(0x3322C55E), Color(0x0022C55E)]
            : const [Color(0x55BFDBFE), Color(0x00BFDBFE)],
      ),
      _BackgroundGlow(
        bottom: 120,
        right: -90,
        size: 280,
        colors: isDark
            ? const [Color(0x33E879F9), Color(0x00E879F9)]
            : const [Color(0x55DDD6FE), Color(0x00DDD6FE)],
      ),
      Positioned.fill(child: child),
    ],
  );
}

Widget buildSoftPanel({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  EdgeInsetsGeometry? margin,
  double radius = 24,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF131D31).withValues(alpha: 0.94)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.9),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.18)
              : const Color(0xFFD8E0F0).withValues(alpha: 0.5),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );
}

Widget buildSectionHeader({
  required BuildContext context,
  required String title,
  String? subtitle,
  Widget? trailing,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.62)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        trailing,
      ],
    ],
  );
}

class _BackgroundGlow extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final List<Color> colors;

  const _BackgroundGlow({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}
