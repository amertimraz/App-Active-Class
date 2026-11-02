// lib/views/help/help_widgets.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/help/help_content.dart';
import 'package:active_class/utils/support_contact.dart';
import 'package:active_class/widgets/app_panel.dart';

/// نص فيه كلمات بين ** ** بتتعرض بخط عريض (أسماء الشاشات والأزرار).
class HelpRichText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle? boldStyle;
  const HelpRichText(this.text, {super.key, required this.style, this.boldStyle});

  @override
  Widget build(BuildContext context) {
    final bold = boldStyle ?? style.copyWith(fontWeight: FontWeight.w700);
    final parts = text.split('**');
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < parts.length; i++)
          if (parts[i].isNotEmpty)
            TextSpan(text: parts[i], style: i.isOdd ? bold : style),
      ]),
    );
  }
}

/// صف "لسه محتاج مساعدة؟" — بيفتح واتساب الدعم (واختياريًا بيذكر الموضوع).
class HelpSupportRow extends StatelessWidget {
  final String? topic;
  const HelpSupportRow({super.key, this.topic});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPanel(
      onTap: () => openSupportWhatsApp(topic: topic),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.positiveSoft,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(Icons.chat_rounded, color: t.positive),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('لسه محتاج مساعدة؟',
                  style: AppType.label.copyWith(color: t.ink)),
              Text('كلّم الدعم على واتساب',
                  style: AppType.caption.copyWith(color: t.inkSoft)),
            ],
          ),
        ),
        Icon(Icons.chevron_left_rounded, color: t.inkSoft),
      ]),
    );
  }
}

/// جسم الموضوع: تحذير (لو فيه)، الخطوات المرقّمة، النصايح. مشترك بين صفحة
/// الموضوع ونافذة المساعدة السريعة داخل الشاشات.
class HelpTopicBody extends StatelessWidget {
  final HelpTopic topic;
  const HelpTopicBody({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = AppType.body.copyWith(color: t.ink, height: 1.6);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (topic.warning != null) ...[
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: t.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(color: t.danger.withValues(alpha: 0.4)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded, color: t.danger),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: HelpRichText(topic.warning!,
                  style: body.copyWith(color: t.danger),
                  boldStyle: body.copyWith(
                      color: t.danger, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.lg),
      ],
      Text('الخطوات', style: AppType.label.copyWith(color: t.ink)),
      const SizedBox(height: AppSpace.sm),
      AppPanel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < topic.steps.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}',
                      style: AppType.label.copyWith(color: t.brand)),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(child: HelpRichText(topic.steps[i], style: body)),
              ]),
            ),
          ],
        ]),
      ),
      if (topic.tips.isNotEmpty) ...[
        const SizedBox(height: AppSpace.lg),
        Text('نصايح', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        AppPanel(
          child: Column(children: [
            for (var i = 0; i < topic.tips.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpace.sm),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 20, color: t.caution),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: HelpRichText(topic.tips[i], style: body)),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}

/// "هل الموضوع ده ساعدك؟" — نعم بتشكر، ولأ بتوصّله للدعم بالموضوع.
class HelpFeedback extends StatefulWidget {
  final HelpTopic topic;
  const HelpFeedback({super.key, required this.topic});
  @override
  State<HelpFeedback> createState() => _HelpFeedbackState();
}

class _HelpFeedbackState extends State<HelpFeedback> {
  bool? _helped;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_helped == true) {
      return AppPanel(
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: t.positive),
          const SizedBox(width: AppSpace.md),
          Expanded(
              child: Text('الحمد لله إنه ساعدك!',
                  style: AppType.label.copyWith(color: t.ink))),
        ]),
      );
    }
    if (_helped == false) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppPanel(
          child: Text('آسفين إن الشرح ما كفاش. ابعتلنا سؤالك وهنساعدك.',
              style: AppType.body.copyWith(color: t.ink, height: 1.5)),
        ),
        const SizedBox(height: AppSpace.sm),
        HelpSupportRow(topic: widget.topic.title),
      ]);
    }
    return AppPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('هل الموضوع ده ساعدك؟',
            style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _helped = true),
              icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
              label: const Text('أيوه'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: t.positive,
                  side: BorderSide(color: t.line),
                  minimumSize: const Size(44, 44)),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _helped = false),
              icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
              label: const Text('لأ'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: t.danger,
                  side: BorderSide(color: t.line),
                  minimumSize: const Size(44, 44)),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// زر "؟" في شريط أي شاشة: بيفتح شرح الشاشة دي في نافذة سريعة.
class HelpButton extends StatelessWidget {
  final String topicId;
  const HelpButton({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'مساعدة',
        icon: const Icon(Icons.help_outline_rounded),
        onPressed: () => showHelpSheet(context, topicId),
      );
}

/// نافذة مساعدة سريعة لموضوع من داخل أي شاشة.
Future<void> showHelpSheet(BuildContext context, String topicId) {
  final topic = helpTopicById(topicId);
  if (topic == null) return Future.value();
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.page,
    showDragHandle: true,
    constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
            shrinkWrap: true,
            children: [
              Row(children: [
                Icon(topic.icon, color: t.brand),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(topic.title,
                      style: AppType.title.copyWith(color: t.ink)),
                ),
              ]),
              const SizedBox(height: AppSpace.xs),
              Text(topic.summary,
                  style: AppType.body.copyWith(color: t.inkSoft, height: 1.5)),
              const SizedBox(height: AppSpace.lg),
              HelpTopicBody(topic: topic),
            ],
          ),
        ),
        // الأزرار ثابتة تحت النافذة (مش جوه التمرير).
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Get.toNamed(ROUTE_HELP_TOPIC, arguments: topic.id);
                },
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('افتح الموضوع كامل'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: t.brand,
                    side: BorderSide(color: t.line),
                    minimumSize: const Size(44, 48)),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            IconButton(
              tooltip: 'كلّم الدعم',
              onPressed: () => openSupportWhatsApp(topic: topic.title),
              icon: Icon(Icons.chat_rounded, color: t.positive),
              style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  side: BorderSide(color: t.line)),
            ),
          ]),
        ),
      ]),
    ),
  );
}
