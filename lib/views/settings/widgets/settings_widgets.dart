part of '../settings_page.dart';

// مشترَكات الإعدادات بتصميم «السبورة والطباشير» (AppTokens): سطح بحد رفيع
// بلا ظل، أيقونة بمربع ملوّن خفيف، وصفوف بارتفاع لمس مريح (>= 56).
// التواقيع ثابتة عشان صفحات الفئات ما تتغيرش.

AppTokens _tk(bool isDark) => isDark ? AppTokens.dark : AppTokens.light;

const double _kTileIcon = 36;
const double _kTilePadH = 16;
const double _kTileGap = 12;

/// مربع الأيقونة المشترك بين كل أنواع الصفوف.
Widget _tileIcon(IconData icon, Color color, {double size = _kTileIcon}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Icon(icon, size: size * 0.55, color: color),
  );
}

/// سطح مجموعة الصفوف: حد رفيع، وقص عشان تأثير اللمس ما يطلعش برا الزوايا.
Widget _settingsCard(AppTokens t, Widget child) {
  return Material(
    color: t.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      side: BorderSide(color: t.line),
    ),
    child: child,
  );
}

Widget _sectionHeader(AppTokens t, String title, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpace.sm),
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.label.copyWith(color: t.ink),
        ),
      ),
    ],
  );
}

Widget _buildSection(
  BuildContext context,
  bool isDark, {
  required String title,
  required IconData icon,
  required Color color,
  required List<Widget> children,
  bool collapsible = false,
  bool initiallyExpanded = true,
}) {
  final t = _tk(isDark);
  final header = _sectionHeader(t, title, icon, color);
  final card = _settingsCard(t, Column(children: children));

  if (!collapsible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpace.sm),
          child: header,
        ),
        card,
      ],
    );
  }

  return _CollapsibleSection(
    isDark: isDark,
    color: color,
    header: header,
    card: card,
    initiallyExpanded: initiallyExpanded,
  );
}

/// هيكل صف موحّد: أيقونة + نص (عنوان/وصف) + عنصر في الآخر.
Widget _tileRow(
  AppTokens t, {
  required IconData icon,
  required Color iconColor,
  required String title,
  String? subtitle,
  Color? titleColor,
  Widget? trailing,
  VoidCallback? onTap,
}) {
  final body = ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 60),
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: _kTilePadH, vertical: AppSpace.sm + 2),
      child: Row(
        children: [
          _tileIcon(icon, iconColor),
          const SizedBox(width: _kTileGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppType.label.copyWith(color: titleColor ?? t.ink)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style: AppType.caption.copyWith(color: t.inkFaint)),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.sm),
            trailing,
          ],
        ],
      ),
    ),
  );
  if (onTap == null) return body;
  return InkWell(onTap: onTap, child: body);
}

Widget _buildSwitchTile(
  BuildContext context,
  bool isDark, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required RxBool rxValue,
  required void Function(bool) onChanged,
}) {
  final t = _tk(isDark);
  // الصف كله بيقلب الإعداد (مش السويتش بس) — هدف لمس أكبر.
  return _tileRow(
    t,
    icon: icon,
    iconColor: iconColor,
    title: title,
    subtitle: subtitle,
    onTap: () => onChanged(!rxValue.value),
    trailing: SizedBox(
      width: 44,
      height: 28,
      child: FittedBox(
        child: Obx(() => Switch(
              value: rxValue.value,
              onChanged: onChanged,
              thumbColor:
                  WidgetStatePropertyAll(isDark ? t.board : Colors.white),
              trackColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? t.brand
                      : t.inkFaint.withValues(alpha: 0.45)),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
            )),
      ),
    ),
  );
}

Widget _buildNavTile(
  BuildContext context,
  bool isDark, {
  required IconData icon,
  required Color iconColor,
  required String title,
  String? subtitle,
  Color? titleColor,
  required VoidCallback onTap,
}) {
  final t = _tk(isDark);
  return _tileRow(
    t,
    icon: icon,
    iconColor: iconColor,
    title: title,
    subtitle: subtitle,
    titleColor: titleColor,
    onTap: onTap,
    trailing:
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.inkFaint),
  );
}

