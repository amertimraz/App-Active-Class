part of '../settings_page.dart';

// spec 051 — هيكل صفحة فئة + بلاطة فئة في الشاشة الرئيسية.

class _SettingsBackdrop extends StatelessWidget {
  final bool isDark;
  const _SettingsBackdrop({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF08101F), Color(0xFF121A2D)]
                : const [Color(0xFFFDFDFF), Color(0xFFEEF4FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

/// صفحة فئة: نفس خلفية/شريط الإعدادات القديمة، وعنوان الفئة.
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
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          _SettingsBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark, title: title),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (highlightId != null)
                        _SearchHitBanner(itemId: highlightId!, isDark: isDark),
                      ...children,
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final c = category.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark
            ? const Color(0xFF131D31).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, size: 22, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.title,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                        )),
                    const SizedBox(height: 2),
                    Text(category.subtitle,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[500] : const Color(0xFF9CA3AF)),
            ]),
          ),
        ),
      ),
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
    const accent = Color(0xFFF59E0B);
    final where = item.section == null ? '' : ' — في قسم «${item.section}»';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'بتدوّر على «${item.title}»$where',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF92400E),
            ),
          ),
        ),
      ]),
    );
  }
}
