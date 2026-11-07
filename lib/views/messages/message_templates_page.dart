// lib/views/messages/message_templates_page.dart
//
// «قوالب الرسائل»: قسمين —
//  1) رسائل البرنامج التلقائية (تنبيه غياب، إيصال، تذكير دفع…): المعلم يشوف
//     نصها الحالي ويعدّله أو يرجّعه للأصلي.
//  2) رسائلي: رسايل جاهزة يكتبها المعلم ويضيف منها (حصة ملغية، نتيجة
//     امتحان…) وبتتبعت من زر الواتساب في الطالب والمجموعة.
// محلية على جهاز المعلم.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/widgets/chalk_dialog.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/message_template_controller.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/message_templates.dart';
import 'package:active_class/utils/system_messages.dart';
import 'package:active_class/views/messages/message_template_editor_page.dart';
import 'package:active_class/views/messages/system_message_editor_page.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

const Map<String, IconData> _sysIcons = {
  'absence': Icons.person_off_rounded,
  'late': Icons.schedule_rounded,
  'payment_reminder': Icons.payments_rounded,
  'receipt': Icons.receipt_long_rounded,
  'statement': Icons.description_rounded,
  'exam_result': Icons.fact_check_rounded,
  'booklet_reminder': Icons.menu_book_rounded,
  'portal_invite': Icons.link_rounded,
};

class MessageTemplatesPage extends StatefulWidget {
  const MessageTemplatesPage({super.key});

  @override
  State<MessageTemplatesPage> createState() => _MessageTemplatesPageState();
}

class _MessageTemplatesPageState extends State<MessageTemplatesPage> {
  MessageTemplateController get _c =>
      Get.isRegistered<MessageTemplateController>()
          ? Get.find<MessageTemplateController>()
          : Get.put(MessageTemplateController());

  Future<void> _edit(MessageTemplate? t) async {
    await Get.to(() => MessageTemplateEditorPage(existing: t));
  }

  Future<void> _editSystem(SystemMessageDef d) async {
    await Get.to(() => SystemMessageEditorPage(def: d));
    if (mounted) setState(() {});
  }

  Future<void> _delete(BuildContext context, MessageTemplate t) async {
    final ok = await showChalkConfirm(
      context,
      icon: Icons.chat_rounded,
      title: 'حذف الرسالة؟',
      message: 'هتتمسح «${t.title}».',
      confirmLabel: 'حذف',
      destructive: true,
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
      appBar: buildBoardAppBar(context, title: 'قوالب الرسائل'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('رسالة جديدة'),
      ),
      body: Obx(() {
        final list = c.templates.toList();
        return ListView(
          padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
              120 + MediaQuery.paddingOf(context).bottom),
          children: [
            _SectionHeader(
              title: 'رسائل البرنامج',
              subtitle:
                  'الرسائل اللي التطبيق بيبعتها لولي الأمر تلقائيًا. افتح أي '
                  'واحدة تشوف نصها وعدّله على مزاجك.',
            ),
            for (final d in kSystemMessageDefs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: _SystemCard(def: d, onTap: () => _editSystem(d)),
              ),
            const SizedBox(height: AppSpace.lg),
            _SectionHeader(
              title: 'رسائلي',
              subtitle:
                  'رسايل جاهزة تكتبها بنفسك وتبعتها من زر الواتساب جنب الطالب '
                  'أو في المجموعة. المتغيّرات زي {اسم_الطالب} بتتعبّى تلقائيًا.',
            ),
            if (c.loading.value && list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Center(
                    child: CircularProgressIndicator(color: t.brand)),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Text(
                    'لسه مفيش رسايل محفوظة. اضغط «رسالة جديدة» وأضف قالب '
                    'على حسب نوع الرسالة.',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: t.inkSoft)),
              )
            else
              for (final m in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: _UserCard(
                    m: m,
                    onEdit: () => _edit(m),
                    onDuplicate: () async {
                      await _c.duplicate(m);
                      ToastHelper.success('اتعمل نسخة');
                    },
                    onDelete: () => _delete(context, m),
                  ),
                ),
          ],
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppType.title.copyWith(color: t.ink)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppType.caption.copyWith(color: t.inkSoft)),
      ]),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final SystemMessageDef def;
  final VoidCallback onTap;
  const _SystemCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final custom = SystemMessages.isCustomized(def.id);
    return AppPanel(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.rosterTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(_sysIcons[def.id] ?? Icons.chat_rounded,
              color: t.rosterInk, size: 22),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(def.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
              ),
              if (custom) ...[
                const SizedBox(width: AppSpace.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.positiveSoft,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text('معدّلة',
                      style: AppType.caption.copyWith(color: t.positive)),
                ),
              ],
            ]),
            Text(def.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption.copyWith(color: t.inkSoft)),
          ]),
        ),
        Icon(Icons.chevron_left_rounded, color: t.inkFaint),
      ]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final MessageTemplate m;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  const _UserCard({
    required this.m,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPanel(
      onTap: onEdit,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
              ),
              const SizedBox(width: AppSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: t.rosterTint,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(m.category.label,
                    style: AppType.caption.copyWith(color: t.rosterInk)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(m.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(color: t.inkSoft)),
          ]),
        ),
        PopupMenuButton<String>(
          tooltip: 'المزيد',
          icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'dup') onDuplicate();
            if (v == 'del') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'dup', child: Text('تكرار')),
            PopupMenuItem(
                value: 'del',
                child: Text('حذف', style: TextStyle(color: t.danger))),
          ],
        ),
      ]),
    );
  }
}