Widget _buildDropdownTile<T>(
  BuildContext context,
  bool isDark, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required void Function(T?)? onChanged,
  String? helper,
}) {
  final t = _tk(isDark);
  return Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: _kTilePadH, vertical: AppSpace.sm + 2),
    child: Row(
      children: [
        _tileIcon(icon, iconColor),
        const SizedBox(width: _kTileGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.caption.copyWith(color: t.inkFaint)),
              DropdownButtonFormField<T>(
                value: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.only(top: 2, bottom: 2),
                ),
                style: AppType.label.copyWith(color: t.ink),
                icon: Icon(Icons.expand_more_rounded, color: t.inkFaint),
                dropdownColor: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.control),
                items: items,
                onChanged: onChanged,
              ),
              if (helper != null && helper.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(helper,
                      style: AppType.caption.copyWith(color: t.inkFaint)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoTile(
  bool isDark, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String trailing,
}) {
  final t = _tk(isDark);
  return _tileRow(
    t,
    icon: icon,
    iconColor: iconColor,
    title: title,
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(
        trailing,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: AppType.body.copyWith(color: t.inkSoft),
      ),
    ),
  );
}

Widget _buildTextField(
  bool isDark, {
  required String label,
  required String value,
  required IconData icon,
  required void Function(String) onChanged,
  TextInputType? keyboardType,
  ui.TextDirection? textDirection,
  bool enabled = true,
}) {
  final t = _tk(isDark);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c, width: w),
      );
  return TextFormField(
    initialValue: value,
    keyboardType: keyboardType,
    textDirection: textDirection ?? ui.TextDirection.rtl,
    enabled: enabled,
    onChanged: onChanged,
    style: AppType.label.copyWith(color: t.ink),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: AppType.body.copyWith(color: t.inkFaint),
      prefixIcon: Icon(icon, size: 20, color: t.inkFaint),
      filled: true,
      fillColor: t.page,
      border: border(t.line),
      enabledBorder: border(t.line),
      disabledBorder: border(t.line.withValues(alpha: 0.6)),
      focusedBorder: border(t.brand, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

/// فاصل بين صفين: بيبدأ عند بداية النص (بعد مربع الأيقونة) مش من الحافة.
Widget _buildDivider(bool isDark) {
  return Divider(
    height: 1,
    thickness: 1,
    indent: _kTilePadH + _kTileIcon + _kTileGap,
    endIndent: 0,
    color: _tk(isDark).line,
  );
}

class _CollapsibleSection extends StatefulWidget {
  final bool isDark;
  final Color color;
  final Widget header;
  final Widget card;
  final bool initiallyExpanded;
  const _CollapsibleSection({
    required this.isDark,
    required this.color,
    required this.header,
    required this.card,
    required this.initiallyExpanded,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final t = _tk(widget.isDark);
    final headerBar = Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: BorderSide(color: t.line),
      ),
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: _kTilePadH, vertical: AppSpace.sm),
            child: Row(
              children: [
                Expanded(child: widget.header),
                if (!_open)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
                    child: Text('اضغط للفتح',
                        style: AppType.caption.copyWith(color: t.inkFaint)),
                  ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: t.inkSoft, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerBar,
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: widget.card,
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

// ─── Gender Chip ──────────────────────────────────────────────────────────

class _GenderChip extends StatelessWidget {
  final bool isDark;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? color
                    : (isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected
                    ? color
                    : (isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top-level helpers (unchanged logic) ──────────────────────────────────

Future<List<Student>?> _pickRecipients(
    BuildContext context, List<Student> all) async {
  return await showDialog<List<Student>>(
    context: context,
    builder: (ctx) {
      List<Student> items = List.of(all)
        ..sort((a, b) => a.name.compareTo(b.name));
      List<bool> sel = List<bool>.filled(items.length, true);
      bool selectAll = true;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('اختر أولياء الأمور',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: selectAll,
                  onChanged: (v) {
                    setState(() {
                      selectAll = v ?? false;
                      for (int i = 0; i < sel.length; i++) {
                        sel[i] = selectAll;
                      }
                    });
                  },
                  title: const Text('تحديد الكل',
                      style: TextStyle(fontFamily: 'Cairo')),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 0),
                SizedBox(
                  height: 360,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final s = items[i];
                      return CheckboxListTile(
                        value: sel[i],
                        onChanged: (v) => setState(() => sel[i] = v ?? false),
                        title: Text(s.name,
                            style: const TextStyle(fontFamily: 'Cairo')),
                        subtitle: Text(s.guardianPhone ?? '-',
                            style: const TextStyle(fontFamily: 'Cairo')),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: sel.any((e) => e)
                  ? () {
                      final chosen = <Student>[];
                      for (int i = 0; i < items.length; i++) {
                        if (sel[i]) chosen.add(items[i]);
                      }
                      Navigator.of(ctx).pop(chosen);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ابدأ الإرسال',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    },
  );
}
