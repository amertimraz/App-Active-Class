part of '../settings_page.dart';

// spec 051 — مشترَكات الإعدادات (نقل حرفي من settings_page.dart)

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
  final header = Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white70 : const Color(0xFF374151),
        ),
      ),
    ],
  );

  final card = Container(
    decoration: BoxDecoration(
      color: isDark
          ? const Color(0xFF131D31).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.9),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.18)
              : const Color(0xFFD8E0F0).withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(children: children),
  );

  if (!collapsible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: header,
        ),
        card,
      ],
    );
  }

  // قسم قابل للطي — ترويسة واضحة (كارت + سهم كبير ملوّن + "اضغط للفتح")
  // بدل السهم الرمادي الصغير القديم.
  return _CollapsibleSection(
    isDark: isDark,
    color: color,
    header: header,
    card: card,
    initiallyExpanded: initiallyExpanded,
  );
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
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Obx(() => Switch(
              value: rxValue.value,
              onChanged: onChanged,
              activeColor: iconColor,
            )),
      ],
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
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor ??
                        (isDark ? Colors.white : const Color(0xFF111827)),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color:
                          isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isDark ? Colors.grey[500] : const Color(0xFF9CA3AF),
          ),
        ],
      ),
    ),
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
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
              DropdownButtonFormField<T>(
                value: value,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: items,
                onChanged: onChanged,
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
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
      ],
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
  return TextFormField(
    initialValue: value,
    keyboardType: keyboardType,
    textDirection: textDirection ?? ui.TextDirection.rtl,
    enabled: enabled,
    onChanged: onChanged,
    style: TextStyle(
      fontFamily: 'Cairo',
      fontSize: 14,
      color: isDark ? Colors.white : const Color(0xFF111827),
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
      ),
      prefixIcon: Icon(icon,
          size: 18, color: isDark ? Colors.grey[400] : const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF8FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

Widget _buildDivider(bool isDark) {
  return Divider(
    height: 1,
    indent: 52,
    endIndent: 16,
    color:
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE5E7EB),
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
    final headerBar = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE7E9F3),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: widget.header),
            if (!_open)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('اضغط للفتح',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: widget.color.withValues(alpha: 0.75))),
              ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: widget.color, size: 22),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerBar,
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
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

// ─── Helper Widgets ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.16)
                  : const Color(0xFFD9E1F2).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
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
