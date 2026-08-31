// lib/widgets/remove_student_dialog.dart
import 'package:flutter/material.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';

/// نافذة "حذف الطالب" الموحّدة — بتدّي المدرس تلات اختيارات:
///   • أرشفة  → يختفي بس بياناته وسجله محفوظين، يترجع من "الأرشيف".
///   • حذف نهائي → يتمسح هو وكل سجلاته (بتأكيد تاني صريح، مفيش تراجع).
///   • إلغاء.
///
/// بتُستخدم من تفاصيل الطالب + قائمة الطلاب + تفاصيل المجموعة عشان
/// السلوك يبقى واحد في كل مكان.
///
/// [canDelete]: صلاحية حذف الطلاب في وضع الفريق — لو false بتظهر رسالة
///   ومترجعش. [onArchive] / [onDeletePermanently] بيرجّعوا true لو نجحوا.
/// [onRemoved]: بيتنادى بعد نجاح أرشفة أو حذف (مثلاً عشان شاشة التفاصيل
///   ترجع للشاشة اللي قبلها).
Future<void> showRemoveStudentDialog(
  BuildContext context, {
  required Student student,
  required bool canDelete,
  required Future<bool> Function() onArchive,
  required Future<bool> Function() onDeletePermanently,
  VoidCallback? onRemoved,
}) async {
  if (student.id == null) return;
  if (!requireDeletePermission(context, canDelete)) return;

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('حذف الطالب'),
      content: Text(
        'إيه اللي تحب تعمله بـ"${student.name}"؟\n\n'
        '• أرشفة: هيختفي من كل الشاشات النشطة، بس بياناته وسجله (حضور، '
        'مدفوعات، درجات) هيفضلوا محفوظين، وتقدر تسترجعه في أي وقت من "الأرشيف".\n'
        '• حذف نهائي: هيتمسح هو وكل سجلاته — مفيش تراجع.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('delete'),
          child: Text('حذف نهائي',
              style: TextStyle(color: Colors.red.shade400)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () => Navigator.of(ctx).pop('archive'),
          child: const Text('أرشفة', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (!context.mounted || choice == null) return;

  if (choice == 'archive') {
    final ok = await onArchive();
    if (ok) {
      ToastHelper.success('تم أرشفة الطالب');
      onRemoved?.call();
    }
    return;
  }

  // choice == 'delete' — تأكيد تاني صريح قبل أي مسح
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('تأكيد الحذف النهائي'),
      content: Text(
        'هل تريد حذف "${student.name}" نهائياً؟\n'
        'هيتحذف معاه كل سجلات حضوره ومدفوعاته ودرجات امتحاناته — '
        'الإجراء ده لا يمكن التراجع عنه إطلاقاً.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('رجوع'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (!context.mounted || confirmed != true) return;

  final ok = await onDeletePermanently();
  if (ok) {
    ToastHelper.success('تم حذف الطالب نهائيًا');
    onRemoved?.call();
  }
}
