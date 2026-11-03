// lib/widgets/student_form/form_sections.dart
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/phone_field.dart';
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
        // flex كبير للنص: الخط الفاصل ياخد الباقي بس، والنص مايتقصش إلا لو ضاق المكان.
        Flexible(
          flex: 8,
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: t.inkSoft)),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Divider(height: 1, color: t.line)),
        if (trailing != null) ...[
          const SizedBox(width: AppSpace.sm),
          Flexible(flex: 8, child: trailing!),
        ],
      ]),
    );
  }
}

/// سطر اسم الطالب وجنبه شريحة الكود؛ الضغط على الشريحة يفتح
/// [StudentCodeField] الكامل (سويتش يدوي + مسح QR) تحت السطر. الحالة
/// (لون/نص/أيقونة) بتيجي من الشاشة المستدعية.
class NameWithCodeRow extends StatefulWidget {
  final Widget nameField;
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

  const NameWithCodeRow({
    super.key,
    required this.nameField,
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
  State<NameWithCodeRow> createState() => _NameWithCodeRowState();
}

class _NameWithCodeRowState extends State<NameWithCodeRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = widget.boxColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: widget.nameField),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: c.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, size: 16, color: c),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(widget.chipText,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption
                          .copyWith(color: c, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                Icon(_open ? Icons.expand_less_rounded : Icons.edit_rounded,
                    size: 14, color: t.inkSoft),
              ]),
            ),
          ),
        ),
      ]),
      if (_open) ...[
        const SizedBox(height: 8),
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
      ],
    ]);
  }
}

/// رقم ولي الأمر + زر جهات الاتصال + زر واتساب؛ الضغط على الواتساب
/// بيظهر حقل «واتساب مختلف؟ (اختياري)» تحت الرقم.
class GuardianPhoneSection extends StatefulWidget {
  final TextEditingController phoneController;
  final TextEditingController whatsappController;
  final String dialCode;
  final String label;
  final VoidCallback onContactPick;

  const GuardianPhoneSection({
    super.key,
    required this.phoneController,
    required this.whatsappController,
    required this.dialCode,
    required this.label,
    required this.onContactPick,
  });

  @override
  State<GuardianPhoneSection> createState() => _GuardianPhoneSectionState();
}

class _GuardianPhoneSectionState extends State<GuardianPhoneSection> {
  late bool _open = widget.whatsappController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PhoneField(
        dense: true,
        controller: widget.phoneController,
        dialCode: widget.dialCode,
        label: widget.label,
        onContactPick: widget.onContactPick,
        extraActions: [
          Container(
            decoration: BoxDecoration(
              color: t.positive.withValues(alpha: _open ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: IconButton(
              tooltip: 'واتساب مختلف؟ (اختياري)',
              icon: Icon(Icons.chat_rounded, color: t.positive),
              onPressed: () => setState(() => _open = !_open),
            ),
          ),
        ],
      ),
      if (_open) ...[
        const SizedBox(height: 10),
        CustomTextField(
          dense: true,
          controller: widget.whatsappController,
          label: 'واتساب مختلف؟ (اختياري)',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        ),
      ],
    ]);
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
