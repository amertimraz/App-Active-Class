// lib/views/help/help_topic_page.dart
//
// موضوع مساعدة: ملخص، تحذير (لو فيه)، خطوات مرقّمة، نصايح، وزر يفتح الشاشة
// المعنية، ومواضيع مرتبطة، و"هل ساعدك؟" مع طريق للدعم.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/help/help_content.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

class HelpTopicPage extends StatelessWidget {
  /// موضوع مباشر (اختبارات)، أو [topicId] اللي بيتقرأ وقت بناء المسار — مش من
  /// Get.arguments وقت الرسم، عشان صفحة تحت صفحة تانية ما تغيّرش موضوعها.
  final HelpTopic? topic;
  final String? topicId;
  const HelpTopicPage({super.key, this.topic, this.topicId});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final args = Get.arguments;
    final topic = this.topic ??
        (topicId != null ? helpTopicById(topicId!) : null) ??
        (args is String ? helpTopicById(args) : null);

    if (topic == null) {
      return Scaffold(
        backgroundColor: t.page,
        appBar: buildBoardAppBar(context, title: 'المساعدة'),
        body: Center(
          child: Text('الموضوع ده مش موجود',
              style: AppType.title.copyWith(color: t.inkSoft)),
        ),
      );
    }

    final related = [
      for (final id in topic.related)
        if (helpTopicById(id) != null) helpTopicById(id)!,
    ];

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: topic.title),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          // الملخص + وقت القراءة
          AppPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(topic.icon, color: t.brand),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(topic.summary,
                      style: AppType.body.copyWith(color: t.ink, height: 1.6)),
                ),
              ]),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.md,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 16, color: t.inkSoft),
                    const SizedBox(width: 4),
                    Text(
                        topic.readMinutes == 1
                            ? 'قراءة أقل من دقيقة'
                            : 'قراءة ${topic.readMinutes} دقايق',
                        style: AppType.caption.copyWith(color: t.inkSoft)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.format_list_numbered_rounded,
                        size: 16, color: t.inkSoft),
                    const SizedBox(width: 4),
                    Text('${topic.steps.length} خطوات',
                        style: AppType.caption.copyWith(color: t.inkSoft)),
                  ]),
                ],
              ),
            ]),
          ),
          if (topic.route != null) ...[
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: () => Get.toNamed(topic.route!),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              label: Text(topic.routeLabel ?? 'افتح الشاشة دي',
                  style: AppType.label.copyWith(color: t.onChalk)),
              style: FilledButton.styleFrom(
                  backgroundColor: t.chalk,
                  foregroundColor: t.onChalk,
                  minimumSize: const Size(44, 48)),
            ),
          ],

          const SizedBox(height: AppSpace.lg),
          HelpTopicBody(topic: topic),

          // مواضيع مرتبطة
          if (related.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            Text('مواضيع مرتبطة', style: AppType.label.copyWith(color: t.ink)),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
              for (final r in related)
                ActionChip(
                  avatar: Icon(r.icon, size: 18, color: t.brand),
                  label: Text(r.title,
                      style: AppType.caption.copyWith(color: t.ink)),
                  backgroundColor: t.surface,
                  side: BorderSide(color: t.line),
                  // نفس المسار مفتوح بالفعل: preventDuplicates:false وإلا GetX
                  // بيتجاهل الضغطة.
                  onPressed: () => Get.toNamed(ROUTE_HELP_TOPIC,
                      arguments: r.id, preventDuplicates: false),
                ),
            ]),
          ],

          const SizedBox(height: AppSpace.lg),
          HelpFeedback(topic: topic),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }
}
