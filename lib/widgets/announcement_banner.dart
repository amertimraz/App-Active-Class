// lib/widgets/announcement_banner.dart
//
// spec 054 — بنر الإعلان: 6 تصاميم × 8 ألوان × فاتح/داكن. Flutter صرف بلا
// GetX ولا نموذج التطبيق (بارامترات صريحة) عشان الملف ده يتنسخ حرفيًا لمشروع
// الأدمن ويطلع في المعاينة نفس اللي بيظهر للعميل بالظبط.
import 'dart:async';

import 'package:flutter/material.dart';

/// ألوان كل لون: [50, 100, 200, 400, 600, 800, 900].
const Map<String, List<Color>> kAnnouncementRamps = {
  'purple': [
    Color(0xFFEEEDFE),
    Color(0xFFCECBF6),
    Color(0xFFAFA9EC),
    Color(0xFF7F77DD),
    Color(0xFF534AB7),
    Color(0xFF3C3489),
    Color(0xFF26215C)
  ],
  'teal': [
    Color(0xFFE1F5EE),
    Color(0xFF9FE1CB),
    Color(0xFF5DCAA5),
    Color(0xFF1D9E75),
    Color(0xFF0F6E56),
    Color(0xFF085041),
    Color(0xFF04342C)
  ],
  'coral': [
    Color(0xFFFAECE7),
    Color(0xFFF5C4B3),
    Color(0xFFF0997B),
    Color(0xFFD85A30),
    Color(0xFF993C1D),
    Color(0xFF712B13),
    Color(0xFF4A1B0C)
  ],
  'pink': [
    Color(0xFFFBEAF0),
    Color(0xFFF4C0D1),
    Color(0xFFED93B1),
    Color(0xFFD4537E),
    Color(0xFF993556),
    Color(0xFF72243E),
    Color(0xFF4B1528)
  ],
  'blue': [
    Color(0xFFE6F1FB),
    Color(0xFFB5D4F4),
    Color(0xFF85B7EB),
    Color(0xFF378ADD),
    Color(0xFF185FA5),
    Color(0xFF0C447C),
    Color(0xFF042C53)
  ],
  'green': [
    Color(0xFFEAF3DE),
    Color(0xFFC0DD97),
    Color(0xFF97C459),
    Color(0xFF639922),
    Color(0xFF3B6D11),
    Color(0xFF27500A),
    Color(0xFF173404)
  ],
  'amber': [
    Color(0xFFFAEEDA),
    Color(0xFFFAC775),
    Color(0xFFEF9F27),
    Color(0xFFBA7517),
    Color(0xFF854F0B),
    Color(0xFF633806),
    Color(0xFF412402)
  ],
  'red': [
    Color(0xFFFCEBEB),
    Color(0xFFF7C1C1),
    Color(0xFFF09595),
    Color(0xFFE24B4A),
    Color(0xFFA32D2D),
    Color(0xFF791F1F),
    Color(0xFF501313)
  ],
};

/// ألوان مشتقة لوضع (فاتح/داكن) — بتضمن تباين ≥ 4.5:1 للنصوص.
class AnnouncementPalette {
  final Color bg, fg, sub, acc, on, chip, countBg, countFg, ring;
  const AnnouncementPalette({
    required this.bg,
    required this.fg,
    required this.sub,
    required this.acc,
    required this.on,
    required this.chip,
    required this.countBg,
    required this.countFg,
    required this.ring,
  });

  factory AnnouncementPalette.of(String color, {required bool dark}) {
    final r = kAnnouncementRamps[color] ?? kAnnouncementRamps['purple']!;
    return dark
        ? AnnouncementPalette(
            bg: r[5],
            fg: r[1],
            sub: r[2],
            acc: r[2],
            on: r[6],
            chip: r[6],
            countBg: r[6],
            countFg: r[1],
            ring: r[4])
        : AnnouncementPalette(
            bg: r[0],
            fg: r[5],
            sub: r[4],
            acc: r[4],
            on: Colors.white,
            chip: r[1],
            countBg: r[5],
            countFg: Colors.white,
            ring: r[2]);
  }
}

IconData announcementKindIcon(String kind) => switch (kind) {
      'deal' => Icons.local_offer_rounded,
      'warn' => Icons.warning_amber_rounded,
      _ => Icons.campaign_rounded,
    };

