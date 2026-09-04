// أداة معاينة سريعة لتصميم الشهادات — بتشتغل بـ `dart run tool/cert_preview.dart`
// وبتطلّع cert_preview.pdf فيه صفحة لكل قالب ببيانات نموذجية.
// نفس تخطيط lib/services/certificate_layout.dart بالظبط.
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:active_class/services/certificate_layout.dart';
import 'package:active_class/models/certificate_model.dart';

Future<void> main() async {
  final reg = pw.Font.ttf(
      (await File('assets/fonts/Cairo-Regular.ttf').readAsBytes()).buffer.asByteData());
  final bold = pw.Font.ttf(
      (await File('assets/fonts/Cairo-Bold.ttf').readAsBytes()).buffer.asByteData());

  final bgs = <CertTemplate, pw.MemoryImage>{
    for (final t in CertTemplate.values)
      t: pw.MemoryImage(await File('assets/images/${t.bgAsset}').readAsBytes()),
  };

  final samples = <CertificateData>[
    const CertificateData(
      studentName: 'أحمد محمود إبراهيم',
      kind: CertKind.examExcellence,
      achievementText: 'تقديرًا لتفوّقه وأدائه المتميّز في امتحان «الوحدة الثالثة»',
      gradeText: 'الدرجة: 92 من 100 (92%)',
      dateText: 'الجمعة 4 سبتمبر 2026',
      teacherName: 'أحمد سمير',
      teacherSpecialization: 'الرياضيات',
      teacherTitle: 'مستر',
    ),
    const CertificateData(
      studentName: 'عبد الرحمن عبد الله الشناوي',
      kind: CertKind.rank1,
      achievementText: 'لحصوله على المركز الأول في مجموعة 3 ثانوي',
      gradeText: 'بمعدّل 95% عبر 6 امتحانات',
      dateText: 'الجمعة 4 سبتمبر 2026',
      teacherName: 'أحمد سمير',
      teacherSpecialization: 'الرياضيات',
      teacherTitle: 'مستر',
    ),
  ];

  final doc = pw.Document();
  for (final t in CertTemplate.values) {
    for (final d in samples) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        textDirection: pw.TextDirection.rtl,
        build: (_) => pw.FullPage(
          ignoreMargins: true,
          child: buildCertificate(
            template: t,
            data: d,
            background: bgs[t]!,
            regular: reg,
            bold: bold,
          ),
        ),
      ));
    }
  }

  await File('cert_preview.pdf').writeAsBytes(await doc.save());
  print('wrote cert_preview.pdf');
}
