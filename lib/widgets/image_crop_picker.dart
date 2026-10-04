// lib/widgets/image_crop_picker.dart
//
// spec 043 — اختيار صورة من المعرض + قص تفاعلي إجباري قبل أي رفع. مشترك
// بين محرّر الامتحان الإلكتروني ومحرّر بنك الأسئلة (صورة سؤال/شرح/اختيار).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:active_class/config/theme.dart';

/// يفتح معرض الصور ثم شاشة قص تفاعلية (تكبير/تصغير/سحب، بلا نسبة ثابتة).
/// يرجّع bytes الصورة المقصوصة، أو null لو المستخدم ألغى أي خطوة (اختيار
/// أو قص) أو فشل الاختيار.
///
/// [maxDimension]/[compressQuality]: صورة السؤال بتتعرض كبيرة (عرض الشاشة
/// كامل) فمحتاجة دقة أعلى؛ صورة الاختيار والشرح بتتعرض صغيرة (مربّع قصير)
/// فبتاخد قيمة أقل — توفير حقيقي على بيانات الطالب بدون فرق يُلاحظ.
Future<Uint8List?> pickAndCropImage(
  BuildContext context, {
  int maxDimension = 1600,
  int compressQuality = 80,
}) async {
  XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
      // requestFullMetadata: false يتجنّب قراءة الـEXIF/الموقع اللي بتكراش
      // على بعض أجهزة MIUI/شاومي (NullPointerException في
      // deliverResultsIfNeeded) — نفس السبب الموجود في صورة السؤال القديمة.
      requestFullMetadata: false,
    );
  } catch (_) {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (!lost.isEmpty && lost.file != null) file = lost.file;
    } catch (_) {}
  }
  if (file == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: file.path,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: compressQuality,
    maxWidth: maxDimension,
    maxHeight: maxDimension,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'قص الصورة',
        toolbarColor: AppTheme.primaryColor,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: AppTheme.primaryColor,
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false,
      ),
      IOSUiSettings(title: 'قص الصورة', aspectRatioLockEnabled: false),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path).readAsBytes();
}

// ── مواءمة صور الاختيارات (منطق صرف، مختبر في test/) ───────────────────

/// تضمن طول [imageUrls] = [optionCount] بالظبط — لسؤال قديم بلا عمود
/// محفوظ، أو بعد أي خلل تزامن. العناصر الزيادة تُقص، الناقصة تُكمَّل null.
List<String?> alignOptionImages(List<String?> imageUrls, int optionCount) {
  final out = List<String?>.of(imageUrls);
  if (out.length > optionCount) {
    out.removeRange(optionCount, out.length);
  } else {
    while (out.length < optionCount) {
      out.add(null);
    }
  }
  return out;
}

/// إضافة اختيار جديد — قائمة جديدة بعنصر null في الآخر.
List<String?> addOptionImageSlot(List<String?> imageUrls) =>
    List<String?>.of(imageUrls)..add(null);

/// حذف اختيار بالـindex [k] — قائمة جديدة بدون العنصر رقم k.
List<String?> removeOptionImageSlot(List<String?> imageUrls, int k) {
  final out = List<String?>.of(imageUrls);
  if (k >= 0 && k < out.length) out.removeAt(k);
  return out;
}
