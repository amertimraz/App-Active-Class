part of '../settings_page.dart';

// هيكل صفحة فئة + صف فئة في الشاشة الرئيسية (تصميم السبورة والطباشير).

/// صفحة فئة: رأس سبورة + قائمة أقسام على خلفية الصفحة.
class _CategoryScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// معرّف عنصر جاي من نتيجة بحث — بيظهر شريط تمييز بأول الصفحة.
  final String? highlightId;
  const _CategoryScaffold(
      {required this.title, required this.children, this.highlightId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: title),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
            AppSpace.xl + MediaQuery.paddingOf(context).bottom),
        children: [
          if (highlightId != null)
            _SearchHitBanner(itemId: highlightId!, isDark: isDark),
          ...children,
        ],
      ),
    );
  }
}

/// صف فئة في الشاشة الرئيسية (أيقونة + اسم + وصف + سهم).
class _SettingsCategoryTile extends StatelessWidget {
  final SettingsCategory category;
  final bool isDark;
  final VoidCallback onTap;
  const _SettingsCategoryTile(
      {required this.category, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = _tk(isDark);
    return _tileRow(
      t,
      icon: category.icon,
      iconColor: category.color,
      title: category.title,
      subtitle: category.subtitle,
      onTap: onTap,
      trailing:
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.inkFaint),
    );
  }
}

/// شريط تمييز نتيجة البحث: يوضّح الإعداد المقصود وقسمه داخل الصفحة.
class _SearchHitBanner extends StatelessWidget {
  final String itemId;
  final bool isDark;
  const _SearchHitBanner({required this.itemId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    SettingsItem? item;
    for (final i in kSettingsItems) {
      if (i.id == itemId) item = i;
    }
    if (item == null) return const SizedBox.shrink();
    final t = _tk(isDark);
    final where = item.section == null ? '' : ' — في قسم «${item.section}»';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.md - 2),
      decoration: BoxDecoration(
        color: t.cautionSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: t.cautionBar.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 18, color: t.caution),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            'بتدوّر على «${item.title}»$where',
            style: AppType.body
                .copyWith(fontWeight: FontWeight.w700, color: t.caution),
          ),
        ),
      ]),
    );
  }
}
