// lib/views/students/archived_students_page.dart
//
// شاشة "الأرشيف" — تعرض الطلاب المؤرشفين بس (بديل الحذف النهائي). من هنا
// المدرس يقدر يستعرض بيانات/سجل طالب مؤرشف، يستعيده (إلغاء أرشفة)، أو
// يحذفه نهائيًا (حذف حقيقي لا يمكن التراجع عنه).

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_toast.dart';

class ArchivedStudentsPage extends StatefulWidget {
  const ArchivedStudentsPage({super.key});

  @override
  State<ArchivedStudentsPage> createState() => _ArchivedStudentsPageState();
}

class _ArchivedStudentsPageState extends State<ArchivedStudentsPage> {
  // isRegistered بدل find مباشر — أكتر أمانًا لو الشاشة دي اتوصلها يوم
  // من مسار جديد معملش Get.put(StudentController()) قبلها.
  final StudentController controller = Get.isRegistered<StudentController>()
      ? Get.find<StudentController>()
      : Get.put(StudentController());
  List<Group> _groups = [];

  @override
  void initState() {
    super.initState();
    controller.loadArchivedStudents();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService().getAllGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Group? _groupOf(Student s) {
    try {
      return _groups.firstWhere((g) => g.id == s.groupId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(title: 'الأرشيف'),
      body: buildSoftBackground(
        context: context,
        child: RefreshIndicator(
          onRefresh: controller.loadArchivedStudents,
          child: Obx(() {
            final students = controller.archivedStudents;
            if (students.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.archive_outlined,
                    title: 'لا يوجد طلاب مؤرشفين',
                    subtitle:
                        'الطلاب اللي بتأرشفهم من شاشة الطلاب هيظهروا هنا',
                  ),
                ],
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        '${students.length} طالب مؤرشف',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    // لازم AlwaysScrollableScrollPhysics عشان RefreshIndicator
                    // يشتغل حتى لو عدد الطلاب المؤرشفين قليل ومش بيملى الشاشة
                    // (الحالة الشائعة أصلاً).
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: students.length,
                    itemBuilder: (_, i) => _ArchivedStudentCard(
                      student: students[i],
                      group: _groupOf(students[i]),
                      onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS,
                          arguments: students[i]),
                      onUnarchive: () =>
                          _confirmUnarchive(context, students[i]),
                      onDeletePermanently: () =>
                          _confirmDeletePermanently(context, students[i]),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── استعادة (إلغاء أرشفة) ──────────────────────────────────────────
  void _confirmUnarchive(BuildContext context, Student student) {
    if (student.id == null) return;
    // نفس صلاحية "حذف الطلاب" بتحكم الاستعادة كمان — عشان الثلاثة
    // إجراءات (أرشفة/استعادة/حذف نهائي) يبقوا محكومين بنفس القاعدة
    // اللي المدرس بيضبطها لكل مساعد في وضع الفريق.
    if (!requireDeletePermission(
        context, TeamModeService().canDeleteStudentsNow)) {
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('استعادة الطالب'),
        content: Text(
          'هل تريد استعادة "${student.name}"؟\n'
          'هيرجع يظهر تاني في كل الشاشات النشطة (القوائم، الحضور، الدفع).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final name = student.name;
              Navigator.of(ctx).pop();
              final ok = await controller.unarchiveStudent(student.id!);
              if (!context.mounted) return;
              if (ok) {
                AppToast.success(context, 'تم استعادة الطالب', subtitle: name);
              }
            },
            child: const Text('استعادة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── حذف نهائي ────────────────────────────────────────────────────
  void _confirmDeletePermanently(BuildContext context, Student student) {
    if (student.id == null) return;
    if (!requireDeletePermission(
        context, TeamModeService().canDeleteStudentsNow)) {
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف نهائي'),
        content: Text(
          'هل تريد حذف "${student.name}" نهائياً؟\n'
          'تحذير: هيتحذف معاه كل سجلات حضوره ومدفوعاته ودرجات امتحاناته '
          '— الإجراء ده لا يمكن التراجع عنه إطلاقاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final name = student.name;
              Navigator.of(ctx).pop();
              await Future.delayed(const Duration(milliseconds: 80));
              final ok = await controller.deleteStudent(student.id!);
              if (!context.mounted) return;
              if (ok) {
                AppToast.success(context, 'تم حذف الطالب نهائيًا', subtitle: name);
              }
            },
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _ArchivedStudentCard
// ══════════════════════════════════════════════════════════════════
class _ArchivedStudentCard extends StatelessWidget {
  const _ArchivedStudentCard({
    required this.student,
    required this.group,
    required this.onTap,
    required this.onUnarchive,
    required this.onDeletePermanently,
  });

  final Student student;
  final Group? group;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;
  final VoidCallback onDeletePermanently;

  @override
  Widget build(BuildContext context) {
    final initials = student.name.trim().isNotEmpty ? student.name.trim()[0] : '؟';
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final archivedAtText = student.archivedAt != null
        ? DateFormat('yyyy/MM/dd').format(student.archivedAt!)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(
                        color: subtitleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (group != null) ...[
                        Text(group!.name,
                            style: TextStyle(color: subtitleColor, fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: subtitleColor, fontSize: 12)),
                        const SizedBox(width: 6),
                      ],
                      Text(student.code,
                          style: TextStyle(color: subtitleColor, fontSize: 12)),
                    ],
                  ),
                  if (archivedAtText != null) ...[
                    const SizedBox(height: 4),
                    Text('أُرشف في $archivedAtText',
                        style: TextStyle(color: subtitleColor, fontSize: 11)),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'unarchive') onUnarchive();
                if (v == 'delete') onDeletePermanently();
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'unarchive',
                  child: Row(children: [
                    Icon(Icons.unarchive_rounded, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Text('استعادة', style: TextStyle(color: AppTheme.primaryColor)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red.shade400),
                    const SizedBox(width: 10),
                    Text('حذف نهائي', style: TextStyle(color: Colors.red.shade400)),
                  ]),
                ),
              ],
              child: Icon(Icons.more_vert_rounded, color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}
