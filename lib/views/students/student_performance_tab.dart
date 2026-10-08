// lib/views/students/student_performance_tab.dart
//
// spec 050 — تبويب "الأداء" في تفاصيل الطالب: مؤشرات (امتحانات/حضور/واجب/
// تسميع) بنسبة الشهر والاتجاه عن الشهر اللي قبله، ورسم آخر 6 شهور، وإرسال
// لولي الأمر (كارت/نص/PDF). كل الأرقام من StudentPerformance (مصدر واحد).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/performance_service.dart';
import 'package:active_class/utils/performance.dart';
import 'package:active_class/views/students/performance_actions.dart';
import 'package:active_class/widgets/performance_card.dart';

class StudentPerformanceTab extends StatefulWidget {
  final Student student;
  final String? groupName;
  const StudentPerformanceTab(
      {super.key, required this.student, this.groupName});

  @override
  State<StudentPerformanceTab> createState() => _StudentPerformanceTabState();
}

class _StudentPerformanceTabState extends State<StudentPerformanceTab> {
  StudentPerformance? _perf;
  DateTime? _month;
  bool _loading = true;
  PerfKind? _selected; // null = كل المؤشرات في الرسم

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final p = await PerformanceService.forStudentDefaultMonth(widget.student,
        groupName: widget.groupName);
    if (!mounted) return;
    setState(() {
      _perf = p;
      _month = p.month;
      _loading = false;
      for (final i in p.indicators) {
        if (i.hasAnyData) {
          _selected = i.kind;
          break;
        }
      }
    });
  }

  Future<void> _go(DateTime month) async {
    setState(() => _loading = true);
    final p = await PerformanceService.forStudent(widget.student, month,
        groupName: widget.groupName);
    if (!mounted) return;
    setState(() {
      _perf = p;
      _month = p.month;
      _loading = false;
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    final m = _month ?? now;
    return m.year == now.year && m.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perf = _perf;
    if (_loading && perf == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (perf == null) return const SizedBox.shrink();
    final month = _month!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // ── اختيار الشهر + الإرسال ───────────────────────────────────
        Row(children: [
          IconButton(
            tooltip: 'الشهر السابق',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _go(DateTime(month.year, month.month - 1, 1)),
          ),
          Expanded(
            child: Column(children: [
              Text(DateFormat('MMMM yyyy', 'ar').format(month),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                  _loading
                      ? 'جاري التحديث…'
                      : 'مقارنة بـ${DateFormat('MMMM', 'ar').format(DateTime(month.year, month.month - 1, 1))}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
          IconButton(
            tooltip: 'الشهر التالي',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _isCurrentMonth
                ? null
                : () => _go(DateTime(month.year, month.month + 1, 1)),
          ),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: perf.hasAnyData
                ? () => showPerformanceSendSheet(context, widget.student, perf)
                : null,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('إرسال لولي الأمر',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 14),

        if (perf.notes.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${perf.notes.join('\n')}\n(بحسب "شهر التقرير" المحدد للامتحان)',
                    style: const TextStyle(fontSize: 12, height: 1.5)),
              ),
            ]),
          ),
        ],
        if (!perf.hasAnyData)
          _EmptyPerf(isDark: isDark)
        else ...[
          for (final i in perf.indicators)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IndicatorCard(
                indicator: i,
                selected: _selected == i.kind,
                isDark: isDark,
                onTap: () => setState(
                    () => _selected = _selected == i.kind ? null : i.kind),
              ),
            ),
          const SizedBox(height: 6),
          _TrendChartCard(
            perf: perf,
            selected: (_selected != null &&
                    (perf.indicator(_selected!)?.hasAnyData ?? false))
                ? _selected
                : null,
            isDark: isDark,
            onSelect: (k) => setState(() => _selected = k),
          ),
        ],
      ],
    );
  }
}

