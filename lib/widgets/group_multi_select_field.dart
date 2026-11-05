// lib/widgets/group_multi_select_field.dart
//
// حقل «المجموعات»: شكله قائمة منسدلة، وبيفتح ورقة فيها المجموعات بعلامات
// اختيار (أكتر من مجموعة للامتحان/اللعبة الواحدة) مع «تحديد الكل» و«مسح».
// المجموعات المختارة بتظهر تحت الحقل كشرائح تتشال بضغطة.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/group_model.dart';

class GroupMultiSelectField extends StatelessWidget {
  final List<Group> groups;
  final Set<int> selected;

  /// بيتنادى بنسخة جديدة من الاختيار كل ما يتغيّر.
  final ValueChanged<Set<int>> onChanged;

  /// عنوان الورقة.
  final String title;

  /// لو true والاختيار فاضي الحقل بيتلوّن بالأحمر (مجموعة واحدة على الأقل).
  final bool required;

  /// نص الحقل لما مفيش اختيار.
  final String emptyHint;

  const GroupMultiSelectField({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
    this.title = 'اختار المجموعات',
    this.required = false,
    this.emptyHint = 'اختار مجموعة أو أكتر',
  });

  Color _colorOf(Group g) => Color(g.color ?? 0xFF4F46E5);

  String get _summary {
    if (groups.isEmpty) return 'مفيش مجموعات — أضف مجموعة الأول';
    final names =
        groups.where((g) => selected.contains(g.id)).map((g) => g.name).toList();
    if (names.isEmpty) return emptyHint;
    if (names.length == 1) return names.first;
    return '${names.length} مجموعات';
  }

  Future<void> _open(BuildContext context) async {
    if (groups.isEmpty) return;
    final t = context.tokens;
    var current = Set<int>.of(selected);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(builder: (ctx, setSheet) {
          void update(Set<int> next) {
            current = next;
            setSheet(() {});
            onChanged(Set<int>.of(next));
          }

          final allIds = {for (final g in groups) if (g.id != null) g.id!};
          return ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
                  child: Row(children: [
                    Expanded(
                      child: Text(title,
                          style: AppType.title.copyWith(color: t.ink)),
                    ),
                    TextButton(
                      onPressed: () => update(current.length == allIds.length
                          ? <int>{}
                          : Set<int>.of(allIds)),
                      child: Text(current.length == allIds.length
                          ? 'مسح الكل'
                          : 'تحديد الكل'),
                    ),
                  ]),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final g in groups)
                        CheckboxListTile(
                          value: current.contains(g.id),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg),
                          secondary: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: _colorOf(g), shape: BoxShape.circle),
                          ),
                          title: Text(g.name,
                              style: AppType.label.copyWith(color: t.ink)),
                          onChanged: (v) {
                            final next = Set<int>.of(current);
                            if (v == true) {
                              next.add(g.id!);
                            } else {
                              next.remove(g.id);
                            }
                            update(next);
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50)),
                      child: Text(current.isEmpty
                          ? 'تم'
                          : 'تم (${current.length} مختارة)'),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final empty = selected.isEmpty;
    final warn = required && empty && groups.isNotEmpty;
    final chosen = groups.where((g) => selected.contains(g.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'المجموعات — $_summary',
          excludeSemantics: true,
          child: Material(
            color: t.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              side: BorderSide(color: warn ? t.danger : t.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: groups.isEmpty ? null : () => _open(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md + 2, vertical: AppSpace.sm),
                  child: Row(children: [
                    Icon(Icons.groups_rounded,
                        size: 22, color: warn ? t.danger : t.brand),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(_summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(
                              fontWeight:
                                  empty ? FontWeight.w400 : FontWeight.w700,
                              color: warn
                                  ? t.danger
                                  : (empty ? t.inkFaint : t.ink))),
                    ),
                    Icon(Icons.expand_more_rounded,
                        color: t.inkFaint, size: 24),
                  ]),
                ),
              ),
            ),
          ),
        ),
        if (warn)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs, right: 4),
            child: Text('اختار مجموعة واحدة على الأقل',
                style: AppType.caption.copyWith(color: t.danger)),
          ),
        if (chosen.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                for (final g in chosen)
                  InputChip(
                    label: Text(g.name,
                        style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700, color: t.ink)),
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _colorOf(g), shape: BoxShape.circle),
                    ),
                    backgroundColor: t.surface,
                    side: BorderSide(color: t.line),
                    visualDensity: VisualDensity.compact,
                    deleteButtonTooltipMessage: 'شيل ${g.name}',
                    onDeleted: () => onChanged(
                        Set<int>.of(selected)..remove(g.id)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
