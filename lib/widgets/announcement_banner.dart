// lib/widgets/announcement_banner.dart
//
// spec 054 — كروت العروض: 6 تصاميم × 8 ألوان × فاتح/داكن. Flutter صرف بلا
// GetX ولا نموذج التطبيق (بارامترات صريحة) عشان الملف ده يتنسخ حرفيًا لمشروع
// الأدمن ويطلع في المعاينة نفس اللي بيظهر للعميل بالظبط.
//
// الاتجاه التصميمي: "ورقة من مكتب المدرس" — كل تصميم قطعة ورق مختلفة (إيصال،
// ملصق، دفتر مسطّر، شريط، تذكرة، ملاحظة) والتمييز بشكل الحافة مش بالظلال أو
// التدرّجات. عنصر واحد متكرر هو **ختم الخصم** (إطار مزدوج مايل).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ألوان كل لون: [50, 100, 200, 400, 600, 800, 900].
const Map<String, List<Color>> kAnnouncementRamps = {
  'purple': [Color(0xFFEEEDFE), Color(0xFFCECBF6), Color(0xFFAFA9EC), Color(0xFF7F77DD), Color(0xFF534AB7), Color(0xFF3C3489), Color(0xFF26215C)],
  'teal': [Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF5DCAA5), Color(0xFF1D9E75), Color(0xFF0F6E56), Color(0xFF085041), Color(0xFF04342C)],
  'coral': [Color(0xFFFAECE7), Color(0xFFF5C4B3), Color(0xFFF0997B), Color(0xFFD85A30), Color(0xFF993C1D), Color(0xFF712B13), Color(0xFF4A1B0C)],
  'pink': [Color(0xFFFBEAF0), Color(0xFFF4C0D1), Color(0xFFED93B1), Color(0xFFD4537E), Color(0xFF993556), Color(0xFF72243E), Color(0xFF4B1528)],
  'blue': [Color(0xFFE6F1FB), Color(0xFFB5D4F4), Color(0xFF85B7EB), Color(0xFF378ADD), Color(0xFF185FA5), Color(0xFF0C447C), Color(0xFF042C53)],
  'green': [Color(0xFFEAF3DE), Color(0xFFC0DD97), Color(0xFF97C459), Color(0xFF639922), Color(0xFF3B6D11), Color(0xFF27500A), Color(0xFF173404)],
  'amber': [Color(0xFFFAEEDA), Color(0xFFFAC775), Color(0xFFEF9F27), Color(0xFFBA7517), Color(0xFF854F0B), Color(0xFF633806), Color(0xFF412402)],
  'red': [Color(0xFFFCEBEB), Color(0xFFF7C1C1), Color(0xFFF09595), Color(0xFFE24B4A), Color(0xFFA32D2D), Color(0xFF791F1F), Color(0xFF501313)],
};

/// ألوان مشتقة لوضع (فاتح/داكن) — بتضمن تباين ≥ 4.5:1 للنصوص.
class AnnouncementPalette {
  /// خلفية الورقة، الحبر (عناوين)، حبر ثانوي (نص)، لون التمييز، النص فوق
  /// التمييز، مساحة تمييز خفيفة، ألوان العدّاد، خط/حدود، خطوط الدفتر.
  final Color paper, ink, sub, acc, on, tint, countBg, countFg, ring, rule;
  const AnnouncementPalette({
    required this.paper,
    required this.ink,
    required this.sub,
    required this.acc,
    required this.on,
    required this.tint,
    required this.countBg,
    required this.countFg,
    required this.ring,
    required this.rule,
  });

  // أسماء قديمة (توافق مع كود المعاينة/الاختبارات).
  Color get bg => paper;
  Color get fg => ink;
  Color get chip => tint;

