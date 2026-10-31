// lib/views/web/web_auth_widgets.dart
//
// spec 055 — مكوّنات شاشتي الترحيب وتسجيل الدخول على الويب.
// الفكرة الوحيدة المميّزة: «كشف الحضور» — جدول طلاب × أيام بيتعلّم بعلامات
// صح مرة واحدة أول ما الشاشة تفتح (ولو المستخدم مفعّل «تقليل الحركة» بيظهر
// مكتمل فورًا). كل حاجة تانية هادية عشان الكشف يبقى هو اللي يتشاف.
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/config/theme.dart';

/// ألوان شاشات الدخول (حبر نيلي غامق + ورق بارد + علامة خضرا + أصفر قلم).
class WebAuthPalette {
  WebAuthPalette._();
  static const ink = Color(0xFF16143F);
  static const inkRaised = Color(0xFF211F57);
  static const brand = AppTheme.primaryColor;
  static const paper = Color(0xFFF5F5FB);
  static const tick = Color(0xFF34D399);
  static const marker = Color(0xFFFBBF24);
  static const mist = Color(0xFFC7C9F5);
}

/// رقم دعم واتساب (نفس المستخدم في باقي التطبيق).
const _supportPhone = '201096066818';

Future<void> openWebSupport(String message) async {
  final uri = Uri.parse(
      'https://wa.me/$_supportPhone?text=${Uri.encodeComponent(message)}');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// شعار التطبيق + الاسم.
class WebBrandMark extends StatelessWidget {
  const WebBrandMark({super.key, this.size = 36, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Active Class',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.asset('assets/icon/logo.png',
              width: size, height: size, excludeFromSemantics: true),
        ),
        SizedBox(width: size * 0.3),
        Flexible(
          child: Text('Active Class',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ]),
    );
  }
}

// ── كشف الحضور ──────────────────────────────────────────────────────────────

// P = حضر، A = غاب، L = اتأخر. ثابتة عشان الشكل يبقى مستقر في كل فتح.
const _kRegister = <String, String>{
  'أحمد سعيد': 'PPPPLPP',
  'مريم عادل': 'PPPPPPP',
  'يوسف حسن': 'PAPPPPP',
  'سلمى محمود': 'PPPPPPA',
  'عمر خالد': 'PPLPPPP',
  'ليلى إبراهيم': 'PPPPPAP',
};
const _kDays = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

class AttendanceRegisterArt extends StatefulWidget {
  const AttendanceRegisterArt(
      {super.key, this.animate = true, this.maxWidth = 520});

  /// false = يظهر مكتمل فورًا (الشاشة التانية / تقليل الحركة).
  final bool animate;
  final double maxWidth;

  @override
  State<AttendanceRegisterArt> createState() => _AttendanceRegisterArtState();
}

class _AttendanceRegisterArtState extends State<AttendanceRegisterArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      // تأخير بسيط عشان العين تلحق الكشف قبل أول علامة.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = _kRegister.keys.toList();
    return Semantics(
      label: 'كشف حضور: ستة طلاب وسبعة أيام، معظمهم حاضر',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: LayoutBuilder(builder: (context, box) {
          // المتاح جوه الإطار = العرض - الحشو (32) - الحدود (2). الخانة بتتحسب
          // من الباقي من غير حد أدنى عشان الصف مايعديش العرض على شاشة ضيقة.
          final avail = box.maxWidth - 34;
          final nameW = (avail * 0.27).clamp(56.0, 132.0);
          final cell = ((avail - nameW) / 7).floorToDouble().clamp(14.0, 56.0);
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: WebAuthPalette.inkRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: WebAuthPalette.mist.withValues(alpha: 0.14)),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    SizedBox(
                      width: nameW,
                      child: Text('كشف الحضور',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color:
                                  WebAuthPalette.mist.withValues(alpha: 0.7))),
                    ),
                    for (final d in _kDays)
                      SizedBox(
                        width: cell,
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: WebAuthPalette.mist
                                      .withValues(alpha: 0.7))),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  for (var r = 0; r < names.length; r++)
                    _row(names[r], _kRegister[names[r]]!, r, nameW, cell),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _row(String name, String marks, int r, double nameW, double cell) {
    return Container(
      height: cell * 0.92,
      decoration: BoxDecoration(
        border: Border(
            top:
                BorderSide(color: WebAuthPalette.mist.withValues(alpha: 0.10))),
      ),
      child: Row(children: [
        SizedBox(
          width: nameW,
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13, color: Colors.white)),
        ),
        for (var d = 0; d < 7; d++)
          SizedBox(
            width: cell,
            height: cell * 0.92,
            child: CustomPaint(
              painter: _MarkPainter(
                mark: marks[d],
                // الترتيب صف بصف، والكل يخلص عند 0.9 من الزمن.
                t: _cellProgress((r * 7 + d) / 42.0),
              ),
            ),
          ),
      ]),
    );
  }

  double _cellProgress(double order) {
    const span = 0.10; // نافذة رسم الخانة الواحدة
    final start = order * (0.9 - span);
    return ((_c.value - start) / span).clamp(0.0, 1.0);
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.mark, required this.t});
  final String mark;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c = size.center(Offset.zero);
    final s = size.shortestSide * 0.30;
    switch (mark) {
      case 'P':
        final p = Path()
          ..moveTo(c.dx - s, c.dy + s * 0.05)
          ..lineTo(c.dx - s * 0.25, c.dy + s * 0.75)
          ..lineTo(c.dx + s, c.dy - s * 0.7);
        final paint = Paint()
          ..color = WebAuthPalette.tick
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        for (final PathMetric m in p.computeMetrics()) {
          canvas.drawPath(m.extractPath(0, m.length * t), paint);
        }
      case 'L':
        canvas.drawCircle(
            c, s * 0.62 * t, Paint()..color = WebAuthPalette.marker);
      default:
        canvas.drawLine(
            Offset(c.dx - s * 0.6, c.dy),
            Offset(c.dx - s * 0.6 + s * 1.2 * t, c.dy),
            Paint()
              ..color = WebAuthPalette.mist.withValues(alpha: 0.35)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.t != t || old.mark != mark;
}
