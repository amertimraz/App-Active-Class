// lib/widgets/student_form/student_date_button.dart
import 'package:flutter/material.dart';

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

  const StudentDateButton({
    super.key,
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: hasValue
              ? color.withValues(alpha: 0.07)
              : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                hasValue ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: hasValue ? color : Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: hasValue ? color : Colors.grey.shade500,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
