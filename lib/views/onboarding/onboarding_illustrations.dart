// lib/views/onboarding/onboarding_illustrations.dart
//
// رسومات الشرح التعريفي: مصغّرات من شاشات التطبيق نفسه (بدل أيقونات عامة)،
// مبنية بودجتات عادية فبتتكيّف مع الفاتح/الداكن. كل رسمة داخل لوحة 300×230.
import 'package:flutter/material.dart';

const kOnbIndigo = Color(0xFF4F46E5);

/// لوحة ثابتة المقاس بتتصغّر لو المساحة أضيق.
class OnbCanvas extends StatelessWidget {
  const OnbCanvas({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        // الرسمة صورة توضيحية مش محتوى: ما بتتكبّرش مع حجم خط النظام (النص
        // الحقيقي تحتها هو اللي بيتكبّر).
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: SizedBox(width: 300, height: 230, child: child),
        ),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.pad = 12});
  final Widget child;
  final double pad;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B2540) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? const Color(0xFF2A3658) : const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

Color _ink(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white : const Color(0xFF111827);
Color _sub(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFFB6BFD6)
    : const Color(0xFF4B5563);

TextStyle _t(BuildContext c, double s, {bool bold = false, Color? color}) =>
    TextStyle(
        fontFamily: 'Cairo',
        fontSize: s,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? _ink(c),
        height: 1.3);

// ── 1) مجموعات ───────────────────────────────────────────────────────
class GroupsIllustration extends StatelessWidget {
  const GroupsIllustration({super.key});

  Widget _card(BuildContext c, String name, String time, int n, Color accent) =>
      _Surface(
        pad: 0,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadiusDirectional.horizontal(
                    start: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(c, 14, bold: true)),
                          Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(c, 11.5, color: _sub(c))),
                        ]),
                  ),
                  Icon(Icons.groups_rounded, size: 18, color: accent),
                  const SizedBox(width: 4),
                  Text('$n', style: _t(c, 13, bold: true)),
                ]),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => OnbCanvas(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _card(context, 'أولى ثانوي — علوم', 'السبت والثلاثاء · 4:00 م', 24,
              const Color(0xFF4F46E5)),
          const SizedBox(height: 10),
          _card(context, 'ثانية إعدادي', 'الأحد والأربعاء · 6:00 م', 18,
              const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _card(context, 'ثالثة ثانوي — مراجعة', 'الخميس · 11:00 ص', 31,
              const Color(0xFFF59E0B)),
        ]),
      );
}

// ── 2) طالب + QR ──────────────────────────────────────────────────────
class StudentIllustration extends StatelessWidget {
  const StudentIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context;
    return OnbCanvas(
      child: Center(
        child: SizedBox(
          width: 270,
          child: _Surface(
            pad: 16,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: kOnbIndigo.withValues(alpha: 0.14), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('أ', style: _t(c, 20, bold: true, color: kOnbIndigo)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('أحمد محمد علي', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(c, 14.5, bold: true)),
                    Text('كود: G1-014', style: _t(c, 12, color: _sub(c))),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.phone_rounded, size: 16, color: _sub(c)),
                const SizedBox(width: 6),
                Flexible(
                  child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('0100 123 4567',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(c, 12.5, color: _sub(c)))),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('ولي الأمر',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(c, 12, color: _sub(c))),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB))),
                child: const Icon(Icons.qr_code_2_rounded, size: 66, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
              Text('كود QR خاص بالطالب', style: _t(c, 11.5, color: _sub(c))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── 3) حضور + مدفوعات ─────────────────────────────────────────────────
class AttendanceIllustration extends StatelessWidget {
  const AttendanceIllustration({super.key});

  Widget _pill(BuildContext c, String t, IconData i, Color col, bool on) =>
      Expanded(
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? col : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? col : _sub(c).withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 15, color: on ? Colors.white : _sub(c)),
            const SizedBox(width: 4),
            Text(t,
                style: _t(c, 12,
                    bold: true, color: on ? Colors.white : _sub(c))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context;
    return OnbCanvas(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Surface(
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('منى سعيد', style: _t(c, 14, bold: true))),
              Text('اليوم', style: _t(c, 11.5, color: _sub(c))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _pill(c, 'حاضر', Icons.check_rounded, const Color(0xFF047857), true),
              const SizedBox(width: 6),
              _pill(c, 'متأخر', Icons.schedule_rounded, const Color(0xFFF59E0B), false),
              const SizedBox(width: 6),
              _pill(c, 'غائب', Icons.close_rounded, const Color(0xFFDC2626), false),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('مدفوعات أكتوبر', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(c, 14, bold: true))),
              Text('٦٠٠ من ٨٠٠ ج', maxLines: 1, style: _t(c, 12, color: _sub(c))),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 0.75,
                minHeight: 8,
                backgroundColor: _sub(c).withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              ),
            ),
            const SizedBox(height: 6),
            Text('متبقي ٢٠٠ جنيه', style: _t(c, 11.5, color: _sub(c))),
          ]),
        ),
      ]),
    );
  }
}

// ── 4) مسح QR ─────────────────────────────────────────────────────────
class ScanIllustration extends StatelessWidget {
  const ScanIllustration({super.key});

  Widget _corner(Alignment a, Color color) => Align(
        alignment: a,
        child: SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(painter: _CornerPainter(color, a)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context;
    const green = Color(0xFF10B981);
    return OnbCanvas(
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            color: Theme.of(c).brightness == Brightness.dark
                ? const Color(0xFF0F1830)
                : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(children: [
            Center(
                child: Icon(Icons.qr_code_2_rounded,
                    size: 110, color: _sub(c).withValues(alpha: 0.55))),
            _corner(Alignment.topLeft, kOnbIndigo),
            _corner(Alignment.topRight, kOnbIndigo),
            _corner(Alignment.bottomLeft, kOnbIndigo),
            _corner(Alignment.bottomRight, kOnbIndigo),
            Center(
                child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: kOnbIndigo)),
          ]),
        ),
        Positioned(
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('تم تسجيل حضور أحمد',
                  style: _t(c, 12.5, bold: true, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final Alignment a;
  _CornerPainter(this.color, this.a);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final left = a.x < 0, top = a.y < 0;
    final path = Path()
      ..moveTo(left ? 0 : s.width, top ? s.height : 0)
      ..lineTo(left ? 0 : s.width, top ? 0 : s.height)
      ..lineTo(left ? s.width : 0, top ? 0 : s.height);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
