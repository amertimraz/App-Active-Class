// lib/widgets/chalk_dialog.dart
//
// نافذة حوار موحّدة بتصميم السبورة والطباشير: أيقونة + عنوان، محتوى بيتمرّر،
// وأزرار تحت (خارج منطقة التمرير) بحجم لمس مريح وبترتيب ثابت:
// الأساسي، ثم الخطر، ثم الإلغاء.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';

enum ChalkTone { neutral, caution, danger }

enum ChalkActionKind {
  /// الزر الأساسي (ممتلئ بلون الهوية).
  primary,

  /// ممتلئ بلون الخطر (تأكيد مسح نهائي).
  dangerFilled,

  /// إطار أحمر (إجراء خطر ثانوي).
  dangerOutlined,

  /// نص بسيط (إلغاء/رجوع).
  text,
}

class ChalkAction {
  final String label;
  final IconData? icon;
  final ChalkActionKind kind;
  final VoidCallback onPressed;
  const ChalkAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ChalkActionKind.primary,
  });
}

/// سطر قاعدة/شرح: أيقونة + نص.
class ChalkRule extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const ChalkRule({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color ?? t.inkSoft),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(text,
              style: AppType.body.copyWith(color: t.ink, height: 1.5)),
        ),
      ]),
    );
  }
}

class ChalkDialog extends StatelessWidget {
  final IconData icon;
  final ChalkTone tone;
  final String title;
  final String? subtitle;
  final List<Widget> body;
  final List<ChalkAction> actions;

  const ChalkDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.actions,
    this.subtitle,
    this.tone = ChalkTone.neutral,
    this.body = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (Color tint, Color ink) = switch (tone) {
      ChalkTone.neutral => (t.rosterTint, t.rosterInk),
      ChalkTone.caution => (t.cautionSoft, t.caution),
      ChalkTone.danger => (t.dangerSoft, t.danger),
    };
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      backgroundColor: t.surface,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        side: BorderSide(color: t.line),
      ),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: maxH, maxWidth: 440, minWidth: 440),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: tint,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.control)),
                          child: Icon(icon, color: ink, size: 24),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style:
                                        AppType.title.copyWith(color: t.ink)),
                                if (subtitle != null && subtitle!.isNotEmpty)
                                  Text(subtitle!,
                                      style: AppType.caption
                                          .copyWith(color: t.inkSoft)),
                              ]),
                        ),
                      ]),
                      if (body.isNotEmpty) const SizedBox(height: AppSpace.lg),
                      ...body,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0)
                      SizedBox(
                          height: actions[i].kind == ChalkActionKind.text
                              ? AppSpace.xs
                              : AppSpace.sm),
                    _button(t, actions[i]),
                  ],
                ]),
              ),
            ]),
      ),
    );
  }

  Widget _button(AppTokens t, ChalkAction a) {
    final label = Text(a.label, textAlign: TextAlign.center);
    const size = Size(double.infinity, 52);
    switch (a.kind) {
      case ChalkActionKind.primary:
        return FilledButton.icon(
          onPressed: a.onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: t.brand, minimumSize: size),
          icon: Icon(a.icon ?? Icons.check_rounded),
          label: label,
        );
      case ChalkActionKind.dangerFilled:
        return FilledButton.icon(
          onPressed: a.onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: t.danger, minimumSize: size),
          icon: Icon(a.icon ?? Icons.delete_forever_rounded),
          label: label,
        );
      case ChalkActionKind.dangerOutlined:
        return OutlinedButton.icon(
          onPressed: a.onPressed,
          style: OutlinedButton.styleFrom(
              foregroundColor: t.danger,
              side: BorderSide(color: t.danger),
              minimumSize: size),
          icon: Icon(a.icon ?? Icons.delete_outline_rounded),
          label: label,
        );
      case ChalkActionKind.text:
        return TextButton(
          onPressed: a.onPressed,
          style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48)),
          child: label,
        );
    }
  }
}

/// نافذة تأكيد بسيطة (عنوان + رسالة + تأكيد/إلغاء) بنفس التصميم.
/// بترجّع true لو المستخدم أكّد، وfalse لو ألغى أو قفلها.
/// [destructive]: التأكيد بلون الخطر (مسح/إجراء مش بيترجع فيه).
Future<bool> showChalkConfirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String? subtitle,
  IconData? confirmIcon,
  String cancelLabel = 'إلغاء',
  bool destructive = false,
  ChalkTone tone = ChalkTone.neutral,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: ChalkDialog(
        icon: icon,
        tone: destructive ? ChalkTone.danger : tone,
        title: title,
        subtitle: subtitle,
        body: [
          Text(message,
              style: AppType.body
                  .copyWith(color: ctx.tokens.ink, height: 1.6)),
        ],
        actions: [
          ChalkAction(
            label: confirmLabel,
            icon: confirmIcon ??
                (destructive
                    ? Icons.delete_forever_rounded
                    : Icons.check_rounded),
            kind: destructive
                ? ChalkActionKind.dangerFilled
                : ChalkActionKind.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          ChalkAction(
            label: cancelLabel,
            kind: ChalkActionKind.text,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  return result == true;
}