  factory AnnouncementPalette.of(String color, {required bool dark}) {
    final r = kAnnouncementRamps[color] ?? kAnnouncementRamps['purple']!;
    return dark
        ? AnnouncementPalette(
            paper: r[6], ink: r[1], sub: r[2], acc: r[2], on: r[6],
            tint: r[5], countBg: r[5], countFg: r[1], ring: r[4], rule: r[5])
        : AnnouncementPalette(
            paper: r[0], ink: r[5], sub: r[4], acc: r[4], on: Colors.white,
            tint: r[1], countBg: r[5], countFg: Colors.white, ring: r[2], rule: r[1]);
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
    this.startsAt,
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
  final DateTime? startsAt, endsAt;
  final bool showCountdown;
  final VoidCallback? onCta, onClose, onExpired;

  /// للاختبار والمعاينة: ساعة بديلة.
  final DateTime Function()? clock;

  /// للمعاينة: فرض وضع (null = وضع الثيم).
  final bool? forceDark;

  bool get _hasCta => ctaLabel.trim().isNotEmpty && onCta != null;
  bool get _countdown => showCountdown && endsAt != null;
  bool get _hasBadge => badge.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final dark = forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final p = AnnouncementPalette.of(color, dark: dark);
    final card = switch (design) {
      'poster' => _poster(p, rtl),
      'glass' => _notebook(p, rtl),
      'strip' => _strip(p),
      'coupon' => _coupon(p, rtl),
      'minimal' => _note(p),
      _ => _receipt(p),
    };
    // Material شفّاف عشان InkWell/InkResponse يشتغلوا حتى لو البنر اتحط في مكان
    // مفيهوش Scaffold (معاينة الأدمن، نافذة منبثقة).
    return Semantics(
      container: true,
      label: '$title. $body',
      child: Material(type: MaterialType.transparency, child: card),
    );
  }

  // ── مكوّنات مشتركة ────────────────────────────────────────────────

  TextStyle _t(AnnouncementPalette p, double size,
          {bool bold = false, Color? c, double h = 1.45}) =>
      TextStyle(
          color: c ?? p.ink,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          height: h);

  /// أرقام/رموز (-30%) لازم تتعرض LTR وإلا بتتقلب "30%-" في السياق العربي.
  Widget _ltr(String text, TextStyle style) => Directionality(
      textDirection: TextDirection.ltr,
      child: Text(text, maxLines: 1, style: style));

