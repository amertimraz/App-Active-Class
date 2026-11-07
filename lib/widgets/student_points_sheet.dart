// lib/widgets/student_points_sheet.dart
//
// تفاصيل نقاط طالب بتصميم السبورة: رأس على السبورة (النقاط ونسبة الالتزام
// والحصص)، وتحته سلم المستويات، وسلاسل الانتظام، وتفصيل النقاط، والأوسمة.
// عرض بس — الحساب كله في utils/student_points.dart.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/student_points.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/points_chalk.dart';

/// لون المستوى (نفس اللون في الوضعين، والنص بيفضل بلون الحبر عشان التباين).
Color pointsLevelColor(PointsLevel l) => switch (l) {
      PointsLevel.starter => const Color(0xFF64748B),
      PointsLevel.bronze => const Color(0xFFCD7F32),
      PointsLevel.silver => const Color(0xFF94A3B8),
      PointsLevel.gold => const Color(0xFFF59E0B),
      PointsLevel.diamond => const Color(0xFF38BDF8),
    };

IconData pointsLevelIcon(PointsLevel l) => switch (l) {
      PointsLevel.starter => Icons.flag_rounded,
      PointsLevel.diamond => Icons.diamond_rounded,
      _ => Icons.military_tech_rounded,
    };

IconData pointsBadgeIcon(PointsBadge b) => switch (b) {
      PointsBadge.regular => Icons.local_fire_department_rounded,
      PointsBadge.excellent => Icons.school_rounded,
      PointsBadge.active => Icons.bolt_rounded,
    };

/// شارة مستوى صغيرة (أيقونة + اسم). [onBoard] لما تتحط فوق السبورة الغامقة.
class PointsLevelChip extends StatelessWidget {
  final PointsLevel level;
  final bool onBoard;
  const PointsLevelChip({super.key, required this.level, this.onBoard = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = pointsLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: onBoard
            ? Colors.white.withValues(alpha: 0.14)
            : c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(pointsLevelIcon(level), size: 14, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(level.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption
                  .copyWith(color: onBoard ? t.boardInk : t.ink)),
        ),
      ]),
    );
  }
}

Future<void> showStudentPointsSheet(
  BuildContext context, {
  required RankedPoints ranked,
  required String periodLabel,
  String? groupName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StudentPointsSheet(
        ranked: ranked, periodLabel: periodLabel, groupName: groupName),
  );
}

class StudentPointsSheet extends StatelessWidget {
  final RankedPoints ranked;
  final String periodLabel;
  final String? groupName;

