// lib/utils/group_price_helper.dart
import 'package:flutter/material.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/utils/helpers.dart';

/// سعر المجموعة العام لا يلمس سعر أي طالب تلقائيًا (كل طالب سعره
/// مستقل من وقت إضافته). بعد تعديل السعر العام، بنعرض على المدرس
/// فرصة يحدّث بيه بس الطلاب اللي سعرهم لسه مطابق للسعر القديم —
/// أي طالب اتخصّص سعره (خصم، اتفاق خاص) بيفضل من غير أي تغيير.
///
/// "السعر القديم" بيتحدد من أكتر سعر متكرر فعليًا بين طلاب المجموعة
/// (مش من سعر المجموعة نفسه) — عشان لو المدرس رفض التحديث مرة، أو
/// عدّل السعر أكتر من مرة من غير ما يأكّد، سعر المجموعة يبقى اتغيّر
/// لكن سعر الطلاب الفعلي يفضل زي ما هو، فلازم نقارن بالسعر الفعلي
/// مش بمرجع قديم ممكن يبقى بعيد عن الواقع.
///
/// مشترك بين شاشة تفاصيل المجموعة وشاشة قائمة المجموعات عشان تعديل
/// السعر من أي الاتنين يعرض نفس الفرصة لتحديث أسعار الطلاب.
Future<void> offerBulkStudentPriceUpdate(
  BuildContext context,
  StudentController studentController,
  int groupId,
  double newPrice, {
  VoidCallback? onUpdated,
}) async {
  final oldPrice = studentController.mostCommonPriceForGroup(groupId,
      excludePrice: newPrice);
  if (oldPrice == null) return;
  final count = studentController.countStudentsAtGroupPrice(
      groupId: groupId, price: oldPrice);
  if (count == 0) return;
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('تحديث سعر الطلاب؟'),
      content: Text(
          'فيه $count طالب سعرهم لسه ${FormatHelper.formatCurrency(oldPrice)} '
          '(السعر القديم للمجموعة). عايز تحدّث سعرهم للسعر الجديد '
          '${FormatHelper.formatCurrency(newPrice)}؟\n\n'
          'أي طالب سعره مختلف عن ده (خصم أو اتفاق خاص) مش هيتأثر.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا، سيبهم زي ما هما')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحديث السعر')),
      ],
    ),
  );
  if (confirmed != true) return;
  final updatedCount = await studentController.bulkUpdatePriceForGroupDefault(
      groupId: groupId, oldPrice: oldPrice, newPrice: newPrice);
  if (updatedCount > 0) {
    ToastHelper.success('تم تحديث سعر $updatedCount طالب');
    onUpdated?.call();
  }
}
