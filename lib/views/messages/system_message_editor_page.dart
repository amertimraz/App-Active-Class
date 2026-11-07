// lib/views/messages/system_message_editor_page.dart
//
// تعديل نص رسالة من رسائل البرنامج التلقائية (تنبيه غياب، إيصال…): النص الحالي
// كامل + أزرار إدراج المتغيّرات + معاينة حيّة + استرجاع الأصلي.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/widgets/chalk_dialog.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/system_messages.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

/// يحفظ كل التعديلات الحالية على الجهاز.
Future<void> persistSystemMessages() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kSystemMessagesPrefsKey, SystemMessages.encode());
}

class SystemMessageEditorPage extends StatefulWidget {
  final SystemMessageDef def;
  const SystemMessageEditorPage({super.key, required this.def});

  @override
  State<SystemMessageEditorPage> createState() =>
      _SystemMessageEditorPageState();
}

class _SystemMessageEditorPageState extends State<SystemMessageEditorPage> {
  late final TextEditingController _body;
  bool _saving = false;

  SystemMessageDef get def => widget.def;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(
        text: SystemMessages.overrideFor(def.id) ?? def.defaultBody);
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _insertVar(String name) {
    final sel = _body.selection;
    final text = _body.text;
    final token = '{$name}';
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  Future<void> _save() async {
    final text = _body.text;
    if (text.trim().isEmpty) {
      ToastHelper.error('نص الرسالة فاضي — استخدم «استرجاع الأصلي» لو عايز الافتراضي');
      return;
    }
    setState(() => _saving = true);
    // لو النص نفس الافتراضي بالظبط، مفيش داعي نعتبرها معدّلة.
    SystemMessages.set(def.id, text == def.defaultBody ? null : text);
    await persistSystemMessages();
    ToastHelper.success('اتحفظت الرسالة');
    Get.back();
  }

  Future<void> _reset() async {
    final ok = await showChalkConfirm(
      context,
      icon: Icons.settings_backup_restore_rounded,
      title: 'استرجاع الأصلي؟',
      message: 'هيرجع نص الرسالة لصياغة البرنامج الأصلية.',
      confirmLabel: 'استرجاع',
    );
    if (ok != true) return;
    SystemMessages.set(def.id, null);
    await persistSystemMessages();
    ToastHelper.success('رجعت الصياغة الأصلية');
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final unknown = unknownVariables(def, _body.text);
    final preview = renderSystemBody(_body.text, def.sample);
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: def.title, actions: [
        if (SystemMessages.isCustomized(def.id))
          TextButton(onPressed: _reset, child: const Text('استرجاع الأصلي')),
      ]),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md + bottom),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52)),
          icon: const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          Text(def.description,
              style: AppType.body.copyWith(color: t.inkSoft)),
          const SizedBox(height: AppSpace.lg),
          _label(t, 'نص الرسالة'),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 14,
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
              for (final v in def.vars)
                ActionChip(
                  label: Text(v.replaceAll('_', ' ')),
                  onPressed: () => _insertVar(v),
                ),
            ],
          ),
          if (unknown.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
                'متغيّر مش معروف: ${unknown.map((e) => '{$e}').join('، ')} — '
                'هيتبعت زي ما هو.',
                style: AppType.caption.copyWith(color: t.danger)),
          ],
          const SizedBox(height: AppSpace.sm),
          Text(
              'سطر متغيّراته كلها فاضية (زي التخصص) بيتشال لوحده من الرسالة. '
              'اسمك وتخصصك بيتضافوا تلقائيًا في آخر الرسالة.',
              style: AppType.caption.copyWith(color: t.inkFaint)),
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
