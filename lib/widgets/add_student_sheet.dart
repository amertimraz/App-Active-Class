// lib/widgets/add_student_sheet.dart
import 'package:flutter/material.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/contact_picker_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/exempt_widgets.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/import_students_dialog.dart';

/// يفتح bottom sheet لإضافة طالب.
/// [preselectedGroup] : لو جاي من صفحة تفاصيل المجموعة — المجموعة محددة مسبقاً.
/// [onAdded]         : callback بعد كل إضافة ناجحة.
Future<void> showAddStudentSheet(
  BuildContext context, {
  required StudentController controller,
  Group? preselectedGroup,
  VoidCallback? onAdded,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: _AddStudentSheet(
        controller: controller,
        preselectedGroup: preselectedGroup,
        onAdded: onAdded,
      ),
    ),
  );
}

class _AddStudentSheet extends StatefulWidget {
  final StudentController controller;
  final Group? preselectedGroup;
  final VoidCallback? onAdded;

  const _AddStudentSheet({
    required this.controller,
    this.preselectedGroup,
    this.onAdded,
  });

  @override
  State<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<_AddStudentSheet> {
  // Controllers
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sibTotalCtrl = TextEditingController();

  // State
  List<Group> _groups = [];
  Group? _selectedGroup;
  String _nextCode = '';
  DateTime? _attendanceStart = DateTime.now();
  DateTime? _birthDate;
  Student? _sibling;
  bool _loading = false;
  bool _loadingGroups = true;

  // Focus
  final _nameFocus = FocusNode();

  // Inline success hint below name field
  String? _savedName;

  // Exemption
  bool _isExempt = false;
  double _exemptPercent = 100;
  String? _exemptReasonPreset;
  final _exemptCustomCtrl = TextEditingController();

  // ثابت: لون المجموعة المحددة
  Color get _primary {
    final c = _selectedGroup?.color;
    return c != null ? Color(c) : const Color(0xFF1E88E5);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _groups = await widget.controller.loadAllGroups();
    _selectedGroup = widget.preselectedGroup ?? (_groups.isNotEmpty ? _groups.first : null);
    await _refreshCode();
    _prefillPrice();
    if (mounted) setState(() => _loadingGroups = false);
  }

  Future<void> _refreshCode() async {
    final g = _selectedGroup;
    if (g == null || g.id == null || (g.code?.isEmpty ?? true)) {
      _nextCode = '';
      return;
    }
    _nextCode = await widget.controller
        .generateNextStudentCode(groupPrefix: g.code!, groupId: g.id!);
    if (mounted) setState(() {});
  }

  void _prefillPrice() {
    final p = _selectedGroup?.price;
    _priceCtrl.text = p != null ? p.toStringAsFixed(0) : '';
  }

  Future<void> _onGroupChanged(Group? g) async {
    setState(() { _selectedGroup = g; _nextCode = ''; });
    _prefillPrice();
    await _refreshCode();
  }

  Future<void> _pickSibling() async {
    final all = await DatabaseService().getAllStudents();
    final list = all.where((s) => s.id != null).toList();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final _sc = TextEditingController();
        List<Student> filtered = list;
        return StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
          title: const Text('اختر الطالب الأخ'),
          content: SizedBox(
            width: 400, height: 360,
            child: Column(children: [
              TextField(
                controller: _sc,
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو الكود...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (v) => setSt(() {
                  filtered = list.where((s) =>
                      s.name.contains(v) || s.code.contains(v)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('لا يوجد نتائج'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _primary.withValues(alpha: 0.15),
                              child: Text(s.name[0],
                                  style: TextStyle(color: _primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                            title: Text(s.name),
                            subtitle: Text('الكود: ${s.code}'),
                            onTap: () {
                              setState(() => _sibling = s);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ],
        ));
      },
    );
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, msg);
    } else {
      AppToast.success(context, msg);
    }
  }

  Future<void> _submit() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final g     = _selectedGroup;

    if (name.isEmpty)  { _toast('أدخل اسم الطالب', isError: true); return; }
    if (g == null || g.id == null) { _toast('اختر المجموعة أولاً', isError: true); return; }
    if (_nextCode.isEmpty) { _toast('لم يتم توليد الكود', isError: true); return; }
    if (price == null) { _toast('أدخل رسوم صحيحة', isError: true); return; }

    final sibTotal = _sibling != null
        ? double.tryParse(_sibTotalCtrl.text.trim())
        : null;
    if (_sibling != null && sibTotal == null) {
      _toast('أدخل إجمالي الأخوين', isError: true); return;
    }

    setState(() => _loading = true);

    // Build exemption reason
    String? finalReason;
    if (_isExempt) {
      if (_exemptReasonPreset == 'أخرى') {
        finalReason = _exemptCustomCtrl.text.trim().isEmpty
            ? 'أخرى'
            : _exemptCustomCtrl.text.trim();
      } else {
        finalReason = _exemptReasonPreset;
      }
    }

    final student = Student(
      name: name,
      code: _nextCode,
      groupId: g.id!,
      price: price,
      createdAt: DateTime.now(),
      attendanceStart: _attendanceStart,
      guardianPhone: phone.isEmpty ? null : phone,
      birthDate: _birthDate,
      siblingId: _sibling?.id,
      siblingsTotal: sibTotal,
      exemptPercent: _isExempt ? _exemptPercent : 0,
      exemptReason: finalReason,
    );

    final created = await widget.controller.addStudent(student);

    // فشلت الإضافة (كود مكرر، تجاوز حد الترخيص، ...) — الكنترولر عرض
    // رسالة الخطأ بالفعل. سيبي الحقول زي ما هي عشان المستخدم يقدر
    // يصلّح ويحاول تاني، من غير ما نمسح بياناته أو نظهر نجاح وهمي.
    if (created == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // ربط الأخ (تحديث ذري للاثنين مع بعض)
    final isExemptSaved = _isExempt;
    if (_sibling != null && sibTotal != null) {
      final s1 = created.copyWith(siblingId: _sibling!.id, siblingsTotal: sibTotal);
      final s2 = _sibling!.copyWith(siblingId: created.id, siblingsTotal: sibTotal);
      await widget.controller.linkSiblings(s1, s2);
    }

    widget.onAdded?.call();
    if (created.birthDate != null) {
      NotificationService().syncAllScheduledNotifications();
    }

    // reset للإضافة التالية — بنسيب تاريخ "بداية الحضور" زي ما هو
    // عمدًا (مش بيترجع لتاريخ النهاردة)، عشان لو المدرس بيسجّل دفعة
    // طلاب حضروا يوم معيّن، يفضل نفس التاريخ لكل الطلاب اللي بيضيفهم
    // ورا بعض من غير ما يعيد اختياره كل مرة. بيرجع لتاريخ النهاردة
    // تلقائي أول ما الشيت يتقفل ويتفتح تاني.
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _sibTotalCtrl.clear();
    _exemptCustomCtrl.clear();
    _birthDate = null;
    _sibling = null;
    _isExempt = false;
    _exemptPercent = 100;
    _exemptReasonPreset = null;
    _prefillPrice();
    await _refreshCode();

    if (mounted) {
      setState(() {
        _loading = false;
        _savedName = name + (isExemptSaved ? ' • معفى' : '');
      });
      // فوكس على حقل الاسم فوراً (اللوحة تبقى ظاهرة)
      _nameFocus.requestFocus();
      // أخفِ الهنت بعد 3 ثواني
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _savedName = null);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _priceCtrl.dispose();
    _sibTotalCtrl.dispose();
    _exemptCustomCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = _primary;
    final hasPreselectedGroup = widget.preselectedGroup != null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 4, 0),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person_add_rounded, color: primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('إضافة طالب جديد',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(
                    _loadingGroups
                        ? 'جاري التحميل...'
                        : _selectedGroup != null
                            ? 'المجموعة: ${_selectedGroup!.name}'
                            : 'اختر المجموعة أولاً',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ])),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ),

            const Divider(height: 20),

            // Form
            Expanded(
              child: _loadingGroups
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        // ── كود تلقائي ──────────────────────────────────────
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _nextCode.isEmpty
                                ? Colors.orange.withValues(alpha: 0.08)
                                : primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _nextCode.isEmpty
                                  ? Colors.orange.withValues(alpha: 0.3)
                                  : primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              _nextCode.isEmpty
                                  ? Icons.warning_amber_rounded
                                  : Icons.qr_code_rounded,
                              color: _nextCode.isEmpty ? Colors.orange : primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _nextCode.isEmpty
                                    ? 'اختر مجموعة لتوليد الكود تلقائياً'
                                    : 'الكود التلقائي: $_nextCode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _nextCode.isEmpty ? Colors.orange : primary,
                                ),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 16),

                        // ── اسم الطالب ──────────────────────────────────────
                        Row(children: [
                          Expanded(child: _Label('اسم الطالب *')),
                          if (_selectedGroup != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => showImportStudentsDialog(
                                context,
                                controller: widget.controller,
                                groups: _groups,
                                preselectedGroup: _selectedGroup,
                                onImported: () {
                                  widget.onAdded?.call();
                                  widget.controller.loadAllStudents();
                                  _refreshCode();
                                },
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.upload_file_rounded, size: 14, color: primary),
                                  const SizedBox(width: 4),
                                  Text('استيراد من إكسل',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: primary)),
                                ]),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        CustomTextField(
                          controller: _nameCtrl,
                          label: 'مثال: أحمد محمد',
                          focusNode: _nameFocus,
                        ),
                        // هنت النجاح أسفل حقل الاسم مباشرة
                        if (_savedName != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF059669)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF059669), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'تم إضافة $_savedName بنجاح ✓',
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // ── اختيار المجموعة (فقط لو مش preselected) ────────
                        if (!hasPreselectedGroup) ...[
                          _Label('المجموعة *'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Group>(
                            isExpanded: true,
                            value: _selectedGroup,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            hint: const Text('اختر المجموعة'),
                            items: _groups.map((g) => DropdownMenuItem(
                              value: g,
                              child: Row(children: [
                                if (g.color != null)
                                  Container(
                                    width: 10, height: 10,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      color: Color(g.color!), shape: BoxShape.circle),
                                  ),
                                Text(
                                  g.price != null
                                      ? '${g.name} • ${FormatHelper.formatCurrency(g.price)}'
                                      : g.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ]),
                            )).toList(),
                            onChanged: _onGroupChanged,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ── الرسوم (شهرية أو بالحصة حسب نوع تسعير المجموعة) ──
                        _Label(_selectedGroup?.isPerSession == true
                            ? 'سعر الحصة الواحدة'
                            : 'الرسوم الشهرية'),
                        const SizedBox(height: 6),
                        CustomTextField(
                          controller: _priceCtrl,
                          label: '0',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 14),

                        // ── رقم ولي الأمر ─────────────────────────────────────
                        _Label('رقم ولي الأمر'),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _phoneCtrl,
                              label: '01xxxxxxxxx',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
                            ),
                            child: IconButton(
                              tooltip: 'اختيار من جهات الاتصال',
                              icon: Icon(Icons.contacts_rounded, color: primary),
                              onPressed: () async {
                                final phone = await ContactPickerService.pickPhoneNumber(context);
                                if (phone != null) {
                                  setState(() => _phoneCtrl.text = phone);
                                }
                              },
                            ),
                          ),
                        ]),

