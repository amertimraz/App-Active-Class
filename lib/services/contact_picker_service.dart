// lib/services/contact_picker_service.dart
import 'package:flutter_contacts/flutter_contacts.dart';

/// يفتح منتقي جهات الاتصال الأصلي لأندرويد ويرجّع رقم الهاتف المختار
/// بصيغة محلية مصرية (01xxxxxxxxx). بيستخدم "External Pick" اللي
/// نظام التشغيل نفسه بيتولاها، وده معناه إن التطبيق مش محتاج إذن
/// قراءة جهات الاتصال خالص.
class ContactPickerService {
  static Future<String?> pickPhoneNumber() async {
    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) return null;

    final full = await FlutterContacts.getContact(picked.id, withProperties: true);
    if (full == null || full.phones.isEmpty) return null;

    return _normalize(full.phones.first.number);
  }

  static String _normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (digits.startsWith('+20')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('0020')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('20') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }

    return digits;
  }
}
