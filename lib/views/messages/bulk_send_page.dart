// lib/views/messages/bulk_send_page.dart
//
// «الإرسال الجماعي»: المدرس يختار نوع الرسالة (تذكير دفع، غياب، تقرير الشهر،
// بطاقة الشهر) والفترة والمجموعة، يشوف مين هيتبعتله، ويبدأ الطابور. بتصميم
// السبورة والطباشير.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/bulk_send_service.dart';
import 'package:active_class/services/points_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/send_queue.dart';
import 'package:active_class/utils/student_points.dart';
import 'package:active_class/views/messages/send_queue_page.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

class BulkSendPage extends StatefulWidget {
  final BulkKind? initialKind;
  final int? initialGroupId;

  /// للاختبار: بيانات جاهزة بدل التحميل من القاعدة.
  final BulkSendData? initialData;

  const BulkSendPage({
    super.key,
    this.initialKind,
    this.initialGroupId,
    this.initialData,
  });

  @override
  State<BulkSendPage> createState() => _BulkSendPageState();
}

class _BulkSendPageState extends State<BulkSendPage> {
  bool _loading = true;
  BulkSendData? _data;
  PointsRules _rules = PointsRules.defaults;
  late BulkKind _kind;
  late DateTime _day;
  late DateTime _month;
  int? _groupId;
  List<QueueItem> _items = const [];
  final Set<int> _selected = {};

  bool get _canFinance => TeamModeService().canSeeFinancials;
  bool get _canAcademics => TeamModeService().canSeeAcademics;

  List<BulkKind> get _kinds => [
        if (_canFinance) BulkKind.payments,
        BulkKind.absence,
        if (_canAcademics) BulkKind.monthlyReport,
        if (_canAcademics) BulkKind.monthlyCard,
      ];

