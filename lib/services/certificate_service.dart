// lib/services/certificate_service.dart
//
// spec 018 — توليد شهادات تقدير PDF. نفس نمط ExportService: تحميل خط
// Cairo، pw.Document، ألوان PdfColor، اتجاه RTL. صفحة A4 رأسية لكل
// شهادة. 3 قوالب: كلاسيكي / حديث / بسيط.

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:active_class/models/certificate_model.dart';

class CertificateService {
  static final CertificateService _i = CertificateService._();
  factory CertificateService() => _i;
  CertificateService._();

  // ── ألوان القوالب ────────────────────────────────────────────────
  static const _gold = PdfColor.fromInt(0xFFB8860B);
  static const _navy = PdfColor.fromInt(0xFF1E3A5F);
  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _violet = PdfColor.fromInt(0xFF7C3AED);
  static const _ink = PdfColor.fromInt(0xFF0F172A);
  static const _slate = PdfColor.fromInt(0xFF64748B);
  static const _greyLine = PdfColor.fromInt(0xFF9CA3AF);

  pw.Font? _regular;
  pw.Font? _bold;

  Future<void> _loadFonts() async {
    if (_regular != null) return;
    final regData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _regular = pw.Font.ttf(regData);
    _bold = pw.Font.ttf(boldData);
  }

