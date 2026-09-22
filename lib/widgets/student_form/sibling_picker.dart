// lib/widgets/student_form/sibling_picker.dart
import 'package:flutter/material.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/widgets/app_toast.dart';

/// حوار اختيار طالب أخ/أخت — موحَّد بين شيتَي إضافة وتعديل الطالب
/// (كانا مكرَّرين بالكامل تقريبًا: _pickSibling/_addSiblingCandidate
/// في الملفين، راجع specs/039-ui-forms-refactor/research.md #1).
///
/// يرجّع القائمة المدموجة الجديدة بعد الإضافة (تشمل باقي أعضاء مجموعة
/// إخوة الطالب المختار لو كان عضوًا في مجموعة موجودة بالفعل)، أو null
/// لو اتلغى الاختيار أو اتجاوز الحد الأقصى (3 أعضاء).
///
/// [excludeStudentId] — معرّف الطالب الحالي نفسه (في شاشة التعديل) عشان
/// ميظهرش كخيار لنفسه؛ null في شاشة الإضافة (لسه معندوش id).
Future<List<Student>?> showSiblingPicker(
  BuildContext context, {
  required List<Student> currentSiblings,
  int? excludeStudentId,
  required Color accentColor,
}) async {
  if (currentSiblings.length >= 2) {
    _showLimitMessage(context);
    return null;
  }
  final all = await DatabaseService().getAllStudents();
  if (!context.mounted) return null;
  final pickedIds = currentSiblings.map((s) => s.id).toSet();
  // معنيش نربط أخ/أخت مؤرشف — الأرشفة أصلاً بتفكّ أي ربط أخوي قائم
  // (راجع DatabaseService.archiveStudent)، فمينفعش نسمح بربط جديد له.
  final list = all
      .where((s) =>
          s.id != excludeStudentId &&
          !s.isArchived &&
          !pickedIds.contains(s.id))
      .toList();

  final picked = await showDialog<Student>(
    context: context,
    builder: (ctx) {
      final searchCtrl = TextEditingController();
      return StatefulBuilder(builder: (ctx, setSt) {
        final filtered = list
            .where((s) =>
                searchCtrl.text.isEmpty ||
                s.name.contains(searchCtrl.text) ||
                s.code.contains(searchCtrl.text))
            .toList();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('اختر الأخ / الأخت'),
          content: SizedBox(
            width: 360,
            height: 350,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الكود...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setSt(() {}),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا يوجد نتائج'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.1),
                                child: Text(s.name[0],
                                    style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(s.name),
                              subtitle: Text('الكود: ${s.code}'),
                              onTap: () => Navigator.of(ctx).pop(s),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء')),
          ],
        );
      });
    },
  );
  if (picked == null || !context.mounted) return null;
  return _mergeSiblingCandidate(
    context,
    currentSiblings: currentSiblings,
    excludeStudentId: excludeStudentId,
    picked: picked,
  );
}

/// يضيف طالب مختار كعضو في مجموعة الإخوة — لو كان عضو أصلاً في مجموعة
/// إخوة موجودة، بنضيف باقي أعضاء مجموعته كمان عشان الربط الجديد ميكسرش
/// رابطهم القديم، مع فرض الحد الأقصى 3 (شامل الطالب الحالي نفسه لو فيه).
Future<List<Student>?> _mergeSiblingCandidate(
  BuildContext context, {
  required List<Student> currentSiblings,
  required int? excludeStudentId,
  required Student picked,
}) async {
  var toAdd = [picked];
  if (picked.siblingGroupId != null) {
    toAdd = await DatabaseService()
        .getStudentsInSiblingGroup(picked.siblingGroupId!);
  }
  final existingIds = currentSiblings.map((s) => s.id).toSet();
  final merged = [
    ...currentSiblings,
    ...toAdd.where(
        (s) => s.id != excludeStudentId && !existingIds.contains(s.id)),
  ];
  if (merged.length > 2) {
    if (context.mounted) _showLimitMessage(context);
    return null;
  }
  return merged;
}

void _showLimitMessage(BuildContext context) {
  // add_student_sheet بيستخدم AppToast، edit_student_sheet بيستخدم
  // ScaffoldMessenger — الاتنين هيشتغلوا هنا لأن AppToast مبني فوق
  // overlay مستقل عن الـScaffold المحلي.
  AppToast.error(context, 'الحد الأقصى لمجموعة الإخوة 3 أعضاء');
}
