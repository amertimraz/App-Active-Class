// lib/widgets/edit_student_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/exempt_widgets.dart';

/// يفتح bottom sheet لتعديل بيانات طالب.
/// يرجع الطالب المُحدَّث عند الحفظ، أو null لو اتلغى.
Future<Student?> showEditStudentSheet(
  BuildContext context, {
  required Student student,
  required Color accentColor,
  StudentController? controller,
}) {
  return showModalBottomSheet<Student>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditStudentSheet(
      student: student,
      accentColor: accentColor,
      controller: controller,
    ),
  );
}

class EditStudentSheet extends StatefulWidget {
  final Student            student;
  final Color              accentColor;
  final StudentController? controller;

  const EditStudentSheet({
    super.key,
    required this.student,
    required this.accentColor,
    this.controller,
  });

  @override
  State<EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<EditStudentSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _exemptCustomCtrl;

  DateTime? _attendanceStart;
  DateTime? _birthDate;
  bool      _saving = false;

  // الإعفاء
  bool    _isExempt;
  double  _exemptPercent;
  String? _exemptPreset;

  _EditStudentSheetState()
      : _isExempt = false,
        _exemptPercent = 100;

  late final StudentController _sc;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl  = TextEditingController(text: s.name);
    _priceCtrl = TextEditingController(text: s.price.toStringAsFixed(0));
    _phoneCtrl = TextEditingController(text: s.guardianPhone ?? '');
    _attendanceStart = s.attendanceStart ?? DateTime.now();
    _birthDate = s.birthDate;

    // الإعفاء
    _isExempt      = s.isExempt;
    _exemptPercent = s.exemptPercent > 0 ? s.exemptPercent : 100;
    _exemptCustomCtrl = TextEditingController();
    // لو السبب من القائمة الجاهزة اختاره، غير كده اعتبره "أخرى"
    const presets = [
      'يتيم', 'مكفول', 'إعفاء مؤسسي', 'ظروف اجتماعية', 'أخ / أخت لطالب', 'أخرى',
    ];
    if (s.exemptReason != null && s.exemptReason!.isNotEmpty) {
      if (presets.contains(s.exemptReason)) {
        _exemptPreset = s.exemptReason;
      } else {
        _exemptPreset = 'أخرى';
        _exemptCustomCtrl.text = s.exemptReason!;
      }
    }

    _sc = widget.controller ??
        (Get.isRegistered<StudentController>()
            ? Get.find<StudentController>()
            : Get.put(StudentController()));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _exemptCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الطالب')),
      );
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim()) ?? widget.student.price;

    String? finalReason;
    if (_isExempt) {
      if (_exemptPreset == 'أخرى') {
        finalReason = _exemptCustomCtrl.text.trim().isEmpty
            ? 'أخرى'
            : _exemptCustomCtrl.text.trim();
      } else {
        finalReason = _exemptPreset;
      }
    }

    setState(() => _saving = true);
    final updated = widget.student.copyWith(
      name:            name,
      price:           price,
      attendanceStart: _attendanceStart,
      guardianPhone:   _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      birthDate:       _birthDate,
      exemptPercent:   _isExempt ? _exemptPercent : 0,
      exemptReason:    finalReason,
      clearExemptReason: !_isExempt,
    );

    await _sc.updateStudent(updated);
    if (mounted) Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),

            // Header
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.edit_rounded, color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('تعديل بيانات الطالب',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(widget.student.code,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ])),
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded)),
            ]),

            const SizedBox(height: 16),
            CustomTextField(controller: _nameCtrl, label: 'اسم الطالب'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: CustomTextField(
                      controller: _priceCtrl,
                      label: 'الرسوم',
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                  child: CustomTextField(
                      controller: _phoneCtrl,
                      label: 'ولي الأمر',
                      keyboardType: TextInputType.phone)),
            ]),
            const SizedBox(height: 12),

            // التواريخ
            Row(children: [
              Expanded(
                child: _DateBtn(
                  icon: Icons.cake_rounded,
                  label: _birthDate != null
                      ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                      : 'تاريخ الميلاد',
                  hasValue: _birthDate != null,
                  color: primary,
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: _birthDate ?? DateTime(2010),
                    );
                    if (p != null) setState(() => _birthDate = p);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBtn(
                  icon: Icons.date_range_rounded,
                  label: _attendanceStart != null
                      ? '${_attendanceStart!.day}/${_attendanceStart!.month}/${_attendanceStart!.year}'
                      : 'بداية الحضور',
                  hasValue: true,
                  color: primary,
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: _attendanceStart ?? DateTime.now(),
                    );
                    if (p != null) setState(() => _attendanceStart = p);
                  },
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // الإعفاء
            ExemptionSection(
              isExempt: _isExempt,
              exemptPercent: _exemptPercent,
              selectedPreset: _exemptPreset,
              customCtrl: _exemptCustomCtrl,
              accentColor: primary,
              onToggle: (v) => setState(() => _isExempt = v),
              onPercentChanged: (v) => setState(() => _exemptPercent = v),
              onPresetChanged: (v) => setState(() => _exemptPreset = v),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('حفظ التعديلات',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// زر اختيار التاريخ
class _DateBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     hasValue;
  final Color    color;
  final VoidCallback onTap;
  const _DateBtn({
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
            color: hasValue
                ? color.withValues(alpha: 0.3)
                : Colors.grey.shade300,
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
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
