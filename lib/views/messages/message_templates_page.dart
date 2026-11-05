// lib/views/messages/message_templates_page.dart
//
// «رسائلي المحفوظة»: المعلم يكتب رسايل واتساب جاهزة (حصة ملغية، نتيجة
// امتحان، مستوى الطالب…) ويعدّلها ويكرّرها ويمسحها. بتتبعت من زر الواتساب
// في الطالب والمجموعة. محلية على جهاز المعلم.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/message_template_controller.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/message_templates.dart';
import 'package:active_class/views/messages/message_template_editor_page.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

class MessageTemplatesPage extends StatelessWidget {
  const MessageTemplatesPage({super.key});

  MessageTemplateController get _c =>
      Get.isRegistered<MessageTemplateController>()
          ? Get.find<MessageTemplateController>()
          : Get.put(MessageTemplateController());

  Future<void> _edit(MessageTemplate? t) async {
    await Get.to(() => MessageTemplateEditorPage(existing: t));
  }

  Future<void> _delete(BuildContext context, MessageTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الرسالة؟'),
        content: Text('هتتمسح «${t.title}».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('حذف', style: TextStyle(color: context.tokens.danger))),
        ],
      ),
    );
    if (ok == true && t.id != null) {
      await _c.delete(t.id!);
      ToastHelper.success('اتمسحت الرسالة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _c;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'رسائلي المحفوظة'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('رسالة جديدة'),
      ),
      body: Obx(() {
        final list = c.templates.toList();
        if (c.loading.value && list.isEmpty) {
          return Center(child: CircularProgressIndicator(color: t.brand));
        }
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 56, color: t.inkFaint),
                const SizedBox(height: AppSpace.lg),
                Text('لسه مفيش رسايل محفوظة',
                    style: AppType.title.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.xs),
                Text('اكتب رسالة جاهزة وابعتها لولي الأمر أو الطالب بضغطة.',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: t.inkSoft)),
              ]),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
              120 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text(
                'الرسايل دي بتظهر لما تدوس زر الواتساب جنب الطالب أو في المجموعة. '
                'المتغيّرات زي {اسم_الطالب} بتتعبّى تلقائيًا.',
                style: AppType.caption.copyWith(color: t.inkSoft)),
            const SizedBox(height: AppSpace.md),
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: AppPanel(
                  onTap: () => _edit(m),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(m.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppType.label.copyWith(color: t.ink)),
                              ),
                              const SizedBox(width: AppSpace.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 1),
                                decoration: BoxDecoration(
                                  color: t.rosterTint,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.chip),
                                ),
                                child: Text(m.category.label,
                                    style: AppType.caption
                                        .copyWith(color: t.rosterInk)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(m.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.body.copyWith(color: t.inkSoft)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'المزيد',
                        icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
                        onSelected: (v) async {
                          if (v == 'edit') await _edit(m);
                          if (v == 'dup') {
                            await _c.duplicate(m);
                            ToastHelper.success('اتعمل نسخة');
                          }
                          if (v == 'del') await _delete(context, m);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('تعديل')),
                          const PopupMenuItem(
                              value: 'dup', child: Text('تكرار')),
                          PopupMenuItem(
                              value: 'del',
                              child: Text('حذف',
                                  style: TextStyle(color: t.danger))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
