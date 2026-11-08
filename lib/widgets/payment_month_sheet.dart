// lib/widgets/payment_month_sheet.dart
//
// «ملخص دفعات الشهر» (بيفتح من كارت الدفعات في الرئيسية): رأس بنسبة التحصيل
// وشريط تقدّم، أرقام واضحة (محصّل / باقي / متأخرين / مُسقَط)، وبعدها كارت
// لكل مجموعة بشريط تقدّمها وحالتها. كل الأرقام جاية من DashboardController
// (نفس أرقام الكارت بالظبط) — الشيت ده عرض بس.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/dashboard_controller.dart'
    show GroupPaymentSummaryEntry, StudentMonthLine;
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/points_chalk.dart' show ChalkDashedLine;

class PaymentMonthSheet extends StatelessWidget {
  final String monthName;
  final double collected;
  final double expected;
  final double remaining;
  final double writtenOff;

  /// نسبة التحصيل 0..1 (نفس نسبة الكارت).
  final double rate;
  final List<GroupPaymentSummaryEntry> groups;

  const PaymentMonthSheet({
    super.key,
    required this.monthName,
    required this.collected,
    required this.expected,
    required this.remaining,
    required this.writtenOff,
    required this.rate,
    required this.groups,
  });

  /// المبلغ بمسافة غير قابلة للكسر (الرقم والعملة ما يتفصلوش على سطرين).
  String _money(double v) =>
      FormatHelper.formatCurrency(v).replaceAll(RegExp(r'\s'), '\u00A0');

  /// سطر واحد دايمًا: لو المساحة ضيقة النص بيصغّر بدل ما ينزل سطر.
  Widget _fit(Widget child,
          {AlignmentGeometry alignment = AlignmentDirectional.centerStart}) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final lateTotal = groups.fold<int>(0, (s, g) => s + g.unpaidStudentsCount);
    final pct = (rate.clamp(0.0, 1.0) * 100).round();
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: t.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: t.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: t.rosterTint,
                    borderRadius: BorderRadius.circular(AppRadius.control)),
                child: Icon(Icons.bar_chart_rounded,
                    color: t.rosterInk, size: 22),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text('ملخص دفعات $monthName',
                    style: AppType.title.copyWith(color: t.ink)),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
              children: [
                _summary(t, pct, lateTotal),
                const SizedBox(height: AppSpace.lg),
                Text('المجموعات',
                    style: AppType.label.copyWith(color: t.ink)),
                if (groups.isNotEmpty)
                  Text('اضغط على مجموعة علشان تشوف المتأخرين والمدفوع فيها',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                const SizedBox(height: AppSpace.sm),
                if (groups.isEmpty)
                  AppPanel(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.lg),
                      child: Text('مفيش مستحقات على أي مجموعة للشهر ده',
                          textAlign: TextAlign.center,
                          style: AppType.body.copyWith(color: t.inkSoft)),
                    ),
                  ),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: _groupCard(context, t, g),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bar(AppTokens t, double value, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 8,
          color: color,
          backgroundColor: t.line,
        ),
      );

  Widget _summary(AppTokens t, int pct, int lateTotal) {
    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(children: [
            _fit(
                Text(value,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppType.label.copyWith(color: color)),
                alignment: Alignment.center),
            const SizedBox(height: 2),
            _fit(
                Text(label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: t.inkSoft)),
                alignment: Alignment.center),
          ]),
        );
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المحصّل',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                  _fit(Text(_money(collected),
                      maxLines: 1,
                      style: AppType.title.copyWith(color: t.positive))),
                  _fit(Text('من ${_money(expected)}',
                      maxLines: 1,
                      style: AppType.caption.copyWith(color: t.inkSoft))),
                ]),
          ),
          Text('$pct%', style: AppType.title.copyWith(color: t.ink)),
        ]),
        const SizedBox(height: AppSpace.md),
        _bar(t, rate, t.positive),
        const SizedBox(height: AppSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stat('الباقي', _money(remaining),
              remaining > 0.5 ? t.danger : t.positive),
          stat('طالب متأخر', '$lateTotal',
              lateTotal > 0 ? t.caution : t.positive),
          if (writtenOff > 0.5) stat('مُسقَط', _money(writtenOff), t.inkSoft),
        ]),
      ]),
    );
  }

  Widget _cell(AppTokens t, String label, String value, Color color) =>
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.caption.copyWith(color: t.inkFaint)),
              _fit(Text(value,
                  maxLines: 1,
                  style: AppType.label.copyWith(color: color))),
            ]),
      );

  Widget _groupCard(
      BuildContext context, AppTokens t, GroupPaymentSummaryEntry g) {
    final done = g.remaining <= 0.01;
    final tappable = g.lines.isNotEmpty;
    final progress =
        g.expected > 0 ? (g.expected - g.remaining) / g.expected : 1.0;
    final accent = done ? t.positive : t.danger;
    return AppPanel(
      onTap: tappable
          ? () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) =>
                    GroupPaymentDetailSheet(monthName: monthName, group: g),
              )
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(g.groupName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: t.ink)),
          ),
          const SizedBox(width: AppSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: done ? t.positiveSoft : t.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(done ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 14, color: accent),
              const SizedBox(width: 4),
              Text(done ? 'مكتملة' : '${g.unpaidStudentsCount} متأخر',
                  style: AppType.caption.copyWith(color: accent)),
            ]),
          ),
          if (tappable) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_left_rounded, color: t.inkFaint),
          ],
        ]),
        const SizedBox(height: AppSpace.sm),
        _bar(t, progress, t.positive),
        const SizedBox(height: AppSpace.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cell(t, 'محصّل', _money(g.collected), t.ink),
          _cell(t, 'المستحق', _money(g.expected), t.inkSoft),
          _cell(t, 'الباقي', done ? '—' : _money(g.remaining),
              done ? t.positive : t.danger),
        ]),
      ]),
    );
  }
}


