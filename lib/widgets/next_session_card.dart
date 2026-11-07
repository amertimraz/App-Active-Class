// lib/widgets/next_session_card.dart
//
// شريط «الحصة الجاية» في الرئيسية: سطرين بس — المجموعة، وتحتها الحالة
// والميعاد وعدد الطلاب — وزرار ابدأ الحضور، وشارة «N متأخر» لو فيه متأخرين
// في الدفع (بتفتح الإرسال الجماعي لمجموعة الحصة).
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/next_session.dart';

class NextSessionCard extends StatelessWidget {
  final NextSessionInfo info;
  final bool canSeeFinancials;
  final VoidCallback onAttendance;
  final VoidCallback onRemind;

  /// للاختبار: وقت ثابت بدل الوقت الحالي.
  final DateTime? now;

  const NextSessionCard({
    super.key,
    required this.info,
    required this.canSeeFinancials,
    required this.onAttendance,
    required this.onRemind,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = AppTokens.dark;
    final n = now ?? DateTime.now();
    final range =
        '${FormatHelper.formatClock(TimeOfDay.fromDateTime(info.start))} - '
        '${FormatHelper.formatClock(TimeOfDay.fromDateTime(info.end))}';
    final status =
        info.isLive ? 'شغالة دلوقتي' : untilText(info.start.difference(n));
    final showOverdue = canSeeFinancials && info.overdueCount > 0;
    return Material(
      color: t.board,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAttendance,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.sm, AppSpace.sm, AppSpace.sm),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: info.isLive ? on.positive : t.chalk),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.label.copyWith(color: t.boardInk)),
                    Text('$status • $range • ${info.studentCount} طالب',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppType.caption.copyWith(color: t.boardInkSoft)),
                  ]),
            ),
            if (showOverdue)
              Tooltip(
                message: 'ذكّر المتأخرين',
                child: InkWell(
                  onTap: onRemind,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: on.danger.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text('${info.overdueCount} متأخر',
                          style: AppType.caption.copyWith(color: on.danger)),
                    ),
                  ),
                ),
              ),
            Tooltip(
              message: 'ابدأ الحضور',
              child: IconButton.filled(
                onPressed: onAttendance,
                style: IconButton.styleFrom(
                    backgroundColor: t.chalk,
                    foregroundColor: t.onChalk,
                    minimumSize: const Size(44, 44)),
                icon: const Icon(Icons.how_to_reg_rounded),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
