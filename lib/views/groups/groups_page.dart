// lib/views/groups/groups_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:intl/intl.dart';

/// يتحقق من وجود مواعيد متداخلة في نفس اليوم داخل نص الجدول
/// (صيغة "اليوم HH:MM-HH:MM,...") — بيرجّع true لو فيه تداخل.
bool _hasScheduleOverlap(String raw) {
  final byDay = <String, List<(int, int)>>{};
  for (final part in raw.split(',')) {
    final s = part.trim();
    if (s.isEmpty) continue;
    final sp = s.split(' ');
    if (sp.length < 2) continue;
    final day = sp.first;
    final range = s.substring(day.length).trim().split('-');
    if (range.length != 2) continue;
    TimeOfDay? parseT(String v) {
      final p = v.trim().split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }
    final from = parseT(range[0]);
    final to = parseT(range[1]);
    if (from == null || to == null) continue;
    byDay
        .putIfAbsent(day, () => [])
        .add((from.hour * 60 + from.minute, to.hour * 60 + to.minute));
  }
  for (final ranges in byDay.values) {
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < ranges.length; i++) {
      if (ranges[i].$1 < ranges[i - 1].$2) return true;
    }
  }
  return false;
}

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final GroupController controller = Get.put(GroupController());
  final StudentController studentController = Get.put(StudentController());
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.loadGroups();
    studentController.loadAllStudents();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // عدد طلاب المجموعة من الـ controller مباشرة (بدون FutureBuilder)
  int _studentCount(int? groupId) {
    if (groupId == null) return 0;
    return studentController.students.where((s) => s.groupId == groupId).length;
  }

  List<Student> _groupStudents(int? groupId) {
    if (groupId == null) return [];
    return studentController.students.where((s) => s.groupId == groupId).toList();
  }

  String _displaySchedule(String raw, bool use24) {
    final parts = raw.split(',');
    String fmt(TimeOfDay t) {
      if (use24) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }
      final dt = DateTime(2000, 1, 1, t.hour, t.minute);
      return DateFormat('hh:mm a', 'ar').format(dt);
    }

    TimeOfDay? parse(String v) {
      final p = v.split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    return parts.map((s) {
      final txt = s.trim();
      if (txt.isEmpty) return txt;
      final sp = txt.split(' ');
      if (sp.length < 2) return txt;
      final day = sp.first;
      final times = txt.substring(day.length).trim();
      final range = times.split('-');
      if (range.length != 2) return txt;
      final from = parse(range[0].trim());
      final to = parse(range[1].trim());
      if (from == null || to == null) return txt;
      return '$day ${fmt(from)}-${fmt(to)}';
    }).join('\n');
  }

  List<Map<String, String>> _parseScheduleSlots(String raw) {
    final parts = raw.split(',');
    return parts.map((s) {
      final txt = s.trim();
      if (txt.isEmpty) return <String, String>{};
      final sp = txt.split(' ');
      if (sp.length < 2) return <String, String>{'day': txt, 'time': ''};
      final day = sp.first;
      final time = txt.substring(day.length).trim();
      return <String, String>{'day': day, 'time': time};
    }).where((m) => m.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'المجموعات',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'مجموعة جديدة',
            onPressed: () => _showGroupFormDialog(context),
          ),
        ],
      ),
      body: buildSoftBackground(
        context: context,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _searchController.text.trim();
          final List<Group> items = controller.groups.where((g) {
            if (query.isEmpty) return true;
            final byGroup = g.name.contains(query) || (g.code?.contains(query) ?? false);
            final byStudent = studentController.students
                .any((s) => s.groupId == g.id && s.name.contains(query));
            return byGroup || byStudent;
          }).toList();

          final totalStudents = studentController.students.length;
          // بنقرأ القيمة هنا (جوه الـ Obx) بدل جوه الـ closure اللي بتتنفذ
          // لاحقًا داخل بناء كل بطاقة — لو قريناها هناك، GetX مش هيسجلها
          // كـ dependency وبالتالي القائمة مش هتتحدّث لما نظام الساعة يتغيّر.
          final use24h = Get.find<SettingsController>().use24hFormat.value;

          return Column(
            children: [
              // ── شريط البحث + ملخص ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  children: [
                    // ملخص سريع
                    Row(
                      children: [
                        _SummaryPill(
                          icon: Icons.groups_rounded,
                          label: '${controller.groups.length} مجموعة',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        _SummaryPill(
                          icon: Icons.person_rounded,
                          label: '$totalStudents طالب',
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomSearchBar(
                      controller: _searchController,
                      hintText: 'ابحث بالاسم أو الكود...',
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── القائمة ─────────────────────────────────────────
              Expanded(
                child: controller.groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(PADDING_LARGE),
                        child: buildSoftPanel(
                          context: context,
                          child: EmptyState(
                            icon: Icons.group_off,
                            title: 'لا توجد مجموعات',
                            subtitle: 'ابدأ بإضافة مجموعة جديدة',
                            actionLabel: 'إضافة مجموعة',
                            onActionPressed: () => _showGroupFormDialog(context),
                          ),
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Text('لا نتائج لـ "$query"',
                                style: TextStyle(color: Colors.grey.shade500)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: items.length,
                            itemBuilder: (_, i) =>
                                _GroupCard(
                                  group: items[i],
                                  studentCount: _studentCount(items[i].id),
                                  students: _groupStudents(items[i].id),
                                  onEdit: () => _showGroupFormDialog(context, group: items[i]),
                                  onDelete: () {
                                    if (items[i].id != null) controller.deleteGroup(items[i].id!);
                                  },
                                  displaySchedule: (raw) =>
                                      _displaySchedule(raw, use24h),
                                  parseSlots: _parseScheduleSlots,
                                ),
                          ),
              ),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final lic = Get.find<LicenseController>();
          final err = lic.checkCanCreateGroup(controller.groups.length);
          if (err != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err, style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'ترقية',
                textColor: Colors.white,
                onPressed: () => Get.toNamed(ROUTE_PLANS),
              ),
            ));
            return;
          }
          _showGroupFormDialog(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('مجموعة جديدة'),
      ),
    );
  }

  void _showGroupFormDialog(BuildContext context, {Group? group}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: _GroupFormSheet(
          group: group,
          existingGroups: controller.groups,
          onSave: (newGroup) => group == null
              ? controller.addGroup(newGroup)
              : controller.updateGroup(newGroup),
          onSaved: (name) {
            ToastHelper.success('تم حفظ "$name"', title: 'تم');
            // إعادة مزامنة إشعارات مواعيد الحصص عشان تعكس الجدول
            // الجديد/المعدَّل فورًا من غير ما المدرس يعمل أي حاجة.
            NotificationService().syncAllScheduledNotifications();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group form bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GroupFormSheet extends StatefulWidget {
  final Group? group;
  final List<Group> existingGroups;
  final Future<bool> Function(Group) onSave;
  final void Function(String groupName) onSaved;

  const _GroupFormSheet({
    required this.group,
    required this.existingGroups,
    required this.onSave,
    required this.onSaved,
  });

  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
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
                     : _hasScheduleOverlap(_scheduleCtrl.text)
                                           ? 'فيه موعدين متداخلين في نفس اليوم'
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
        widget.onSaved(name);
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
      builder: (_) => _PickerSheet(
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
      builder: (_) => _PickerSheet(
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  // اسم المجموعة
                  _FormLabel('اسم المجموعة *'),
                  const SizedBox(height: 6),
                  CustomTextField(
                    controller: _nameCtrl,
                    label: 'مثال: الرابعة الابتدائي أ',
                  ),
                  if (_nameError != null) _ErrorText(_nameError!),
                  const SizedBox(height: 16),

                  // نوع التسعير — شهري أو بالحصة
                  _FormLabel('نوع التسعير'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: _PricingTypeChip(
                        label: 'شهري',
                        selected: _pricingType == GroupPricingType.monthly,
                        onTap: () => setState(
                            () => _pricingType = GroupPricingType.monthly),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PricingTypeChip(
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
                            _FormLabel('بادئة الكود *'),
                            const SizedBox(height: 6),
                            CustomTextField(
                              controller: _codeCtrl,
                              label: 'مثال: G4A',
                            ),
                            if (_codeError != null) _ErrorText(_codeError!),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FormLabel(_pricingType == GroupPricingType.perSession
                                ? 'سعر الحصة الواحدة *'
                                : 'سعر الاشتراك الشهري *'),
                            const SizedBox(height: 6),
                            CustomTextField(
                              controller: _priceCtrl,
                              label: '0',
                              keyboardType: TextInputType.number,
                            ),
                            if (_priceError != null) _ErrorText(_priceError!),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // مظهر المجموعة — لون وأيقونة (معاينة مدمجة، تفتح
                  // منتقي منبثق بدل ما ياخدوا مساحة تابتة في الفورم)
                  _FormLabel('مظهر المجموعة'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _AppearancePreviewTile(
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
                      _AppearancePreviewTile(
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
                  _ScheduleEditor(
                    controller: _scheduleCtrl,
                    onChanged: () {
                      if (_scheduleError != null) setState(() => _scheduleError = null);
                    },
                  ),
                  if (_scheduleError != null) _ErrorText(_scheduleError!),
                ],
              ),
            ),

            // ── زر الحفظ ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  isEdit ? 'حفظ التعديلات' : 'إضافة المجموعة',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    );
  }
}

class _PricingTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PricingTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? primary : null,
          ),
        ),
      ),
    );
  }
}

/// معاينة مدمجة (لون/أيقونة) بتفتح منتقي منبثق بدل ما تاخد مساحة تابتة
/// في الفورم — الهدف تقصير طول شيت إضافة/تعديل المجموعة.
class _AppearancePreviewTile extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  const _AppearancePreviewTile({
    required this.label,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.grey.shade700)),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more_rounded,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// حاوية موحّدة لمنتقيات اللون/الأيقونة المنبثقة.
class _PickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _PickerSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 13, color: Colors.red),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group card widget
// ─────────────────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Group group;
  final int studentCount;
  final List<Student> students;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) displaySchedule;
  final List<Map<String, String>> Function(String) parseSlots;

  const _GroupCard({
    required this.group,
    required this.studentCount,
    required this.students,
    required this.onEdit,
    required this.onDelete,
    required this.displaySchedule,
    required this.parseSlots,
  });

  IconData get _icon {
    switch (group.icon) {
      case 'class': return Icons.class_;
      case 'book': return Icons.menu_book;
      case 'math': return Icons.calculate;
      case 'science': return Icons.science;
      case 'language': return Icons.language;
      case 'code': return Icons.code;
      case 'star': return Icons.star;
      default: return Icons.groups_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = group.color != null ? Color(group.color!) : Colors.indigo;
    final slots = group.schedule != null && group.schedule!.isNotEmpty
        ? parseSlots(group.schedule!)
        : <Map<String, String>>[];

    return GestureDetector(
      onTap: () => Get.toNamed(ROUTE_GROUP_DETAILS, arguments: group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31).withValues(alpha: 0.94) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : color.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.1 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  // أيقونة المجموعة
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),

                  // اسم + كود
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        if (group.code != null && group.code!.isNotEmpty)
                          Text(
                            'الكود: ${group.code}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ),

                  // عدد الطلاب badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '$studentCount',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color),
                        ),
                      ],
                    ),
                  ),

                  // قائمة الخيارات
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') {
                        Get.defaultDialog(
                          title: 'حذف المجموعة',
                          middleText: studentCount > 0
                              ? 'هل تريد حذف مجموعة "${group.name}"؟\n'
                                  'تحذير: هيتحذف معاها $studentCount طالب '
                                  'وكل سجلات حضورهم ودفعاتهم ودرجات امتحاناتهم '
                                  'نهائياً — الإجراء ده لا يمكن التراجع عنه.'
                              : 'هل تريد حذف مجموعة "${group.name}"؟ '
                                  'لا يمكن التراجع عن هذا الإجراء.',
                          textCancel: 'إلغاء',
                          textConfirm: 'حذف',
                          confirmTextColor: Colors.white,
                          buttonColor: Colors.red,
                          onConfirm: () async {
                            Get.back(); // أغلق الـ dialog
                            await Future.delayed(
                                const Duration(milliseconds: 80));
                            onDelete();
                          },
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                    child: const Icon(Icons.more_vert_rounded, size: 20),
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : color.withValues(alpha: 0.1),
            ),

            // ── Footer: سعر + مواعيد ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // المواعيد
                  Expanded(
                    child: slots.isEmpty
                        ? Text('لا توجد مواعيد',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: slots.map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${s['day']} ${s['time']}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  // السعر
                  if (group.price != null && group.price! > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Obx(() {
                        final currency =
                            Get.find<SettingsController>().currencyCode.value;
                        return Text(
                          '${FormatHelper.formatCurrency(group.price)} $currency',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.green),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary pill
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule editor
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleEditor extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  const _ScheduleEditor({required this.controller, this.onChanged});

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  static const List<String> _days = [
    'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'
  ];

  final List<_ScheduleEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _parseFromText();
  }

  void _parseFromText() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    for (final raw in text.split(',')) {
      final s = raw.trim();
      final day = _days.firstWhere((d) => s.startsWith(d), orElse: () => '');
      if (day.isEmpty) continue;
      final times = s.replaceFirst(day, '').trim().split('-');
      if (times.length == 2) {
        final from = _parseTime(times[0].trim());
        if (from != null) {
          _entries.add(_ScheduleEntry(day: day, from: from, to: _addHour(from)));
        }
      }
    }
    _syncToText();
  }

  TimeOfDay? _parseTime(String v) {
    final p = v.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _syncToText() {
    widget.controller.text = _entries
        .map((e) => '${e.day} ${_fmt(e.from)}-${_fmt(e.to)}')
        .join(', ');
    widget.onChanged?.call();
    setState(() {});
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmt(TimeOfDay t) => '${_pad(t.hour)}:${_pad(t.minute)}';
  String _fmtDisplay(TimeOfDay t) {
    try {
      if (!Get.find<SettingsController>().use24hFormat.value) {
        return DateFormat('hh:mm a', 'ar').format(DateTime(2000, 1, 1, t.hour, t.minute));
      }
    } catch (_) {}
    return _fmt(t);
  }

  TimeOfDay _addHour(TimeOfDay t) => TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);
  TimeOfDay _subHour(TimeOfDay t) => TimeOfDay(hour: (t.hour + 23) % 24, minute: t.minute);

  Future<void> _pickTime(int index, bool isFrom) async {
    final cur = isFrom ? _entries[index].from : _entries[index].to;
    final picked = await showTimePicker(context: context, initialTime: cur);
    if (picked != null) {
      if (isFrom) {
        _entries[index] = _entries[index].copyWith(from: picked, to: _addHour(picked));
      } else {
        _entries[index] = _entries[index].copyWith(from: _subHour(picked), to: picked);
      }
      _syncToText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المواعيد الأسبوعية (حد أدنى موعد واحد)',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        ...List.generate(_entries.length, (i) {
          final e = _entries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: e.day,
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      _entries[i] = e.copyWith(day: val);
                      _syncToText();
                    },
                    decoration: const InputDecoration(labelText: 'اليوم'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(i, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'من'),
                      child: Text(_fmtDisplay(e.from)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(i, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'إلى'),
                      child: Text(_fmtDisplay(e.to)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    _entries.removeAt(i);
                    _syncToText();
                  },
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _entries.add(_ScheduleEntry(
                day: _days[_entries.isEmpty ? 0 : (_entries.length % _days.length)],
                from: const TimeOfDay(hour: 18, minute: 0),
                to: const TimeOfDay(hour: 19, minute: 0),
              ));
              _syncToText();
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة موعد'),
          ),
        ),
      ],
    );
  }
}

class _ScheduleEntry {
  final String day;
  final TimeOfDay from;
  final TimeOfDay to;
  const _ScheduleEntry({required this.day, required this.from, required this.to});
  _ScheduleEntry copyWith({String? day, TimeOfDay? from, TimeOfDay? to}) =>
      _ScheduleEntry(day: day ?? this.day, from: from ?? this.from, to: to ?? this.to);
}