class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({
    super.key,
    required this.title,
    required this.body,
    this.kind = 'news',
    this.badge = '',
    this.design = 'classic',
    this.color = 'purple',
    this.couponCode = '',
    this.endsAt,
    this.showCountdown = false,
    this.ctaLabel = '',
    this.onCta,
    this.onClose,
    this.onExpired,
    this.clock,
    this.forceDark,
  });

  final String title, body, kind, badge, design, color, couponCode, ctaLabel;
  final DateTime? endsAt;
  final bool showCountdown;
  final VoidCallback? onCta, onClose, onExpired;

  /// للاختبار والمعاينة: ساعة بديلة.
  final DateTime Function()? clock;

  /// للمعاينة: فرض وضع (null = وضع الثيم).
  final bool? forceDark;

  bool get _hasCta => ctaLabel.trim().isNotEmpty && onCta != null;
  bool get _countdown => showCountdown && endsAt != null;

  @override
  Widget build(BuildContext context) {
    final dark = forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final p = AnnouncementPalette.of(color, dark: dark);
    final card = switch (design) {
      'poster' => _poster(p),
      'glass' => _glass(p),
      'strip' => _strip(p),
      'coupon' => _coupon(p),
      'minimal' => _minimal(p, dark),
      _ => _classic(p),
    };
    return Semantics(
      container: true,
      label: '$title. $body',
      child: card,
    );
  }

  // ── مكوّنات مشتركة ────────────────────────────────────────────────

  Widget _close(Color c) => onClose == null
      ? const SizedBox.shrink()
      : InkResponse(
          onTap: onClose,
          radius: 22,
          child: Semantics(
            button: true,
            label: 'إغلاق',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.close_rounded,
                  size: 18, color: c.withValues(alpha: 0.7)),
            ),
          ),
        );

  Widget _badge(AnnouncementPalette p) => badge.trim().isEmpty
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: p.acc,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(badge,
              style: TextStyle(
                  color: p.on, fontWeight: FontWeight.w800, fontSize: 13)),
        );

  Widget _count(AnnouncementPalette p) => !_countdown
      ? const SizedBox.shrink()
      : AnnouncementCountdown(
          endsAt: endsAt!,
          palette: p,
          clock: clock,
          onExpired: onExpired,
        );

  Widget _cta(AnnouncementPalette p, {bool solid = true, bool small = false}) {
    if (!_hasCta) return const SizedBox.shrink();
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final pad = EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: 10);
    final label = Text(ctaLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5));
    return solid
        ? FilledButton(
            onPressed: onCta,
            style: FilledButton.styleFrom(
              backgroundColor: p.acc,
              foregroundColor: p.on,
              minimumSize: const Size(44, 44),
              padding: pad,
              shape: shape,
            ),
            child: label,
          )
        : OutlinedButton(
            onPressed: onCta,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.acc,
              side: BorderSide(color: p.acc, width: 1.4),
              minimumSize: const Size(44, 44),
              padding: pad,
              shape: shape,
            ),
            child: label,
          );
  }

  TextStyle _t(AnnouncementPalette p, double size,
          {bool bold = true, Color? c}) =>
      TextStyle(
          color: c ?? p.fg,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          height: 1.35);

  // ── 1) كلاسيك مليان ───────────────────────────────────────────────
  Widget _classic(AnnouncementPalette p) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 14),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(announcementKindIcon(kind), color: p.acc, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: _t(p, 15))),
            _badge(p),
            _close(p.fg),
          ]),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(body, style: _t(p, 12.5, bold: false, c: p.sub)),
          ),
          if (_countdown) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Align(
                  alignment: AlignmentDirectional.centerEnd, child: _count(p)),
            ),
          ],
          if (_hasCta) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _cta(p),
            ),
          ],
        ]),
      );

  // ── 2) ملصق خصم كبير ──────────────────────────────────────────────
  Widget _poster(AnnouncementPalette p) {
    final big = badge.trim().isEmpty ? null : badge.trim();
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
      decoration:
          BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
              color: p.acc, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (big != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(big,
                    style: TextStyle(
                        color: p.on,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1)),
              )
            else
              Icon(announcementKindIcon(kind), color: p.on, size: 34),
            if (big != null)
              Text('خصم',
                  style: TextStyle(
                      color: p.on, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: _t(p, 15)),
            const SizedBox(height: 2),
            Text(body, style: _t(p, 12.5, bold: false, c: p.sub)),
            if (_countdown) ...[const SizedBox(height: 8), _count(p)],
            if (_hasCta) ...[
              const SizedBox(height: 6),
              _cta(p, solid: false, small: true),
            ],
          ]),
        ),
        _close(p.fg),
      ]),
    );
  }

  // ── 3) زجاجي بحدود ────────────────────────────────────────────────
  Widget _glass(AnnouncementPalette p) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.ring, width: 1.5),
          color: p.bg.withValues(alpha: 0.35),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.chip, shape: BoxShape.circle),
              child: Icon(announcementKindIcon(kind), color: p.acc, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(p, 15, c: p.fg)),
                    Text(body, style: _t(p, 12.5, bold: false, c: p.sub)),
                  ]),
            ),
            _badge(p),
            _close(p.fg),
          ]),
          if (_hasCta || _countdown) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Row(children: [
                if (_hasCta) Expanded(child: _cta(p, solid: false)),
                if (_hasCta && _countdown) const SizedBox(width: 10),
                if (_countdown) _count(p),
              ]),
            ),
          ],
        ]),
      );

  // ── 4) شريط مدمج ──────────────────────────────────────────────────
  Widget _strip(AnnouncementPalette p) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
        decoration:
            BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(announcementKindIcon(kind), color: p.acc, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(p, 13.5)),
                  if (_countdown)
                    AnnouncementCountdown(
                      endsAt: endsAt!,
                      palette: p,
                      clock: clock,
                      onExpired: onExpired,
                      compactText: true,
                    )
                  else
                    Text(body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(p, 12, bold: false, c: p.sub)),
                ]),
          ),
          const SizedBox(width: 6),
          if (_hasCta)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: _cta(p, small: true),
            ),
          _close(p.fg),
        ]),
      );

  // ── 5) كوبون / تذكرة ──────────────────────────────────────────────
  Widget _coupon(AnnouncementPalette p) => Container(
        decoration:
            BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (couponCode.trim().isNotEmpty) ...[
                        Text('كود الخصم',
                            style: _t(p, 11, bold: false, c: p.sub)),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(couponCode,
                              style: TextStyle(
                                  color: p.acc,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2)),
                        ),
                      ],
                      Text(title, style: _t(p, 14)),
                      Text(body, style: _t(p, 12, bold: false, c: p.sub)),
                      if (_countdown) ...[const SizedBox(height: 8), _count(p)],
                    ]),
              ),
            ),
            CustomPaint(
              size: const Size(2, double.infinity),
              painter: _DashedLinePainter(p.ring),
            ),
            Container(
              width: 104,
              color: p.chip,
              padding: const EdgeInsets.all(8),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _closeInline(p),
                    Icon(Icons.confirmation_number_rounded,
                        color: p.acc, size: 28),
                    const SizedBox(height: 6),
                    if (_hasCta) _cta(p, small: true),
                  ]),
            ),
          ]),
        ),
      );

  Widget _closeInline(AnnouncementPalette p) => onClose == null
      ? const SizedBox.shrink()
      : Align(
          alignment: AlignmentDirectional.topEnd,
          child: InkResponse(
            onTap: onClose,
            child: Semantics(
              button: true,
              label: 'إغلاق',
              child: SizedBox(
                  width: 44,
                  height: 30,
                  child: Icon(Icons.close_rounded,
                      size: 18, color: p.fg.withValues(alpha: 0.7))),
            ),
          ),
        );

  // ── 6) هادئ مينيمال ───────────────────────────────────────────────
  Widget _minimal(AnnouncementPalette p, bool dark) {
    final surface = dark ? const Color(0xFF131D31) : Colors.white;
    final text = dark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.ring, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: p.acc, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: _t(p, 14.5, c: text))),
          _badge(p),
          _close(text),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 17, end: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(body,
                style:
                    _t(p, 12.5, bold: false, c: text.withValues(alpha: 0.75))),
            if (_countdown) ...[
              const SizedBox(height: 6),
              AnnouncementCountdown(
                  endsAt: endsAt!,
                  palette: p,
                  clock: clock,
                  onExpired: onExpired,
                  compactText: true),
            ],
            if (_hasCta)
              TextButton(
                onPressed: onCta,
                style: TextButton.styleFrom(
                  foregroundColor: p.acc,
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  alignment: AlignmentDirectional.centerStart,
                ),
                child: Text('$ctaLabel ←',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(
          Offset(1, y), Offset(1, (y + 4).clamp(0, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

/// عدّاد تنازلي حيّ — بيعيد بناء نفسه بس كل ثانية (مش الشاشة كلها)، وبيستدعي
/// [onExpired] مرة واحدة عند الصفر.
class AnnouncementCountdown extends StatefulWidget {
  const AnnouncementCountdown({
    super.key,
    required this.endsAt,
    required this.palette,
    this.clock,
    this.onExpired,
    this.compactText = false,
  });

  final DateTime endsAt;
  final AnnouncementPalette palette;
  final DateTime Function()? clock;
  final VoidCallback? onExpired;

  /// نص مضغوط "03:04:27:12" بدل المربعات.
  final bool compactText;

  @override
  State<AnnouncementCountdown> createState() => _AnnouncementCountdownState();
}

class _AnnouncementCountdownState extends State<AnnouncementCountdown> {
  Timer? _timer;
  bool _fired = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkExpired();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExpired());
  }

  void _checkExpired() {
    if (_fired) return;
    if (!_now.isBefore(widget.endsAt)) {
      _fired = true;
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    var s = widget.endsAt.difference(_now).inSeconds;
    if (s < 0) s = 0;
    final d = s ~/ 86400,
        h = (s % 86400) ~/ 3600,
        m = (s % 3600) ~/ 60,
        sec = s % 60;
    final p = widget.palette;
    if (widget.compactText) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Text('$d:${_two(h)}:${_two(m)}:${_two(sec)}',
            style: TextStyle(
                color: p.acc,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()])),
      );
    }
    Widget cell(String v, String unit) =>
        Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            decoration: BoxDecoration(
                color: p.countBg, borderRadius: BorderRadius.circular(6)),
            child: Text(v,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: p.countFg,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Text(unit, style: TextStyle(color: p.sub, fontSize: 9.5)),
        ]);
    return Semantics(
      label: 'ينتهي العرض بعد $d يوم و$h ساعة و$m دقيقة',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            cell('$d', 'يوم'),
            const SizedBox(width: 4),
            cell(_two(h), 'س'),
            const SizedBox(width: 4),
            cell(_two(m), 'د'),
            const SizedBox(width: 4),
            cell(_two(sec), 'ث'),
          ]),
        ),
      ),
    );
  }
}
