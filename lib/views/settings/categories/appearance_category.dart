part of '../settings_page.dart';

// spec 051 — فئة «المظهر والعرض» بتصميم السبورة والكروت.

class _AppearanceCategoryPage extends StatelessWidget {
  const _AppearanceCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    final SettingsController settings = Get.find();
    final ThemeController themeController = Get.find();
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'المظهر والعرض',
      highlightId: highlightId,
      children: [
        Obx(() => _boardSummary(
              t,
              icon: Icons.palette_rounded,
              title: 'المظهر والعرض',
              subtitle: 'شكل التطبيق وعرض الوقت',
              stats: [
                (
                  label: 'المظهر',
                  value: themeController.isDarkMode.value ? 'ليلي' : 'نهاري'
                ),
                (
                  label: 'نظام الساعة',
                  value: settings.use24hFormat.value ? '24 ساعة' : '12 ساعة'
                ),
              ],
            )),
        gap,
        _plainSectionBlock(
          t,
          'المظهر والتوقيت',
          Icons.palette_rounded,
          const Color(0xFF8B5CF6),
          _cardGrid([
            _toggleCard(
              t,
              rx: themeController.isDarkMode,
              icon: Icons.dark_mode_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'الوضع الليلي',
              onHint: 'التطبيق بالمظهر الداكن',
              offHint: 'تغيير مظهر التطبيق للداكن',
              set: (v) async => themeController.setTheme(v),
            ),
            // _toggleCard فيها Obx جوّاها: لفّها في Obx تاني بلا أي observable كان بيرمي
            // ObxError فالكارت يظهر مربع رمادي طويل.
            _toggleCard(
              t,
              rx: settings.use24hFormat,
              icon: Icons.access_time_rounded,
              color: const Color(0xFF06B6D4),
              title: 'نظام الساعة 24',
              onHint: 'يعرض 14:30',
              offHint: 'يعرض 2:30 م',
              set: (v) async => await settings.setUse24hFormat(v),
            ),
          ]),
        ),
      ],
    );
  }
}
