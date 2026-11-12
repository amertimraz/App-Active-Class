// lib/utils/ai_exam_prepare.dart
//
// spec 057 — تحضير الصور قبل رفعها: ضغط لـ JPEG بحجم معقول، وتحويل صفحات PDF
// لصور. الحدود هنا لازم تطابق إعدادات الخدمة (ai_config) أو تكون أضيق منها.

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

const int kAiMaxImages = 10;
const int kAiMaxBytes = 15 * 1024 * 1024;
const int kAiMaxSide = 1600;
const int kAiMaxQuestions = 30;
const int kAiJpegQuality = 80;

/// بيضغط صورة (أي صيغة) لـ JPEG بأقصى ضلع [maxSide]. بيرمي لو مش صورة.
Uint8List compressToJpegSync(Uint8List bytes,
    {int maxSide = kAiMaxSide, int quality = kAiJpegQuality}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null; // ملف تالف: بعض الـ decoders بترمي RangeError
  }
  if (decoded == null) throw const FormatException('not an image');
  var out = decoded;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxSide)
        : img.copyResize(decoded, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

Uint8List _task(Uint8List b) => compressToJpegSync(b);

/// نفس الضغط بس على isolate عشان الواجهة ما تتجمدش.
Future<Uint8List> compressImage(Uint8List bytes) => compute(_task, bytes);

/// صفحات PDF ← صور JPEG (حد أقصى [maxPages]).
Future<List<Uint8List>> rasterizePdf(Uint8List pdf,
    {int maxPages = kAiMaxImages}) async {
  final out = <Uint8List>[];
  await for (final page in Printing.raster(pdf, dpi: 130)) {
    if (out.length >= maxPages) break;
    out.add(await compressImage(await page.toPng()));
  }
  return out;
}

class AiLimitCheck {
  final bool ok;
  final String? message;
  const AiLimitCheck(this.ok, [this.message]);
}

/// فحص حدود الطلب قبل الرفع (نفس رسايل الحدود للمدرس).
AiLimitCheck checkAiLimits({required int imageCount, required int totalBytes}) {
  if (imageCount > kAiMaxImages) {
    return const AiLimitCheck(
        false, 'أقصى $kAiMaxImages صفحات في المرة — احذف صفحات أو قسّمهم على مرتين');
  }
  if (totalBytes > kAiMaxBytes) {
    return const AiLimitCheck(false, 'الحجم الإجمالي كبير — قلّل عدد الصور');
  }
  return const AiLimitCheck(true);
}
