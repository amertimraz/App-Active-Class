part of '../settings_page.dart';

// spec 051 — فئة «المظهر والعرض»

class _AppearanceCategoryPage extends StatelessWidget {
  const _AppearanceCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    final ThemeController themeController = Get.find();
    return _CategoryScaffold(
      title: 'المظهر والعرض',
      highlightId: highlightId,
      children: [
        _buildSection(
          context,
          isDark,
          title: 'المظهر والتوقيت',
          icon: Icons.palette_rounded,
          color: const Color(0xFF8B5CF6),
          children: [
            _buildSwitchTile(
              context,
              isDark,
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'الوضع الليلي',
              subtitle: 'تغيير مظهر التطبيق',
              rxValue: themeController.isDarkMode,
              onChanged: themeController.setTheme,
            ),
            _buildDivider(isDark),
            Obx(() => _buildSwitchTile(
                  context,
                  isDark,
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  title: 'نظام الساعة 24',
                  subtitle: settings.use24hFormat.value
                      ? 'يعرض 14:30'
                      : 'يعرض 2:30 م',
                  rxValue: settings.use24hFormat,
                  onChanged: (v) async => await settings.setUse24hFormat(v),
                )),
          ],
        ),
      ],
    );
  }
}