  Widget _close(Color c) => onClose == null
      ? const SizedBox.shrink()
      : Semantics(
          button: true,
          label: 'إغلاق',
          child: InkResponse(
            onTap: onClose,
            radius: 22,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.close_rounded,
                  size: 18, color: c.withValues(alpha: 0.65)),
            ),
          ),
        );

  /// ختم الخصم — العنصر المميّز الوحيد: إطار مزدوج مايل، دائرة للنص القصير
  /// ومستطيل للأطول.
  Widget _stamp(AnnouncementPalette p, {double size = 56}) {
    if (!_hasBadge) return const SizedBox.shrink();
    final text = badge.trim();
    final round = text.length <= 5;
    final w = round ? size : size * 1.55;
    final h = round ? size : size * 0.78;
    return Transform.rotate(
      angle: -0.16,
      child: CustomPaint(
        painter: _StampPainter(p.acc, round: round),
        child: SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.17),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _ltr(
                    text,
                    TextStyle(
                        color: p.acc,
                        fontWeight: FontWeight.w700,
                        fontSize: size * 0.34,
                        height: 1.1)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _count(AnnouncementPalette p, {bool compact = false}) => !_countdown
      ? const SizedBox.shrink()
      : AnnouncementCountdown(
          endsAt: endsAt!,
          palette: p,
          clock: clock,
          onExpired: onExpired,
          compactText: compact,
        );

  /// شريط "الوقت اللي فات من العرض" — بيوضّح الاستعجال بصريًا.
  Widget _remaining(AnnouncementPalette p) =>
      (_countdown && startsAt != null)
          ? _RemainingBar(
              startsAt: startsAt!, endsAt: endsAt!, palette: p, clock: clock)
          : const SizedBox.shrink();

  /// زرار الدعوة للإجراء: كتلة لون بسهم اتجاه (أيقونة مش رمز نصي).
  Widget _cta(AnnouncementPalette p,
      {bool block = true, bool small = false, bool outline = false}) {
    if (!_hasCta) return const SizedBox.shrink();
    final label = Flexible(
      child: Text(ctaLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: small ? 12.5 : 14,
              color: outline ? p.acc : p.on)),
    );
    final arrow = Icon(Icons.arrow_back_rounded,
        size: small ? 15 : 18, color: outline ? p.acc : p.on);
    return Semantics(
      button: true,
      label: ctaLabel,
      child: Material(
        color: outline ? Colors.transparent : p.acc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(small ? 10 : 6),
          side: outline ? BorderSide(color: p.acc, width: 1.4) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onCta,
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(small ? 10 : 6)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: small ? 40 : 46, minWidth: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
              child: Row(
                mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [label, SizedBox(width: small ? 5 : 8), arrow],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1) إيصال: شريط لون + حافة مسنّنة + ختم ───────────────────────────
  Widget _receipt(AnnouncementPalette p) => ClipPath(
        clipper: const _ScallopClipper(),
        child: Container(
          color: p.paper,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 6, color: p.acc),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(title, style: _t(p, 17, bold: true, h: 1.3)),
                    ),
                  ),
                  if (_hasBadge)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8, top: 6, end: 4),
                      child: _stamp(p),
                    ),
                  _close(p.ink),
                ]),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Text(body, style: _t(p, 13, c: p.sub)),
                ),
                if (_countdown) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Align(alignment: AlignmentDirectional.centerStart, child: _count(p)),
                      _remaining(p),
                    ]),
                  ),
                ],
                if (_hasCta) ...[
                  const SizedBox(height: 14),
                  Padding(padding: const EdgeInsetsDirectional.only(end: 12), child: _cta(p)),
                ],
              ]),
            ),
          ]),
        ),
      );

  // ── 2) ملصق: لوح لون بقطع قطري + رقم كبير ───────────────────────────
  Widget _poster(AnnouncementPalette p, bool rtl) {
    final big = _hasBadge ? badge.trim() : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: p.paper,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipPath(
              clipper: _DiagonalClipper(rtl: rtl),
              child: Container(
                width: 112,
                padding: const EdgeInsetsDirectional.fromSTEB(10, 14, 22, 14),
                color: p.acc,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (big != null) ...[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ltr(
                          big,
                          TextStyle(
                              color: p.on,
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1)),
                    ),
                    const SizedBox(height: 2),
                    Text('خصم',
                        style: TextStyle(
                            color: p.on, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ] else
                    Icon(announcementKindIcon(kind), color: p.on, size: 38),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 0, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(title, style: _t(p, 15.5, bold: true, h: 1.3)),
                      ),
                    ),
                    _close(p.ink),
                  ]),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Text(body, style: _t(p, 12.5, c: p.sub)),
                  ),
                  if (_countdown) ...[const SizedBox(height: 8), _count(p)],
                  if (_hasCta) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: _cta(p, block: false, small: true),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 3) دفتر مسطّر: خطوط وهامش + ختم صغير ────────────────────────────
  Widget _notebook(AnnouncementPalette p, bool rtl) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _NotebookPainter(
              paper: p.paper, rule: p.rule, margin: p.acc, rtl: rtl),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(48, 8, 4, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(title, style: _t(p, 16.5, bold: true, h: 1.45)),
                  ),
                ),
                _close(p.ink),
              ]),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Text(body, style: _t(p, 13, c: p.sub, h: 1.85)),
              ),
              if (_hasBadge || _countdown) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    if (_hasBadge) _stamp(p, size: 46),
                    if (_hasBadge && _countdown) const SizedBox(width: 12),
                    if (_countdown) Flexible(child: _count(p)),
                  ]),
                ),
              ],
              if (_hasCta) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: _cta(p, outline: true),
                ),
              ],
            ]),
          ),
        ),
      );

  // ── 4) شريط: لوح أيقونة + نص + زرار صغير ────────────────────────────
  Widget _strip(AnnouncementPalette p) => ClipRRect(
        borderRadius: const BorderRadiusDirectional.horizontal(
            start: Radius.circular(4), end: Radius.circular(14)),
        child: Container(
          color: p.paper,
          constraints: const BoxConstraints(minHeight: 56),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 46,
                color: p.acc,
                child: Icon(announcementKindIcon(kind), color: p.on, size: 22),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(p, 13.5, bold: true, h: 1.3)),
                        if (_countdown)
                          _count(p, compact: true)
                        else
                          Text(body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(p, 12, c: p.sub, h: 1.3)),
                      ]),
                ),
              ),
              if (_hasCta)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: ctaLabel,
                      child: Material(
                        color: p.acc,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onCta,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.arrow_back_rounded, color: p.on, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (onClose != null) _close(p.ink) else const SizedBox(width: 6),
            ]),
          ),
        ),
      );

  // ── 5) تذكرة: شقّين نصف دايرة + كود بإطار متقطّع ────────────────────
  Widget _coupon(AnnouncementPalette p, bool rtl) {
    const stubW = 118.0;
    return ClipPath(
      clipper: _TicketClipper(stubWidth: stubW, rtl: rtl),
      child: Container(
        color: p.paper,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: _t(p, 15, bold: true, h: 1.3)),
                  Text(body, style: _t(p, 12, c: p.sub)),
                  if (couponCode.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    CustomPaint(
                      painter: _DashedRectPainter(p.acc),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(couponCode,
                              style: TextStyle(
                                  color: p.acc,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  height: 1.2)),
                        ),
                      ),
                    ),
                  ],
                  if (_countdown) ...[const SizedBox(height: 8), _count(p)],
                ]),
              ),
            ),
            Container(
              width: stubW,
              color: p.acc,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: onClose == null
                      ? const SizedBox(height: 40)
                      : InkResponse(
                          onTap: onClose,
                          child: Semantics(
                            button: true,
                            label: 'إغلاق',
                            child: SizedBox(
                                width: 44,
                                height: 40,
                                child: Icon(Icons.close_rounded,
                                    size: 18, color: p.on.withValues(alpha: 0.75))),
                          ),
                        ),
                ),
                if (_hasBadge)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _ltr(
                        badge.trim(),
                        TextStyle(
                            color: p.on, fontSize: 26, fontWeight: FontWeight.w700, height: 1)),
                  )
                else
                  Icon(Icons.confirmation_number_rounded, color: p.on, size: 30),
                const SizedBox(height: 8),
                if (_hasCta)
                  Semantics(
                    button: true,
                    label: ctaLabel,
                    child: Material(
                      color: p.on,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        onTap: onCta,
                        customBorder:
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(ctaLabel,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.acc,
                                      fontSize: 12,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 6) ملاحظة هادئة: بدون خلفية، خط جانبي فقط ───────────────────────
  Widget _note(AnnouncementPalette p) => Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: p.acc, width: 3)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(title, style: _t(p, 15, bold: true, h: 1.3)),
              ),
            ),
            if (_hasBadge)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, start: 8),
                child: _ltr(
                    badge.trim(),
                    TextStyle(color: p.acc, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            _close(p.ink),
          ]),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Text(body, style: _t(p, 12.5, c: p.sub)),
          ),
          if (_countdown) ...[
            const SizedBox(height: 6),
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: _count(p, compact: true)),
          ],
          if (_hasCta)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onCta,
                style: TextButton.styleFrom(
                  foregroundColor: p.acc,
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                label: Text(ctaLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                icon: const SizedBox.shrink(),
                iconAlignment: IconAlignment.end,
              ),
            ),
        ]),
      );
}

