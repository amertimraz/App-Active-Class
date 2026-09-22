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
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/utils/group_price_helper.dart';
import 'package:active_class/services/notification_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/views/groups/group_form/group_form_sheet.dart';
import 'package:active_class/views/groups/group_widgets.dart';

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
    return studentController.students.where((s) => s.groupId == groupId).toList();
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
                        SummaryPill(
                          icon: Icons.groups_rounded,
                          label: '${controller.groups.length} مجموعة',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        SummaryPill(
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
                                GroupCard(
                                  group: items[i],
                                  studentCount: _studentCount(items[i].id),
                                  archivedCount: _archivedStudentCount(items[i].id),
                                  students: _groupStudents(items[i].id),
                                  onEdit: () => _showGroupFormDialog(context, group: items[i]),
                                  onDelete: () {
                                    if (!requireDeletePermission(context,
                                        TeamModeService().canDeleteStudentsNow)) {
                                      return;
                                    }
                                    if (items[i].id != null) controller.deleteGroup(items[i].id!);
                                  },
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

  Future<void> _showGroupFormDialog(BuildContext context, {Group? group}) async {
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


