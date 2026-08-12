// lib/services/contact_picker_service.dart
import 'package:flutter_contacts/flutter_contacts.dart';

/// يفتح منتقي جهات الاتصال الأصلي لأندرويد ويرجّع رقم الهاتف المختار
/// بصيغة محلية مصرية (01xxxxxxxxx).
class ContactPickerService {
  static Future<String?> pickPhoneNumber() async {
    try {
      final picked = await FlutterContacts.openExternalPick();
      if (picked == null) return null;

      // قراءة تفاصيل جهة الاتصال (الأرقام) محتاجة إذن قراءة جهات
      // الاتصال حتى بعد اختيارها من المنتقي الخارجي — نطلبه هنا
      // فقط، لحظة الاستخدام الفعلي.
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission) return null;

      final full = await FlutterContacts.getContact(picked.id, withProperties: true);
      if (full == null || full.phones.isEmpty) return null;

      return _normalize(full.phones.first.number);
    } catch (_) {
      return null;
    }
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
