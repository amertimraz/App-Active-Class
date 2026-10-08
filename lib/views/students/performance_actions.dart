// lib/views/students/performance_actions.dart
//
// spec 050 — إرسال تقرير الأداء لولي الأمر: نص واتساب / صورة كارت / PDF.
// مشترك بين تبويب أداء الطالب وصفحة أداء المجموعة (الإرسال الجماعي).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/export_service.dart';
import 'package:active_class/utils/performance.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/utils/helpers.dart' show ToastHelper;
import 'package:active_class/widgets/performance_card.dart';

({String name, String spec}) _teacher() {
  if (!Get.isRegistered<SettingsController>()) return (name: '', spec: '');
  final st = Get.find<SettingsController>();
  return (
    name: st.teacherFullName.value.trim(),
    spec: st.teacherSpecialization.value.trim(),
  );
}

bool studentHasGuardianContact(Student s) =>
    (s.guardianPhone ?? '').trim().isNotEmpty ||
    (s.guardianWhatsapp ?? '').trim().isNotEmpty;

/// رسالة واتساب نصية مباشرة لولي أمر الطالب. بترجّع true لو فتحت واتساب.
Future<bool> sendPerformanceText(
    BuildContext context, Student s, StudentPerformance perf) async {
  if (!studentHasGuardianContact(s)) {
    ToastHelper.error('مفيش رقم لولي أمر ${s.name}');
    return false;
  }
  final t = _teacher();
  final dial = Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().countryDial.value
      : '';
  return launchGuardianWhatsapp(
    context: context,
    phone: s.guardianPhone,
    whatsapp: s.guardianWhatsapp,
    message: performanceMessage(perf,
        teacherName: t.name, teacherSpecialization: t.spec),
    dialCode: dial,
  );
}

/// يحفظ PNG في المجلد المؤقت ويفتح مشاركة النظام.
Future<void> sharePerformancePng(Uint8List bytes, String fileName,
    {String? text}) async {
  final dir = await getTemporaryDirectory();
  final path = p.join(dir.path, '$fileName.png');
  await File(path).writeAsBytes(bytes);
  await Share.shareXFiles([XFile(path, mimeType: 'image/png')], text: text);
}

String performanceFileName(StudentPerformance perf) =>
    'performance_${perf.studentId}_${perf.month.year}${perf.month.month.toString().padLeft(2, '0')}';

/// معاينة الكارت ثم مشاركته كصورة.
Future<void> showPerformanceCardSheet(
    BuildContext context, StudentPerformance perf) async {
  final t = _teacher();
  final key = GlobalKey();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: SingleChildScrollView(
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: PerformanceCard(
                    perf: perf,
                    teacherName: t.name,
                    teacherSpecialization: t.spec,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة الصورة (واتساب)',
                  style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () async {
                final bytes = await capturePerformancePng(key);
                if (bytes == null) {
                  ToastHelper.error('تعذر إنشاء الصورة');
                  return;
                }
                await sharePerformancePng(bytes, performanceFileName(perf));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

/// يرسم الكارت خارج الشاشة ويلتقطه (للإرسال الجماعي) — بيزيح الودجت خارج
/// الإطار (مش Opacity 0، عشان يترسم فعلًا).
Future<Uint8List?> renderPerformanceCardOffscreen(
    BuildContext context, StudentPerformance perf) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final t = _teacher();
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -4000,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: key,
          child: PerformanceCard(
            perf: perf,
            teacherName: t.name,
            teacherSpecialization: t.spec,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    return await capturePerformancePng(key);
  } finally {
    entry.remove();
  }
}

/// تصدير PDF صفحة واحدة ثم مشاركته.
Future<void> sharePerformancePdf(
    BuildContext context, StudentPerformance perf) async {
  final t = _teacher();
  final res = await ExportService().exportStudentPerformancePDF(perf,
      teacherName: t.name, teacherSpecialization: t.spec);
  if (!res.success || res.path == null) {
    ToastHelper.error(res.error ?? 'فشل إنشاء PDF');
    return;
  }
  await Share.shareXFiles([XFile(res.path!, mimeType: 'application/pdf')]);
}

/// قايمة اختيار طريقة الإرسال لولي أمر طالب واحد.
Future<void> showPerformanceSendSheet(
    BuildContext context, Student s, StudentPerformance perf) async {
  final hasContact = studentHasGuardianContact(s);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.image_rounded, color: Color(0xFF4F46E5)),
          title: const Text('صورة كارت',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          subtitle: const Text('كارت أنيق بالنسب والأسهم والرسم'),
          onTap: () => Navigator.pop(ctx, 'card'),
        ),
        ListTile(
          enabled: hasContact,
          leading: const Icon(Icons.chat_rounded, color: Color(0xFF10B981)),
          title: const Text('رسالة نصية واتساب',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          subtitle: Text(hasContact
              ? 'تتفتح مباشرة على رقم ولي الأمر'
              : 'مفيش رقم لولي الأمر'),
          onTap: hasContact ? () => Navigator.pop(ctx, 'text') : null,
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_rounded,
              color: Color(0xFFEF4444)),
          title: const Text('PDF',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          subtitle: const Text('صفحة واحدة للطباعة أو المشاركة'),
          onTap: () => Navigator.pop(ctx, 'pdf'),
        ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'card':
      await showPerformanceCardSheet(context, perf);
      break;
    case 'text':
      await sendPerformanceText(context, s, perf);
      break;
    case 'pdf':
      await sharePerformancePdf(context, perf);
      break;
  }
}
