// lib/widgets/student_sort_bar.dart
//
// شريط أيقونات بسيط لترتيب قائمة الطلاب — أيقونة لكل معيار، الضغط على
// نفس الأيقونة المفعّلة تاني بيعكس الاتجاه (تصاعدي/تنازلي) بدل ما نضيف
// أزرار/نصوص زيادة تكبّر حجم الشريط.
import 'package:flutter/material.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/utils/student_sort_helper.dart';

class StudentSortBar extends StatelessWidget {
  final StudentSort sortBy;
  final bool ascending;
  final void Function(StudentSort sort) onChanged;

  const StudentSortBar({
    super.key,
    required this.sortBy,
    required this.ascending,
    required this.onChanged,
  });

  static const _icons = {
    StudentSort.name: Icons.sort_by_alpha_rounded,
    StudentSort.paymentStatus: Icons.payments_rounded,
    StudentSort.attendanceRate: Icons.pie_chart_rounded,
    StudentSort.joinDate: Icons.event_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: StudentSort.values.map((s) {
        final active = s == sortBy;
        final dirIcon =
            ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: active
                ? '${s.label} (${ascending ? "تصاعدي" : "تنازلي"})'
                : 'ترتيب حسب ${s.label}',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(s),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_icons[s],
                      size: 18,
                      color: active
                          ? AppTheme.primaryColor
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  if (active) ...[
                    const SizedBox(width: 2),
                    Icon(dirIcon, size: 12, color: AppTheme.primaryColor),
                  ],
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
