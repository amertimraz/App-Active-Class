// lib/services/student_card_pdf.dart
//
// «بطاقة الطالب الشهرية»: صفحة PDF واحدة بتصميم السبورة (رأس غامق وأرقام
// بالطباشيري) فيها الحضور والواجب والامتحانات والنقاط والمستوى والمتبقي.
// بتتبعت لولي الأمر مع رسالة واتساب قصيرة.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentCardData {
  final String studentName;
  final String studentCode;
  final String groupName;
  final String monthLabel;
  final int present;
  final int late;
  final int absent;
  final int hwDone;
  final int hwTotal;
  final List<({String name, String grade})> exams;
  final int points;
  final String levelLabel;

  /// نسبة الالتزام % (null لو مفيش حصص).
  final double? commitment;

  /// المتبقي منسّق ("150 ج.م")، أو null لو مخفي/مفيش.
  final String? remainingText;
  final String teacherName;
  final String teacherSpecialization;

  const StudentCardData({
    required this.studentName,
    required this.studentCode,
    required this.groupName,
    required this.monthLabel,
    required this.present,
    required this.late,
    required this.absent,
    required this.hwDone,
    required this.hwTotal,
    required this.exams,
    required this.points,
    required this.levelLabel,
    required this.commitment,
    this.remainingText,
    this.teacherName = '',
    this.teacherSpecialization = '',
  });

  int get sessions => present + absent;

  /// نسبة حضور الشهر % (حاضر + متأخر ÷ الحصص).
  double? get monthRate =>
      sessions == 0 ? null : present / sessions * 100;
}

class StudentCardPdf {
  StudentCardPdf._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _fonts() async {
    if (_regular != null) return;
    _regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    _bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  }

  static const _board = PdfColor.fromInt(0xFF2B2785);
  static const _chalk = PdfColor.fromInt(0xFFFFD15C);
  static const _ink = PdfColor.fromInt(0xFF14172B);
  static const _soft = PdfColor.fromInt(0xFF4A5068);
  static const _line = PdfColor.fromInt(0xFFE2E5F0);
  static const _tint = PdfColor.fromInt(0xFFECECFB);
  static const _green = PdfColor.fromInt(0xFF0B7A55);
  static const _red = PdfColor.fromInt(0xFFC9252D);

  /// بطاقة واحدة (صفحة A5 طولية).
  static Future<Uint8List> build(StudentCardData d) async {
    await _fonts();
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.zero,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
      build: (_) => _page(d),
    ));
    return doc.save();
  }

  static pw.Widget _page(StudentCardData d) {
    final rate = d.monthRate;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── رأس السبورة ──
        pw.Container(
          color: _board,
          padding: const pw.EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('بطاقة الطالب • ${d.monthLabel}',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFCDCFF4), fontSize: 11)),
                pw.SizedBox(height: 6),
                pw.Text(d.studentName,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                    [
                      if (d.groupName.trim().isNotEmpty && d.groupName != '-')
                        d.groupName,
                      if (d.studentCode.isNotEmpty) 'كود ${d.studentCode}',
                    ].join('  •  '),
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFCDCFF4), fontSize: 11)),
                pw.SizedBox(height: 12),
                pw.Container(height: 1.2, color: _chalk),
                pw.SizedBox(height: 12),
                pw.Row(children: [
                  _boardStat(rate == null ? '—' : '${rate.round()}%',
                      'حضور الشهر'),
                  _boardStat('${d.points}', 'نقاط'),
                  _boardStat(d.levelLabel, 'المستوى'),
                ]),
              ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _section('الحضور'),
                pw.Row(children: [
                  _chip('حاضر', '${d.present - d.late}', _green),
                  _chip('متأخر', '${d.late}', const PdfColor.fromInt(0xFF9A5200)),
                  _chip('غائب', '${d.absent}', _red),
                ]),
                if (d.commitment != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                      'نسبة الالتزام على مدى الوقت: ${d.commitment!.round()}%',
                      style: const pw.TextStyle(color: _soft, fontSize: 10)),
                ],
                if (d.hwTotal > 0) ...[
                  pw.SizedBox(height: 12),
                  _section('الواجب'),
                  pw.Text('${d.hwDone} من ${d.hwTotal} واجب تم',
                      style: const pw.TextStyle(color: _ink, fontSize: 12)),
                ],
                if (d.exams.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _section('الامتحانات'),
                  for (final e in d.exams.take(5))
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                                child: pw.Text(e.name,
                                    maxLines: 1,
                                    style: const pw.TextStyle(
                                        color: _ink, fontSize: 11))),
                            pw.Text(e.grade,
                                style: pw.TextStyle(
                                    color: _ink,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold)),
                          ]),
                    ),
                ],
                if (d.remainingText != null) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                        color: _tint,
                        borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('المتبقي من الاشتراك',
                              style: const pw.TextStyle(
                                  color: _soft, fontSize: 11)),
                          pw.Text(d.remainingText!,
                              style: pw.TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold)),
                        ]),
                  ),
                ],
              ]),
        ),
        pw.Spacer(),
        if (d.teacherName.trim().isNotEmpty ||
            d.teacherSpecialization.trim().isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(22, 10, 22, 14),
            decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _line))),
            child: pw.Text(
                [
                  if (d.teacherName.trim().isNotEmpty) d.teacherName.trim(),
                  if (d.teacherSpecialization.trim().isNotEmpty)
                    d.teacherSpecialization.trim(),
                ].join('  •  '),
                style: const pw.TextStyle(color: _soft, fontSize: 10)),
          ),
      ],
    );
  }

  static pw.Widget _boardStat(String value, String label) => pw.Expanded(
        child: pw.Column(children: [
          pw.Text(value,
              style: pw.TextStyle(
                  color: _chalk, fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(label,
              style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xFFCDCFF4), fontSize: 10)),
        ]),
      );

  static pw.Widget _section(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(t,
            style: pw.TextStyle(
                color: _board, fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _chip(String label, String value, PdfColor c) =>
      pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(left: 6),
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Text(value,
                style: pw.TextStyle(
                    color: c, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(label,
                style: const pw.TextStyle(color: _soft, fontSize: 10)),
          ]),
        ),
      );
}
