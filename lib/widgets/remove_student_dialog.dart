// lib/widgets/remove_student_dialog.dart
import 'package:flutter/material.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/chalk_dialog.dart';

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
    builder: (ctx) => ChalkDialog(
      icon: Icons.person_remove_rounded,
      tone: ChalkTone.caution,
      title: 'حذف ${student.name}',
      subtitle: 'اختار إيه اللي يحصل لسجلاته',
      body: const [
        ChalkRule(
          icon: Icons.archive_rounded,
          text: 'أرشفة: يختفي من كل الشاشات النشطة، وبياناته وسجله (حضور، '
              'مدفوعات، درجات) يفضلوا محفوظين. تقدر تسترجعه في أي وقت من '
              '«الأرشيف».',
        ),
        ChalkRule(
          icon: Icons.delete_forever_rounded,
          text: 'حذف نهائي: يتمسح هو وكل سجلاته. مفيش تراجع.',
        ),
      ],
      actions: [
        ChalkAction(
          label: 'أرشفة',
          icon: Icons.archive_rounded,
          onPressed: () => Navigator.of(ctx).pop('archive'),
        ),
        ChalkAction(
          label: 'حذف نهائي',
          kind: ChalkActionKind.dangerOutlined,
          onPressed: () => Navigator.of(ctx).pop('delete'),
        ),
        ChalkAction(
          label: 'إلغاء',
          kind: ChalkActionKind.text,
          onPressed: () => Navigator.of(ctx).pop(),
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
  final confirmed = await showConfirmPermanentDelete(context, student.name);

  if (!context.mounted || confirmed != true) return;

  final ok = await onDeletePermanently();
  if (ok) {
    ToastHelper.success('تم حذف الطالب نهائيًا');
    onRemoved?.call();
  }
}

/// تأكيد الحذف النهائي لطالب (مشترك بين نافذة الحذف وشاشة الأرشيف).
Future<bool?> showConfirmPermanentDelete(
    BuildContext context, String studentName) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => ChalkDialog(
      icon: Icons.warning_amber_rounded,
      tone: ChalkTone.danger,
      title: 'تأكيد الحذف النهائي',
      subtitle: studentName,
      body: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: ctx.tokens.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.panel),
          ),
          child: Text(
            'هيتحذف معاه كل سجلات حضوره ومدفوعاته ودرجات امتحاناته. '
            'الإجراء ده لا يمكن التراجع عنه إطلاقًا.',
            style: AppType.body.copyWith(color: ctx.tokens.danger, height: 1.5),
          ),
        ),
      ],
      actions: [
        ChalkAction(
          label: 'حذف نهائي',
          kind: ChalkActionKind.dangerFilled,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        ChalkAction(
          label: 'رجوع',
          kind: ChalkActionKind.text,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );
}
