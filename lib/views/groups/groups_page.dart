// lib/views/groups/groups_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/tour/tour.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/chalk_dialog.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/utils/group_price_helper.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/views/groups/group_form/group_form_sheet.dart';
import 'package:active_class/views/groups/group_widgets.dart';
import 'package:active_class/views/help/help_widgets.dart';

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

  // عدد الطلاب المؤرشفين في المجموعة — بيُستخدم بس في تحذير حذف المجموعة
  // (مش في شارة العدد العادية)، لأن حذف المجموعة بيمسحهم نهائيًا هما
  // كمان بسبب قيد المفتاح الأجنبي، رغم إنهم كانوا "محفوظين للأبد" عمدًا.
  int _archivedStudentCount(int? groupId) {
    if (groupId == null) return 0;
    return studentController.archivedStudents
        .where((s) => s.groupId == groupId)
        .length;
  }

  List<Student> _groupStudents(int? groupId) {
    if (groupId == null) return [];
    return studentController.students
        .where((s) => s.groupId == groupId)
        .toList();
  }

  List<Map<String, String>> _parseScheduleSlots(String raw) {
    final parts = raw.split(',');
    return parts
        .map((s) {
          final txt = s.trim();
          if (txt.isEmpty) return <String, String>{};
          final sp = txt.split(' ');
          if (sp.length < 2) return <String, String>{'day': txt, 'time': ''};
          final day = sp.first;
          final time = txt.substring(day.length).trim();
          return <String, String>{'day': day, 'time': time};
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  void _onAdd(BuildContext context, {String? center}) {
    final lic = Get.find<LicenseController>();
    final err = lic.checkCanCreateGroup(controller.groups.length);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        persist:
            false, // Flutter ≥3.29: SnackBar فيه action مابيختفيش لوحده من غير ده
        action: SnackBarAction(
          label: 'ترقية',
          textColor: Colors.white,
          onPressed: () => Get.toNamed(ROUTE_PLANS),
        ),
      ));
      return;
    }
    _showGroupFormDialog(context, initialCenter: center);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // ألوان الأرقام فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'المجموعات', actions: const [
        HelpButton(topicId: 'groups'),
      ]),
      floatingActionButton: TourTarget(id: 'groups.add', child: FloatingActionButton.extended(
        onPressed: () => _onAdd(context),
        backgroundColor: t.chalk,
        foregroundColor: t.onChalk,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مجموعة جديدة'),
      )),
      body: ColoredBox(
        color: t.page,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _searchController.text.trim();
          // فلتر السنتر: لو السنتر المختار اتشال من كل المجموعات نرجع لـ«الكل».
          final centers = controller.centers;
          var centerFilter = controller.selectedCenter.value;
          if (centerFilter != null &&
              centerFilter != GroupController.kNoCenterFilter &&
              !centers.contains(centerFilter)) {
            centerFilter = null;
          }
          final scoped = controller.groups
              .where((g) => GroupController.matchesCenter(g, centerFilter))
              .toList();
          final List<Group> items = scoped.where((g) {
            if (query.isEmpty) return true;
            final byGroup =
                g.name.contains(query) || (g.code?.contains(query) ?? false);
            final byStudent = studentController.students
                .any((s) => s.groupId == g.id && s.name.contains(query));
            return byGroup || byStudent;
          }).toList();

          final scopedIds = {for (final g in scoped) g.id};
          final totalStudents = studentController.students
              .where((st) => scopedIds.contains(st.groupId))
              .length;
          final emptyGroups =
              scoped.where((g) => _studentCount(g.id) == 0).length;

          return Column(
            children: [
              // ── السبورة: أرقام سريعة ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
                decoration: BoxDecoration(
                  color: t.board,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.board)),
                ),
                child: Row(children: [
                  Expanded(
                      child: BoardStat(
                          label: 'مجموعة',
                          value: '${scoped.length}',
                          color: t.boardInk)),
                  Expanded(
                      child: BoardStat(
                          label: 'طالب',
                          value: '$totalStudents',
                          color: on.positive)),
                  Expanded(
                      child: BoardStat(
                          label: 'بدون طلاب',
                          value: '$emptyGroups',
                          color: emptyGroups > 0 ? t.chalk : t.boardInkSoft)),
                ]),
              ),

              // ── البحث ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
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

              // ── السناتر: عنوان + زر «سنتر جديد»، وتحتهم الشريط ──────
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.lg, AppSpace.xs, AppSpace.sm, 0),
                child: Row(children: [
                  Icon(Icons.apartment_rounded, size: 18, color: t.inkSoft),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text('السناتر',
                        style: AppType.label.copyWith(color: t.ink)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showNewCenterDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('سنتر جديد'),
                  ),
                ]),
              ),
              if (centers.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    children: [
                      for (final entry in <MapEntry<String?, String>>[
                        const MapEntry(null, 'الكل'),
                        for (final c in centers) MapEntry(c, c),
                        if (controller.groups.any((g) =>
                            GroupController.normalizeCenter(g.center) == null))
                          const MapEntry(
                              GroupController.kNoCenterFilter, 'بدون سنتر'),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: _CenterChip(
                            label: entry.value,
                            selected: centerFilter == entry.key,
                            onTap: () =>
                                controller.selectedCenter.value = entry.key,
                          ),
                        ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.xs),
                  child: Text(
                      'بتشتغل في أكتر من سنتر؟ اعمل سنتر وحط مجموعاتك تحته.',
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ),

              // ── القائمة ─────────────────────────────────────────
              Expanded(
                child: controller.groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: AppPanel(
                          child: EmptyState(
                            icon: Icons.group_off,
                            title: 'لا توجد مجموعات',
                            subtitle: 'ابدأ بإضافة مجموعة جديدة',
                            actionLabel: 'إضافة مجموعة',
                            onActionPressed: () => _onAdd(context),
                          ),
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Text('لا نتائج لـ "$query"',
                                style: AppType.body
                                    .copyWith(color: t.inkSoft)),
                          )
                        : _buildSectionedList(
                            context, items, centers.isNotEmpty),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── القايمة مقسّمة لأقسام: كل سنتر وتحته مجموعاته ──────────────────
  Widget _buildSectionedList(
      BuildContext context, List<Group> items, bool hasCenters) {
    final sections = GroupController.sectionsOf(items);
    final entries = <Object>[];
    for (final sec in sections) {
      if (hasCenters) entries.add(sec);
      entries.addAll(sec.groups);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, 100),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        if (e is CenterSection) return _buildCenterHeader(context, e);
        final g = e as Group;
        return GroupCard(
          key: ValueKey('group-${g.id}'),
          group: g,
          studentCount: _studentCount(g.id),
          archivedCount: _archivedStudentCount(g.id),
          students: _groupStudents(g.id),
          onEdit: () => _showGroupFormDialog(context, group: g),
          onDelete: () {
            if (!requireDeletePermission(
                context, TeamModeService().canDeleteStudentsNow)) {
              return;
            }
            if (g.id != null) controller.deleteGroup(g.id!);
          },
          parseSlots: _parseScheduleSlots,
          showCenter: !hasCenters,
        );
      },
    );
  }

  Widget _buildCenterHeader(BuildContext context, CenterSection sec) {
    final t = context.tokens;
    final name = sec.center;
    final students =
        sec.groups.fold<int>(0, (n, g) => n + _studentCount(g.id));
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.xs),
      child: Row(children: [
        Icon(name == null ? Icons.folder_off_outlined : Icons.apartment_rounded,
            size: 20, color: t.brand),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(name ?? 'بدون سنتر',
              style: AppType.title.copyWith(color: t.ink)),
        ),
        Text('${sec.groups.length} مجموعة · $students طالب',
            style: AppType.caption.copyWith(color: t.inkSoft)),
        if (name != null) ...[
          IconButton(
            tooltip: 'مجموعة جديدة في $name',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _onAdd(context, center: name),
          ),
          PopupMenuButton<String>(
            tooltip: 'خيارات السنتر',
            onSelected: (v) {
              if (v == 'rename') _showRenameCenterDialog(context, name);
              if (v == 'dissolve') _confirmDissolveCenter(context, name);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('تعديل اسم السنتر')),
              PopupMenuItem(value: 'dissolve', child: Text('فك السنتر')),
            ],
          ),
        ],
      ]),
    );
  }

  /// «سنتر جديد»: اسم + (اختياري) مجموعات موجودة تتنقل تحته. لو ما اخترتش
  /// ولا مجموعة بيفتحلك فورم مجموعة جديدة جوّه السنتر ده.
  Future<void> _showNewCenterDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final picked = <int>{};
    String? error;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return ChalkDialog(
          icon: Icons.add_business_rounded,
          title: 'سنتر جديد',
          subtitle:
              'اكتب اسم السنتر، واختار مجموعات تنقلها تحته، أو سيبها فاضية وهتضيف مجموعة جديدة.',
          body: [
            CustomTextField(
              dense: true,
              controller: nameCtrl,
              label: 'اسم السنتر',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(error!,
                    style:
                        AppType.caption.copyWith(color: ctx.tokens.danger)),
              ),
            if (controller.groups.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              Text('انقل مجموعات تحت السنتر (اختياري)',
                  style: AppType.label.copyWith(color: ctx.tokens.ink)),
              for (final g in controller.groups)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: picked.contains(g.id),
                  title: Text(g.name),
                  subtitle: (g.center ?? '').trim().isEmpty
                      ? null
                      : Text('حاليًا: ${g.center!.trim()}'),
                  onChanged: (v) => setSt(() {
                    final id = g.id;
                    if (id == null) return;
                    if (v == true) {
                      picked.add(id);
                    } else {
                      picked.remove(id);
                    }
                  }),
                ),
            ],
          ],
          actions: [
            ChalkAction(
              label: 'حفظ',
              icon: Icons.check_rounded,
              onPressed: () {
                if (GroupController.normalizeCenter(nameCtrl.text) == null) {
                  setSt(() => error = 'اكتب اسم السنتر');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
            ),
            ChalkAction(
              label: 'إلغاء',
              kind: ChalkActionKind.text,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        );
      }),
    );
    final name = GroupController.normalizeCenter(nameCtrl.text);
    nameCtrl.dispose();
    if (go != true || name == null || !context.mounted) return;
    if (picked.isNotEmpty) {
      await controller.setCenterForGroups(picked, name);
      controller.selectedCenter.value = name;
      ToastHelper.success('تم إنشاء السنتر "$name"', title: 'تم');
    } else {
      _onAdd(context, center: name);
    }
  }

  Future<void> _showRenameCenterDialog(
      BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ChalkDialog(
        icon: Icons.edit_rounded,
        title: 'تعديل اسم السنتر',
        body: [
          CustomTextField(dense: true, controller: ctrl, label: 'اسم السنتر'),
        ],
        actions: [
          ChalkAction(
            label: 'حفظ',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          ChalkAction(
            label: 'إلغاء',
            kind: ChalkActionKind.text,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    final name = GroupController.normalizeCenter(ctrl.text);
    ctrl.dispose();
    if (ok != true || name == null || name == current) return;
    await controller.renameCenter(current, name);
    if (controller.selectedCenter.value == current) {
      controller.selectedCenter.value = name;
    }
  }

  Future<void> _confirmDissolveCenter(
      BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ChalkDialog(
        icon: Icons.folder_off_outlined,
        tone: ChalkTone.caution,
        title: 'فك السنتر "$name"؟',
        subtitle:
            'المجموعات والطلاب مش هيتمسحوا. المجموعات هترجع «بدون سنتر».',
        actions: [
          ChalkAction(
            label: 'فك السنتر',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          ChalkAction(
            label: 'إلغاء',
            kind: ChalkActionKind.text,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.dissolveCenter(name);
    if (controller.selectedCenter.value == name) {
      controller.selectedCenter.value = null;
    }
  }

  Future<void> _showGroupFormDialog(BuildContext context,
      {Group? group, String? initialCenter}) async {
    double? savedNewPrice;
    await showDialog(
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
            // maxHeight بدل height ثابت — الشيت بقى بيتقاس على حجم
            // محتواه الفعلي (بيصغر لو الفورم قصير)، وبيوصل للحد الأقصى
            // ده بس لو المحتوى فعلاً محتاج المساحة دي (يبقى قابل للتمرير).
            constraints: BoxConstraints(
              minWidth: size.width * 0.92,
              maxWidth: size.width * 0.92,
              maxHeight: size.height * 0.85,
            ),
            child: GroupFormSheet(
              group: group,
              initialCenter: initialCenter,
              existingGroups: controller.groups,
              onSave: (newGroup) => group == null
                  ? controller.addGroup(newGroup)
                  : controller.updateGroup(newGroup),
              onSaved: (name, newPrice) {
                ToastHelper.success('تم حفظ "$name"', title: 'تم');
                // إعادة مزامنة إشعارات مواعيد الحصص عشان تعكس الجدول
                // الجديد/المعدَّل فورًا من غير ما المدرس يعمل أي حاجة.
                NotificationService().syncAllScheduledNotifications();
                savedNewPrice = newPrice;
              },
            ),
          ),
        );
      },
    );
    if (!context.mounted) return;
    final oldPrice = group?.price;
    final groupId = group?.id;
    if (savedNewPrice != null &&
        oldPrice != null &&
        groupId != null &&
        savedNewPrice != oldPrice) {
      await offerBulkStudentPriceUpdate(
          context, Get.find<StudentController>(), groupId, savedNewPrice!);
    }
  }
}

/// زر اختيار سنتر في الشريط: مساحة لمس مريحة وحالة «مختار» واضحة من غير الاعتماد
/// على اللون بس (الخط أتقل).
class _CenterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CenterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Align(
        child: Material(
          color: selected ? t.board : t.surface,
          shape: StadiumBorder(
              side: BorderSide(color: selected ? t.board : t.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: 10),
              child: Text(label,
                  style: AppType.label.copyWith(
                      color: selected ? t.boardInk : t.ink,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}
