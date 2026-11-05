// lib/views/messages/message_template_editor_page.dart
//
// إنشاء/تعديل رسالة واتساب محفوظة: العنوان + التصنيف + النص (مع أزرار إدراج
// المتغيّرات) + مستويات الطالب (تظهر لو النص فيه {المستوى}) + معاينة حيّة.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/message_template_controller.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/message_templates.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

class MessageTemplateEditorPage extends StatefulWidget {
  final MessageTemplate? existing;
  const MessageTemplateEditorPage({super.key, this.existing});

  @override
  State<MessageTemplateEditorPage> createState() =>
      _MessageTemplateEditorPageState();
}

class _MessageTemplateEditorPageState extends State<MessageTemplateEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late MessageCategory _category;
  late List<String> _levels;
  final _levelCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _category = e?.category ?? MessageCategory.general;
    _levels = List.of(e?.levels ?? const []);
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  /// بيدخل `{متغيّر}` عند مكان المؤشر في النص.
  void _insertVar(String name) {
    final sel = _body.selection;
    final text = _body.text;
    final token = '{$name}';
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, token);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _addLevel() {
    final v = _levelCtrl.text.trim();
    if (v.isEmpty || _levels.contains(v)) return;
    setState(() {
      _levels.add(v);
      _levelCtrl.clear();
    });
  }

  Future<void> _save() async {
    final tpl = MessageTemplate(
      id: widget.existing?.id,
      title: _title.text.trim(),
      body: _body.text,
      category: _category,
      levels: _levels,
    );
    if (!tpl.isValid) {
      ToastHelper.error('اكتب عنوان ونص للرسالة');
      return;
    }
    setState(() => _saving = true);
    try {
      final c = Get.isRegistered<MessageTemplateController>()
          ? Get.find<MessageTemplateController>()
          : Get.put(MessageTemplateController());
      await c.save(tpl);
      ToastHelper.success('اتحفظت الرسالة');
      Get.back();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      ToastHelper.error('تعذّر الحفظ — حاول تاني');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final usesLevel = templateVariables(_body.text).contains(MsgVar.level);
    final preview = renderTemplate(_body.text, {
      MsgVar.student: 'عمر',
      MsgVar.group: 'الصف الثاني',
      MsgVar.date: '20 نوفمبر',
      MsgVar.teacher: 'مستر أحمد',
      if (usesLevel)
        MsgVar.level: (_levels.isEmpty ? kDefaultLevels : _levels).first,
    });
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context,
          title: widget.existing == null ? 'رسالة جديدة' : 'تعديل الرسالة'),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md + bottom),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          icon: const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الرسالة'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          _label(t, 'عنوان الرسالة'),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'مثال: حصة ملغية'),
          ),
          const SizedBox(height: AppSpace.lg),
          _label(t, 'النوع'),
          DropdownButtonFormField<MessageCategory>(
            initialValue: _category,
            isExpanded: true,
            items: [
              for (final c in MessageCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: AppSpace.lg),
          _label(t, 'نص الرسالة'),
          TextField(
            controller: _body,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
                hintText: 'اكتب الرسالة… وادوس على متغيّر تحت لإدراجه'),
          ),
          const SizedBox(height: AppSpace.sm),
          Text('اضغط لإدراج متغيّر في مكان المؤشر:',
              style: AppType.caption.copyWith(color: t.inkFaint)),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              for (final v in MsgVar.all)
                ActionChip(
                  label: Text(v.replaceAll('_', ' ')),
                  onPressed: () => _insertVar(v),
                ),
            ],
          ),
          if (usesLevel) ...[
            const SizedBox(height: AppSpace.xl),
            _label(t, 'مستويات الطالب'),
            Text(
                'وقت الإرسال هتختار المستوى من الشرايح دي. لو سبتها فاضية '
                'هتظهر: ${kDefaultLevels.join('، ')}.',
                style: AppType.caption.copyWith(color: t.inkFaint)),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                for (final l in _levels)
                  InputChip(
                    label: Text(l),
                    onDeleted: () => setState(() => _levels.remove(l)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _levelCtrl,
                  onSubmitted: (_) => _addLevel(),
                  decoration: const InputDecoration(hintText: 'مستوى جديد'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              IconButton.filledTonal(
                tooltip: 'إضافة المستوى',
                onPressed: _addLevel,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
          ],
          const SizedBox(height: AppSpace.xl),
          _label(t, 'معاينة (بقيم تجريبية)'),
          AppPanel(
            child: Text(preview.isEmpty ? '—' : preview,
                style: AppType.body.copyWith(color: t.ink, height: 1.7)),
          ),
        ],
      ),
    );
  }

  Widget _label(AppTokens t, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(text, style: AppType.label.copyWith(color: t.ink)),
      );
}
