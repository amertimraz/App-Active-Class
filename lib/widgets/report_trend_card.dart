// lib/widgets/report_trend_card.dart
//
// كارت «الاتجاه» في نظرة عامة التقارير: خط لآخر ٦ شهور لمؤشر واحد يختاره
// المدرس (حضور / تحصيل / واجب / امتحانات). الشهور من غير بيانات بتبان فجوة.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/report_trend.dart';
import 'package:active_class/widgets/app_panel.dart';

class ReportTrendCard extends StatefulWidget {
  final List<TrendPoint> points;

  /// false = مؤشر «الامتحانات» مخفي (مساعد من غير صلاحية الأكاديمي).
  final bool showExams;
  const ReportTrendCard({super.key, required this.points, this.showExams = true});

  @override
  State<ReportTrendCard> createState() => _ReportTrendCardState();
}

class _Metric {
  final String label;
  final double? Function(TrendPoint) pick;
  const _Metric(this.label, this.pick);
}

class _ReportTrendCardState extends State<ReportTrendCard> {
  static final _metrics = <_Metric>[
    _Metric('الحضور', (p) => p.attendance),
    _Metric('التحصيل', (p) => p.collection),
    _Metric('الواجب', (p) => p.homework),
    _Metric('الامتحانات', (p) => p.exams),
  ];
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final metrics = widget.showExams
        ? _metrics
        : [for (final m in _metrics) if (m.label != 'الامتحانات') m];
    final m = metrics[_sel.clamp(0, metrics.length - 1)];
    final pts = widget.points;
    final vals = [for (final p in pts) m.pick(p)];
    final has = vals.any((v) => v != null);
    final fmt = DateFormat('MMM', 'ar');

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: AppSpace.sm, children: [
            for (var i = 0; i < metrics.length; i++)
              ChoiceChip(
                label: Text(metrics[i].label),
                selected: i == _sel,
                onSelected: (_) => setState(() => _sel = i),
              ),
          ]),
          const SizedBox(height: AppSpace.md),
          if (!has)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              child: Text('مفيش بيانات كفاية في آخر ٦ شهور.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: t.inkSoft)),
            )
          else
            SizedBox(
              height: 170,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: LineChart(LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: (pts.length - 1).toDouble(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: t.line, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text('${v.round()}%',
                            style: AppType.caption.copyWith(color: t.inkFaint)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) {
                          final i = v.round();
                          if (i < 0 || i >= pts.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(fmt.format(pts[i].month),
                                style: AppType.caption
                                    .copyWith(color: t.inkSoft)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => t.board,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem('${s.y.round()}%',
                              AppType.label.copyWith(color: t.boardInk)),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < vals.length; i++)
                          vals[i] == null
                              ? FlSpot.nullSpot
                              : FlSpot(i.toDouble(), vals[i]! * 100),
                      ],
                      isCurved: false,
                      color: t.brand,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                )),
              ),
            ),
        ],
      ),
    );
  }
}
