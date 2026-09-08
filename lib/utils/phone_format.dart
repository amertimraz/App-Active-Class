// lib/utils/phone_format.dart
//
// spec 033 — غلاف رفيع فوق PhoneHelper للتوافق مع المستدعين القدامى.
// المنطق كله دلوقتي في phone_helper.dart (نقطة واحدة).
import 'package:active_class/utils/phone_helper.dart';

String normalizeWhatsappPhone(String input, String defaultDial) =>
    PhoneHelper.waMe(input, defaultDial);
