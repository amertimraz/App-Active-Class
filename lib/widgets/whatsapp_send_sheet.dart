// lib/widgets/whatsapp_send_sheet.dart
//
// ورقة إرسال رسالة واتساب من الرسائل المحفوظة:
//  - من طالب: يختار لمين (ولي الأمر / الطالب نفسه / الاتنين) والرسالة، وتتعبّى
//    متغيّراتها (الدرجة، المستوى بشرايح)، ويعدّل النص لو حب، ويبعت.
//  - من مجموعة: الرسالة بتتنسخ ويتفتح جروب المجموعة بالرابط المحفوظ (واتساب
//    مابيسمحش بنص جاهز في روابط الجروبات، فبتلصقه المعلم في الجروب).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/message_template_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/message_templates.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/utils/whatsapp_targets.dart';
import 'package:active_class/views/messages/message_templates_page.dart';

/// من الطالب: ولي الأمر / الطالب / الاتنين.
Future<void> showStudentWhatsappSheet(BuildContext context, Student student) =>
    _show(context, student: student);

/// من المجموعة: فتح الجروب بالرابط ونسخ الرسالة.
Future<void> showGroupWhatsappSheet(BuildContext context, Group group,
        {MessageCategory? preferCategory}) =>
    _show(context, group: group, preferCategory: preferCategory);

Future<void> _show(BuildContext context,
    {Student? student, Group? group, MessageCategory? preferCategory}) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: t.surface,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _WhatsappSheet(
          student: student, group: group, preferCategory: preferCategory),
    ),
  );
}

class _WhatsappSheet extends StatefulWidget {
  final Student? student;
  final Group? group;
  final MessageCategory? preferCategory;
  const _WhatsappSheet({this.student, this.group, this.preferCategory});

  @override
  State<_WhatsappSheet> createState() => _WhatsappSheetState();
}

class _WhatsappSheetState extends State<_WhatsappSheet> {
  late final MessageTemplateController _tc =
      Get.isRegistered<MessageTemplateController>()
          ? Get.find<MessageTemplateController>()
          : Get.put(MessageTemplateController());
  final SettingsController _settings = Get.find<SettingsController>();

  MessageTemplate? _tpl;
  String? _level;
  final _grade = TextEditingController();
  final _msg = TextEditingController();
  bool _edited = false; // المعلم عدّل النص بإيده؟ — ما نكتبش فوقه
  WhatsappAudience _audience = WhatsappAudience.guardian;

  bool get _isGroupMode => widget.group != null;

  List<WhatsappAudience> get _audiences => widget.student == null
      ? const []
      : availableAudiences(widget.student!,
          studentMessagingEnabled: _settings.studentWhatsappEnabled.value);

  @override
  void initState() {
    super.initState();
    final list = _tc.templates;
    if (list.isNotEmpty) {
      _tpl = (widget.preferCategory == null
              ? null
              : list.firstWhereOrNull(
                  (m) => m.category == widget.preferCategory)) ??
          list.first;
    }
    final a = _audiences;
    if (a.isNotEmpty) _audience = a.first;
    _grade.addListener(_refresh);
    _syncLevelDefault();
    _regen();
  }

  @override
  void dispose() {
    _grade.dispose();
    _msg.dispose();
    super.dispose();
  }

  void _syncLevelDefault() {
    final tpl = _tpl;
    if (tpl == null) return;
    final levels = tpl.effectiveLevels;
    if (_level == null || !levels.contains(_level)) _level = levels.first;
  }

  String get _groupName {
    if (widget.group != null) return widget.group!.name;
    final gid = widget.student?.groupId;
    if (gid == null || !Get.isRegistered<GroupController>()) return '';
    return Get.find<GroupController>()
            .groups
            .firstWhereOrNull((g) => g.id == gid)
            ?.name ??
        '';
  }

  Map<String, String> _values() => {
        MsgVar.student: widget.student?.name ?? 'الطلاب',
        MsgVar.group: _groupName,
        MsgVar.date: DateFormat('d MMMM', 'ar').format(DateTime.now()),
        MsgVar.teacher: _settings.teacherFullName.value.trim(),
        MsgVar.grade: _grade.text,
        MsgVar.level: _level ?? '',
      };

  void _refresh() {
    if (!_edited) _regen();
    setState(() {});
  }

  void _regen() {
    final tpl = _tpl;
    _msg.text = tpl == null ? '' : renderTemplate(tpl.body, _values());
  }

  void _pickTemplate(MessageTemplate m) {
    setState(() {
      _tpl = m;
      _edited = false;
      _level = null;
      _syncLevelDefault();
      _regen();
    });
  }

