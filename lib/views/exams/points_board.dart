// lib/views/exams/points_board.dart
//
// «لوحة النقاط»: ترتيب الطلاب بنقاط الحضور والامتحانات والواجب والتسميع
// والتفاعل، بتصميم السبورة والطباشير: رأس سبورة فيه الفلاتر والمنصّة لأول 3،
// وتحتها باقي الترتيب في كروت. المستوى بنسبة الالتزام (الحضور ÷ الحصص).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/services/points_service.dart';
import 'package:active_class/utils/student_points.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/points_chalk.dart';
import 'package:active_class/widgets/points_rules_sheet.dart';
import 'package:active_class/widgets/student_points_sheet.dart';

enum PointsPeriod { all, thisMonth, lastMonth }

/// الشاشة المستقلة للوحة النقاط (بتتفتح من صفحة الطلاب).
class PointsPage extends StatelessWidget {
  const PointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'نقاط الطلاب'),
      body: const PointsBoard(),
    );
  }
}

class PointsBoard extends StatefulWidget {
  /// للاختبار: بيانات جاهزة بدل التحميل من القاعدة.
  final PointsData? initialData;
  final PointsRules? initialRules;

  const PointsBoard({super.key, this.initialData, this.initialRules});

  @override
  State<PointsBoard> createState() => _PointsBoardState();
}

