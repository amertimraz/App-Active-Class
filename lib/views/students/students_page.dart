// lib/views/students/students_page.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/edit_student_sheet.dart';
import 'package:active_class/widgets/exempt_widgets.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';

// ══════════════════════════════════════════════════════════════════
//  StudentsPage
// ══════════════════════════════════════════════════════════════════
class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage>
    with WidgetsBindingObserver {
  final StudentController controller = Get.put(StudentController());
  late final TextEditingController _searchCtrl;
  List<Group> _groups = [];
  bool _gridMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchCtrl = TextEditingController(text: controller.searchQuery.value);
    _searchCtrl.addListener(() => controller.searchStudents(_searchCtrl.text));
    // امسح فلتر المجموعة المتبقي من صفحات أخرى
    controller.setGroupFilter(null);
    controller.loadAllStudents();
    _loadGroups();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند العودة من الخلفية، أعِد تحميل الطلاب
    if (state == AppLifecycleState.resumed) {
      controller.loadAllStudents();
    }
  }

  Future<void> _loadGroups() async {
    final groups = await controller.loadAllGroups();
    if (mounted) setState(() => _groups = groups);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  Group? _groupOf(Student s) =>
      _groups.where((g) => g.id == s.groupId).firstOrNull;

  Color _groupColor(Student s) {
    final g = _groupOf(s);
    if (g?.color != null) return Color(g!.color!);
    return AppTheme.primaryColor;
  }

  // ── build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        title: 'الطلاب',
        actions: [
          IconButton(
            tooltip: _gridMode ? 'عرض قائمة' : 'عرض شبكة',
            icon: Icon(_gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
          IconButton(
            tooltip: 'معرض QR',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => Get.toNamed(ROUTE_QR_GALLERY),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddStudentSheet(context, controller: controller),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('إضافة طالب'),
      ),
      body: buildSoftBackground(
        context: context,
        child: Obx(() {
          final students = controller.filteredStudents;

          // ── Empty ───────────────────────────────────────────────
          if (controller.students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: buildSoftPanel(
                  context: context,
                  child: EmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'لا يوجد طلاب',
                    subtitle: 'ابدأ بإضافة طالب جديد',
                    actionLabel: 'إضافة طالب',
                    onActionPressed: () =>
                        showAddStudentSheet(context, controller: controller),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              // ── Stats + Search + Filter ──────────────────────────
              _buildTopSection(context),

              // ── List / Grid ──────────────────────────────────────
              Expanded(
                child: students.isEmpty
                    ? Center(
                        child: Text(
                          'لا نتائج للبحث',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : _gridMode
                        ? _buildGrid(context, students)
                        : _buildList(context, students),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Top section ──────────────────────────────────────────────────
  Widget _buildTopSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          // Stats pills
          Obx(() {
            final total = controller.students.length;
            return Row(
              children: [
                _StatPill(
                  icon: Icons.person_rounded,
                  label: '$total طالب',
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  icon: Icons.groups_rounded,
                  label: '${_groups.length} مجموعة',
                  color: Colors.teal,
                ),
              ],
            );
          }),
          const SizedBox(height: 12),

          // Search bar
          CustomSearchBar(
            controller: _searchCtrl,
            hintText: 'ابحث عن طالب...',
            onChanged: (v) => controller.searchStudents(v),
            onClear: () {
              _searchCtrl.clear();
              controller.searchStudents('');
            },
          ),

          // Group filter chips
          if (_groups.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: Obx(() {
                final sel = controller.selectedGroupId.value;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: sel == null,
                      color: AppTheme.primaryColor,
                      onTap: () => controller.setGroupFilter(null),
                    ),
                    const SizedBox(width: 6),
                    ..._groups.map((g) {
                      final color =
                          g.color != null ? Color(g.color!) : AppTheme.primaryColor;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _FilterChip(
                          label: g.name,
                          selected: sel == g.id,
                          color: color,
                          onTap: () => controller.setGroupFilter(g.id),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── List ─────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context, List<Student> students) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: students.length,
      itemBuilder: (_, i) => _StudentCard(
        student: students[i],
        group: _groupOf(students[i]),
        groupColor: _groupColor(students[i]),
        onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: students[i]),
        onQr: () => _showQRDialog(context, students[i]),
        onEdit: () => _showEditSheet(context, students[i]),
        onDelete: () => _confirmDelete(context, students[i]),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────
  Widget _buildGrid(BuildContext context, List<Student> students) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: students.length,
      itemBuilder: (_, i) => _StudentGridTile(
        student: students[i],
        group: _groupOf(students[i]),
        groupColor: _groupColor(students[i]),
        onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: students[i]),
        onQr: () => _showQRDialog(context, students[i]),
        onEdit: () => _showEditSheet(context, students[i]),
        onDelete: () => _confirmDelete(context, students[i]),
      ),
    );
  }

  // ── QR Dialog ────────────────────────────────────────────────────
  void _showQRDialog(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Group?>(
        future: DatabaseService().getGroup(student.groupId),
        builder: (context, snapshot) {
          final group = snapshot.data;
          final borderColor =
              group?.color != null ? Color(group!.color!) : AppTheme.primaryColor;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (group != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.name,
                        style: TextStyle(
                            color: borderColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ]),
                ),
                // QR
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: student.code.trim().isEmpty
                      ? const Text('لا يوجد كود',
                          style: TextStyle(color: Colors.red))
                      : Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: borderColor, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: student.code,
                            version: QrVersions.auto,
                            size: 180,
                            backgroundColor: Colors.white,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'الكود: ${student.code}',
                      style: TextStyle(
                          color: borderColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق'),
              ),
              ElevatedButton.icon(
                onPressed: student.code.trim().isEmpty
                    ? null
                    : () async {
                        final ok = await _saveStudentQrImage(student);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'تم حفظ صورة QR بنجاح' : 'تعذر حفظ الصورة'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: ok ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 2),
                        ));
                      },
                icon: const Icon(Icons.download_rounded),
                label: const Text('حفظ الصورة'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Edit Sheet ───────────────────────────────────────────────────
  void _showEditSheet(BuildContext context, Student student) {
    showEditStudentSheet(
      context,
      student: student,
      accentColor: _groupColor(student),
      controller: controller,
      groups: _groups,
    );
  }

  // ── Delete ───────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, Student student) {
    if (student.id == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الطالب'),
        content: Text(
          'هل تريد حذف "${student.name}" نهائياً؟\n'
          'تحذير: هيتحذف معاه كل سجلات حضوره ومدفوعاته ودرجات '
          'امتحاناته — الإجراء ده لا يمكن التراجع عنه.',
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
                AppToast.success(context, 'تم حذف الطالب', subtitle: name);
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Save QR ──────────────────────────────────────────────────────
  Future<bool> _saveStudentQrImage(Student student) async {
    try {
      final group = await DatabaseService().getGroup(student.groupId);
      final groupName = group?.name;
      const int qrSize = 700;
      const double padding = 40;
      const double spacing = 24;
      final painter = QrPainter(
        data: student.code,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
      );
      final ui.Image qrImage = await painter.toImage(qrSize.toDouble());
      final textStyleTitle = const TextStyle(
          color: Colors.black, fontSize: 48, fontWeight: FontWeight.w600, fontFamily: 'Cairo');
      final textStyleSub =
          const TextStyle(color: Colors.black, fontSize: 36, fontFamily: 'Cairo');
      final tpName = TextPainter(
        text: TextSpan(text: student.name, style: textStyleTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());
      final groupLine =
          (groupName == null || groupName.isEmpty) ? null : 'المجموعة: $groupName';
      final TextPainter? tpGroup = groupLine == null
          ? null
          : (TextPainter(
              text: TextSpan(text: groupLine, style: textStyleSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
            )..layout(maxWidth: qrSize.toDouble()));
      final tpCode = TextPainter(
        text: TextSpan(text: 'الكود: ${student.code}', style: textStyleSub),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: qrSize.toDouble());
      final double textHeight =
          tpName.height + (tpGroup?.height ?? 0) + tpCode.height + spacing * 2;
      final int widthPx = (qrSize + padding * 2).round();
      final int heightPx = (padding + qrSize + spacing + textHeight + padding).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
          Paint()..color = const Color(0xFFFFFFFF));
      final qrLeft = (widthPx - qrSize) / 2;
      canvas.drawImageRect(
        qrImage,
        Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble()),
        Rect.fromLTWH(qrLeft, padding, qrSize.toDouble(), qrSize.toDouble()),
        Paint(),
      );
      double y = padding + qrSize + spacing;
      tpName.paint(canvas, Offset((widthPx - tpName.width) / 2, y));
      y += tpName.height + 8;
      if (tpGroup != null) {
        tpGroup.paint(canvas, Offset((widthPx - tpGroup.width) / 2, y));
        y += tpGroup.height + 8;
      }
      tpCode.paint(canvas, Offset((widthPx - tpCode.width) / 2, y));
      final composed = await recorder.endRecording().toImage(widthPx, heightPx);
      final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      await Permission.storage.request();
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'ActiveClass';
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/student_qr_${student.code}.png');
      await tmpFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      var saveInfo = await MediaStore().saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.photo,
        dirName: DirType.photo.defaults,
      );
      saveInfo ??= await MediaStore().saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.download,
        dirName: DirType.download.defaults,
      );
      final success = saveInfo?.uri != null;
      if (success) {
        final sUri = saveInfo?.uri;
        if (sUri != null) {
          try {
            final path =
                await MediaStore().getFilePathFromUri(uriString: sUri.toString());
            if (path != null && path.isNotEmpty) {
              await DatabaseService().updateStudent(student.copyWith(qrPath: path));
            }
          } catch (_) {}
        }
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
//  _StudentCard  (list mode)
// ══════════════════════════════════════════════════════════════════
class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.group,
    required this.groupColor,
    required this.onTap,
    required this.onQr,
    required this.onEdit,
    required this.onDelete,
  });

  final Student student;
  final Group? group;
  final Color groupColor;
  final VoidCallback onTap;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = student.name.trim().isNotEmpty ? student.name.trim()[0] : '?';
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black26 : Colors.black12;
    final moreIconBg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.grey.shade100;
    final moreIconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Main row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: groupColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: groupColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: onSurface,
                                ),
                              ),
                            ),
                            if (student.isExempt) ...[
                              const SizedBox(width: 6),
                              ExemptBadge(student: student, compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (group != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: groupColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  group!.name,
                                  style: TextStyle(
                                    color: groupColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              student.code,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Popup menu
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'qr') onQr();
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'qr',
                        child: Row(children: [
                          Icon(Icons.qr_code_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('عرض QR'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('تعديل'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade400),
                          const SizedBox(width: 10),
                          Text('حذف', style: TextStyle(color: Colors.red.shade400)),
                        ]),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: moreIconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.more_vert_rounded,
                          size: 18, color: moreIconColor),
                    ),
                  ),
                ],
              ),
            ),
            // ── Bottom accent bar ──────────────────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: groupColor.withValues(alpha: 0.35),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _StudentGridTile  (grid mode)
// ══════════════════════════════════════════════════════════════════
class _StudentGridTile extends StatelessWidget {
  const _StudentGridTile({
    required this.student,
    required this.group,
    required this.groupColor,
    required this.onTap,
    required this.onQr,
    required this.onEdit,
    required this.onDelete,
  });

  final Student student;
  final Group? group;
  final Color groupColor;
  final VoidCallback onTap;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = student.name.trim().isNotEmpty ? student.name.trim()[0] : '?';
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black26 : Colors.black12;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Color header
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: groupColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: groupColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: groupColor.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: groupColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      student.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.code,
                      style: TextStyle(color: subtitleColor, fontSize: 11),
                    ),
                    if (student.isExempt) ...[
                      const SizedBox(height: 4),
                      ExemptBadge(student: student, compact: true),
                    ],
                    if (group != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: groupColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          group!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: groupColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Quick actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _GridAction(
                            icon: Icons.qr_code_rounded,
                            color: groupColor,
                            onTap: onQr),
                        _GridAction(
                            icon: Icons.edit_rounded,
                            color: Colors.orange,
                            onTap: onEdit),
                        _GridAction(
                            icon: Icons.delete_rounded,
                            color: Colors.red,
                            onTap: onDelete),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridAction extends StatelessWidget {
  const _GridAction(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _StatPill
// ══════════════════════════════════════════════════════════════════
class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _FilterChip
// ══════════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = Theme.of(context).colorScheme.surface;
    final unselectedBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final unselectedText = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : unselectedBorder, width: 1.2),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : unselectedText,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
