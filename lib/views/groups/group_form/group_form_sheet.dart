// lib/views/groups/group_form/group_form_sheet.dart
// شيت إضافة/تعديل المجموعة الموحَّد — النسخة الأكمل (اختيار أيقونة/لون/
// نوع تسعير + تحقق تكرار الاسم/الكود + رسائل خطأ inline)، مُستخرَجة من
// _GroupFormSheet في groups_page.dart لتُستخدَم من groups_page.dart
// وgroup_details_page.dart معًا بدل نسختين منفصلتين (spec 039،
// راجع research.md #2).
import 'package:flutter/material.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/views/groups/group_form/group_schedule_conflict.dart';
import 'package:active_class/views/groups/group_form/group_schedule_editor.dart';
import 'package:active_class/views/groups/group_widgets.dart';

class GroupFormSheet extends StatefulWidget {
  final Group? group;
  final List<Group> existingGroups;
  final Future<bool> Function(Group) onSave;
  final void Function(String groupName, double newPrice)? onSaved;

  const GroupFormSheet({
    super.key,
    required this.group,
    required this.existingGroups,
    required this.onSave,
    this.onSaved,
  });

  @override
  State<GroupFormSheet> createState() => GroupFormSheetState();
}

class GroupFormSheetState extends State<GroupFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _scheduleCtrl;

  late String _selectedIcon;
  late int _selectedColor;
  late String _pricingType;
  bool _saving = false;

  // Inline validation errors
  String? _nameError;
  String? _codeError;
  String? _priceError;
  String? _scheduleError;

  static const _iconOptions = <String, IconData>{
    'group': Icons.groups_rounded,
    'class': Icons.class_rounded,
    'book': Icons.menu_book_rounded,
    'math': Icons.calculate_rounded,
    'science': Icons.science_rounded,
    'language': Icons.language_rounded,
    'code': Icons.code_rounded,
    'star': Icons.star_rounded,
    'music': Icons.music_note_rounded,
    'art': Icons.brush_rounded,
    'sport': Icons.sports_soccer_rounded,
    'english': Icons.translate_rounded,
  };

  static const _colorOptions = <int>[
    0xFFE53935, // أحمر
    0xFF1E88E5, // أزرق
    0xFF43A047, // أخضر
    0xFFFB8C00, // برتقالي
    0xFF8E24AA, // بنفسجي
    0xFF00ACC1, // سماوي
    0xFFEC407A, // وردي
    0xFFFFB300, // ذهبي
    0xFF6D4C41, // بني
    0xFF546E7A, // رمادي
    0xFF00897B, // تيل
    0xFF3949AB, // نيلي
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _codeCtrl = TextEditingController(text: g?.code ?? '');
    _priceCtrl = TextEditingController(text: g?.price?.toString() ?? '');
    _scheduleCtrl = TextEditingController(text: g?.schedule ?? '');
    _pricingType = g?.pricingType ?? GroupPricingType.monthly;

    // اختيار أيقونة ولون افتراضيين
    if (g?.icon != null && _iconOptions.containsKey(g!.icon)) {
      _selectedIcon = g.icon!;
    } else {
      final usedIcons = widget.existingGroups.map((x) => x.icon).whereType<String>().toSet();
      _selectedIcon = _iconOptions.keys.firstWhere(
        (k) => !usedIcons.contains(k),
        orElse: () => 'group',
      );
    }

    if (g?.color != null) {
      _selectedColor = g!.color!;
    } else {
      final usedColors = widget.existingGroups.map((x) => x.color).whereType<int>().toSet();
      _selectedColor = _colorOptions.firstWhere(
        (c) => !usedColors.contains(c),
        orElse: () => _colorOptions.first,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _priceCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name      = _nameCtrl.text.trim();
    final code      = _codeCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();
    final slots     = _scheduleCtrl.text.split(',').where((e) => e.trim().isNotEmpty).length;

    // تحقق مبدئي من التكرار قبل ما نلجأ لقاعدة البيانات — بيدّي رسالة
    // أوضح فوراً بدل ما ننتظر خطأ UNIQUE constraint من الـDB.
    final nameTaken = widget.existingGroups.any((g) =>
        g.id != widget.group?.id &&
        g.name.trim().toLowerCase() == name.toLowerCase());
    final codeTaken = code.isNotEmpty &&
        widget.existingGroups.any((g) =>
            g.id != widget.group?.id &&
            (g.code?.trim().toLowerCase() ?? '') == code.toLowerCase());

    // تعارض مع ميعاد مجموعة أخرى (نفس اليوم ونطاق وقت متداخل)
    final otherGroups = widget.existingGroups.where((g) => g.id != widget.group?.id).toList();
    final conflictingGroup = slots >= 1 && !hasScheduleOverlap(_scheduleCtrl.text)
        ? findConflictingGroup(_scheduleCtrl.text, otherGroups)
        : null;

    // Inline validation
    setState(() {
      _nameError     = name.isEmpty      ? 'مطلوب'
                     : nameTaken          ? 'الاسم ده مستخدم بالفعل'
                     : null;
      _codeError     = code.isEmpty      ? 'مطلوب'
                     : codeTaken          ? 'الكود ده مستخدم بالفعل'
                     : null;
      _priceError    = priceText.isEmpty ? 'مطلوب'
                     : double.tryParse(priceText) == null ? 'رقم غير صالح' : null;
      _scheduleError = slots < 1         ? 'أضف موعد واحد على الأقل'
                     : hasScheduleOverlap(_scheduleCtrl.text)
                                           ? 'فيه موعدين متداخلين في نفس اليوم'
                     : conflictingGroup != null
                                           ? 'الميعاد ده متعارض مع ميعاد مجموعة "${conflictingGroup.name}"'
                     : null;
    });

    if (_nameError != null || _codeError != null ||
        _priceError != null || _scheduleError != null) return;

    final price = double.parse(priceText);
    setState(() => _saving = true);
    try {
      final success = await widget.onSave(Group(
        id: widget.group?.id,
        name: name,
        code: code,
        price: price,
        color: _selectedColor,
        icon: _selectedIcon,
        schedule: _scheduleCtrl.text.trim().isEmpty ? null : _scheduleCtrl.text.trim(),
        createdAt: widget.group?.createdAt,
        pricingType: _pricingType,
      ));
      if (!mounted) return;
      if (success) {
        widget.onSaved?.call(name, price);
        Navigator.of(context).pop();
      }
      // لو فشل: الـcontroller أظهر رسالة الخطأ بالفعل، خلّي الشيت مفتوح
    } catch (e) {
      if (mounted) ToastHelper.error('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── منتقي اللون (منبثق) ─────────────────────────────────────
  Future<void> _pickColor() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheet(
        title: 'اختر لون المجموعة',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorOptions.map((c) {
            final selected = _selectedColor == c;
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(c),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : null,
                  boxShadow: selected
                      ? [BoxShadow(
                          color: Color(c).withValues(alpha: 0.5),
                          blurRadius: 8, spreadRadius: 1)]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedColor = picked);
  }

  // ── منتقي الأيقونة (منبثق) ──────────────────────────────────
  Future<void> _pickIcon() async {
    final primary = Color(_selectedColor);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheet(
        title: 'اختر أيقونة المجموعة',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _iconOptions.entries.map((e) {
            final selected = _selectedIcon == e.key;
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(e.key),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? primary : Colors.grey.withValues(alpha: 0.2),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Icon(e.value,
                    color: selected ? primary : Colors.grey.shade500, size: 24),
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedIcon = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Color(_selectedColor);
    final isEdit = widget.group != null;

    return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header مع أيقونة المجموعة ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // أيقونة المجموعة (preview)
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_iconOptions[_selectedIcon]!, color: primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'تعديل المجموعة' : 'مجموعة جديدة',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          isEdit ? widget.group!.name : 'أدخل بيانات المجموعة',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // ── Form ─────────────────────────────────────────────
            // Flexible+SingleChildScrollView بدل Expanded+ListView — كده
            // القسم ده بياخد بس المساحة اللي محتاجها فورم قصير، ويبقى
            // قابل للتمرير بس لو المحتوى فعلاً أطول من المساحة المتاحة.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المجموعة
                  FormLabel('اسم المجموعة *'),
                  const SizedBox(height: 6),
                  CustomTextField(
                    controller: _nameCtrl,
                    label: 'مثال: الرابعة الابتدائي أ',
                  ),
                  if (_nameError != null) ErrorText(_nameError!),
                  const SizedBox(height: 16),

                  // نوع التسعير — شهري أو بالحصة
                  FormLabel('نوع التسعير'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: PricingTypeChip(
                        label: 'شهري',
                        selected: _pricingType == GroupPricingType.monthly,
                        onTap: () => setState(
                            () => _pricingType = GroupPricingType.monthly),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PricingTypeChip(
                        label: 'بالحصة',
                        selected: _pricingType == GroupPricingType.perSession,
                        onTap: () => setState(
                            () => _pricingType = GroupPricingType.perSession),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // بادئة الكود والسعر في صف
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FormLabel('بادئة الكود *'),
                            const SizedBox(height: 6),
                            CustomTextField(
                              controller: _codeCtrl,
                              label: 'مثال: G4A',
                            ),
                            if (_codeError != null) ErrorText(_codeError!),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FormLabel(_pricingType == GroupPricingType.perSession
                                ? 'سعر الحصة الواحدة *'
                                : 'سعر الاشتراك الشهري *'),
                            const SizedBox(height: 6),
                            CustomTextField(
                              controller: _priceCtrl,
                              label: '0',
                              keyboardType: TextInputType.number,
                            ),
                            if (_priceError != null) ErrorText(_priceError!),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // مظهر المجموعة — لون وأيقونة (معاينة مدمجة، تفتح
                  // منتقي منبثق بدل ما ياخدوا مساحة تابتة في الفورم)
                  FormLabel('مظهر المجموعة'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      AppearancePreviewTile(
                        label: 'اللون',
                        onTap: _pickColor,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(
                                color: primary.withValues(alpha: 0.4),
                                blurRadius: 6)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppearancePreviewTile(
                        label: 'الأيقونة',
                        onTap: _pickIcon,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_iconOptions[_selectedIcon]!,
                              color: primary, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // المواعيد
                  GroupScheduleEditor(
                    controller: _scheduleCtrl,
                    onChanged: () {
                      if (_scheduleError != null) setState(() => _scheduleError = null);
                    },
                  ),
                  if (_scheduleError != null) ErrorText(_scheduleError!),
                ],
                ),
              ),
            ),

            // ── زر الحفظ ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  isEdit ? 'حفظ التعديلات' : 'إضافة المجموعة',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
