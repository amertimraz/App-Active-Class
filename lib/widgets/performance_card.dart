// lib/widgets/performance_card.dart
//
// spec 050 — كارت مستوى الطالب (يتحوّل لصورة PNG ويتبعت لولي الأمر).
// عرض ثابت 360 وألوان ثابتة (مش مرتبطة بثيم التطبيق) عشان الصورة تطلع
// نفسها على أي جهاز. السهم نص (↑ ↓ ➖) مش لون بس.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:active_class/utils/performance.dart';

const Color kPerfUp = Color(0xFF10B981);
const Color kPerfDown = Color(0xFFEF4444);
const Color kPerfSteady = Color(0xFF6B7280);

Color perfTrendColor(PerfTrend t) {
  switch (t) {
    case PerfTrend.up:
      return kPerfUp;
    case PerfTrend.down:
      return kPerfDown;
    default:
      return kPerfSteady;
  }
}

Color perfKindColor(PerfKind k) {
  switch (k) {
    case PerfKind.exams:
      return const Color(0xFF4F46E5);
    case PerfKind.attendance:
      return const Color(0xFF10B981);
    case PerfKind.homework:
      return const Color(0xFFF59E0B);
    case PerfKind.recitation:
      return const Color(0xFF0EA5E9);
  }
}

String perfPct(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? '${v.toInt()}%' : '${v.toStringAsFixed(1)}%';
}

String perfDelta(double? d) {
  if (d == null) return '';
  final r = d.abs() == d.abs().roundToDouble()
      ? d.abs().toInt().toString()
      : d.abs().toStringAsFixed(1);
  return d >= 0 ? '+$r' : '-$r';
}

class PerformanceCard extends StatelessWidget {
  final StudentPerformance perf;
  final String teacherName;
  final String teacherSpecialization;

  const PerformanceCard({
    super.key,
    required this.perf,
    this.teacherName = '',
    this.teacherSpecialization = '',
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(perf.month);
    final tn = teacherName.trim();
    final ts = teacherSpecialization.trim();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تقرير مستوى الطالب — $monthLabel',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(perf.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.25)),
                  if (perf.groupName.isNotEmpty && perf.groupName != '-')
                    Text(perf.groupName,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            color: Colors.white70)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(children: [
                for (final i in perf.indicators)
                  if (i.hasAnyData) _IndicatorRow(i)
                  else const SizedBox.shrink(),
                if (!perf.hasAnyData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('لا توجد بيانات كافية بعد',
                        style: TextStyle(
                            fontFamily: 'Cairo', color: Color(0xFF6B7280))),
                  ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                      [
                        if (tn.isNotEmpty) tn,
                        if (ts.isNotEmpty) ts,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600)),
                ),
                const Text('Active Class',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  final PerfIndicator i;
  const _IndicatorRow(this.i);

  @override
  Widget build(BuildContext context) {
    final c = perfKindColor(i.kind);
    final tc = perfTrendColor(i.trend);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Column(children: [
        Row(children: [
          Text(i.kind.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(i.kind.label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c)),
          ),
          if (i.current != null) ...[
            Text(perfPct(i.current),
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    height: 1.1)),
          ] else
            const Text('—',
                style: TextStyle(fontSize: 20, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          if (i.trend != PerfTrend.none)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  '${trendArrow(i.trend)} ${trendWord(i.trend)} ${perfDelta(i.delta)}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: tc)),
            )
          else
            Text(
                i.current == null
                    ? 'لا بيانات هذا الشهر'
                    : 'لا يوجد شهر سابق للمقارنة',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Color(0xFF6B7280))),
          const SizedBox(width: 8),
          if (i.previous != null)
            Text('السابق ${perfPct(i.previous)}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Color(0xFF6B7280))),
          const Spacer(),
          if (i.level.isNotEmpty)
            Text(i.level,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          width: double.infinity,
          child: CustomPaint(painter: SparklinePainter(i.series, c)),
        ),
      ]),
    );
  }
}

/// خط صغير لآخر شهور — الشهور بلا بيانات (null) فجوة مش صفر.
class SparklinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;
  SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final n = values.length;
    final dx = size.width / (n - 1);
    Offset pt(int i) =>
        Offset(i * dx, size.height - (values[i]!.clamp(0, 100) / 100) * (size.height - 6) - 3);

    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = color;
    final base = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), base);

    Path? seg;
    for (var i = 0; i < n; i++) {
      if (values[i] == null) {
        if (seg != null) canvas.drawPath(seg, line);
        seg = null;
        continue;
      }
      final p = pt(i);
      if (seg == null) {
        seg = Path()..moveTo(p.dx, p.dy);
      } else {
        seg.lineTo(p.dx, p.dy);
      }
      canvas.drawCircle(p, i == n - 1 ? 3.6 : 2.4, dot);
    }
    if (seg != null) canvas.drawPath(seg, line);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter old) =>
      old.values != values || old.color != color;
}

/// يلتقط RepaintBoundary كـPNG (pixelRatio 3 لجودة واتساب).
Future<Uint8List?> capturePerformancePng(GlobalKey key,
    {double pixelRatio = 3}) async {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  // ملحوظة: ما نستخدمش boundary.debugNeedsPaint — في الـrelease بيرمي
  // LateInitializationError (مبني على assert).
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
