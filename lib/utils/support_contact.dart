// lib/utils/support_contact.dart
//
// فتح واتساب الدعم برسالة جاهزة فيها اسم المدرس، واختياريًا الموضوع اللي كان
// بيقرا عنه في المساعدة. مشترك بين "تواصل معنا" في الإعدادات ومركز المساعدة.
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/helpers.dart';

const kSupportPhone = '201096066818';

/// نص رسالة الدعم (صرف — بيتختبر).
String buildSupportMessage({String? teacherName, String? topic}) {
  final b = StringBuffer()
    ..writeln('مرحبًا، أنا مدرس بستخدم تطبيق Active Class وعايز مساعدة/دعم فني.');
  final n = teacherName?.trim() ?? '';
  if (n.isNotEmpty) b.writeln('الاسم: $n');
  final t = topic?.trim() ?? '';
  if (t.isNotEmpty) b.writeln('كنت بقرا عن: $t');
  return b.toString().trimRight();
}

/// نص طلب تفعيل الواتساب التلقائي (صرف — بيتختبر). بيوصل لرقم الإدارة.
String buildWaActivationRequest(
    {String? teacherName, String? teacherPhone, String? account}) {
  final b = StringBuffer()
    ..writeln('مرحبًا، عايز أفعّل خدمة الواتساب التلقائي في Active Class وأعرف الباقات والأسعار.');
  void line(String label, String? v) {
    final t = v?.trim() ?? '';
    if (t.isNotEmpty) b.writeln('$label: $t');
  }

  line('الاسم', teacherName);
  line('رقم الهاتف', teacherPhone);
  line('حساب الدخول', account);
  return b.toString().trimRight();
}

/// يفتح واتساب برسالة طلب التفعيل جاهزة على رقم الإدارة. بيرجع true لو اتفتح.
Future<bool> openWaActivationRequest(
    {String? teacherName, String? teacherPhone, String? account}) async {
  final message = buildWaActivationRequest(
      teacherName: teacherName, teacherPhone: teacherPhone, account: account);
  final uri = Uri.parse(
      'https://wa.me/$kSupportPhone?text=${Uri.encodeComponent(message)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذر فتح واتساب');
    return false;
  }
}

Future<void> openSupportWhatsApp({String? topic}) async {
  final name = Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().teacherFullName.value
      : null;
  final message = buildSupportMessage(teacherName: name, topic: topic);
  final uri = Uri.parse(
      'https://wa.me/$kSupportPhone?text=${Uri.encodeComponent(message)}');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ToastHelper.error('تعذر فتح واتساب');
  }
}
