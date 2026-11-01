// lib/widgets/app_panel.dart
import 'package:flutter/material.dart';
import 'package:active_class/config/theme.dart';

/// الوحدة الأساسية للمحتوى: سطح بحد رفيع بلا ظل.
class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? lineColor;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.onTap,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: BorderSide(color: lineColor ?? t.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// صينية لون القسم: بتجمع كروته البيضا، فاللون بيفرّق الأقسام من غير ما
/// كل كارت يتحوّل لخلية ملوّنة.
class AppTray extends StatelessWidget {
  final Color color;
  final Widget child;

  const AppTray({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.board),
      ),
      child: child,
    );
  }
}

/// رقم كبير وتحته اسمه فوق السبورة (حاضر / غائب ...).
class BoardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const BoardStat(
      {super.key,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: AppType.figure.copyWith(color: color)),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label,
            maxLines: 1,
            style: AppType.caption.copyWith(color: t.boardInkSoft)),
      ),
    ]);
  }
}

class AppSegmentItem {
  final String value;
  final String label;
  final IconData icon;
  final Color ink;
  const AppSegmentItem(this.value, this.label, this.icon, this.ink);
}

/// عنصر تحكّم مجزّأ متصل: يُختار واحد، والضغط على المختار يمسحه (يرجع
/// "غير مسجّل"). بيتستعمل للحضور وللواجب.
class AppSegmented extends StatelessWidget {
  final String? value;
  final List<AppSegmentItem> items;
  final ValueChanged<String?> onSelect;
  // اسم صاحب الصف (طالب مثلًا) بيتضاف لوصف كل خانة لقارئ الشاشة.
  final String? subject;
  // مضغوط للصفوف الكتير: ارتفاع وخط وأيقونات أصغر.
  final bool dense;

  const AppSegmented(
      {super.key,
      this.subject,
      this.dense = false,
      required this.value,
      required this.items,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // نص الخانة المختارة: أبيض على الفاتح، وغامق على الداكن (ألوان الداكن فاتحة).
    final onInk =
        Theme.of(context).brightness == Brightness.dark ? t.page : Colors.white;

    final h = dense ? 38.0 : 44.0;
    final iconSize = dense ? 15.0 : 18.0;
    final textStyle = dense ? AppType.caption : AppType.body;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Container(width: 1, height: h, color: t.line),
          Expanded(
            child: Semantics(
              button: true,
              selected: value == items[i].value,
              label: subject == null
                  ? items[i].label
                  : '${items[i].label} — $subject',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onSelect(
                    value == items[i].value ? null : items[i].value),
                child: Container(
                  height: h,
                  alignment: Alignment.center,
                  color: value == items[i].value
                      ? items[i].ink
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(items[i].icon,
                          size: iconSize,
                          color: value == items[i].value
                              ? onInk
                              : items[i].ink),
                      const SizedBox(width: AppSpace.xs),
                      Text(items[i].label,
                          maxLines: 1,
                          style: textStyle.copyWith(
                              fontWeight: value == items[i].value
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: value == items[i].value
                                  ? onInk
                                  : t.inkSoft)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// ثلاث أزرار أيقونات صغيرة جنب بعض (حاضر/متأخر/غائب مثلًا) للصف الواحد:
/// المختار بيتلوّن، والضغط عليه تاني بيمسحه. المعنى بيتشرح مرة في وسيلة إيضاح
/// فوق القايمة، وكل زرار ليه Tooltip ووصف لقارئ الشاشة.
class AppStatusPicker extends StatelessWidget {
  final String? value;
  final List<AppSegmentItem> items;
  final ValueChanged<String?> onSelect;
  final String? subject;

  const AppStatusPicker({
    super.key,
    required this.value,
    required this.items,
    required this.onSelect,
    this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onInk =
        Theme.of(context).brightness == Brightness.dark ? t.page : Colors.white;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 6),
          child: Semantics(
            button: true,
            selected: value == items[i].value,
            label: subject == null
                ? items[i].label
                : '${items[i].label} — $subject',
            excludeSemantics: true,
            child: Tooltip(
              message: items[i].label,
              child: Material(
                color: value == items[i].value
                    ? items[i].ink
                    : Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  side: BorderSide(
                      color: value == items[i].value
                          ? items[i].ink
                          : t.line),
                ),
                child: InkWell(
                  onTap: () => onSelect(
                      value == items[i].value ? null : items[i].value),
                  child: SizedBox(
                    width: 42,
                    height: 40,
                    child: Icon(items[i].icon,
                        size: 20,
                        color: value == items[i].value
                            ? onInk
                            : items[i].ink),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// زرار أيقونة فوق السبورة (أسهم التنقل مثلًا) بمقاس لمس 44.
class BoardIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const BoardIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 24,
      color: t.boardInk,
      disabledColor: t.boardInkSoft.withValues(alpha: 0.4),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}