// ═════════════════ رسم الأشكال ══════════════════════════════════════

class _StampPainter extends CustomPainter {
  final Color color;
  final bool round;
  _StampPainter(this.color, {required this.round});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final inner = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final r = Offset.zero & size;
    if (round) {
      final c = r.center;
      final rad = math.min(size.width, size.height) / 2;
      canvas.drawCircle(c, rad - 1.1, outer);
      canvas.drawCircle(c, rad - 5, inner);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(1.1), const Radius.circular(10)), outer);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(7)), inner);
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) =>
      old.color != color || old.round != round;
}

/// حافة سفلية مسنّنة (زي إيصال مقطوع).
class _ScallopClipper extends CustomClipper<Path> {
  const _ScallopClipper();
  @override
  Path getClip(Size s) {
    const r = 6.0;
    final n = math.max(1, (s.width / (r * 2.4)).floor());
    final step = s.width / n;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height);
    for (var i = 0; i < n; i++) {
      final x = s.width - (i + 1) * step;
      path.arcToPoint(Offset(x, s.height),
          radius: Radius.circular(step / 2), clockwise: false);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// لوح الملصق: حافته الداخلية مائلة.
class _DiagonalClipper extends CustomClipper<Path> {
  final bool rtl;
  const _DiagonalClipper({required this.rtl});
  @override
  Path getClip(Size s) {
    const cut = 18.0;
    final p = Path();
    if (rtl) {
      // اللوح على اليمين؛ الحافة الداخلية على اليسار.
      p
        ..moveTo(s.width, 0)
        ..lineTo(cut, 0)
        ..lineTo(0, s.height)
        ..lineTo(s.width, s.height);
    } else {
      p
        ..moveTo(0, 0)
        ..lineTo(s.width - cut, 0)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant _DiagonalClipper old) => old.rtl != rtl;
}

/// تذكرة: نصف دايرة مقطوعة فوق وتحت عند خط التقطيع.
class _TicketClipper extends CustomClipper<Path> {
  final double stubWidth;
  final bool rtl;
  const _TicketClipper({required this.stubWidth, required this.rtl});
  @override
  Path getClip(Size s) {
    final x = rtl ? stubWidth : s.width - stubWidth;
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(10)));
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: 9))
      ..addOval(Rect.fromCircle(center: Offset(x, s.height), radius: 9));
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) =>
      old.stubWidth != stubWidth || old.rtl != rtl;
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75), const Radius.circular(6)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

