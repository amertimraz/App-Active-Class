// lib/utils/booklet_message.dart
//
// spec 041 — نصوص واتساب الخاصة بالملازم (تذكير بالمتبقي + أسطر تقرير الطالب).
import 'package:get/get.dart';

import 'package:active_class/controllers/booklet_controller.dart';
import 'package:active_class/utils/booklet_math.dart';
import 'package:active_class/utils/helpers.dart';

/// رسالة تذكير لولي الأمر بمتبقي ملزمة واحدة.
String buildBookletReminderMessage({
  required String studentName,
  required String bookletName,
  required double price,
  required double paid,
  required double remaining,
  String teacherName = '',
}) {
  final b = StringBuffer()
    ..writeln('السلام عليكم ورحمة الله')
    ..writeln('تذكير بخصوص "$bookletName" للطالب/ة $studentName:')
    ..writeln('• السعر: ${FormatHelper.formatCurrency(price)}');
  if (paid > 0) b.writeln('• المدفوع: ${FormatHelper.formatCurrency(paid)}');
  b.writeln('• المتبقي: ${FormatHelper.formatCurrency(remaining)}');
  b.writeln('\nبرجاء السداد في أقرب وقت. شكرًا لحضراتكم.');
  if (teacherName.trim().isNotEmpty) b.writeln('\n${teacherName.trim()}');
  return b.toString();
}

/// أسطر "الملازم" لتقرير الطالب الشهري (فاضية لو مفيش ملازم).
List<String> bookletReportLines(int? studentId) {
  if (studentId == null || !Get.isRegistered<BookletController>()) return const [];
  final lines = Get.find<BookletController>().linesForStudent(studentId);
  return [
    for (final l in lines)
      '• ${l.booklet.name}: ${l.delivered ? 'استلم' : 'لم يستلم'} — '
          '${l.status == BookletPaymentStatus.full ? 'مدفوعة' : 'متبقي ${FormatHelper.formatCurrency(l.remaining)}'}',
  ];
}
