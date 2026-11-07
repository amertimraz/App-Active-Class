// lib/widgets/payment_month_sheet.dart
//
// «ملخص دفعات الشهر» (بيفتح من كارت الدفعات في الرئيسية): رأس بنسبة التحصيل
// وشريط تقدّم، أرقام واضحة (محصّل / باقي / متأخرين / مُسقَط)، وبعدها كارت
// لكل مجموعة بشريط تقدّمها وحالتها. كل الأرقام جاية من DashboardController
// (نفس أرقام الكارت بالظبط) — الشيت ده عرض بس.
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/dashboard_controller.dart'
    show GroupPaymentSummaryEntry;
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_panel.dart';

class PaymentMonthSheet extends StatelessWidget {
  final String monthName;
  final double collected;
  final double expected;
  final double remaining;
  final double writtenOff;

  /// نسبة التحصيل 0..1 (نفس نسبة الكارت).
  final double rate;
  final List<GroupPaymentSummaryEntry> groups;

  /// الضغط على مجموعة عليها متأخرين (null = طلاب بلا مجموعة).
  final void Function(int? groupId) onGroupTap;

  const PaymentMonthSheet({
    super.key,
    required this.monthName,
    required this.collected,
    required this.expected,
    required this.remaining,
    required this.writtenOff,
    required this.rate,
    required this.groups,
    required this.onGroupTap,
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
                if (groups.any((g) => g.unpaidStudentsCount > 0))
                  Text('اضغط على مجموعة علشان تشوف المتأخرين فيها',
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
                    child: _groupCard(t, g),
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

  Widget _groupCard(AppTokens t, GroupPaymentSummaryEntry g) {
    final done = g.remaining <= 0.01;
    final tappable = g.unpaidStudentsCount > 0;
    final progress =
        g.expected > 0 ? (g.expected - g.remaining) / g.expected : 1.0;
    final accent = done ? t.positive : t.danger;
    return AppPanel(
      onTap: tappable ? () => onGroupTap(g.groupId) : null,
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