/// تفاصيل مجموعة واحدة في الشهر: تابين «متأخر» و«مدفوع» بكل طالب ومبلغه —
/// عشان تعرف المبلغ الصغير (زي 10 ج) ده بتاع مين وإزاي اتحسب.
class GroupPaymentDetailSheet extends StatelessWidget {
  final String monthName;
  final GroupPaymentSummaryEntry group;
  const GroupPaymentDetailSheet(
      {super.key, required this.monthName, required this.group});

  String _money(double v) =>
      FormatHelper.formatCurrency(v).replaceAll(RegExp(r'\s'), ' ');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final late = group.lines.where((l) => l.unpaid).toList()
      ..sort((a, b) => b.shortfall.compareTo(a.shortfall));
    final paid = group.lines
        .where((l) => l.paid > 0.01 || l.writtenOff > 0.01)
        .toList()
      ..sort((a, b) => b.paid.compareTo(a.paid));
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return DefaultTabController(
      length: 2,
      child: Container(
        height: maxH,
        decoration: BoxDecoration(
          color: t.page,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: t.line, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.groupName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.title.copyWith(color: t.ink)),
                      Text(
                          '$monthName — محصّل ${_money(group.collected)} من ${_money(group.expected)}',
                          style: AppType.caption.copyWith(color: t.inkSoft)),
                    ]),
              ),
            ),
            TabBar(
              labelColor: t.ink,
              unselectedLabelColor: t.inkSoft,
              indicatorColor: t.positive,
              labelStyle: AppType.label,
              dividerColor: t.line,
              tabs: [
                Tab(text: 'متأخر (${late.length})'),
                Tab(text: 'مدفوع (${paid.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [
                _list(t, late, isLate: true),
                _list(t, paid, isLate: false),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _list(AppTokens t, List<StudentMonthLine> items,
      {required bool isLate}) {
    if (items.isEmpty) {
      return Center(
        child: Text(isLate ? 'مفيش متأخرين في المجموعة دي' : 'لسه مفيش مدفوعات',
            style: AppType.body.copyWith(color: t.inkSoft)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: ChalkDashedLine()),
      itemBuilder: (_, i) {
        final l = items[i];
        final amount = isLate ? l.shortfall : l.paid;
        final color = isLate ? t.danger : t.positive;
        final soft = isLate ? t.dangerSoft : t.positiveSoft;
        final String detail;
        if (isLate) {
          detail = l.paid > 0.01
              ? 'دفع ${_money(l.paid)} من ${_money(l.due)}'
              : 'المستحق ${_money(l.due)} ولسه ما دفعش';
        } else {
          detail = l.unpaid
              ? 'رصيد من دفعات قبل كده — المستحق ${_money(l.due)}'
              : l.writtenOff > 0.01
                  ? 'المستحق ${_money(l.due)} (اتسقط ${_money(l.writtenOff)})'
                  : 'سدّد المستحق ${_money(l.due)}';
        }
        final isSibling =
            l.student.siblingGroupId != null || l.student.siblingId != null;
        return Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Text(
                l.student.name.trim().isNotEmpty
                    ? l.student.name.trim()[0]
                    : '?',
                style: AppType.label.copyWith(color: color)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(l.student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(color: t.ink)),
                    ),
                    if (isSibling) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: t.line.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text('إخوة',
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      ),
                    ],
                  ]),
                  Text(detail,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                  if (!isLate && l.payments.isNotEmpty)
                    Text(
                        'إجمالي دفعاته ${_money(l.payments.fold<double>(0, (a, p) => a + p.amount))}'
                        ' − مستحق الشهور اللي فاتت ${_money(l.dueBefore)}',
                        style: AppType.caption.copyWith(color: t.inkFaint)),
                ]),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(_money(amount), style: AppType.label.copyWith(color: color)),
        ]);
      },
    );
  }
}
