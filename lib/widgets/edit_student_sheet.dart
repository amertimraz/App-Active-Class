// lib/widgets/edit_student_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/contact_picker_service.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/widgets/exempt_widgets.dart';
import 'package:active_class/widgets/code_scanner_page.dart';

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
  return showDialog<Student>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.075,
        ),
        child: ConstrainedBox(
          // maxHeight بدل height ثابت — الشيت بقى بيتقاس على حجم محتواه
          // الفعلي بدل ما ياخد 85% من الشاشة دايمًا حتى لو الفورم قصير
          // (نفس تعديل شيتي إضافة المجموعة/الطالب).
          constraints: BoxConstraints(
            minWidth: size.width * 0.92,
            maxWidth: size.width * 0.92,
            maxHeight: size.height * 0.85,
          ),
          child: EditStudentSheet(
            student: student,
            accentColor: accentColor,
            controller: controller,
            groups: groups,
          ),
        ),
      );
    },
  );
}

class EditStudentSheet extends StatefulWidget {
  final Student student;
  final Color accentColor;
  final StudentController? controller;
  final List<Group>? groups;

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
  bool _saving = false;
  late String _code;
  late final TextEditingController _codeCtrl;
  bool _codeIsManual = false;

  Group? _selectedGroup;
  // باقي أعضاء مجموعة إخوة الطالب ده (بحد أقصى عضوين، أي مجموعة حتى
  // 3 مع الطالب الحالي). راجع specs/007-three-sibling-support.
  List<Student> _siblings = [];
  // نسخة من _siblings وقت فتح الشيت — بنقارن بيها عند الحفظ عشان نعرف
  // مين اتشال (فك ربط جزئي لعضو واحد بس، من غير ما يأثر على الباقي).
  List<Student> _initialSiblings = [];

  // الإعفاء
  bool _isExempt;
  double _exemptPercent;
  String? _exemptPreset;

  _EditStudentSheetState()
      : _isExempt = false,
        _exemptPercent = 100;

