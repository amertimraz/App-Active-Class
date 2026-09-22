// lib/views/groups/group_widgets.dart
// ويدجتس مساعدة صغيرة مشتركة بين groups_page.dart وGroupFormSheet
// (استُخرِجت من groups_page.dart — spec 039).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/clock_text.dart';

class FormLabel extends StatelessWidget {
  final String text;
  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    );
  }
}

class PricingTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const PricingTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? primary : null,
          ),
        ),
      ),
    );
  }
}

/// معاينة مدمجة (لون/أيقونة) بتفتح منتقي منبثق بدل ما تاخد مساحة تابتة
/// في الفورم — الهدف تقصير طول شيت إضافة/تعديل المجموعة.
class AppearancePreviewTile extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  const AppearancePreviewTile({
    super.key,
    required this.label,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.grey.shade700)),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more_rounded,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// حاوية موحّدة لمنتقيات اللون/الأيقونة المنبثقة.
class PickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const PickerSheet({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class ErrorText extends StatelessWidget {
  final String text;
  const ErrorText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 13, color: Colors.red),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// يعرض نطاق وقت حصة ("14:30-16:00") وفق إعداد "نظام الساعة 24" (spec 009).
/// لازم يُستدعى جوه ClockBuilder/Obx عشان يتحدّث فورًا عند تغيير الإعداد.
String _fmtScheduleRange(String rawRange) {
  TimeOfDay? p(String v) {
    final s = v.trim().split(':');
    if (s.length != 2) return null;
    final h = int.tryParse(s[0]), m = int.tryParse(s[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  final parts = rawRange.split('-');
  if (parts.length == 2) {
    final a = p(parts[0]), b = p(parts[1]);
    if (a != null && b != null) {
      return '${FormatHelper.formatClock(a)}-${FormatHelper.formatClock(b)}';
    }
  }
  return rawRange;
}

// ─────────────────────────────────────────────────────────────────────────────
// Group card widget
// ─────────────────────────────────────────────────────────────────────────────

class GroupCard extends StatelessWidget {
  final Group group;
  final int studentCount;
  final int archivedCount;
  final List<Student> students;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<Map<String, String>> Function(String) parseSlots;

  const GroupCard({
    super.key,
    required this.group,
    required this.studentCount,
    this.archivedCount = 0,
    required this.students,
    required this.onEdit,
    required this.onDelete,
    required this.parseSlots,
  });

  IconData get _icon {
    switch (group.icon) {
      case 'class': return Icons.class_;
      case 'book': return Icons.menu_book;
      case 'math': return Icons.calculate;
      case 'science': return Icons.science;
      case 'language': return Icons.language;
      case 'code': return Icons.code;
      case 'star': return Icons.star;
      default: return Icons.groups_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = group.color != null ? Color(group.color!) : Colors.indigo;
    final slots = group.schedule != null && group.schedule!.isNotEmpty
        ? parseSlots(group.schedule!)
        : <Map<String, String>>[];

    return GestureDetector(
      onTap: () => Get.toNamed(ROUTE_GROUP_DETAILS, arguments: group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31).withValues(alpha: 0.94) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : color.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.1 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  // أيقونة المجموعة
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),

                  // اسم + كود
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        if (group.code != null && group.code!.isNotEmpty)
                          Text(
                            'الكود: ${group.code}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ),

                  // عدد الطلاب badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '$studentCount',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color),
                        ),
                      ],
                    ),
                  ),

                  // قائمة الخيارات
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') {
                        final totalToDelete = studentCount + archivedCount;
                        Get.defaultDialog(
                          title: 'حذف المجموعة',
                          middleText: totalToDelete > 0
                              ? 'هل تريد حذف مجموعة "${group.name}"؟\n'
                                  'تحذير: هيتحذف معاها $totalToDelete طالب'
                                  '${archivedCount > 0 ? ' (منهم $archivedCount من الأرشيف)' : ''} '
                                  'وكل سجلات حضورهم ودفعاتهم ودرجات امتحاناتهم '
                                  'نهائياً — الإجراء ده لا يمكن التراجع عنه.'
                              : 'هل تريد حذف مجموعة "${group.name}"؟ '
                                  'لا يمكن التراجع عن هذا الإجراء.',
                          textCancel: 'إلغاء',
                          textConfirm: 'حذف',
                          confirmTextColor: Colors.white,
                          buttonColor: Colors.red,
                          onConfirm: () async {
                            Get.back(); // أغلق الـ dialog
                            await Future.delayed(
                                const Duration(milliseconds: 80));
                            onDelete();
                          },
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                    child: const Icon(Icons.more_vert_rounded, size: 20),
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : color.withValues(alpha: 0.1),
            ),

            // ── Footer: سعر + مواعيد ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // المواعيد
                  Expanded(
                    child: slots.isEmpty
                        ? Text('لا توجد مواعيد',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400))
                        : ClockBuilder(
                            builder: (_) => Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: slots.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${s['day']} ${_fmtScheduleRange(s['time'] ?? '')}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),

                  // السعر
                  if (group.price != null && group.price! > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Obx(() {
                        final currency =
                            Get.find<SettingsController>().currencyCode.value;
                        return Text(
                          '${FormatHelper.formatCurrency(group.price)} $currency',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.green),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary pill
// ─────────────────────────────────────────────────────────────────────────────

class SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const SummaryPill({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

