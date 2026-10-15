// lib/utils/arabic_normalize.dart
//
// تطبيع عربي مشترك (بحث الإعدادات + اكتشاف التكرار): صرف بلا GetX/DB.

/// تطبيع عربي للبحث: يشيل التشكيل والتطويل، يوحّد الألف والياء والتاء
/// المربوطة، ويحوّل الأرقام الهندية للاتينية.
String normalizeArabic(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    switch (r) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        b.writeCharCode(0x0627);
        break;
      case 0x0649: // ى
        b.writeCharCode(0x064A);
        break;
      case 0x0629: // ة
        b.writeCharCode(0x0647);
        break;
      default:
        if (r >= 0x0660 && r <= 0x0669) {
          b.writeCharCode(0x30 + (r - 0x0660));
        } else {
          b.writeCharCode(r);
        }
    }
  }
  return b.toString().toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}
