// lib/services/certificate_service.dart
//
// spec 018 (إعادة تصميم) — توليد شهادات تقدير PDF فوق صورة خلفية جاهزة.
// A4 أفقي لكل شهادة. التخطيط الفعلي في certificate_layout.dart (ملف نقي
// pw عشان أداة المعاينة tool/cert_preview.dart تشارك نفس الكود).

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:active_class/models/certificate_model.dart';
import 'package:active_class/services/certificate_layout.dart';

class CertificateService {
  static final CertificateService _i = CertificateService._();
  factory CertificateService() => _i;
  CertificateService._();

  pw.Font? _regular;
  pw.Font? _bold;
  final Map<CertTemplate, pw.MemoryImage> _bgCache = {};

  Future<void> _loadFonts() async {
    if (_regular != null) return;
    final regData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _regular = pw.Font.ttf(regData);
    _bold = pw.Font.ttf(boldData);
  }

  Future<pw.MemoryImage> _bg(CertTemplate t) async {
    final cached = _bgCache[t];
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/images/${t.bgAsset}');
    final img = pw.MemoryImage(data.buffer.asUint8List());
    _bgCache[t] = img;
    return img;
  }

  /// يبني PDF فيه صفحة A4 أفقية لكل عنصر بالقالب المحدّد.
  Future<Uint8List> buildCertificatesPdf(
    List<CertificateData> items,
    CertTemplate template,
  ) async {
    await _loadFonts();
    final bg = await _bg(template);
    final doc = pw.Document();
    for (final item in items) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          textDirection: pw.TextDirection.rtl,
          build: (_) => pw.FullPage(
            ignoreMargins: true,
            child: buildCertificate(
              template: template,
              data: item,
              background: bg,
              regular: _regular!,
              bold: _bold!,
            ),
          ),
        ),
      );
    }
    return doc.save();
  }
}
