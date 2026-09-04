// lib/services/certificate_layout.dart
//
// spec 018 (إعادة تصميم) — تخطيط الشهادة: صورة خلفية جاهزة + نص ديناميكي
// فوقها. ملف نقي pw (بدون Flutter/rootBundle) عشان أداة المعاينة
// `tool/cert_preview.dart` تستخدم نفس الكود بالظبط.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:active_class/models/certificate_model.dart';

const _navy = PdfColor.fromInt(0xFF15294B);
const _navySoft = PdfColor.fromInt(0xFF33456B);
const _gold = PdfColor.fromInt(0xFF9A7B18);
const _muted = PdfColor.fromInt(0xFF6A7180);

// ارتفاع صفحة A4 الأفقي بالنقاط (المواضع الرأسية نِسَب منه).
const double _h = 595.28;

pw.Widget buildCertificate({
  required CertTemplate template,
  required CertificateData data,
  required pw.ImageProvider background,
  required pw.Font regular,
  required pw.Font bold,
}) {
  pw.TextStyle st(double size, {bool b = false, PdfColor color = _navy, double? spacing}) =>
      pw.TextStyle(
        font: b ? bold : regular,
        fontBold: bold,
        fontSize: size,
        color: color,
        letterSpacing: spacing,
        lineSpacing: 3,
      );

  // اسم الطالب: نقلّل الخط تدريجيًا بدل ما يخرج عن الحدود.
  double nameSize(double base) {
    final n = data.studentName.trim().length;
    if (n <= 22) return base;
    if (n <= 30) return base - 5;
    if (n <= 40) return base - 9;
    return base - 12;
  }

  final tLine = data.teacherLine;
  final spec = data.teacherSpecialization?.trim() ?? '';
  final teacherFull = [
    if (tLine != null) tLine,
    if (spec.isNotEmpty) spec,
  ].join(' — ');

  // صف نص أفقي عند موضع رأسي top (نقاط من أعلى)، ممتد بعرض الصفحة ناقص
  // الهوامش، ومتوسّط أفقيًا.
  pw.Widget at(double top, pw.Widget child,
          {double left = 0, double right = 0}) =>
      pw.Positioned(
        top: top,
        left: left,
        right: right,
        child: pw.Container(
            alignment: pw.Alignment.center, child: child),
      );

  pw.Widget centered(String text, pw.TextStyle style, {int maxLines = 2}) =>
      pw.Text(text,
          textAlign: pw.TextAlign.center,
          maxLines: maxLines,
          overflow: pw.TextOverflow.clip,
          style: style);

  pw.Widget gradePill(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _gold, width: 1.3),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          color: PdfColors.white,
        ),
        child: pw.Text(text, style: st(13.5, b: true, color: _gold)),
      );

  final layers = <pw.Widget>[
    pw.Positioned.fill(
      child: pw.Image(background, fit: pw.BoxFit.cover),
    ),
  ];

  switch (template) {
    // ── قالب ١: أزرق وذهبي — عنوان فوق، موجة تحت، شريط يسار ──────────
    case CertTemplate.blueGold:
      layers.addAll([
        at(_h * 0.40, centered('تمنح هذه الشهادة إلى', st(14, color: _muted, spacing: 1))),
        at(_h * 0.455, centered(data.studentName, st(nameSize(36), b: true, color: _navy), maxLines: 1)),
        at(_h * 0.575, pw.Container(width: 220, height: 1.8, color: _gold)),
        at(_h * 0.62, centered(data.achievementText, st(15, color: _navySoft)),
            left: 130, right: 130),
        if (data.gradeText != null) at(_h * 0.71, gradePill(data.gradeText!)),
        at(
          _h * 0.79,
          centered(
            [
              if (tLine != null) teacherFull,
              data.dateText,
            ].join('        ·        '),
            st(12, color: _muted),
          ),
          left: 110,
          right: 110,
        ),
      ]);
      break;

    // ── قالب ٢: أزرق وأبيض — عنوان + شريط "تُمنح إلى" + سطر منقّط ─────
    case CertTemplate.blueWhite:
      layers.addAll([
        at(_h * 0.605, centered(data.studentName, st(nameSize(25), b: true, color: _navy), maxLines: 1)),
        at(_h * 0.685,
            centered(_shortReason(data) + (data.gradeText != null ? '  ·  ${data.gradeText}' : ''),
                st(10, color: _muted)),
            left: 150, right: 150),
        at(
          _h * 0.905,
          centered(
            [
              if (tLine != null) teacherFull,
              data.dateText,
            ].join('        ·        '),
            st(9.5, color: _muted),
          ),
          left: 90,
          right: 90,
        ),
      ]);
      break;

    // ── قالب ٣: ذهبي وأبيض — صورة خرّيج يسار، عنوان فوق ──────────────
    case CertTemplate.goldWhite:
      const l = 280.0, r = 45.0;
      layers.addAll([
        at(_h * 0.505, centered(data.studentName, st(nameSize(34), b: true, color: _navy), maxLines: 1),
            left: l, right: r),
        at(_h * 0.625, centered(data.achievementText, st(14.5, color: _navySoft)),
            left: l, right: r),
        if (data.gradeText != null) at(_h * 0.735, gradePill(data.gradeText!), left: l, right: r),
        at(
          _h * 0.85,
          centered(
            [
              if (tLine != null) teacherFull,
              data.dateText,
            ].join('        ·        '),
            st(11.5, color: _muted),
          ),
          left: l,
          right: r,
        ),
      ]);
      break;
  }

  // سطر صغير أسفل كل شهادة يشير للتطبيق — بعيد عن زخارف الحواف.
  final (creditTop, creditL, creditR) = switch (template) {
    CertTemplate.blueGold => (_h * 0.85, 0.0, 0.0),
    CertTemplate.blueWhite => (_h * 0.945, 90.0, 90.0),
    CertTemplate.goldWhite => (_h * 0.90, 280.0, 45.0),
  };
  layers.add(at(
    creditTop,
    pw.Text('صادرة عبر تطبيق Active Class · active-class.online',
        textAlign: pw.TextAlign.center,
        style: st(8, color: _muted, spacing: 0.3)),
    left: creditL,
    right: creditR,
  ));

  return pw.Stack(children: layers);
}

// نسخة مختصرة من نص الإنجاز للقوالب اللي فيها نص جاهز مطبوع (٢).
String _shortReason(CertificateData d) {
  switch (d.kind) {
    case CertKind.examExcellence:
      // "تقديرًا لتفوّقه في امتحان «X»" → "امتحان «X»"
      final i = d.achievementText.indexOf('امتحان');
      return i >= 0 ? d.achievementText.substring(i) : d.achievementText;
    case CertKind.rank1:
    case CertKind.rank2:
    case CertKind.rank3:
    case CertKind.appreciation:
      return d.achievementText;
  }
}