/// دفتر مسطّر: ورق + خطوط أفقية + خط هامش على جانب البداية.
class _NotebookPainter extends CustomPainter {
  final Color paper, rule, margin;
  final bool rtl;
  _NotebookPainter(
      {required this.paper, required this.rule, required this.margin, required this.rtl});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final line = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (double y = 34; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final mx = rtl ? size.width - 36 : 36;
    canvas.drawLine(
        Offset(mx.toDouble(), 0),
        Offset(mx.toDouble(), size.height),
        Paint()
          ..color = margin.withValues(alpha: 0.55)
          ..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter old) =>
      old.paper != paper || old.rule != rule || old.margin != margin || old.rtl != rtl;
}

/// شريط رفيع: النسبة المتبقية من مدة العرض.
class _RemainingBar extends StatefulWidget {
  const _RemainingBar(
      {required this.startsAt,
      required this.endsAt,
      required this.palette,
      this.clock});
  final DateTime startsAt, endsAt;
  final AnnouncementPalette palette;
  final DateTime Function()? clock;
  @override
  State<_RemainingBar> createState() => _RemainingBarState();
}

class _RemainingBarState extends State<_RemainingBar> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.clock ?? DateTime.now)();
    final total = widget.endsAt.difference(widget.startsAt).inSeconds;
    final left = widget.endsAt.difference(now).inSeconds;
    final f = total <= 0 ? 0.0 : (left / total).clamp(0.0, 1.0);
    final p = widget.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: f,
          minHeight: 4,
          backgroundColor: p.tint,
          valueColor: AlwaysStoppedAnimation(p.acc),
        ),
      ),
    );
  }
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

  /// نص مضغوط "3:04:27:12" بدل المربعات.
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
    final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final p = widget.palette;
    if (widget.compactText) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Text('$d:${_two(h)}:${_two(m)}:${_two(sec)}',
            style: TextStyle(
                color: p.acc,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()])),
      );
    }
    Widget cell(String v, String unit) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            decoration: BoxDecoration(color: p.countBg, borderRadius: BorderRadius.circular(4)),
            child: Text(v,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: p.countFg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Text(unit, style: TextStyle(color: p.sub, fontSize: 10)),
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
