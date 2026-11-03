// lib/widgets/student_form/student_date_button.dart
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';

/// زر اختيار تاريخ (تاريخ الميلاد / بداية الحضور) — موحَّد بين شيتَي
/// إضافة وتعديل الطالب (كانا مكرَّرين بالحرف تقريبًا: _DatePickerBtn
/// في add_student_sheet.dart وَ_DateBtn في edit_student_sheet.dart،
/// راجع specs/039-ui-forms-refactor/research.md #1).
class StudentDateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final Color color;
  final VoidCallback onTap;
  final bool dense;
  // لو متحدد: الزر بيتعرض كحقل بعنوان صغير فوق الإطار زي باقي الحقول.
  final String? fieldLabel;

  const StudentDateButton({
    super.key,
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.color,
    required this.onTap,
    this.dense = false,
    this.fieldLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (fieldLabel != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            isDense: true,
            labelText: fieldLabel,
            labelStyle: const TextStyle(fontSize: 13),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                borderSide: BorderSide(color: color.withValues(alpha: 0.45))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                borderSide: BorderSide(color: color.withValues(alpha: 0.45))),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: AppType.body.copyWith(
                      fontSize: 14, color: color, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: dense ? 42 : 48),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 8 : 12),
        decoration: BoxDecoration(
          color: hasValue ? color.withValues(alpha: 0.08) : t.page,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
              color: hasValue ? color.withValues(alpha: 0.45) : t.line),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: hasValue ? color : t.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: AppType.body.copyWith(
                  fontSize: dense ? 13 : null,
                  color: hasValue ? color : t.inkSoft,
                  fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