class _EmptyPerf extends StatelessWidget {
  final bool isDark;
  const _EmptyPerf({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2540) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(Icons.insights_rounded, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text('لا توجد بيانات كافية بعد',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('هيظهر مستوى الطالب بعد تسجيل حضور أو امتحانات أو واجب.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      );
}

class _IndicatorCard extends StatelessWidget {
  final PerfIndicator indicator;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _IndicatorCard({
    required this.indicator,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i = indicator;
    final c = perfKindColor(i.kind);
    final tc = perfTrendColor(i.trend);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2540) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? c : c.withValues(alpha: 0.15),
              width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(i.kind.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(i.kind.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: c)),
                  if (i.level.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(i.level,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500)),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(
                  i.current == null
                      ? (i.previous == null
                          ? 'لا توجد بيانات'
                          : 'لا بيانات هذا الشهر — السابق ${perfPct(i.previous)}')
                      : (i.previous == null
                          ? 'لا يوجد شهر سابق للمقارنة · ${i.kind.samplesLabel(i.currentSamples)}'
                          : 'السابق ${perfPct(i.previous)} · ${i.kind.samplesLabel(i.currentSamples)}'),
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(perfPct(i.current),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
            if (i.trend != PerfTrend.none)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    '${trendArrow(i.trend)} ${trendWord(i.trend)} ${perfDelta(i.delta)}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: tc)),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  final StudentPerformance perf;
  final PerfKind? selected;
  final bool isDark;
  final ValueChanged<PerfKind?> onSelect;
  const _TrendChartCard({
    required this.perf,
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  PerfIndicator? get _single {
    if (selected == null) return null;
    for (final i in perf.indicators) {
      if (i.kind == selected && i.hasAnyData) return i;
    }
    return null;
  }

  /// مقاطع متصلة من السلسلة (الشهور بلا بيانات تقطع الخط).
  List<List<FlSpot>> _segments(PerfIndicator ind) {
    final out = <List<FlSpot>>[];
    var seg = <FlSpot>[];
    for (var m = 0; m < ind.series.length; m++) {
      final v = ind.series[m];
      if (v == null) {
        if (seg.isNotEmpty) out.add(seg);
        seg = <FlSpot>[];
      } else {
        seg.add(FlSpot(m.toDouble(), v));
      }
    }
    if (seg.isNotEmpty) out.add(seg);
    return out;
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color,
      {required bool filled, double width = 3}) {
    return LineChartBarData(
      spots: spots,
      isCurved: spots.length > 2,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (s, p, b, i) => FlDotCirclePainter(
          radius: filled ? 4.5 : 3.2,
          color: Colors.white,
          strokeWidth: filled ? 2.6 : 2,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: filled,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final single = _single;
    final bars = <LineChartBarData>[];
    final shownKinds = <PerfKind>[];
    if (single != null) {
      final c = perfKindColor(single.kind);
      for (final seg in _segments(single)) {
        bars.add(_bar(seg, c, filled: true));
      }
    } else {
      for (final ind in perf.indicators) {
        if (!ind.hasAnyData) continue;
        shownKinds.add(ind.kind);
        final c = perfKindColor(ind.kind);
        for (final seg in _segments(ind)) {
          bars.add(_bar(seg, c, filled: false, width: 2.4));
        }
      }
    }

    // تسميات القيم ثابتة فوق كل نقطة لما مؤشر واحد بس مختار.
    final showing = <ShowingTooltipIndicators>[];
    if (single != null) {
      for (var b = 0; b < bars.length; b++) {
        for (var s = 0; s < bars[b].spots.length; s++) {
          showing.add(ShowingTooltipIndicators([
            LineBarSpot(bars[b], b, bars[b].spots[s]),
          ]));
        }
      }
    }

    final values = single?.series.whereType<double>().toList() ?? const [];
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final hi = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    final lo = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final change = values.length >= 2 ? values.last - values.first : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2540) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text('اتجاه آخر ${perf.months.length} شهور',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        Wrap(spacing: 6, runSpacing: 4, children: [
          ChoiceChip(
            label: const Text('الكل', style: TextStyle(fontSize: 11.5)),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
            visualDensity: VisualDensity.compact,
          ),
          for (final i in perf.indicators)
            if (i.hasAnyData)
              ChoiceChip(
                avatar: CircleAvatar(
                    radius: 5, backgroundColor: perfKindColor(i.kind)),
                label: Text(i.kind.label, style: const TextStyle(fontSize: 11.5)),
                selected: selected == i.kind,
                selectedColor: perfKindColor(i.kind).withValues(alpha: 0.22),
                onSelected: (_) => onSelect(i.kind),
                visualDensity: VisualDensity.compact,
              ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: bars.isEmpty
              ? Center(
                  child: Text('لا توجد نقاط للعرض',
                      style: TextStyle(color: Colors.grey.shade500)))
              : LineChart(LineChartData(
                  minX: 0,
                  maxX: (perf.months.length - 1).toDouble(),
                  minY: 0,
                  maxY: 110,
                  clipData: const FlClipData.none(),
                  // مناطق المستوى: أحمر (<50) / كهرماني (50–75) / أخضر (≥75)
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                          y1: 0,
                          y2: 50,
                          color: kPerfDown.withValues(alpha: 0.06)),
                      HorizontalRangeAnnotation(
                          y1: 50,
                          y2: 75,
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.06)),
                      HorizontalRangeAnnotation(
                          y1: 75,
                          y2: 100,
                          color: kPerfUp.withValues(alpha: 0.06)),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    checkToShowHorizontalLine: (v) => v <= 100,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.grey.withValues(alpha: 0.2),
                        strokeWidth: 1,
                        dashArray: [4, 4]),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    // هامش يمين صغير عشان آخر نقطة ما تتقصّش
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 12,
                        getTitlesWidget: (v, meta) => const SizedBox.shrink(),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        reservedSize: 36,
                        getTitlesWidget: (v, meta) => v > 100
                            ? const SizedBox.shrink()
                            : Text('${v.toInt()}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 26,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if ((v - i).abs() > 0.01 ||
                              i < 0 ||
                              i >= perf.months.length) {
                            return const SizedBox.shrink();
                          }
                          final isLast = i == perf.months.length - 1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                DateFormat('MMM', 'ar').format(perf.months[i]),
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight:
                                        isLast ? FontWeight.w800 : FontWeight.w500,
                                    color: isLast
                                        ? null
                                        : Colors.grey.shade500)),
                          );
                        },
                      ),
                    ),
                  ),
                  showingTooltipIndicators: showing,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: single == null,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      tooltipMargin: 6,
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipRoundedRadius: 6,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                              '${s.y == s.y.roundToDouble() ? s.y.toInt() : s.y.toStringAsFixed(1)}%',
                              TextStyle(
                                  color: s.bar.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12)),
                      ],
                    ),
                  ),
                  lineBarsData: bars,
                )),
        ),
        if (single != null && avg != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            _MiniStat('المتوسط', perfPct(double.parse(avg.toStringAsFixed(1)))),
            _MiniStat('الأعلى', perfPct(hi)),
            _MiniStat('الأقل', perfPct(lo)),
            _MiniStat(
                'التغيّر',
                change == null
                    ? '—'
                    : '${change >= 0 ? '↑' : '↓'} ${perfDelta(double.parse(change.toStringAsFixed(1)))}',
                color: change == null
                    ? null
                    : (change >= kTrendSteadyBand
                        ? kPerfUp
                        : change <= -kTrendSteadyBand
                            ? kPerfDown
                            : kPerfSteady)),
          ]),
        ] else if (single == null && shownKinds.length > 1) ...[
          const SizedBox(height: 8),
          Text('اضغط على مؤشر لعرضه لوحده بقيمه ومتوسطه.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      );
}
