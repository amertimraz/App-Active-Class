// lib/views/whatsapp/wa_consent_page.dart
//
// spec 056 — موافقة أولياء الأمور على الرسايل التلقائية. المدرس بيختار طلاب
// (كلهم أو مجموعة) ويسجّل إنه حصل على موافقة ولي الأمر. الـ worker مابيبعتش
// لأي رقم بلا موافقة، وبيوقف فورًا لو ولي الأمر رد بكلمة «إيقاف».
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/whatsapp_auto_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/whatsapp_auto_rules.dart';
import 'package:active_class/widgets/app_chrome.dart';

class WaConsentPage extends StatefulWidget {
  const WaConsentPage({super.key});

  @override
  State<WaConsentPage> createState() => _WaConsentPageState();
}

class _WaConsentPageState extends State<WaConsentPage> {
  List<Student> _all = [];
  List<Group> _groups = [];
  final SettingsController _settings = Get.find();
  Map<int, WaConsent> _consents = {};
  final Set<int> _selected = {};
  int? _groupId;
  bool _loading = true;
  bool _saving = false;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseService();
    _all = (await db.getAllStudents()).where((s) => !s.isArchived).toList();
    _groups = await db.getAllGroups();
    try {
      _consents = await WhatsAppAutoService.instance.loadConsents();
      _offline = false;
    } catch (_) {
      _offline = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  String? _phoneOf(Student s) =>
      waRecipientPhone(s.guardianPhone, _settings.countryDial.value);

  List<Student> get _visible => _all
      .where((s) => s.id != null)
      .where((s) => _groupId == null || s.groupId == _groupId)
      .toList();

  /// طلاب ينفع نسجّل موافقتهم: رقم صالح ومفيش موافقة/إيقاف.
  List<Student> get _eligible => _visible
      .where((s) => _phoneOf(s) != null && !_consents.containsKey(s.id))
      .toList();

  Future<void> _grant() async {
    final items = [
      for (final s in _all)
        if (_selected.contains(s.id) && _phoneOf(s) != null)
          (studentId: s.id!, phone: _phoneOf(s)!)
    ];
    if (items.isEmpty) return;
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('تأكيد الموافقة'),
      content: Text(
          'بسجّل إن ${items.length} من أولياء الأمور وافقوا على استلام رسايل '
          'الغياب على واتساب من رقم الأكاديمية. وأي ولي أمر يرد بكلمة «إيقاف» '
          'هيتوقف الإرسال له فورًا.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Get.back(result: true), child: const Text('أؤكد')),
      ],
    ));
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final n = await WhatsAppAutoService.instance.grantConsent(items);
      ToastHelper.success('اتسجّلت الموافقة لـ $n ولي أمر', title: 'تم');
      _selected.clear();
      await _load();
    } catch (e) {
      ToastHelper.error('تعذّر الحفظ، تأكد من الإنترنت وحاول تاني');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final groups = _groups;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'موافقات أولياء الأمور'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final list = _visible;
              final eligible = _eligible;
              return Column(children: [
                if (_offline)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('مفيش اتصال بالسيرفر — اتأكد من الإنترنت وحاول تاني',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _groupId,
                        decoration: const InputDecoration(labelText: 'المجموعة'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('كل المجموعات')),
                          for (final g in groups)
                            DropdownMenuItem<int?>(value: g.id, child: Text(g.name)),
                        ],
                        onChanged: (v) => setState(() {
                          _groupId = v;
                          _selected.clear();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: eligible.isEmpty
                          ? null
                          : () => setState(() {
                                _selected
                                  ..clear()
                                  ..addAll(eligible.map((s) => s.id!));
                              }),
                      child: Text('تحديد الكل (${eligible.length})'),
                    ),
                  ]),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('مفيش طلاب'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _row(list[i]),
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _selected.isEmpty || _saving ? null : _grant,
                        child: Text(_saving
                            ? 'جارٍ الحفظ…'
                            : 'تسجيل الموافقة للمحدد (${_selected.length})'),
                      ),
                    ),
                  ),
                ),
              ]);
            }),
    );
  }

  Widget _row(Student s) {
    final phone = _phoneOf(s);
    final c = _consents[s.id];
    final (label, color, icon) = phone == null
        ? ('بلا رقم صالح', const Color(0xFF9CA3AF), Icons.phone_disabled_rounded)
        : switch (c) {
            WaConsent.granted => ('موافق', const Color(0xFF16A34A), Icons.check_circle_rounded),
            WaConsent.stopped => ('أوقف الرسايل', const Color(0xFFEF4444), Icons.block_rounded),
            _ => ('بلا موافقة', const Color(0xFFF59E0B), Icons.help_outline_rounded),
          };
    final selectable = phone != null && c == null;
    return CheckboxListTile(
      value: _selected.contains(s.id),
      onChanged: selectable
          ? (v) => setState(() => v == true ? _selected.add(s.id!) : _selected.remove(s.id))
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(s.name),
      subtitle: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}
