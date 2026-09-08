// lib/utils/whatsapp_launcher.dart
//
// spec 033 — نقطة إرسال واتساب لولي الأمر الموحّدة. أولوية:
//   1) رابط wa.me صالح في حقل الواتساب → يُفتح مباشرة.
//   2) رقم صالح (من حقل الرقم أو حقل الواتساب) → wa.me/<رقم>?text=.
//   3) اسم مستخدم → يفتح واتساب + ينسخ الرسالة + تنبيه.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/utils/phone_helper.dart';
import 'package:active_class/widgets/app_toast.dart';

/// يرجّع true لو فتح واتساب (أو نسخ رسالة username)، false لو مفيش وجهة.
Future<bool> launchGuardianWhatsapp({
  required BuildContext context,
  String? phone,
  String? whatsapp,
  required String message,
  required String dialCode,
}) async {
  final encoded = Uri.encodeComponent(message);
  final handle = PhoneHelper.parseWhatsappHandle(whatsapp ?? '');

  // 1) رابط wa.me
  if (handle.kind == WhatsappHandleKind.waLink) {
    var url = handle.value;
    // wa.me/<digits> بدون نص → أضِف الرسالة
    final m = RegExp(r'wa\.me/(\+?\d[\d]*)/?$', caseSensitive: false)
        .firstMatch(url);
    if (m != null && !url.contains('?')) {
      url = 'https://wa.me/${m.group(1)}?text=$encoded';
    }
    return _open(url);
  }

  // 2) رقم (من حقل الواتساب لو كان رقمًا، وإلا من حقل الرقم)
  String waNumber = '';
  if (handle.kind == WhatsappHandleKind.phone) {
    waNumber = PhoneHelper.waMe(handle.value, dialCode);
  }
  if (waNumber.isEmpty && (phone != null && phone.trim().isNotEmpty)) {
    waNumber = PhoneHelper.waMe(phone, dialCode);
  }
  if (waNumber.isNotEmpty) {
    return _open('https://wa.me/$waNumber?text=$encoded');
  }

  // 3) username
  if (handle.kind == WhatsappHandleKind.username) {
    await Clipboard.setData(ClipboardData(text: message));
    final ok = await _open('https://wa.me/');
    if (context.mounted) {
      AppToast.info(context,
          'اتنسخت الرسالة — الصقها في شات ولي الأمر @${handle.value}');
    }
    return ok;
  }

  // 4) لا وجهة
  if (context.mounted) {
    AppToast.error(context, 'مفيش رقم أو واتساب لولي الأمر');
  }
  return false;
}

Future<bool> _open(String url) async {
  try {
    return await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