class _PointsBoardState extends State<PointsBoard> {
  bool _loading = true;
  PointsData? _data;
  PointsRules _rules = PointsRules.defaults;
  PointsPeriod _period = PointsPeriod.all;
  int? _groupId;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _rules = widget.initialRules ?? PointsRules.defaults;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final rules = await PointsService.loadRules();
    final data = await PointsService.load();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _data = data;
      _loading = false;
    });
  }

  DateTime? get _month {
    final n = DateTime.now();
    switch (_period) {
      case PointsPeriod.all:
        return null;
      case PointsPeriod.thisMonth:
        return DateTime(n.year, n.month, 1);
      case PointsPeriod.lastMonth:
        return DateTime(n.year, n.month - 1, 1);
    }
  }

  String get _periodLabel {
    final m = _month;
    return m == null ? 'كل الوقت' : DateFormat('MMMM yyyy', 'ar').format(m);
  }

  String? _groupName(int? id) {
    for (final g in _data?.groups ?? const []) {
      if (g.id == id) return g.name;
    }
    return null;
  }

  List<RankedPoints> get _ranked => _data == null
      ? const []
      : _data!.rank(rules: _rules, month: _month, groupId: _groupId);

  Future<void> _editRules() async {
    final r = await showPointsRulesSheet(context, _rules);
    if (r == null || !mounted) return;
    await PointsService.saveRules(r);
    setState(() => _rules = r);
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
    setState(() => _groupId = picked == -1 ? null : picked);
  }

  void _share(List<RankedPoints> ranked) {
    if (ranked.isEmpty) return;
    final s = Get.find<SettingsController>();
    final name = s.teacherFullName.value.trim();
    final line = name.isEmpty
        ? ''
        : [
            '${s.teacherTitle} $name',
            if (s.teacherSpecialization.value.trim().isNotEmpty)
              s.teacherSpecialization.value.trim(),
          ].join('، ');
    final scope = _groupId == null
        ? _periodLabel
        : '$_periodLabel — ${_groupName(_groupId) ?? ''}';
    Share.share(buildPointsShareText(ranked,
        periodLabel: scope, teacherLine: line, rules: _rules));
  }

  void _open(RankedPoints r) => showStudentPointsSheet(context,
      ranked: r,
      periodLabel: _periodLabel,
      groupName: _groupName(r.entry.student.groupId));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final ranked = _ranked;
    final podium =
        ranked.length >= 3 ? ranked.take(3).toList() : <RankedPoints>[];
    final rest = ranked.skip(podium.length).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
        children: [
          _board(t, ranked, podium),
          const SizedBox(height: AppSpace.lg),
          if (ranked.isEmpty)
            _empty(t)
          else ...[
            if (rest.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text('باقي الترتيب',
                    style: AppType.label.copyWith(color: t.ink)),
              ),
              for (final r in rest)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: _row(t, r),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _empty(AppTokens t) => Column(children: [
        const SizedBox(height: AppSpace.md),
        Icon(Icons.stars_rounded, size: 56, color: t.inkFaint),
        const SizedBox(height: AppSpace.md),
        Text('لسه مفيش نقاط في الفترة دي',
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(color: t.ink)),
        const SizedBox(height: AppSpace.sm),
        Text(
            'النقاط بتتحسب تلقائيًا من الحضور والامتحانات والواجب '
            'والتسميع والتفاعل. سجّل حضور وامتحانات وهتظهر هنا.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: t.inkSoft)),
      ]);

  // ── السبورة: العنوان + الفلاتر + المنصّة ───────────────────────────────
  Widget _board(AppTokens t, List<RankedPoints> ranked, List<RankedPoints> podium) {
    return Container(
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: BorderRadius.circular(AppRadius.board),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لوحة النقاط',
                      style: AppType.greeting.copyWith(color: t.boardInk)),
                  Text(
                      ranked.isEmpty
                          ? 'ترتيب الطلاب بالنقاط'
                          : '${ranked.length} طالب لهم نقاط',
                      style: AppType.caption.copyWith(color: t.boardInkSoft)),
                ]),
          ),
          BoardIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: 'مشاركة لوحة النقاط',
            onPressed: ranked.isEmpty ? null : () => _share(ranked),
          ),
          BoardIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'قواعد النقاط',
            onPressed: _editRules,
          ),
        ]),
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
          for (final p in PointsPeriod.values)
            BoardChoice(
              label: switch (p) {
                PointsPeriod.all => 'كل الوقت',
                PointsPeriod.thisMonth => 'هذا الشهر',
                PointsPeriod.lastMonth => 'الشهر اللي فات',
              },
              selected: _period == p,
              onTap: () => setState(() => _period = p),
            ),
          BoardChoice(
            icon: Icons.groups_rounded,
            label: _groupId == null
                ? 'كل المجموعات'
                : (_groupName(_groupId) ?? 'مجموعة'),
            selected: _groupId != null,
            onTap: _pickGroup,
          ),
        ]),
        if (podium.isNotEmpty) ...[
          const SizedBox(height: AppSpace.lg),
          const ChalkDashedLine(),
          const SizedBox(height: AppSpace.lg),
          _podium(t, podium),
        ],
        const SizedBox(height: AppSpace.md),
        const ChalkDashedLine(),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: t.boardInkSoft),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
                'المستوى بنسبة الالتزام: الحضور ÷ الحصص المسجّلة. '
                'اضغط على أي طالب للتفاصيل.',
                style: AppType.caption.copyWith(color: t.boardInkSoft)),
          ),
        ]),
      ]),
    );
  }

  Color _medalColor(AppTokens t, int rank) => switch (rank) {
        1 => t.chalk,
        2 => const Color(0xFFCBD5E1),
        3 => const Color(0xFFE6A15C),
        _ => const Color(0xFF94A3B8),
      };

  Widget _podium(AppTokens t, List<RankedPoints> top) {
    // الأول في النص، التاني والتالت على الجانبين.
    final order = [top[1], top[0], top[2]];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final r in order)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _podiumColumn(t, r),
            ),
          ),
      ],
    );
  }

  Widget _podiumColumn(AppTokens t, RankedPoints r) {
    final c = _medalColor(t, r.rank);
    final e = r.entry;
    final first = r.rank == 1;
    final pedestal = first ? 56.0 : (r.rank == 2 ? 42.0 : 32.0);
    return Semantics(
      button: true,
      label: 'المركز ${r.rank} ${e.student.name} ${e.points} نقطة',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () => _open(r),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (first)
            Icon(Icons.emoji_events_rounded, color: c, size: 30)
          else
            const SizedBox(height: 4),
          const SizedBox(height: 4),
          Container(
            width: first ? 56 : 46,
            height: first ? 56 : 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: first ? c : Colors.transparent,
              border: Border.all(color: c, width: 2),
            ),
            child: Text(
                e.student.name.trim().isEmpty
                    ? '?'
                    : e.student.name.trim().characters.first,
                style: AppType.title
                    .copyWith(color: first ? t.onChalk : t.boardInk)),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(e.student.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: t.boardInk)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${e.points} نقطة',
                style: AppType.label.copyWith(color: c)),
          ),
          const SizedBox(height: 4),
          PointsLevelChip(level: e.level, onBoard: true),
          const SizedBox(height: AppSpace.sm),
          // قاعدة المنصّة: طباشير مرسومة بإطار علوي.
          Container(
            height: pedestal,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.chip)),
              border: Border(top: BorderSide(color: c, width: 2)),
            ),
            child: Text('${r.rank}',
                style: AppType.figure.copyWith(color: c)),
          ),
        ]),
      ),
    );
  }

  Widget _row(AppTokens t, RankedPoints r) {
    final e = r.entry;
    final rate = e.commitment;
    final group = _groupId == null ? _groupName(e.student.groupId) : null;
    return AppPanel(
      onTap: () => _open(r),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: t.rosterTint),
          child: Text('${r.rank}',
              style: AppType.label.copyWith(color: t.rosterInk)),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PointsLevelChip(level: e.level),
                      if (rate != null)
                        Text('التزام ${rate.round()}%',
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      if (group != null)
                        Text(group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                    ]),
              ]),
        ),
        const SizedBox(width: AppSpace.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${e.points}', style: AppType.title.copyWith(color: t.ink)),
          Text('نقطة', style: AppType.caption.copyWith(color: t.inkSoft)),
        ]),
        Icon(Icons.chevron_left_rounded, color: t.inkFaint),
      ]),
    );
  }
}
