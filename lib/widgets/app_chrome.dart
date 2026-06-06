import 'package:flutter/material.dart';
import 'package:active_class/config/theme.dart';

PreferredSizeWidget buildGradientAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  Widget? leading,
  bool centerTitle = true,
}) {
  return AppBar(
    centerTitle: centerTitle,
    title: Text(
      title,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    actions: actions,
    leading: leading,
    bottom: bottom,
    elevation: 0,
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.accentColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
  );
}

BoxDecoration buildScreenBackground(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
  );
}
