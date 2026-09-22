// lib/widgets/student_form/student_code_field.dart
import 'package:flutter/material.dart';

/// قسم "كود الطالب" (تلقائي/يدوي + سويتش + زرار مسح QR) — موحَّد بين
/// شيتَي إضافة وتعديل الطالب. ويدجت عرض بحت: منطق تحديد الحالة
/// (فارغ/يدوي/تلقائي في الإضافة، تغيّر/بدون تغيير في التعديل) يبقى في
/// الشاشة المستدعية بنفس منطقها الحالي — الويدجت بس بيرسم الشكل
/// المشترك بالألوان/النصوص الجاهزة (راجع specs/039-ui-forms-refactor/
/// research.md #1).
class StudentCodeField extends StatelessWidget {
  final TextEditingController codeController;
  final bool isManual;
  final Color boxColor;
  final IconData icon;
  final String displayText;
  final String manualHint;
  final ValueChanged<bool> onManualChanged;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onScanQr;
  final VoidCallback? onReset;

  const StudentCodeField({
    super.key,
    required this.codeController,
    required this.isManual,
    required this.boxColor,
    required this.icon,
    required this.displayText,
    required this.manualHint,
    required this.onManualChanged,
    required this.onCodeChanged,
    required this.onScanQr,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: boxColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: boxColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: boxColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: isManual
              ? TextField(
                  controller: codeController,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: boxColor,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: manualHint,
                  ),
                  onChanged: onCodeChanged,
                )
              : Text(
                  displayText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: boxColor,
                  ),
                ),
        ),
        if (onReset != null)
          IconButton(
            tooltip: 'رجوع للكود الأصلي',
            icon: const Icon(Icons.refresh_rounded,
                size: 20, color: Colors.purple),
            onPressed: onReset,
          ),
        Switch.adaptive(
          value: isManual,
          activeThumbColor: Colors.purple,
          onChanged: onManualChanged,
        ),
        IconButton(
          tooltip: 'مسح QR من كرت مطبوع مسبقاً',
          icon: Icon(Icons.qr_code_scanner_rounded, size: 20, color: boxColor),
          onPressed: onScanQr,
        ),
      ]),
    );
  }
}