  const StudentPointsSheet({
    super.key,
    required this.ranked,
    required this.periodLabel,
    this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = ranked.entry;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final b = e.breakdown;
    final rows = <(IconData, String, int)>[
      (Icons.event_available_rounded, 'الحضور', b.attendance),
      (Icons.local_fire_department_rounded, 'مكافأة الانتظام', b.streak),
      (Icons.quiz_rounded, 'الامتحانات', b.exams),
      (Icons.school_rounded, 'مكافأة التفوّق', b.excellence),
      (Icons.menu_book_rounded, 'الواجب', b.homework),
      (Icons.record_voice_over_rounded, 'التسميع', b.recitation),
      (Icons.bolt_rounded, 'التفاعل', b.interaction),
    ].where((r) => r.$3 > 0).toList();
    final maxRow =
        rows.fold<int>(1, (m, r) => r.$3 > m ? r.$3 : m).toDouble();

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: t.page,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.board)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _boardHeader(t, e),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg,
                AppSpace.xl + MediaQuery.paddingOf(context).bottom),
            children: [
              _ladder(t, e),
              const SizedBox(height: AppSpace.md),
              // ── سلاسل الانتظام ──
              Row(children: [
                Expanded(
                    child: _statCard(t, Icons.local_fire_department_rounded,
                        '${e.currentStreak}', 'سلسلة حضور حالية')),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                    child: _statCard(t, Icons.emoji_events_rounded,
                        '${e.bestStreak}', 'أطول سلسلة')),
              ]),
              const SizedBox(height: AppSpace.lg),
              // ── التفصيل ──
              Text('من فين جت النقاط؟',
                  style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.sm),
              if (rows.isEmpty)
                AppPanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                    child: Text('مفيش نقاط في الفترة دي',
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: t.inkSoft)),
                  ),
                )
              else
                AppPanel(
                  child: Column(children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(children: [
                          Row(children: [
                            Icon(r.$1, size: 18, color: t.inkSoft),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: Text(r.$2,
                                  style: AppType.body.copyWith(color: t.ink)),
                            ),
                            Text('${r.$3}',
                                style: AppType.label.copyWith(color: t.ink)),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: r.$3 / maxRow,
                              minHeight: 5,
                              color: t.brand,
                              backgroundColor: t.line,
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
              const SizedBox(height: AppSpace.lg),
              // ── الأوسمة ──
              Text('الأوسمة', style: AppType.label.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.sm),
              for (final badge in PointsBadge.values)
                _badgeRow(t, badge, e.badges.contains(badge)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── رأس السبورة ─────────────────────────────────────────────────────────
  Widget _boardHeader(AppTokens t, StudentPoints e) {
    // ألوان الأرقام فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    final rate = e.commitment;
    final hint = levelHint(rate: rate, sessions: e.sessions);
    return Container(
      width: double.infinity,
      color: t.board,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpace.md),
            decoration: BoxDecoration(
                color: t.boardInkSoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.chalk),
            child: Text(_initial(e.student.name),
                style: AppType.greeting.copyWith(color: t.onChalk)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.student.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.greeting.copyWith(color: t.boardInk)),
                  Text(
                      [
                        if (groupName != null && groupName!.isNotEmpty)
                          groupName!,
                        'المركز ${ranked.rank}',
                      ].join(' • '),
                      style: AppType.caption.copyWith(color: t.boardInkSoft)),
                ]),
          ),
          const SizedBox(width: AppSpace.sm),
          PointsLevelChip(level: e.level, onBoard: true),
        ]),
        const SizedBox(height: AppSpace.md),
        const ChalkDashedLine(),
        const SizedBox(height: AppSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: BoardStat(
                  label: 'نقاط $periodLabel',
                  value: '${e.points}',
                  color: t.chalk)),
          Expanded(
              child: BoardStat(
                  label: 'نسبة الالتزام',
                  value: rate == null ? '—' : '${rate.round()}%',
                  color: on.positive)),
          Expanded(
              child: BoardStat(
                  label: 'حضور من الحصص',
                  value: '${e.attended}/${e.sessions}',
                  color: t.boardInk)),
        ]),
        if (hint != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(hint, style: AppType.caption.copyWith(color: t.boardInkSoft)),
        ],
      ]),
    );
  }

  // ── سلم المستويات ───────────────────────────────────────────────────────
  Widget _ladder(AppTokens t, StudentPoints e) {
    final rate = e.commitment;
    final next = e.level.next;
    final progress = levelProgress(rate: rate, sessions: e.sessions);
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('سلم المستويات', style: AppType.label.copyWith(color: t.ink)),
        const SizedBox(height: 2),
        Text('المستوى بنسبة الالتزام: الحصص اللي حضرها ÷ كل الحصص المسجّلة.',
            style: AppType.caption.copyWith(color: t.inkSoft)),
        if (next != null) ...[
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: pointsLevelColor(e.level),
              backgroundColor: t.line,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        for (final l in PointsLevel.values.reversed)
          _ladderRow(t, l, reached: l.index <= e.level.index, current: l == e.level),
      ]),
    );
  }

  Widget _ladderRow(AppTokens t, PointsLevel l,
      {required bool reached, required bool current}) {
    final c = pointsLevelColor(l);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 6),
      decoration: BoxDecoration(
        color: current ? c.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: current ? c : Colors.transparent),
      ),
      child: Row(children: [
        Icon(pointsLevelIcon(l), size: 22, color: reached ? c : t.inkFaint),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.label,
                    style: AppType.label
                        .copyWith(color: reached ? t.ink : t.inkSoft)),
                Text(
                    l == PointsLevel.starter
                        ? 'البداية'
                        : 'التزام ${l.minRate}% أو أكتر، و${l.minSessions} حصة على الأقل',
                    style: AppType.caption.copyWith(color: t.inkSoft)),
              ]),
        ),
        if (current)
          Text('أنت هنا', style: AppType.caption.copyWith(color: t.ink))
        else if (reached)
          Icon(Icons.check_circle_rounded, size: 18, color: t.positive),
      ]),
    );
  }

  static String _initial(String name) {
    final s = name.trim();
    return s.isEmpty ? '?' : s.characters.first;
  }

  Widget _statCard(AppTokens t, IconData icon, String value, String label) =>
      AppPanel(
        child: Row(children: [
          Icon(icon, color: t.caution, size: 24),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AppType.title.copyWith(color: t.ink)),
                  Text(label,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ]),
          ),
        ]),
      );

  Widget _badgeRow(AppTokens t, PointsBadge b, bool unlocked) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: AppPanel(
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: unlocked ? t.cautionSoft : t.line.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(pointsBadgeIcon(b),
                  color: unlocked ? t.caution : t.inkFaint, size: 22),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.label,
                        style: AppType.label
                            .copyWith(color: unlocked ? t.ink : t.inkSoft)),
                    Text(b.description,
                        style: AppType.caption.copyWith(color: t.inkSoft)),
                  ]),
            ),
            Icon(
                unlocked
                    ? Icons.check_circle_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
                color: unlocked ? t.positive : t.inkFaint),
          ]),
        ),
      );
}
