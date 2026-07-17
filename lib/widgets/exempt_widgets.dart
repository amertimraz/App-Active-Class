// lib/widgets/exempt_widgets.dart
// ويدجتات الإعفاء المشتركة بين صفحات الإضافة والتعديل والتقارير

import 'package:flutter/material.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/models/student_model.dart';

// ══════════════════════════════════════════════════════════════════
//  ExemptionSection — قسم الإعفاء (إضافة / تعديل)
// ══════════════════════════════════════════════════════════════════
class ExemptionSection extends StatelessWidget {
  const ExemptionSection({
    super.key,
    required this.isExempt,
    required this.exemptPercent,
    required this.selectedPreset,
    required this.customCtrl,
    required this.accentColor,
    required this.onToggle,
    required this.onPercentChanged,
    required this.onPresetChanged,
  });

  final bool isExempt;
  final double exemptPercent;
  final String? selectedPreset;
  final TextEditingController customCtrl;
  final Color accentColor;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onPercentChanged;
  final ValueChanged<String?> onPresetChanged;

  static const exemptColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isExempt
            ? exemptColor.withValues(alpha: isDark ? 0.15 : 0.07)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExempt
              ? exemptColor.withValues(alpha: 0.5)
              : scheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toggle row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isExempt
                        ? exemptColor.withValues(alpha: 0.15)
                        : scheme.onSurface.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    size: 18,
                    color: isExempt
                        ? exemptColor
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعفاء من الرسوم',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isExempt ? exemptColor : scheme.onSurface,
                        ),
                      ),
                      Text(
                        isExempt
                            ? (exemptPercent >= 100
                                ? 'إعفاء كامل • مجاني تماماً'
                                : 'إعفاء جزئي • ${exemptPercent.toInt()}% خصم')
                            : 'الطالب يدفع رسوماً عادية',
                        style: TextStyle(
                          fontSize: 11,
                          color: isExempt
                              ? exemptColor.withValues(alpha: 0.8)
                              : scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isExempt,
                  onChanged: onToggle,
                  activeColor: exemptColor,
                ),
              ],
            ),
          ),

          // ── Expanded options ──
          if (isExempt) ...[
            Divider(height: 1, color: exemptColor.withValues(alpha: 0.2)),

            // Percentage slider
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'نسبة الإعفاء:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: exemptColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          exemptPercent >= 100
                              ? 'إعفاء كامل 100%'
                              : '${exemptPercent.toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: exemptColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: exemptPercent.clamp(10, 100),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    activeColor: exemptColor,
                    inactiveColor: exemptColor.withValues(alpha: 0.2),
                    onChanged: onPercentChanged,
                  ),
                  // Quick preset buttons
                  Wrap(
                    spacing: 6,
                    children: [25, 50, 75, 100].map((pct) {
                      final active = exemptPercent.toInt() == pct;
                      return GestureDetector(
                        onTap: () => onPercentChanged(pct.toDouble()),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? exemptColor
                                : exemptColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? exemptColor
                                  : exemptColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            pct == 100 ? 'كامل' : '$pct%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: active ? Colors.white : exemptColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Reason selector
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سبب الإعفاء:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: EXEMPT_PRESET_REASONS.map((reason) {
                      final active = selectedPreset == reason;
                      return GestureDetector(
                        onTap: () => onPresetChanged(reason),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? exemptColor : scheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? exemptColor
                                  : scheme.outline.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: active
                                  ? Colors.white
                                  : scheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedPreset == 'أخرى') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customCtrl,
                      decoration: InputDecoration(
                        hintText: 'اكتب سبب الإعفاء...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: exemptColor.withValues(alpha: 0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: exemptColor),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  ExemptBadge — شارة الإعفاء الصغيرة
// ══════════════════════════════════════════════════════════════════
class ExemptBadge extends StatelessWidget {
  const ExemptBadge({super.key, required this.student, this.compact = false});
  final Student student;
  final bool compact;

  static const exemptColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    if (!student.isExempt) return const SizedBox.shrink();
    final label = student.isFullyExempt
        ? (compact ? 'معفى' : 'معفى كلياً')
        : (compact
            ? '${student.exemptPercent.toInt()}%'
            : 'معفى ${student.exemptPercent.toInt()}%');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: exemptColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: exemptColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volunteer_activism_rounded,
              size: compact ? 10 : 12, color: exemptColor),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: exemptColor,
            ),
          ),
        ],
      ),
    );
  }
}
