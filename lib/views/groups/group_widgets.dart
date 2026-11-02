// lib/views/groups/group_widgets.dart
// ويدجتس مساعدة صغيرة مشتركة بين groups_page.dart وGroupFormSheet
// (استُخرِجت من groups_page.dart — spec 039).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_panel.dart';
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
// Group card widget — لوحة مسطّحة بنفس لغة الرئيسية. لون المجموعة (اللي
// المدرس اختاره) بيظهر في مربع الأيقونة بس؛ باقي الكارت بالتوكنز.
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

  void _confirmDelete() {
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
        await Future.delayed(const Duration(milliseconds: 80));
        onDelete();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = group.color != null ? Color(group.color!) : t.brand;
    final slots = group.schedule != null && group.schedule!.isNotEmpty
        ? parseSlots(group.schedule!)
        : <Map<String, String>>[];
    final hasPrice = group.price != null && group.price! > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppPanel(
        padding: EdgeInsets.zero,
        onTap: () => Get.toNamed(ROUTE_GROUP_DETAILS, arguments: group),
        child: Column(children: [
          // ── الرأس: أيقونة + اسم/كود + عدد الطلاب + قائمة ──────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.sm),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(_icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.title.copyWith(color: t.ink)),
                    if ((group.code != null && group.code!.isNotEmpty) ||
                        hasPrice)
                      Wrap(
                        spacing: AppSpace.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (group.code != null && group.code!.isNotEmpty)
                            Text('الكود: ${group.code}',
                                style: AppType.caption
                                    .copyWith(color: t.inkSoft)),
                          if (hasPrice)
                            Obx(() {
                              final currency = Get.find<SettingsController>()
                                  .currencyCode
                                  .value;
                              return Text(
                                '${FormatHelper.formatCurrency(group.price)} $currency',
                                style: AppType.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: t.positive),
                              );
                            }),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Semantics(
                label: '$studentCount طالب',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_rounded, size: 14, color: t.inkSoft),
                    const SizedBox(width: 4),
                    Text('$studentCount',
                        style: AppType.label.copyWith(color: t.ink)),
                  ]),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات المجموعة',
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') _confirmDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
                icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
              ),
            ]),
          ),
          Divider(height: 1, thickness: 1, color: t.line),

          // ── التذييل: المواعيد + السعر ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: slots.isEmpty
                      ? Text('لا توجد مواعيد',
                          style: AppType.caption.copyWith(color: t.inkFaint))
                      : ClockBuilder(
                          builder: (_) => Wrap(
                            spacing: AppSpace.sm,
                            runSpacing: AppSpace.sm,
                            children: slots.map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.sm, vertical: 3),
                                decoration: BoxDecoration(
                                  color: t.page,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.chip),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.schedule_rounded,
                                          size: 13, color: t.inkSoft),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${s['day']} \u2066${_fmtScheduleRange(s['time'] ?? '')}\u2069',
                                          style: AppType.caption.copyWith(
                                              color: t.ink,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ]),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
