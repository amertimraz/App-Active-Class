// lib/utils/whatsapp_targets.dart
//
// وجهات واتساب: رسالة لولي الأمر أو للطالب نفسه أو للاتنين، ورابط جروب
// المجموعة. منطق بحت عشان يتختبر.
import 'package:active_class/models/student_model.dart';

/// لمين الرسالة: ولي الأمر / الطالب نفسه / الاتنين.
enum WhatsappAudience { guardian, student, both }

extension WhatsappAudienceX on WhatsappAudience {
  String get label => switch (this) {
        WhatsappAudience.guardian => 'ولي الأمر',
        WhatsappAudience.student => 'الطالب نفسه',
        WhatsappAudience.both => 'الاتنين',
      };
}

/// هل عند الطالب رقم نقدر نبعتله على واتساب؟
bool studentHasOwnPhone(Student s) => (s.studentPhone ?? '').trim().isNotEmpty;

bool studentHasGuardianContact(Student s) =>
    (s.guardianPhone ?? '').trim().isNotEmpty ||
    (s.guardianWhatsapp ?? '').trim().isNotEmpty;

/// الاختيارات المتاحة للطالب ده. «الطالب» و«الاتنين» بيظهروا بس لو
/// الإعداد شغّال وعند الطالب رقم؛ «ولي الأمر» لو عنده وسيلة تواصل.
List<WhatsappAudience> availableAudiences(
  Student s, {
  required bool studentMessagingEnabled,
}) {
  final guardian = studentHasGuardianContact(s);
  final own = studentMessagingEnabled && studentHasOwnPhone(s);
  return [
    if (guardian) WhatsappAudience.guardian,
    if (own) WhatsappAudience.student,
    if (guardian && own) WhatsappAudience.both,
  ];
}

/// رابط جروب واتساب صالح بعد التنضيف، أو null. بنقبل بس نطاقات واتساب
/// (chat.whatsapp.com للجروبات، whatsapp.com/channel للقنوات)، ومن غير
/// بروتوكول بنضيف https://.
String? normalizeWhatsappGroupLink(String? raw) {
  var v = (raw ?? '').trim();
  if (v.isEmpty) return null;
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) {
    v = 'https://$v';
  }
  final uri = Uri.tryParse(v);
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  final path = uri.path;
  final isGroup = host == 'chat.whatsapp.com' && path.length > 1;
  final isChannel = (host == 'whatsapp.com' || host == 'www.whatsapp.com') &&
      path.startsWith('/channel/') &&
      path.length > '/channel/'.length;
  if (!isGroup && !isChannel) return null;
  return Uri(
    scheme: 'https',
    host: host == 'www.whatsapp.com' ? 'whatsapp.com' : host,
    path: path,
  ).toString();
}