                        const SizedBox(height: 14),

                        // ── التواريخ ──────────────────────────────────────────
                        Row(children: [
                          Expanded(child: _DatePickerBtn(
                            icon: Icons.cake_rounded,
                            label: _birthDate != null
                                ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                : 'تاريخ الميلاد',
                            hasValue: _birthDate != null,
                            color: primary,
                            onTap: () async {
                              final p = await showDatePicker(
                                context: context,
                                firstDate: DateTime(1990),
                                lastDate: DateTime.now(),
                                initialDate: _birthDate ?? DateTime(2012),
                              );
                              if (p != null) setState(() => _birthDate = p);
                            },
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _DatePickerBtn(
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
                          )),
                        ]),

                        const SizedBox(height: 16),

                        // ── ربط أخ ───────────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.group_rounded,
                                    color: Colors.purple, size: 18),
                              ),
                              title: Text(
                                _sibling == null
                                    ? 'ربط بطالب آخر (أخ / أخت)'
                                    : 'الأخ: ${_sibling!.name}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _sibling != null ? Colors.purple : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: _sibling != null
                                  ? Text('الكود: ${_sibling!.code}',
                                      style: const TextStyle(fontSize: 11))
                                  : const Text('خصم مشترك للأخوين',
                                      style: TextStyle(fontSize: 11)),
                              trailing: _sibling == null
                                  ? IconButton(
                                      onPressed: _pickSibling,
                                      icon: const Icon(Icons.add_circle_outline_rounded,
                                          color: Colors.purple),
                                      tooltip: 'اختر الطالب الأخ',
                                    )
                                  : IconButton(
                                      onPressed: () => setState(() {
                                        _sibling = null;
                                        _sibTotalCtrl.clear();
                                      }),
                                      icon: const Icon(Icons.close_rounded, color: Colors.red),
                                    ),
                            ),
                            if (_sibling != null) ...[
                              const Divider(height: 0, indent: 16, endIndent: 16),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _Label('إجمالي الاشتراك للأخوين معاً'),
                                  const SizedBox(height: 6),
                                  CustomTextField(
                                    controller: _sibTotalCtrl,
                                    label: 'مثال: 300',
                                    keyboardType: TextInputType.number,
                                  ),
                                ]),
                              ),
                            ],
                          ]),
                        ),

                        const SizedBox(height: 16),

                        // ── قسم الإعفاء ──────────────────────────────────────
                        ExemptionSection(
                          isExempt: _isExempt,
                          exemptPercent: _exemptPercent,
                          selectedPreset: _exemptReasonPreset,
                          customCtrl: _exemptCustomCtrl,
                          accentColor: primary,
                          onToggle: (v) => setState(() => _isExempt = v),
                          onPercentChanged: (v) =>
                              setState(() => _exemptPercent = v),
                          onPresetChanged: (v) =>
                              setState(() => _exemptReasonPreset = v),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
            ),

            // ── زر الإضافة ─────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20,
                  MediaQuery.of(context).viewInsets.bottom + 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إغلاق'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_rounded),
                    label: const Text('إضافة الطالب',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13));
}

class _DatePickerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final Color color;
  final VoidCallback onTap;
  const _DatePickerBtn({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: hasValue ? color.withValues(alpha: 0.07) : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: hasValue ? color : Colors.grey.shade500),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 11,
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