  String get _teacherName => Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().teacherFullName.value.trim()
      : '';
  String get _teacherSpec => Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().teacherSpecialization.value.trim()
      : '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _month = defaultCollectionMonth();
    _groupId = widget.initialGroupId;
    _kind = widget.initialKind != null && _kinds.contains(widget.initialKind)
        ? widget.initialKind!
        : _kinds.first;
    _load();
  }

  Future<void> _load() async {
    final data = widget.initialData ?? await BulkSendService.load();
    final rules = widget.initialData != null
        ? PointsRules.defaults
        : await PointsService.loadRules();
    if (!mounted) return;
    _data = data;
    _rules = rules;
    _rebuild();
    setState(() => _loading = false);
  }

  void _rebuild() {
    final d = _data;
    if (d == null) return;
    switch (_kind) {
      case BulkKind.payments:
        _items = BulkSendService.payments(d,
            groupId: _groupId,
            teacherName: _teacherName,
            teacherSpecialization: _teacherSpec);
      case BulkKind.absence:
        _items = BulkSendService.absences(d,
            day: _day,
            groupId: _groupId,
            teacherName: _teacherName,
            teacherSpecialization: _teacherSpec);
      case BulkKind.monthlyReport:
        _items = BulkSendService.monthlyReports(d,
            month: _month,
            groupId: _groupId,
            teacherName: _teacherName,
            teacherSpecialization: _teacherSpec);
      case BulkKind.monthlyCard:
        _items = BulkSendService.monthlyCards(d,
            month: _month,
            groupId: _groupId,
            rules: _rules,
            teacherName: _teacherName,
            teacherSpecialization: _teacherSpec);
    }
    _selected
      ..clear()
      ..addAll([
        for (var i = 0; i < _items.length; i++)
          if (_items[i].canSend) i
      ]);
  }

  String? _groupName(int? id) {
    for (final g in _data?.groups ?? const []) {
      if (g.id == id) return g.name;
    }
    return null;
  }

  Future<void> _pickDay() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'اختر يوم الغياب',
    );
    if (p == null || !mounted) return;
    setState(() {
      _day = DateTime(p.year, p.month, p.day);
      _rebuild();
    });
  }

  Future<void> _pickMonth() async {
    final cm = defaultCollectionMonth();
    final p = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(cm.year - 3, 1, 1),
      lastDate: DateTime(cm.year, cm.month + 1, 0),
      helpText: 'اختر الشهر',
    );
    if (p == null || !mounted) return;
    setState(() {
      _month = DateTime(p.year, p.month, 1);
      _rebuild();
    });
  }

  Future<void> _pickGroup() async {
    final groups = _data?.groups ?? const [];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            title: const Text('كل المجموعات'),
            trailing: _groupId == null ? const Icon(Icons.check_rounded) : null,
            onTap: () => Navigator.pop(ctx, -1),
          ),
          for (final g in groups)
            ListTile(
              title: Text(g.name),
              trailing:
                  _groupId == g.id ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(ctx, g.id),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _groupId = picked == -1 ? null : picked;
      _rebuild();
    });
  }

  void _start() {
    final chosen = [
      for (final i in (_selected.toList()..sort())) _items[i],
    ];
    if (chosen.isEmpty) return;
    Get.to(() => SendQueuePage(title: _kind.title, items: chosen));
  }

  static IconData _icon(BulkKind k) => switch (k) {
        BulkKind.payments => Icons.payments_rounded,
        BulkKind.absence => Icons.person_off_rounded,
        BulkKind.monthlyReport => Icons.summarize_rounded,
        BulkKind.monthlyCard => Icons.badge_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'الإرسال الجماعي'),
      bottomNavigationBar: _loading || _items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _start,
                  style: FilledButton.styleFrom(
                      backgroundColor: t.brand,
                      minimumSize: const Size(double.infinity, 52)),
                  icon: const Icon(Icons.send_rounded),
                  label: Text('ابدأ الإرسال (${_selected.length})'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
              children: [
                _header(t),
                const SizedBox(height: AppSpace.md),
                _kindGrid(t),
                const SizedBox(height: AppSpace.md),
                _options(t),
                const SizedBox(height: AppSpace.md),
                _summary(t),
                const SizedBox(height: AppSpace.sm),
                if (_items.isEmpty) _empty(t),
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: _row(t, i),
                  ),
              ],
            ),
    );
  }

  Widget _header(AppTokens t) => Container(
        decoration: BoxDecoration(
          color: t.board,
          borderRadius: BorderRadius.circular(AppRadius.board),
        ),
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.chalk),
            child: Icon(Icons.send_rounded, color: t.onChalk),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ابعت لأولياء الأمور بسرعة',
                      style: AppType.greeting.copyWith(color: t.boardInk)),
                  Text(
                      'اختار الرسالة، وإحنا نفتحلك واتساب لكل ولي أمر برسالة '
                      'جاهزة. إنت بس بتدوس «إرسال» وبترجع.',
                      style: AppType.caption.copyWith(color: t.boardInkSoft)),
                ]),
          ),
        ]),
      );

  Widget _kindGrid(AppTokens t) {
    final kinds = _kinds;
    return Column(children: [
      for (var i = 0; i < kinds.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _kindCard(t, kinds[i])),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                  child: i + 1 < kinds.length
                      ? _kindCard(t, kinds[i + 1])
                      : const SizedBox.shrink()),
            ]),
          ),
        ),
    ]);
  }

  Widget _kindCard(AppTokens t, BulkKind k) {
    final sel = k == _kind;
    return AppPanel(
      onTap: () => setState(() {
        _kind = k;
        _rebuild();
      }),
      lineColor: sel ? t.brand : null,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_icon(k), color: sel ? t.brand : t.inkSoft, size: 24),
          const Spacer(),
          if (sel) Icon(Icons.check_circle_rounded, color: t.brand, size: 20),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text(k.title,
            style: AppType.label.copyWith(color: sel ? t.brand : t.ink)),
        Text(k.hint, style: AppType.caption.copyWith(color: t.inkSoft)),
      ]),
    );
  }

  Widget _options(AppTokens t) => Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            if (_kind.needsDay)
              _optChip(t, Icons.event_rounded,
                  DateFormat('d MMMM yyyy', 'ar').format(_day), _pickDay),
            if (_kind.needsMonth)
              _optChip(t, Icons.calendar_month_rounded,
                  DateFormat('MMMM yyyy', 'ar').format(_month), _pickMonth),
            _optChip(
                t,
                Icons.groups_rounded,
                _groupId == null
                    ? 'كل المجموعات'
                    : (_groupName(_groupId) ?? 'مجموعة'),
                _pickGroup),
          ]);

  Widget _optChip(AppTokens t, IconData icon, String label, VoidCallback onTap) =>
      Material(
        color: t.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: t.line),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: t.brand),
                const SizedBox(width: AppSpace.xs),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(color: t.ink)),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: t.inkFaint),
              ]),
            ),
          ),
        ),
      );

  Widget _summary(AppTokens t) {
    final noContact = _items.where((i) => !i.canSend).length;
    final canAll = _items.where((i) => i.canSend).length;
    final allSelected = canAll > 0 && _selected.length == canAll;
    return Row(children: [
      Expanded(
        child: Text(
            _items.isEmpty
                ? ''
                : '${_items.length} طالب'
                    '${noContact > 0 ? ' • $noContact من غير رقم' : ''}',
            style: AppType.label.copyWith(color: t.ink)),
      ),
      if (canAll > 0)
        TextButton(
          onPressed: () => setState(() {
            if (allSelected) {
              _selected.clear();
            } else {
              _selected
                ..clear()
                ..addAll([
                  for (var i = 0; i < _items.length; i++)
                    if (_items[i].canSend) i
                ]);
            }
          }),
          child: Text(allSelected ? 'إلغاء الكل' : 'اختيار الكل'),
        ),
    ]);
  }

  Widget _empty(AppTokens t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
        child: Column(children: [
          Icon(Icons.inbox_rounded, size: 48, color: t.inkFaint),
          const SizedBox(height: AppSpace.sm),
          Text(
              switch (_kind) {
                BulkKind.payments => 'مفيش حد عليه متبقي. الحمد لله 👌',
                BulkKind.absence => 'مفيش غياب مسجّل في اليوم ده',
                _ => 'مفيش طلاب في الاختيار ده',
              },
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: t.inkSoft)),
        ]),
      );

  Widget _row(AppTokens t, int i) {
    final it = _items[i];
    final sel = _selected.contains(i);
    return AppPanel(
      onTap: it.canSend
          ? () => setState(() => sel ? _selected.remove(i) : _selected.add(i))
          : null,
      child: Row(children: [
        Icon(
            it.canSend
                ? (sel
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded)
                : Icons.phone_disabled_rounded,
            color: it.canSend ? (sel ? t.brand : t.inkFaint) : t.danger),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(
                        color: it.canSend ? t.ink : t.inkFaint)),
                Text(
                    it.canSend
                        ? it.subtitle
                        : 'مفيش رقم لولي الأمر — أضفه من صفحة الطالب',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(
                        color: it.canSend ? t.inkSoft : t.danger)),
              ]),
        ),
      ]),
    );
  }
}