  pw.TextStyle _st({
    double size = 12,
    bool bold = false,
    PdfColor color = PdfColors.black,
    double? letterSpacing,
  }) =>
      pw.TextStyle(
        font: bold ? _bold : _regular,
        fontBold: _bold,
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// يبني PDF فيه صفحة A4 رأسية لكل عنصر بالقالب المحدّد.
  Future<Uint8List> buildCertificatesPdf(
    List<CertificateData> items,
    CertTemplate template,
  ) async {
    await _loadFonts();
    final doc = pw.Document();
    for (final item in items) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          textDirection: pw.TextDirection.rtl,
          build: (_) => pw.FullPage(
            ignoreMargins: true,
            child: switch (template) {
              CertTemplate.classic => _classic(item),
              CertTemplate.modern => _modern(item),
              CertTemplate.simple => _simple(item),
            },
          ),
        ),
      );
    }
    return doc.save();
  }

  // زخرفة بسيطة مرسومة (بدل رموز يونيكود اللي مش مضمونة في خط Cairo).
  pw.Widget _diamonds(PdfColor c) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) pw.SizedBox(width: 7),
            pw.Container(
              width: i == 1 ? 8 : 6,
              height: i == 1 ? 8 : 6,
              decoration: pw.BoxDecoration(
                color: c,
                shape: pw.BoxShape.circle,
              ),
            ),
          ],
        ],
      );

  // اسم الطالب: نقلّل الخط تدريجيًا لو طويل بدل ما نقصّه.
  double _nameSize(String name, {double base = 30}) {
    final n = name.trim().length;
    if (n <= 22) return base;
    if (n <= 30) return base - 5;
    if (n <= 40) return base - 9;
    return base - 13;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  كلاسيكي
  // ═══════════════════════════════════════════════════════════════════
  pw.Widget _classic(CertificateData d) {
    final tLine = d.teacherLine;
    final spec = d.teacherSpecialization?.trim() ?? '';
    return pw.Container(
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(26),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _gold, width: 6),
        ),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _navy, width: 1.5),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 44),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                _diamonds(_gold),
                pw.SizedBox(height: 12),
                pw.Text('شهادة تقدير',
                    style: _st(size: 34, bold: true, color: _navy)),
                pw.SizedBox(height: 6),
                pw.Container(width: 120, height: 3, color: _gold),
              ]),
              pw.Column(children: [
                pw.Text('تُمنح هذه الشهادة إلى',
                    style: _st(size: 13, color: _slate)),
                pw.SizedBox(height: 14),
                pw.Text(d.studentName,
                    textAlign: pw.TextAlign.center,
                    style: _st(
                        size: _nameSize(d.studentName),
                        bold: true,
                        color: _gold)),
                pw.SizedBox(height: 10),
                pw.Container(
                    width: 220,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom:
                              pw.BorderSide(color: PdfColors.grey400, width: 1)),
                    )),
                pw.SizedBox(height: 18),
                pw.Text(d.achievementText,
                    textAlign: pw.TextAlign.center,
                    style: _st(size: 14, color: _ink)),
                if (d.gradeText != null) ...[
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFF2F4F8),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(20)),
                    ),
                    child: pw.Text(d.gradeText!,
                        style: _st(size: 12, bold: true, color: _navy)),
                  ),
                ],
                pw.SizedBox(height: 16),
                pw.Text(d.congratsText,
                    textAlign: pw.TextAlign.center,
                    style: _st(size: 11, color: _slate)),
              ]),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(d.dateText, style: _st(size: 10, color: _slate)),
                  if (tLine != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('المعلّم',
                            style: _st(size: 9, color: _slate)),
                        pw.SizedBox(height: 3),
                        pw.Text(tLine,
                            style: _st(size: 11, bold: true, color: _navy)),
                        if (spec.isNotEmpty)
                          pw.Text(spec, style: _st(size: 9, color: _slate)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  حديث
  // ═══════════════════════════════════════════════════════════════════
  pw.Widget _modern(CertificateData d) {
    final tLine = d.teacherLine;
    final spec = d.teacherSpecialization?.trim() ?? '';
    final footer = [
      if (tLine != null) tLine,
      if (spec.isNotEmpty) spec,
    ].join(' — ');
    return pw.Container(
      color: PdfColors.white,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 130,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_indigo, _violet],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
            ),
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _diamonds(PdfColors.white),
                pw.SizedBox(height: 8),
                pw.Text('شهادة تقدير',
                    style: _st(size: 30, bold: true, color: PdfColors.white)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 40),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('تُمنح بكل فخر إلى',
                      style: _st(size: 12, color: _slate)),
                  pw.SizedBox(height: 12),
                  pw.Text(d.studentName,
                      textAlign: pw.TextAlign.center,
                      style: _st(
                          size: _nameSize(d.studentName),
                          bold: true,
                          color: _indigo)),
                  pw.SizedBox(height: 16),
                  pw.Text(d.achievementText,
                      textAlign: pw.TextAlign.center,
                      style: _st(size: 13, color: _ink)),
                  if (d.gradeText != null) ...[
                    pw.SizedBox(height: 16),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 18, vertical: 7),
                      decoration: pw.BoxDecoration(
                        gradient: const pw.LinearGradient(
                            colors: [_indigo, _violet]),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(20)),
                      ),
                      child: pw.Text(d.gradeText!,
                          style:
                              _st(size: 12, bold: true, color: PdfColors.white)),
                    ),
                  ],
                  pw.SizedBox(height: 18),
                  pw.Text(d.congratsText,
                      textAlign: pw.TextAlign.center,
                      style: _st(size: 10.5, color: _slate)),
                ],
              ),
            ),
          ),
          pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(d.dateText, style: _st(size: 9.5, color: _slate)),
                if (footer.isNotEmpty)
                  pw.Text(footer,
                      style: _st(size: 9.5, bold: true, color: _slate)),
              ],
            ),
          ),
          pw.Container(
            height: 10,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [_indigo, _violet]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  بسيط
  // ═══════════════════════════════════════════════════════════════════
  pw.Widget _simple(CertificateData d) {
    final tLine = d.teacherLine;
    final spec = d.teacherSpecialization?.trim() ?? '';
    final foot = [
      if (tLine != null) tLine,
      if (spec.isNotEmpty) spec,
      d.dateText,
    ].join(' · ');
    return pw.Container(
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(30),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _greyLine, width: 1),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 54),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('شهادة تقدير',
                style: _st(
                    size: 22, bold: true, color: _ink, letterSpacing: 3)),
            pw.Column(children: [
              pw.Text('تُمنح إلى', style: _st(size: 11, color: _slate)),
              pw.SizedBox(height: 12),
              pw.Text(d.studentName,
                  textAlign: pw.TextAlign.center,
                  style: _st(
                      size: _nameSize(d.studentName, base: 26),
                      bold: true,
                      color: _ink)),
              pw.SizedBox(height: 16),
              pw.Text(d.achievementText,
                  textAlign: pw.TextAlign.center,
                  style: _st(size: 12.5, color: _ink)),
              if (d.gradeText != null) ...[
                pw.SizedBox(height: 12),
                pw.Text(d.gradeText!,
                    style: _st(size: 11.5, bold: true, color: _slate)),
              ],
              pw.SizedBox(height: 14),
              pw.Text(d.congratsText,
                  textAlign: pw.TextAlign.center,
                  style: _st(size: 10, color: _slate)),
            ]),
            pw.Text(foot,
                textAlign: pw.TextAlign.center,
                style: _st(size: 9, color: _slate)),
          ],
        ),
      ),
    );
  }
}
