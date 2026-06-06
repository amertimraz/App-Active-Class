// lib/views/groups/groups_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:intl/intl.dart';
import 'package:active_class/controllers/student_controller.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final GroupController controller = Get.put(GroupController());
  final StudentController studentController = Get.put(StudentController());
  final TextEditingController _searchController = TextEditingController();
  bool _gridMode = false;

  @override
  void initState() {
    super.initState();
    controller.loadGroups();
    _searchController.addListener(() => setState(() {}));
  }

  String _displaySchedule(String raw, bool use24) {
    final parts = raw.split(',');
    String fmt(TimeOfDay t) {
      if (use24) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
    final mapped = parts.map((s) {
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
    }).join(', ');
    return mapped;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF2196F3); // اللون الرئيسي
    final secondary = const Color(0xFFFFC107); // اللون المساعد

    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'المجموعات والطلاب',
        actions: [
          IconButton(
            tooltip: _gridMode ? 'عرض قائمة' : 'عرض شبكة',
            icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGroupFormDialog(context),
        backgroundColor: primary,
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: buildScreenBackground(context),
        child: Obx(() {
          final query = _searchController.text.trim();
          final List<Group> items = controller.groups
              .where((g) {
                if (query.isEmpty) return true;
                final byGroupFields = g.name.contains(query) || (g.code?.contains(query) ?? false);
                final byStudentName = studentController.students.any((s) => s.groupId == g.id && s.name.contains(query));
                return byGroupFields || byStudentName;
              })
              .toList();

        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(PADDING_LARGE),
            child: EmptyState(
              icon: Icons.group_off,
              title: 'لا توجد مجموعات',
              subtitle: 'ابدأ بإضافة مجموعة جديدة',
              actionLabel: 'إضافة مجموعة',
              onActionPressed: () => _showGroupFormDialog(context),
            ),
          );
        }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(PADDING_NORMAL),
                child: CustomSearchBar(
                  controller: _searchController,
                  hintText: 'ابحث بالاسم أو الكود...',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              Expanded(
                child: _gridMode
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL, vertical: PADDING_NORMAL),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: SPACING_NORMAL,
                          mainAxisSpacing: SPACING_NORMAL,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final group = items[index];
                          return _buildGroupGridTile(context, group);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final group = items[index];
                          return _buildGroupCard(context, group, primary, secondary);
                        },
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group group,
    Color primary,
    Color secondary,
  ) {
    final Color avatarColor = (group.color != null)
        ? Color(group.color!)
        : ColorHelper.getRandomColor();
    final iconData = _iconFromName(group.icon) ?? Icons.group;

    return Card(
      surfaceTintColor: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: PADDING_NORMAL),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: avatarColor),
        ),
        title: Text(
          group.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<int>(
                future: group.id != null
                    ? controller.getGroupStudentCount(group.id!)
                    : Future.value(0),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  final chips = <Widget>[
                    _infoChip(
                      label: 'الطلاب',
                      value: '$count',
                      color: Colors.blue,
                    ),
                  ];
                  if (group.price != null) {
                    chips.add(_infoChip(
                      label: 'السعر',
                      value: FormatHelper.formatCurrency(group.price),
                      color: Colors.green,
                    ));
                  }
                  if (group.code != null && group.code!.isNotEmpty) {
                    chips.add(_infoChip(
                      label: 'الكود',
                      value: group.code!,
                      color: Colors.deepPurple,
                    ));
                  }
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips,
                  );
                },
              ),
              if (group.schedule != null && group.schedule!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Obx(() {
                    final use24 = Get.find<SettingsController>().use24hFormat.value;
                    final disp = _displaySchedule(group.schedule!, use24);
                    return Text(
                      'المواعيد: $disp',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showGroupFormDialog(context, group: group);
            } else if (value == 'delete') {
              if (group.id != null) controller.deleteGroup(group.id!);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('تعديل'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => Get.toNamed(ROUTE_GROUP_DETAILS, arguments: group),
      ),
    );
  }

  Widget _infoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildGroupGridTile(BuildContext context, Group group) {
    final Color avatarColor = (group.color != null)
        ? Color(group.color!)
        : ColorHelper.getRandomColor();
    final iconData = _iconFromName(group.icon) ?? Icons.group;

    return Card(
      surfaceTintColor: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
        onTap: () => Get.toNamed(ROUTE_GROUP_DETAILS, arguments: group),
        child: Padding(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                child: Icon(iconData, color: avatarColor),
              ),
              const SizedBox(height: SPACING_NORMAL),
              Text(
                group.name,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              FutureBuilder<int>(
                future: group.id != null
                    ? controller.getGroupStudentCount(group.id!)
                    : Future.value(0),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Text(
                    'عدد الطلاب: $count',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupFormDialog(BuildContext context, {Group? group}) {
    // Controllers
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final codeCtrl = TextEditingController(text: group?.code ?? '');
    final priceCtrl = TextEditingController(text: group?.price?.toString() ?? '');
    final scheduleCtrl = TextEditingController(text: group?.schedule ?? '');



    Get.dialog(
      StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(group == null ? 'إضافة مجموعة جديدة' : 'تعديل المجموعة'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم
                  CustomTextField(
                    controller: nameCtrl,
                    label: 'اسم المجموعة',
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // بادئة الكود (يدوي فقط)
                  CustomTextField(
                    controller: codeCtrl,
                    label: 'بادئة الكود',
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // السعر (إجباري)
                  CustomTextField(
                    controller: priceCtrl,
                    label: 'السعر',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // الأيقونة واللون سيتم تعيينهما تلقائيًا بدون تكرار بين المجموعات الجديدة
                  const SizedBox(height: SPACING_NORMAL),

                  // المواعيد: عنصرين أسبوعيًا مع زر إضافة/حذف
                  _ScheduleEditor(controller: scheduleCtrl),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إلغاء'),
            ),
            CustomButton(
              label: group == null ? 'إضافة' : 'حفظ',
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final priceText = priceCtrl.text.trim();
                final codeText = codeCtrl.text.trim();
                if (codeText.isEmpty || priceText.isEmpty) {
                  ToastHelper.info('يرجى إدخال بادئة الكود والسعر');
                  return;
                }
                final double? price = double.tryParse(priceText);
                if (price == null) {
                  ToastHelper.info('السعر غير صالح');
                  return;
                }
                final slotsCount = scheduleCtrl.text.split(',').where((e) => e.trim().isNotEmpty).length;
                if (slotsCount < 2) {
                  ToastHelper.info('يجب إضافة موعدين على الأقل');
                  return;
                }
                // تعيين أيقونة ولون عشوائيين بدون تكرار بسيط داخل الجلسة الحالية
                final usedIcons = controller.groups.map((g) => g.icon).whereType<String>().toSet();
                final availableIcons = _iconOptions.where((i) => !usedIcons.contains(i)).toList();
                final chosenIcon = (availableIcons.isNotEmpty)
                    ? availableIcons[DateTime.now().millisecond % availableIcons.length]
                    : _randomIconName();
                final usedColors = controller.groups.map((g) => g.color).whereType<int>().toSet();
                final candidateColors = [
                  Colors.red.toARGB32(),
                  Colors.blue.toARGB32(),
                  Colors.green.toARGB32(),
                  Colors.orange.toARGB32(),
                  Colors.purple.toARGB32(),
                  Colors.cyan.toARGB32(),
                  Colors.pink.toARGB32(),
                  Colors.amber.toARGB32(),
                ];
                final remainingColors = candidateColors.where((c) => !usedColors.contains(c)).toList();
                final chosenColor = (remainingColors.isNotEmpty)
                    ? remainingColors[DateTime.now().second % remainingColors.length]
                    : candidateColors[DateTime.now().second % candidateColors.length];

                final newGroup = Group(
                  id: group?.id,
                  name: name,
                  code: codeText, // بادئة الكود يدوي فقط
                  price: price,
                  color: chosenColor,
                  icon: chosenIcon,
                  schedule: scheduleCtrl.text.trim().isEmpty ? null : scheduleCtrl.text.trim(),
                  createdAt: group?.createdAt,
                );

                if (group == null) {
                  await controller.addGroup(newGroup);
                } else {
                  await controller.updateGroup(newGroup);
                }
                ToastHelper.success('تم انشاء وحفظ المجموعة', title: 'تم');
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers =====

  String _randomIconName() => _iconOptions[DateTime.now().millisecond % _iconOptions.length];

  IconData? _iconFromName(String? name) {
    switch (name) {
      case 'group':
        return Icons.group;
      case 'class':
        return Icons.class_;
      case 'book':
        return Icons.menu_book;
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'language':
        return Icons.language;
      case 'code':
        return Icons.code;
      case 'star':
        return Icons.star;
      default:
        return null;
    }
  }

  final List<String> _iconOptions = const [
    'group',
    'class',
    'book',
    'math',
    'science',
    'language',
    'code',
    'star',
  ];
}

// Widget to manage up to two weekly schedules and serialize into controller text.
class _ScheduleEditor extends StatefulWidget {
  final TextEditingController controller;
  const _ScheduleEditor({required this.controller});

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  static const List<String> _days = <String>[
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
    final parts = text.split(',');
    for (final raw in parts) {
      final s = raw.trim();
      final day = _days.firstWhere(
        (d) => s.startsWith(d),
        orElse: () => '',
      );
      if (day.isEmpty) continue;
      final times = s.replaceFirst(day, '').trim();
      final range = times.split('-');
      if (range.length == 2) {
        final from = _parseTime(range[0].trim());
        if (from != null) {
          final fixedTo = _addHour(from);
          _entries.add(_ScheduleEntry(day: day, from: from, to: fixedTo));
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
    final str = _entries
        .map((e) => '${e.day} ${_fmtStore(e.from)}-${_fmtStore(e.to)}')
        .join(', ');
    widget.controller.text = str;
    setState(() {});
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');
  String _fmtStore(TimeOfDay t) => '${_pad2(t.hour)}:${_pad2(t.minute)}';
  String _fmtDisplay(TimeOfDay t) {
    try {
      final settings = Get.find<SettingsController>();
      if (!settings.use24hFormat.value) {
        final dt = DateTime(2000, 1, 1, t.hour, t.minute);
        return DateFormat('hh:mm a', 'ar').format(dt);
      }
    } catch (_) {}
    return _fmtStore(t);
  }

  TimeOfDay _addHour(TimeOfDay t) {
    final h = (t.hour + 1) % 24;
    return TimeOfDay(hour: h, minute: t.minute);
  }

  TimeOfDay _subHour(TimeOfDay t) {
    final h = (t.hour + 23) % 24;
    return TimeOfDay(hour: h, minute: t.minute);
  }

  Future<void> _pickTime({required int index, required bool isFrom}) async {
    final current = isFrom ? _entries[index].from : _entries[index].to;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      if (isFrom) {
        final to = _addHour(picked);
        _entries[index] = _entries[index].copyWith(from: picked, to: to);
      } else {
        final from = _subHour(picked);
        _entries[index] = _entries[index].copyWith(from: from, to: picked);
      }
      _syncToText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المواعيد الأسبوعية (حد أدنى 2)', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        ...List.generate(_entries.length, (i) {
          final e = _entries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Day selector
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
                // From time
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(index: i, isFrom: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'من'),
                      child: Text(_fmtDisplay(e.from)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // To time
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(index: i, isFrom: false),
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
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'حذف',
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _entries.add(
                _ScheduleEntry(
                  day: _days[_entries.isEmpty ? 0 : (_entries.length % _days.length)],
                  from: const TimeOfDay(hour: 18, minute: 0),
                  to: const TimeOfDay(hour: 19, minute: 0),
                ),
              );
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
  _ScheduleEntry({required this.day, required this.from, required this.to});

  _ScheduleEntry copyWith({String? day, TimeOfDay? from, TimeOfDay? to}) =>
      _ScheduleEntry(day: day ?? this.day, from: from ?? this.from, to: to ?? this.to);
}