  Future<void> _send() async {
    final tpl = _tpl;
    final text = _msg.text.trim();
    if (tpl == null || text.isEmpty) {
      ToastHelper.error('اختار رسالة الأول');
      return;
    }
    // متغيّرات ناقصة (الدرجة مثلًا) — بس لو المعلم ما عدّلش النص بإيده.
    if (!_edited) {
      final missing = missingVariables(tpl.body, _values());
      if (missing.isNotEmpty) {
        ToastHelper.error(
            'كمّل: ${missing.map((e) => e.replaceAll('_', ' ')).join('، ')}');
        return;
      }
    }
    final dial = _settings.countryDial.value;
    if (_isGroupMode) {
      await _openGroup(text);
      return;
    }
    final s = widget.student!;
    final nav = Navigator.of(context);
    if (_audience == WhatsappAudience.guardian ||
        _audience == WhatsappAudience.both) {
      final ok = await launchGuardianWhatsapp(
        context: context,
        phone: s.guardianPhone,
        whatsapp: s.guardianWhatsapp,
        message: text,
        dialCode: dial,
      );
      if (!ok) return;
    }
    if (_audience == WhatsappAudience.student ||
        _audience == WhatsappAudience.both) {
      if (_audience == WhatsappAudience.both) {
        if (!mounted) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('كمّل للطالب'),
            content: const Text('ولي الأمر اتبعتله. ابعت نفس الرسالة للطالب؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('لا')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('ابعت للطالب')),
            ],
          ),
        );
        if (go != true) {
          nav.pop();
          return;
        }
      }
      if (!mounted) return;
      await launchGuardianWhatsapp(
        context: context,
        phone: s.studentPhone,
        whatsapp: null,
        message: text,
        dialCode: dial,
        missingMessage: 'مفيش رقم للطالب',
      );
    }
    if (mounted) nav.pop();
  }

  Future<void> _openGroup(String text) async {
    final link = normalizeWhatsappGroupLink(widget.group!.whatsappLink);
    if (link == null) {
      ToastHelper.error('رابط جروب المجموعة مش مضاف أو مش صحيح');
      return;
    }
    await Clipboard.setData(ClipboardData(text: withTeacherSignature(text)));
    ToastHelper.info('اتنسخت الرسالة — الصقها في الجروب');
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {
      ToastHelper.error('تعذّر فتح واتساب');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Obx(() {
      final templates = _tc.templates.toList();
      final audiences = _audiences;
      final tpl = _tpl;
      final asked = tpl == null ? <String>[] : askedVariables(tpl.body);
      final noTargets = !_isGroupMode && audiences.isEmpty;
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Color(0xFF128C7E), size: 22),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _isGroupMode
                              ? 'رسالة لجروب المجموعة'
                              : 'رسالة واتساب',
                          style: AppType.title.copyWith(color: t.ink)),
                      Text(
                          _isGroupMode
                              ? widget.group!.name
                              : widget.student!.name,
                          style: AppType.caption.copyWith(color: t.inkFaint)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Get.to(() => const MessageTemplatesPage()),
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text('رسائلي'),
                ),
              ]),
              const SizedBox(height: AppSpace.lg),
              if (noTargets) ...[
                Text(
                    'مفيش رقم لولي الأمر ولا للطالب. أضف الرقم من تعديل الطالب.',
                    style: AppType.body.copyWith(color: t.danger)),
                const SizedBox(height: AppSpace.md),
              ] else if (!_isGroupMode && audiences.length > 1) ...[
                Text('لمين؟', style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.sm),
                SegmentedButton<WhatsappAudience>(
                  showSelectedIcon: false,
                  segments: [
                    for (final a in audiences)
                      ButtonSegment(value: a, label: Text(a.label)),
                  ],
                  selected: {_audience},
                  onSelectionChanged: (s) =>
                      setState(() => _audience = s.first),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              Text('الرسالة', style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.sm),
              if (templates.isEmpty)
                Text('مفيش رسايل محفوظة — اكتب واحدة من «رسائلي».',
                    style: AppType.body.copyWith(color: t.inkSoft))
              else
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (final m in templates)
                      ChoiceChip(
                        label: Text(m.title),
                        selected: tpl?.id == m.id,
                        onSelected: (_) => _pickTemplate(m),
                      ),
                  ],
                ),
              if (asked.contains(MsgVar.grade)) ...[
                const SizedBox(height: AppSpace.lg),
                Text('الدرجة', style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _grade,
                  decoration: const InputDecoration(hintText: 'مثال: 45 من 50'),
                ),
              ],
              if (asked.contains(MsgVar.level) && tpl != null) ...[
                const SizedBox(height: AppSpace.lg),
                Text('المستوى', style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (final l in tpl.effectiveLevels)
                      ChoiceChip(
                        label: Text(l),
                        selected: _level == l,
                        onSelected: (_) {
                          _level = l;
                          _refresh();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              Text('النص (تقدر تعدّله)',
                  style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _msg,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => _edited = true,
              ),
              const SizedBox(height: AppSpace.lg),
              FilledButton.icon(
                onPressed: noTargets ? null : _send,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: const Color(0xFF128C7E)),
                icon: Icon(_isGroupMode
                    ? Icons.open_in_new_rounded
                    : Icons.send_rounded),
                label: Text(_isGroupMode
                    ? 'انسخ الرسالة وافتح الجروب'
                    : (_audience == WhatsappAudience.both
                        ? 'ابعت للاتنين'
                        : 'ابعت على واتساب')),
              ),
            ],
          ),
        ),
      );
    });
  }
}
