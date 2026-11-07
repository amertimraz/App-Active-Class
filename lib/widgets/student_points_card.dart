// lib/widgets/student_points_card.dart
//
// كارت نقاط الطالب في صفحة تفاصيله: سبورة صغيرة فيها المستوى والنقاط ونسبة
// الالتزام ومركزه في مجموعته. الضغط يفتح تفاصيل النقاط. لو التحميل فشل بيختفي
// بهدوء (مش بيكسر الصفحة).
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/points_service.dart';
import 'package:active_class/utils/student_points.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/points_chalk.dart';
import 'package:active_class/widgets/student_points_sheet.dart';

class StudentPointsCard extends StatefulWidget {
  final Student student;
  final String? groupName;

  /// بيتغيّر لما بيانات الطالب تتغيّر (مثلًا عدد سجلات الحضور) علشان الكارت يتحدّث.
  final int refreshKey;

  /// للاختبار: بيانات جاهزة بدل التحميل من القاعدة.
  final PointsData? initialData;
  final PointsRules? initialRules;

  const StudentPointsCard({
    super.key,
    required this.student,
    this.groupName,
    this.refreshKey = 0,
    this.initialData,
    this.initialRules,
  });

  @override
  State<StudentPointsCard> createState() => _StudentPointsCardState();
}

class _StudentPointsCardState extends State<StudentPointsCard> {
  RankedPoints? _mine;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StudentPointsCard old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey ||
        old.student.id != widget.student.id) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final rules = widget.initialRules ?? await PointsService.loadRules();
      final data = widget.initialData ?? await PointsService.load();
      final id = widget.student.id;
      if (id == null) throw StateError('no id');
      final own = computeStudentPoints(
        student: widget.student,
        attendance: data.attendance[id] ?? const [],
        homework: data.homework[id] ?? const [],
        exams: data.exams[id] ?? const [],
        rules: rules,
      );
      // المركز بين طلاب نفس المجموعة (كل الوقت). لو نقاطه صفر ما بيظهرش في
      // الترتيب، فنحطه في الآخر.
      final board =
          data.rank(rules: rules, groupId: widget.student.groupId);
      var rank = board.length + 1;
      for (final r in board) {
        if (r.entry.student.id == id) {
          rank = r.rank;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _mine = RankedPoints(rank, own);
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    if (_failed || mine == null) return const SizedBox.shrink();
    final t = context.tokens;
    final e = mine.entry;
    final rate = e.commitment;
    final on = AppTokens.dark;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
      child: Material(
        color: t.board,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showStudentPointsSheet(context,
              ranked: mine,
              periodLabel: 'كل الوقت',
              groupName: widget.groupName),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(children: [
              Row(children: [
                Icon(pointsLevelIcon(e.level),
                    color: pointsLevelColor(e.level), size: 26),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text('نقاطه ومستواه',
                      style: AppType.label.copyWith(color: t.boardInk)),
                ),
                PointsLevelChip(level: e.level, onBoard: true),
                const SizedBox(width: AppSpace.xs),
                Icon(Icons.chevron_left_rounded, color: t.boardInkSoft),
              ]),
              const SizedBox(height: AppSpace.sm),
              const ChalkDashedLine(),
              const SizedBox(height: AppSpace.sm),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: BoardStat(
                        label: 'نقطة',
                        value: '${e.points}',
                        color: t.chalk)),
                Expanded(
                    child: BoardStat(
                        label: 'التزام',
                        value: rate == null ? '—' : '${rate.round()}%',
                        color: on.positive)),
                Expanded(
                    child: BoardStat(
                        label: 'مركزه في مجموعته',
                        value: '${mine.rank}',
                        color: t.boardInk)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
