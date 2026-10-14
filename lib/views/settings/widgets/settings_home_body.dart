part of '../settings_page.dart';

// spec 051 — جسم الشاشة الرئيسية: بحث + قائمة الفئات/النتايج.

/// بيرجّع صفحة الفئة بالمعرّف (مع تمييز عنصر اختياري).
Widget _categoryPageFor(String id, {String? highlightId}) {
  switch (id) {
    case 'account':
      return _AccountTeamCategoryPage(highlightId: highlightId);
    case 'attendance':
      return _AttendanceCategoryPage(highlightId: highlightId);
    case 'billing':
      return _BillingCategoryPage(highlightId: highlightId);
    case 'whatsapp':
      return _WhatsappCategoryPage(highlightId: highlightId);
    case 'followup':
      return _FollowupCategoryPage(highlightId: highlightId);
    case 'appearance':
      return _AppearanceCategoryPage(highlightId: highlightId);
    case 'data':
      return _DataCategoryPage(highlightId: highlightId);
    default:
      return _AboutCategoryPage(highlightId: highlightId);
  }
}

class _SettingsHomeBody extends StatefulWidget {
  final bool isDark;
  const _SettingsHomeBody({required this.isDark});

  @override
  State<_SettingsHomeBody> createState() => _SettingsHomeBodyState();
}

class _SettingsHomeBodyState extends State<_SettingsHomeBody> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<SettingsItem> _results() {
    final team = TeamModeService();
    final isAssistant = team.isEnabled.value && !team.isOwner.value;
    final portal = Get.isRegistered<LicenseController>() &&
        Get.find<LicenseController>().parentPortalEnabled.value;
    return searchSettings(_q, isAssistant: isAssistant, portalEnabled: portal);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cats = [...kSettingsCategories]
      ..sort((a, b) => a.order.compareTo(b.order));
    final searching = normalizeArabic(_q).length >= 2;
    final results = searching ? _results() : const <SettingsItem>[];
    final catById = {for (final c in kSettingsCategories) c.id: c};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const LicenseStatusTile(),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          onChanged: (v) => setState(() => _q = v),
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: 'دوّر في الإعدادات…',
            hintStyle: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? Colors.grey[500] : const Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _q = '');
                    },
                  ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.96),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        if (!searching)
          for (final c in cats)
            _SettingsCategoryTile(
              category: c,
              isDark: isDark,
              onTap: () => Get.to(() => _categoryPageFor(c.id)),
            )
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('مفيش إعداد مطابق',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  )),
            ),
          )
        else
          for (final r in results)
            Builder(builder: (context) {
              final cat = catById[r.categoryId]!;
              return _buildNavTile(
                context,
                isDark,
                icon: cat.icon,
                iconColor: cat.color,
                title: r.title,
                subtitle: r.section == null
                    ? cat.title
                    : '${cat.title} › ${r.section}',
                onTap: () => Get.to(
                    () => _categoryPageFor(r.categoryId, highlightId: r.id)),
              );
            }),
      ],
    );
  }
}
