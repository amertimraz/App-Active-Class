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

    final t = _tk(isDark);
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget group(List<Widget> rows) {
      final spaced = <Widget>[];
      for (var k = 0; k < rows.length; k++) {
        if (k > 0) spaced.add(_buildDivider(isDark));
        spaced.add(rows[k]);
      }
      return _settingsCard(t, Column(children: spaced));
    }

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          borderSide: BorderSide(color: c, width: w),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xl + bottom),
      children: [
        _settingsCard(t, const LicenseStatusTile()),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _ctrl,
          onChanged: (v) => setState(() => _q = v),
          textInputAction: TextInputAction.search,
          style: AppType.label.copyWith(color: t.ink),
          decoration: InputDecoration(
            hintText: 'دوّر في الإعدادات…',
            hintStyle: AppType.body.copyWith(color: t.inkFaint),
            prefixIcon: Icon(Icons.search_rounded, size: 22, color: t.inkFaint),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    icon: Icon(Icons.close_rounded, size: 20, color: t.inkSoft),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _q = '');
                    },
                  ),
            filled: true,
            fillColor: t.surface,
            border: border(t.line),
            enabledBorder: border(t.line),
            focusedBorder: border(t.brand, 1.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (!searching)
          group([
            for (final c in cats)
              _SettingsCategoryTile(
                category: c,
                isDark: isDark,
                onTap: () => Get.to(() => _categoryPageFor(c.id)),
              ),
          ])
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(Icons.search_off_rounded, size: 40, color: t.inkFaint),
              const SizedBox(height: AppSpace.sm),
              Text('مفيش إعداد مطابق',
                  style: AppType.label.copyWith(color: t.inkSoft)),
              const SizedBox(height: 2),
              Text('جرّب كلمة تانية أو جزء من الاسم',
                  style: AppType.caption.copyWith(color: t.inkFaint)),
            ]),
          )
        else
          group([
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
          ]),
      ],
    );
  }
}