  late final StudentController _sc;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s.name);
    _priceCtrl = TextEditingController(text: s.price.toStringAsFixed(0));
    _phoneCtrl = TextEditingController(text: s.guardianPhone ?? '');
    _sibTotalCtrl =
        TextEditingController(text: s.siblingsTotal?.toString() ?? '');
    _attendanceStart = s.attendanceStart ?? DateTime.now();
    _birthDate = s.birthDate;
    _code = s.code;
    _codeCtrl = TextEditingController(text: _code);

    if (widget.groups != null) {
      _selectedGroup =
          widget.groups!.where((g) => g.id == s.groupId).firstOrNull;
    }

    // الإعفاء
    _isExempt = s.isExempt;
    _exemptPercent = s.exemptPercent > 0 ? s.exemptPercent : 100;
    _exemptCustomCtrl = TextEditingController();
    // لو السبب من القائمة الجاهزة اختاره، غير كده اعتبره "أخرى"
    const presets = [
      'يتيم',
      'مكفول',
      'إعفاء مؤسسي',
      'ظروف اجتماعية',
      'أخ / أخت لطالب',
      'أخرى',
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
    final groupId = widget.student.siblingGroupId;
    if (groupId != null) {
      final members = await DatabaseService()
          .getStudentsInSiblingGroup(groupId, excludeId: widget.student.id);
      if (mounted) {
        setState(() {
          _siblings = members;
          _initialSiblings = members;
        });
      }
      return;
    }
    // توافق قديم: طالب لسه معندوش siblingGroupId (نادر بعد الـmigration).
    if (widget.student.siblingId != null) {
      final s = await DatabaseService().getStudent(widget.student.siblingId!);
      if (mounted && s != null) {
        setState(() {
          _siblings = [s];
          _initialSiblings = [s];
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _exemptCustomCtrl.dispose();
    _sibTotalCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSibling() async {
    if (_siblings.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحد الأقصى لمجموعة الإخوة 3 أعضاء')),
      );
      return;
    }
    final all = await DatabaseService().getAllStudents();
    if (!mounted) return;
    final pickedIds = _siblings.map((s) => s.id).toSet();
    // معنيش نربط أخ/أخت مؤرشف — الأرشفة أصلاً بتفكّ أي ربط أخوي قائم
    // (راجع DatabaseService.archiveStudent)، فمينفعش نسمح بربط جديد له.
    final list = all
        .where((s) =>
            s.id != widget.student.id &&
            !s.isArchived &&
            !pickedIds.contains(s.id))
        .toList();

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
      await _addSiblingCandidate(picked);
    }
  }

  /// يضيف طالب مختار كعضو في مجموعة الإخوة — لو كان عضو أصلاً في
  /// مجموعة إخوة موجودة، بنضيف باقي أعضاء مجموعته كمان عشان الربط
  /// الجديد ميكسرش رابطهم القديم، مع فرض الحد الأقصى 3 (شامل الطالب
  /// الحالي نفسه).
  Future<void> _addSiblingCandidate(Student picked) async {
    var toAdd = [picked];
    if (picked.siblingGroupId != null) {
      toAdd = await DatabaseService()
          .getStudentsInSiblingGroup(picked.siblingGroupId!);
    }
    final existingIds = _siblings.map((s) => s.id).toSet();
    final merged = [
      ..._siblings,
      ...toAdd.where(
          (s) => s.id != widget.student.id && !existingIds.contains(s.id)),
    ];
    if (merged.length > 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحد الأقصى لمجموعة الإخوة 3 أعضاء')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _siblings = merged);
  }

  // ── مسح QR من كرت مطبوع مسبقاً واستبدال كود الطالب بيه ───────────
  Future<void> _scanPrintedCode() async {
    final scanned = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CodeScannerPage()));
    if (scanned == null || !mounted) return;
    final trimmed = scanned.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كود QR غير صالح')),
      );
      return;
    }
    if (trimmed == _code) return;
    final existing = await DatabaseService().getStudentByCode(trimmed);
    if (!mounted) return;
    if (existing != null && existing.id != widget.student.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('هذا الكود مستخدم بالفعل للطالب: ${existing.name}')),
      );
      return;
    }
    setState(() {
      _code = trimmed;
      _codeCtrl.text = trimmed;
    });
  }

  void _resetCode() => setState(() {
        _code = widget.student.code;
        _codeCtrl.text = _code;
      });

  void _onManualSwitchChanged(bool value) {
    setState(() {
      _codeIsManual = value;
      _codeCtrl.text = _code;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الطالب')),
      );
      return;
    }
    if (_siblings.isNotEmpty) {
      final total = double.tryParse(_sibTotalCtrl.text.trim());
      if (total == null || total < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال الإجمالي المشترك للإخوة')),
        );
        return;
      }
    }
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رسوم صحيحة')),
      );
      return;
    }

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
      final newTotal = _siblings.isNotEmpty
          ? double.tryParse(_sibTotalCtrl.text.trim())
          : null;

      final updated = widget.student.copyWith(
        name: name,
        code: _code,
        price: price,
        groupId: _selectedGroup?.id ?? widget.student.groupId,
        siblingsTotal: _siblings.isNotEmpty ? newTotal : null,
        clearSiblingsTotal: _siblings.isEmpty,
        clearSiblingGroupId: _siblings.isEmpty,
        attendanceStart: _attendanceStart,
        guardianPhone:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        birthDate: _birthDate,
        exemptPercent: _isExempt ? _exemptPercent : 0,
        exemptReason: finalReason,
        clearExemptReason: !_isExempt,
      );

      final db = DatabaseService();
      // فك ربط الأعضاء اللي اتشالوا من القائمة (فك جزئي — عضو ده بس،
      // مش هيأثر على باقي المجموعة لو فيها أكتر من واحد).
      final currentIds = _siblings.map((s) => s.id).toSet();
      final removed =
          _initialSiblings.where((s) => !currentIds.contains(s.id));
      for (final r in removed) {
        final fresh = await db.getStudent(r.id!);
        if (fresh == null) continue;
        final cleared = fresh.copyWith(
            clearSiblingsTotal: true, clearSiblingGroupId: true);
        await db.updateStudent(cleared);
        final idx = _sc.students.indexWhere((s) => s.id == cleared.id);
        if (idx != -1) _sc.students[idx] = cleared;
      }

      if (_siblings.isNotEmpty && newTotal != null) {
        // اربط الطالب الحالي مع كل الأعضاء الحاليين بإجمالي موحّد —
        // linkSiblingGroup بيحدّث الطالب الحالي كمان فمفيش داعي لـ
        // updateStudent منفصلة له.
        final members = [
          updated.copyWith(siblingsTotal: newTotal),
          for (final s in _siblings) s.copyWith(siblingsTotal: newTotal),
        ];
        await _sc.linkSiblingGroup(members);
      } else {
        await _sc.updateStudent(updated);
      }
      NotificationService().syncAllScheduledNotifications();
      _sc.filterStudents();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 44,
                height: 44,
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
                  ])),
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded)),
            ]),

            const SizedBox(height: 16),

            // ── كود الطالب (QR) ────────────────────────────────────
            Builder(builder: (context) {
              final changed = _code != widget.student.code;
              final boxColor = changed ? Colors.purple : primary;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: boxColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: boxColor.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(
                    changed ? Icons.qr_code_2_rounded : Icons.qr_code_rounded,
                    color: boxColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _codeIsManual
                        ? TextField(
                            controller: _codeCtrl,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: boxColor,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'اكتب كود الطالب',
                            ),
                            onChanged: (v) => setState(() => _code = v.trim()),
                          )
                        : Text(
                            changed
                                ? 'كود من كرت مطبوع: $_code'
                                : 'الكود: $_code',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: boxColor,
                            ),
                          ),
                  ),
                  if (changed)
                    IconButton(
                      tooltip: 'رجوع للكود الأصلي',
                      icon: const Icon(Icons.refresh_rounded,
                          size: 20, color: Colors.purple),
                      onPressed: _resetCode,
                    ),
                  Switch.adaptive(
                    value: _codeIsManual,
                    activeThumbColor: Colors.purple,
                    onChanged: _onManualSwitchChanged,
                  ),
                  IconButton(
                    tooltip: 'مسح QR من كرت مطبوع مسبقاً',
                    icon: Icon(Icons.qr_code_scanner_rounded,
                        size: 20, color: boxColor),
                    onPressed: _scanPrintedCode,
                  ),
                ]),
              );
            }),

            const SizedBox(height: 12),
            CustomTextField(controller: _nameCtrl, label: 'اسم الطالب'),
            const SizedBox(height: 12),
            CustomTextField(
                controller: _priceCtrl,
                label: 'الرسوم',
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: CustomTextField(
                      controller: _phoneCtrl,
                      label: 'ولي الأمر',
                      keyboardType: TextInputType.phone)),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
                ),
                child: IconButton(
                  tooltip: 'اختيار من جهات الاتصال',
                  icon: Icon(Icons.contacts_rounded, color: widget.accentColor),
                  onPressed: () async {
                    final phone =
                        await ContactPickerService.pickPhoneNumber(context);
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                onChanged: (g) {
                  setState(() => _selectedGroup = g);
                  // بنفصل بس (مش بنغيّر الرسوم تلقائي) عشان معندناش أي
                  // فكرة هل الرسوم الحالية مخصصة عمدًا أو كانت افتراضية
                  // من المجموعة القديمة — لو غيّرناها من غير تنبيه ممكن
                  // نمسح سعر مخصص المدرّس حطه بنفسه.
                  final newPrice = g?.price;
                  final currentPrice = double.tryParse(_priceCtrl.text.trim());
                  if (g != null &&
                      newPrice != null &&
                      currentPrice != null &&
                      newPrice != currentPrice) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'سعر مجموعة "${g.name}" مختلف — راجع خانة الرسوم قبل الحفظ'),
                      duration: const Duration(seconds: 3),
                    ));
                  }
                },
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

            // ربط إخوة (حتى 3 أعضاء، شامل الطالب الحالي)
            GestureDetector(
              onTap: _siblings.length >= 2 ? null : _pickSibling,
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
                      color: _siblings.isNotEmpty ? primary : Colors.grey,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _siblings.isNotEmpty
                          ? 'الإخوة (${_siblings.length + 1}/3)'
                          : 'ربط بطالب آخر (أخ / أخت)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _siblings.isNotEmpty
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55)),
                    ),
                  ),
                  if (_siblings.length < 2)
                    Icon(Icons.add_circle_outline_rounded,
                        color: Colors.grey.shade400, size: 18),
                ]),
              ),
            ),
            if (_siblings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._siblings.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(
                        child: Text('${s.name} (${s.code})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _siblings = _siblings
                            .where((x) => x.id != s.id)
                            .toList()),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.red),
                      ),
                    ]),
                  )),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _sibTotalCtrl,
                label: 'الإجمالي المشترك للإخوة للشهر',
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
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
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
  final String label;
  final bool hasValue;
  final Color color;
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
