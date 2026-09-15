// lib/widgets/sibling_departure_dialog.dart
//
// spec 035 — حوار "قرار معلّق" لما عضو يخرج من مجموعة إخوة (٣ نزلت لـ٢).
// بيظهر لما PricingHelper.siblingGroupDepartureAlert بيرجّع نتيجة —
// المدرّس (أو أي عضو فريق عنده صلاحية) لازم يأكّد أو يعدّل المبلغ
// المشترك قبل ما القسمة الجديدة تتفعّل فعليًا (راجع contracts/
// departure-decision-dialog.md).
import 'package:flutter/material.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';

/// يعرض حوار قرار الإخوة لو فيه فرق (راجع
/// PricingHelper.siblingGroupDepartureAlert) — بلا أي تأثير لو null.
/// [remainingMembers] لازم يكونوا كل الأعضاء النشطين الحاليين لنفس
/// المجموعة (بما فيهم [student]).
Future<void> showSiblingDepartureDialogIfNeeded(
  BuildContext context, {
  required Student student,
  required List<Student> remainingMembers,
  required int oldCount,
  required int newCount,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SiblingDepartureDialog(
      remainingMembers: remainingMembers,
      oldCount: oldCount,
      newCount: newCount,
    ),
  );
}

class _SiblingDepartureDialog extends StatefulWidget {
  final List<Student> remainingMembers;
  final int oldCount;
  final int newCount;
  const _SiblingDepartureDialog({
    required this.remainingMembers,
    required this.oldCount,
    required this.newCount,
  });

  @override
  State<_SiblingDepartureDialog> createState() =>
      _SiblingDepartureDialogState();
}

class _SiblingDepartureDialogState extends State<_SiblingDepartureDialog> {
  late final TextEditingController _amountCtrl;
  bool _saving = false;

  double get _currentTotal =>
      widget.remainingMembers.first.siblingsTotal ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: _currentTotal.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm({required bool keepSameAmount}) async {
    final newTotal =
        keepSameAmount ? null : double.tryParse(_amountCtrl.text.trim());
    if (!keepSameAmount && (newTotal == null || newTotal < 0)) {
      ToastHelper.error('أدخل مبلغ صحيح');
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseService().confirmSiblingGroupDeparture(
        widget.remainingMembers,
        newSiblingsTotal: newTotal,
      );
      if (mounted) Navigator.of(context).pop();
      ToastHelper.success('اتحدّث مبلغ الإخوة');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      ToastHelper.error('تعذّر الحفظ — حاول تاني');
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.remainingMembers.map((s) => s.name).join('، ');
    final perPersonOld = widget.oldCount > 0 ? _currentTotal / widget.oldCount : 0;
    final perPersonNew = widget.newCount > 0 ? _currentTotal / widget.newCount : 0;
    return AlertDialog(
      title: const Text('خروج عضو من مجموعة الإخوة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عدد أعضاء مجموعة الإخوة نقص من ${widget.oldCount} لـ${widget.newCount} '
              '(الباقيين: $names).',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              'المبلغ المشترك الحالي: ${_currentTotal.toStringAsFixed(0)} جنيه '
              '(كان نصيب كل واحد ${perPersonOld.toStringAsFixed(0)} جنيه).',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54),
            ),
            Text(
              'لو أكّدت المبلغ زي ما هو، نصيب كل واحد من الباقيين هيبقى '
              '${perPersonNew.toStringAsFixed(0)} جنيه.',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'المبلغ المشترك الجديد (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('لاحقًا', style: TextStyle(fontFamily: 'Cairo')),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => _confirm(keepSameAmount: true),
          child: const Text('تأكيد بنفس المبلغ', style: TextStyle(fontFamily: 'Cairo')),
        ),
        ElevatedButton(
          onPressed: _saving ? null : () => _confirm(keepSameAmount: false),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ المبلغ الجديد',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        ),
      ],
    );
  }
}
