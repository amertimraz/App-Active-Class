// lib/widgets/month_income_card.dart
//
// كارت «دخل الشهر ده» (تاب «الدخل» في كارت الفلوس بالرئيسية): الكاش اللي دخل
// فعلًا في الشهر الحالي (اشتراكات + كراسات) ومقارنته بالشهر اللي فات. بيفتح
// صفحة «دخلي». التخطيط عمودي (عنوان فوق، الرقم تحته) عشان ما يتكسرش النص.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/config/theme.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/income_summary.dart';
import 'package:active_class/widgets/app_panel.dart';

class MonthIncomeCard extends StatefulWidget {
  /// بيتغيّر لما بيانات الرئيسية تتحدّث — عشان الكارت يعيد القراءة.
  final Object? refreshKey;
  final bool locked;
  final bool hidden; // إخفاء الأرقام (زرار العين في الرئيسية)
  final VoidCallback onTap;

  const MonthIncomeCard({
    super.key,
    required this.refreshKey,
    required this.locked,
    required this.hidden,
    required this.onTap,
  });

  @override
  State<MonthIncomeCard> createState() => _MonthIncomeCardState();
}

class _MonthIncomeCardState extends State<MonthIncomeCard> {
  double? _total;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MonthIncomeCard old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    if (widget.locked) return;
    try {
      final db = DatabaseService();
      final payments = await db.getAllPayments();
      final booklets = await db.getAllBookletPayments();
      final now = DateTime.now();
      final cur = incomeTotalFor(
          month: now, payments: payments, bookletPayments: booklets);
      final prev = incomeTotalFor(
          month: DateTime(now.year, now.month - 1, 1),
          payments: payments,
          bookletPayments: booklets);
      if (mounted) {
        setState(() {
          _total = cur;
          _prev = prev;
        });
      }
    } catch (_) {
      // الكارت مساعد: لو فشل القراءة مانكسرش الرئيسية.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = _total;
    final monthName = DateFormat('MMMM', 'ar').format(DateTime.now());
    final shown = widget.locked || widget.hidden
        ? '••••'
        : (total == null ? '…' : FormatHelper.formatCurrency(total));

    String caption;
    Color? captionColor;
    if (widget.locked) {
      caption = 'مقفول';
    } else if (total == null) {
      caption = 'بنحسب…';
    } else if (_prev <= 0) {
      caption = 'الكاش اللي دخل فعلًا الشهر ده';
    } else {
      final pct = (total - _prev) * 100 / _prev;
      caption =
          '${pct >= 0 ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}% عن الشهر اللي فات';
      captionColor = pct >= 0 ? t.positive : t.danger;
    }

    return Semantics(
      button: true,
      label: 'دخل $monthName: $shown. $caption',
      child: AppPanel(
        onTap: widget.onTap,
        lineColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.payments_rounded, color: t.positive, size: 20),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text('دخل $monthName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
              ),
              Icon(Icons.chevron_left_rounded, size: 20, color: t.inkSoft),
            ]),
            const SizedBox(height: AppSpace.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(shown,
                  maxLines: 1,
                  style: AppType.figure.copyWith(color: t.moneyInk)),
            ),
            const SizedBox(height: 2),
            Text(caption,
                style: AppType.caption.copyWith(
                    color: captionColor ?? t.inkSoft, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
