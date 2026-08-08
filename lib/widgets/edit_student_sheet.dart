// lib/widgets/edit_student_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/contact_picker_service.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/widgets/exempt_widgets.dart';

/// يفتح bottom sheet لتعديل بيانات طالب.
/// يرجع الطالب المُحدَّث عند الحفظ، أو null لو اتلغى.
/// [groups] لو اتبعتت، بيظهر قائمة تغيير المجموعة (شاشة الطلاب
/// بتبعتها؛ شاشة تفاصيل الطالب ممكن تسيبها من غير تغيير مجموعة).
Future<Student?> showEditStudentSheet(
  BuildContext context, {
  required Student student,
  required Color accentColor,
  StudentController? controller,
  List<Group>? groups,
}) {
  return showModalBottomSheet<Student>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditStudentSheet(
      student: student,
      accentColor: accentColor,
      controller: controller,
      groups: groups,
    ),
  );
}

class EditStudentSheet extends StatefulWidget {
  final Student            student;
  final Color              accentColor;
  final StudentController? controller;
  final List<Group>?       groups;

  const EditStudentSheet({
    super.key,
    required this.student,
    required this.accentColor,
    this.controller,
    this.groups,
  });

  @override
  State<EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<EditStudentSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _exemptCustomCtrl;
  late final TextEditingController _sibTotalCtrl;

  DateTime? _attendanceStart;
  DateTime? _birthDate;
  bool      _saving = false;

  Group?   _selectedGroup;
  Student? _sibling;

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
    _sibTotalCtrl = TextEditingController(text: s.siblingsTotal?.toString() ?? '');
    _attendanceStart = s.attendanceStart ?? DateTime.now();
    _birthDate = s.birthDate;

    if (widget.groups != null) {
      _selectedGroup = widget.groups!.where((g) => g.id == s.groupId).firstOrNull;
    }

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

    _loadSibling();
  }

  Future<void> _loadSibling() async {
    if (widget.student.siblingId != null) {
      final s = await DatabaseService().getStudent(widget.student.siblingId!);
      if (mounted) setState(() => _sibling = s);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _exemptCustomCtrl.dispose();
    _sibTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSibling() async {
    final all = await DatabaseService().getAllStudents();
    if (!mounted) return;
    final list = all.where((s) => s.id != widget.student.id).toList();

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
                      hintText: 'بحث...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setSt(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                widget.accentColor.withValues(alpha: 0.1),
                            child: Text(s.name[0],
                                style: TextStyle(
                                    color: widget.accentColor,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(s.name),
                          subtitle: Text(s.code),
                          onTap: () => Navigator.of(ctx).pop(s),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    if (picked != null && mounted) {
      setState(() => _sibling = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الطالب')),
      );
      return;
    }
    if (_sibling != null) {
      final total = double.tryParse(_sibTotalCtrl.text.trim());
      if (total == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال إجمالي الأخوين')),
        );
        return;
      }
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
    try {
      final prevSiblingId = widget.student.siblingId;
      final newTotal = _sibling != null
          ? double.tryParse(_sibTotalCtrl.text.trim())
          : null;

      final updated = widget.student.copyWith(
        name:            name,
        price:           price,
        groupId:         _selectedGroup?.id ?? widget.student.groupId,
        siblingId:       _sibling?.id,
        siblingsTotal:   _sibling != null ? newTotal : null,
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

      final db = DatabaseService();
      // Clear old sibling link
      if (prevSiblingId != null &&
          (_sibling == null || prevSiblingId != _sibling!.id)) {
        final prev = await db.getStudent(prevSiblingId);
        if (prev != null) {
          final cleared = prev.copyWith(siblingId: null, siblingsTotal: null);
          await db.updateStudent(cleared);
          final idx = _sc.students.indexWhere((s) => s.id == cleared.id);
          if (idx != -1) _sc.students[idx] = cleared;
          _sc.filterStudents();
        }
      }
      // Link new sibling
      if (_sibling != null) {
        final sib = await db.getStudent(_sibling!.id!);
        if (sib != null) {
          final linked = sib.copyWith(
              siblingId: widget.student.id, siblingsTotal: newTotal);
          await db.updateStudent(linked);
          final idx = _sc.students.indexWhere((s) => s.id == linked.id);
          if (idx != -1) _sc.students[idx] = linked;
          _sc.filterStudents();
        }
      }

      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحفظ')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
                ),
                child: IconButton(
                  tooltip: 'اختيار من جهات الاتصال',
                  icon: Icon(Icons.contacts_rounded, color: widget.accentColor),
                  onPressed: () async {
                    final phone = await ContactPickerService.pickPhoneNumber();
                    if (phone != null) {
                      setState(() => _phoneCtrl.text = phone);
                    }
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // المجموعة (لو الشاشة المستدعية بعتت قائمة المجموعات)
            if (widget.groups != null && widget.groups!.isNotEmpty) ...[
              DropdownButtonFormField<Group>(
                isExpanded: true,
                initialValue: _selectedGroup,
                decoration: InputDecoration(
                  labelText: 'المجموعة',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.groups!
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (g) => setState(() => _selectedGroup = g),
              ),
              const SizedBox(height: 12),
            ],

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

            // ربط أخ / أخت
            GestureDetector(
              onTap: _pickSibling,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.shade50,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.group_rounded,
                      color: _sibling != null ? primary : Colors.grey,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sibling != null
                          ? 'الأخ/الأخت: ${_sibling!.name}'
                          : 'ربط بطالب آخر (أخ / أخت)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _sibling != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55)),
                    ),
                  ),
                  if (_sibling != null)
                    GestureDetector(
                      onTap: () => setState(() => _sibling = null),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.red),
                    )
                  else
                    Icon(Icons.add_circle_outline_rounded,
                        color: Colors.grey.shade400, size: 18),
                ]),
              ),
            ),
            if (_sibling != null) ...[
              const SizedBox(height: 10),
              CustomTextField(
                controller: _sibTotalCtrl,
                label: 'إجمالي الأخوين للشهر',
                keyboardType: TextInputType.number,
              ),
            ],

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
