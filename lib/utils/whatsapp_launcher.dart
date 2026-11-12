// lib/utils/whatsapp_launcher.dart
//
// spec 033 — نقطة إرسال واتساب لولي الأمر الموحّدة. أولوية:
//   1) رابط wa.me صالح في حقل الواتساب → يُفتح مباشرة.
//   2) رقم صالح (من حقل الرقم أو حقل الواتساب) → wa.me/<رقم>?text=.
//   3) اسم مستخدم → يفتح واتساب + ينسخ الرسالة + تنبيه.
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/phone_helper.dart';
import 'package:active_class/widgets/app_toast.dart';

/// يضيف توقيع المعلم (الاسم + التخصص) لآخر أي رسالة لولي الأمر — بنفس
/// شكل تقرير الطالب الشهري. لو الرسالة فيها التوقيع أصلًا (👨‍🏫) ما بيتكرّرش،
/// ولو الاسم والتخصص فاضيين في الإعدادات ما بيتضافش حاجة.
String withTeacherSignature(String message) {
  if (message.contains('👨‍🏫')) return message;
  if (!Get.isRegistered<SettingsController>()) return message;
  final st = Get.find<SettingsController>();
  final name = st.teacherFullName.value.trim();
  final spec = st.teacherSpecialization.value.trim();
  if (name.isEmpty && spec.isEmpty) return message;
  final b = StringBuffer(message.trimRight())..writeln();
  b.writeln('👨‍🏫 المعلم: ${name.isNotEmpty ? name : '-'}');
  b.write('📘 التخصص: ${spec.isNotEmpty ? spec : '-'}');
  return b.toString();
}

/// يرجّع true لو فتح واتساب (أو نسخ رسالة username)، false لو مفيش وجهة.
Future<bool> launchGuardianWhatsapp({
  required BuildContext context,
  String? phone,
  String? whatsapp,
  required String message,
  required String dialCode,
  String missingMessage = 'مفيش رقم أو واتساب لولي الأمر',
}) async {
  message = withTeacherSignature(message);
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
    AppToast.error(context, missingMessage);
  }
  return false;
}

Future<bool> _open(String url) => openWhatsappLink(url);

const _kWaPackage = 'com.whatsapp';
const _kWaBusinessPackage = 'com.whatsapp.w4b';

/// wa.me/<رقم>?text=… → whatsapp://send?phone=<رقم>&text=… (بيفتحه واتساب
/// وWhatsApp Business بس، عكس wa.me اللي ممكن يروح للمتصفح).
String waSchemeUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null || !u.host.toLowerCase().endsWith('wa.me')) return url;
  final phone = u.pathSegments.isNotEmpty
      ? u.pathSegments.first.replaceAll(RegExp(r'\D'), '')
      : '';
  final text = u.queryParameters['text'] ?? '';
  final q = <String>[
    if (phone.isNotEmpty) 'phone=$phone',
    if (text.isNotEmpty) 'text=${Uri.encodeComponent(text)}',
  ];
  return 'whatsapp://send${q.isEmpty ? '' : '?${q.join('&')}'}';
}

/// يفتح رابط واتساب حسب إعداد «تطبيق واتساب»: الافتراضي (زي الأول)، أو
/// اسأل كل مرة (قايمة اختيار: واتساب / Business / نسخة تانية)، أو تطبيق محدد.
/// الاختيار بس على أندرويد؛ أي حالة تانية أو فشل → الفتح العادي.
Future<bool> openWhatsappLink(String url) async {
  final mode = Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().waApp.value
      : 'default';
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      mode != 'default') {
    try {
      final data = waSchemeUrl(url);
      // قايمة الاختيار بس لروابط الرسايل (whatsapp://) — غير كده هتعرض متصفحات.
      if (mode == 'ask' && data != url) {
        await AndroidIntent(action: 'action_view', data: data)
            .launchChooser('اختار حساب الواتساب');
        return true;
      }
      if (mode != 'ask') {
        await AndroidIntent(
          action: 'action_view',
          data: data,
          package: mode == 'business' ? _kWaBusinessPackage : _kWaPackage,
        ).launch();
        return true;
      }
    } catch (_) {
      // التطبيق المطلوب مش متثبّت → نكمل بالفتح العادي.
    }
  }
  try {
    return await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
