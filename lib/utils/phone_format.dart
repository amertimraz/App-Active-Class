// lib/utils/phone_format.dart
//
// تطبيع رقم الهاتف لرابط wa.me — نفس منطق إرسال تقارير الحضور/الدرجات.

String normalizeWhatsappPhone(String input, String defaultDial) {
  var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('+')) p = p.substring(1);
  if (p.startsWith('00')) p = p.substring(2);
  if (p.startsWith(defaultDial)) return p;
  if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
  return defaultDial + p.replaceFirst(RegExp(r'^0+'), '');
}
