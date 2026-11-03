// lib/widgets/student_form/form_sections.dart
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/student_form/student_code_field.dart';

/// عنوان قسم داخل فورم الطالب ("الأساسي" / "ولي الأمر" / "الاشتراك").
class FormSectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Widget? trailing;
  const FormSectionTitle(this.text,
      {super.key, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(children: [
        Icon(icon, size: 16, color: t.inkSoft),
        const SizedBox(width: 6),
        Text(text, style: AppType.label.copyWith(color: t.inkSoft)),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Divider(height: 1, color: t.line)),
        if (trailing != null) ...[
          const SizedBox(width: AppSpace.sm),
          Flexible(child: trailing!),
        ],
      ]),
    );
  }
}

/// كود الطالب كشريحة صغيرة؛ الضغط عليها يفتح [StudentCodeField] الكامل
/// (سويتش يدوي + مسح QR). الحالة (لون/نص/أيقونة) بتيجي من الشاشة
/// المستدعية زي ما كانت.
class CollapsibleCodeField extends StatefulWidget {
  final TextEditingController codeController;
  final bool isManual;
  final Color boxColor;
  final IconData icon;
  final String chipText;
  final String displayText;
  final String manualHint;
  final ValueChanged<bool> onManualChanged;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onScanQr;
  final VoidCallback? onReset;

  const CollapsibleCodeField({
    super.key,
    required this.codeController,
    required this.isManual,
    required this.boxColor,
    required this.icon,
    required this.chipText,
    required this.displayText,
    required this.manualHint,
    required this.onManualChanged,
    required this.onCodeChanged,
    required this.onScanQr,
    this.onReset,
  });

  @override
  State<CollapsibleCodeField> createState() => _CollapsibleCodeFieldState();
}

class _CollapsibleCodeFieldState extends State<CollapsibleCodeField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_open) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StudentCodeField(
          codeController: widget.codeController,
          isManual: widget.isManual,
          boxColor: widget.boxColor,
          icon: widget.icon,
          displayText: widget.displayText,
          manualHint: widget.manualHint,
          onManualChanged: widget.onManualChanged,
          onCodeChanged: widget.onCodeChanged,
          onScanQr: widget.onScanQr,
          onReset: widget.onReset,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => setState(() => _open = false),
            child: const Text('تم'),
          ),
        ),
      ]);
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: () => setState(() => _open = true),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.boxColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: widget.boxColor.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 16, color: widget.boxColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(widget.chipText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(
                      color: widget.boxColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_rounded, size: 14, color: t.inkSoft),
          ]),
        ),
      ),
    );
  }
}

/// قسم "خيارات إضافية" مطوي: بيعرض ملخص الحاجات المفعّلة (إعفاء/إخوة)
/// وهو مقفول.
class MoreOptionsPanel extends StatefulWidget {
  final List<String> summary;
  final bool initiallyOpen;
  final List<Widget> children;

  const MoreOptionsPanel({
    super.key,
    required this.summary,
    required this.children,
    this.initiallyOpen = false,
  });

  @override
  State<MoreOptionsPanel> createState() => _MoreOptionsPanelState();
}

class _MoreOptionsPanelState extends State<MoreOptionsPanel> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.page,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: t.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.sm),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 18, color: t.inkSoft),
              const SizedBox(width: AppSpace.sm),
              Text('خيارات إضافية',
                  style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  if (!_open)
                    for (final s in widget.summary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.positiveSoft,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(s,
                            style: AppType.caption.copyWith(
                                color: t.positive,
                                fontWeight: FontWeight.w700)),
                      ),
                ]),
              ),
              Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: t.inkSoft),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, 0, AppSpace.md, AppSpace.md),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children),
          ),
      ]),
    );
  }
}
