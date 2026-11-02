// lib/views/help/help_center_page.dart
//
// مركز المساعدة: بحث بالعامّية + مواضيع مقسّمة بفئات، وكل موضوع نص وخطوات.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/help/help_content.dart';
import 'package:active_class/utils/help_search.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});
  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(HelpTopic t) => Get.toNamed(ROUTE_HELP_TOPIC, arguments: t.id);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final query = _search.text.trim();
    final results = query.isEmpty ? const <HelpTopic>[] : searchHelp(query);

    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'المساعدة'),
      body: ColoredBox(
        color: t.page,
        child: Column(children: [
          // السبورة: سؤال + بحث
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
            decoration: BoxDecoration(
              color: t.board,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.board)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عايز تعمل إيه؟',
                    style: AppType.title.copyWith(color: t.boardInk)),
                const SizedBox(height: AppSpace.xs),
                Text('اكتب سؤالك أو اختار موضوع من تحت.',
                    style: AppType.body.copyWith(color: t.boardInkSoft)),
                const SizedBox(height: AppSpace.md),
                CustomSearchBar(
                  controller: _search,
                  hintText: 'مثلًا: إزاي أسجل دفعة؟',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _search.clear();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: query.isEmpty
                  ? _browse(t)
                  : _resultsList(t, query, results),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _browse(AppTokens t) {
    return [
      Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
        for (final q in kHelpSuggestions)
          ActionChip(
            label: Text(q, style: AppType.caption.copyWith(color: t.ink)),
            backgroundColor: t.surface,
            side: BorderSide(color: t.line),
            onPressed: () => _search.text = q,
          ),
      ]),
      _header(t, 'الأكثر استخدامًا'),
      for (final id in kHelpPopular)
        if (helpTopicById(id) != null)
          _TopicRow(
              topic: helpTopicById(id)!,
              onTap: () => _open(helpTopicById(id)!)),
      for (final c in HelpCategory.values) ...[
        _header(t, '${c.title}  (${kHelpTopics.where((x) => x.category == c).length})'),
        for (final topic in kHelpTopics.where((x) => x.category == c))
          _TopicRow(topic: topic, onTap: () => _open(topic)),
      ],
      const SizedBox(height: AppSpace.lg),
      const HelpSupportRow(),
      const SizedBox(height: AppSpace.xl),
    ];
  }

  List<Widget> _resultsList(AppTokens t, String query, List<HelpTopic> r) {
    if (r.isEmpty) {
      return [
        const SizedBox(height: AppSpace.xl),
        Icon(Icons.search_off_rounded, size: 48, color: t.inkFaint),
        const SizedBox(height: AppSpace.md),
        Text('ما لقيناش موضوع بالكلام ده',
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.xs),
        Text('جرّب كلمة تانية (مثلًا: حضور، دفعة، تسميع) أو كلّم الدعم.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: t.inkSoft)),
        const SizedBox(height: AppSpace.lg),
        HelpSupportRow(topic: query),
      ];
    }
    return [
      _header(t, '${r.length} نتيجة'),
      for (final topic in r) _TopicRow(topic: topic, onTap: () => _open(topic)),
      const SizedBox(height: AppSpace.lg),
      HelpSupportRow(topic: query),
      const SizedBox(height: AppSpace.xl),
    ];
  }

  Widget _header(AppTokens t, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm),
        child: Text(title, style: AppType.label.copyWith(color: t.ink)),
      );
}

class _TopicRow extends StatelessWidget {
  final HelpTopic topic;
  final VoidCallback onTap;
  const _TopicRow({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(topic.icon, color: t.brand, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
                Text(topic.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: t.inkSoft)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 13, color: t.inkFaint),
                  const SizedBox(width: 4),
                  Text(
                      topic.readMinutes == 1
                          ? 'أقل من دقيقة'
                          : '${topic.readMinutes} دقايق',
                      style: AppType.caption.copyWith(color: t.inkFaint)),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: t.inkSoft),
        ]),
      ),
    );
  }
}
