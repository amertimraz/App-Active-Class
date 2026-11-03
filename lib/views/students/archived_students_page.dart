// lib/views/students/archived_students_page.dart
//
// شاشة "الأرشيف" — تعرض الطلاب المؤرشفين بس (بديل الحذف النهائي). من هنا
// المدرس يقدر يستعرض بيانات/سجل طالب مؤرشف، يستعيده (إلغاء أرشفة)، أو
// يحذفه نهائيًا (حذف حقيقي لا يمكن التراجع عنه).

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/utils/student_sort_helper.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/student_sort_bar.dart';

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
  final AttendanceController _attCtrl = Get.isRegistered<AttendanceController>()
      ? Get.find<AttendanceController>()
      : Get.put(AttendanceController());
  final PaymentController _payCtrl = Get.isRegistered<PaymentController>()
      ? Get.find<PaymentController>()
      : Get.put(PaymentController());
  List<Group> _groups = [];

  // ترتيب — نفس أيقونات StudentSortBar المستخدمة في شاشة الطلاب/تفاصيل
  // المجموعة، عشان تبقى موجودة في أي قايمة فيها طلاب.
  StudentSort _sortBy = StudentSort.name;
  bool _sortAscending = true;

  void _onSortTap(StudentSort sort) {
    setState(() {
      if (_sortBy == sort) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sort;
        _sortAscending = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    controller.loadArchivedStudents();
    _loadGroups();
    if (_attCtrl.attendance.isEmpty) _attCtrl.loadAttendance();
    if (_payCtrl.payments.isEmpty) _payCtrl.loadPayments();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await DatabaseService().getAllGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {}
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'الأرشيف'),
      body: ColoredBox(
        color: t.page,
        child: RefreshIndicator(
          onRefresh: controller.loadArchivedStudents,
          child: Obx(() {
            final students = sortStudents(
              students: controller.archivedStudents,
              sortBy: _sortBy,
              ascending: _sortAscending,
              groupOf: _groupOf,
              allAttendance: _attCtrl.attendance,
              allPayments: _payCtrl.payments,
            );
            if (students.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.xl),
                children: [
                  const SizedBox(height: AppSpace.xl),
                  AppPanel(
                    child: EmptyState(
                      icon: Icons.archive_outlined,
                      title: 'لا يوجد طلاب مؤرشفين',
                      subtitle:
                          'الطلاب اللي بتأرشفهم من شاشة الطلاب هيظهروا هنا',
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                // السبورة: عدد المؤرشفين + شرح قصير
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
                    BoardStat(
                        label: 'طالب مؤرشف',
                        value: '${students.length}',
                        color: t.chalk),
                    const SizedBox(width: AppSpace.lg),
                    Expanded(
                      child: Text(
                        'سجلاتهم محفوظة. تقدر تستعيد أي طالب أو تحذفه نهائيًا.',
                        style: AppType.body.copyWith(color: t.boardInkSoft),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('ترتيب القايمة',
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      ),
                      StudentSortBar(
                        sortBy: _sortBy,
                        ascending: _sortAscending,
                        onChanged: _onSortTap,
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
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.xs, AppSpace.lg, 100),
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
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.tokens.brand,
                minimumSize: const Size(44, 44)),
            onPressed: () async {
              final name = student.name;
              Navigator.of(ctx).pop();
              final ok = await controller.unarchiveStudent(student.id!);
              if (!context.mounted) return;
              if (ok) {
                AppToast.success(context, 'تم استعادة الطالب', subtitle: name);
              }
            },
            child: const Text('استعادة'),
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
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.tokens.danger,
                minimumSize: const Size(44, 44)),
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
            child: const Text('حذف نهائي'),
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
    final t = context.tokens;
    final initials = student.name.trim().isNotEmpty ? student.name.trim()[0] : '؟';
    final archivedAtText = student.archivedAt != null
        ? DateFormat('yyyy/MM/dd').format(student.archivedAt!)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.md),
        child: Row(
          children: [
            // أفاتار رمادي: الطالب غير نشط
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.line, shape: BoxShape.circle),
              child: Center(
                child: Text(initials,
                    style: AppType.title.copyWith(color: t.inkSoft)),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(color: t.ink)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (group != null)
                        Text(group!.name,
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(student.code,
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      ),
                    ],
                  ),
                  if (archivedAtText != null) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.archive_rounded, size: 13, color: t.inkFaint),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('أُرشف في $archivedAtText',
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'خيارات الطالب المؤرشف',
              onSelected: (v) {
                if (v == 'unarchive') onUnarchive();
                if (v == 'delete') onDeletePermanently();
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control)),
              icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'unarchive',
                  child: Row(children: [
                    Icon(Icons.unarchive_rounded, size: 18, color: t.brand),
                    const SizedBox(width: 10),
                    Text('استعادة', style: TextStyle(color: t.brand)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_forever_rounded,
                        size: 18, color: t.danger),
                    const SizedBox(width: 10),
                    Text('حذف نهائي', style: TextStyle(color: t.danger)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
