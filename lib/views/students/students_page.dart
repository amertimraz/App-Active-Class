// lib/views/students/students_page.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/utils/responsive.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/widgets/guardian_phone_line.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/utils/student_sort_helper.dart';
import 'package:active_class/widgets/student_sort_bar.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/widgets/add_student_sheet.dart';
import 'package:active_class/widgets/edit_student_sheet.dart';
import 'package:active_class/widgets/remove_student_dialog.dart';
import 'package:active_class/widgets/import_students_dialog.dart';
import 'package:active_class/widgets/exempt_widgets.dart';
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
  final AttendanceController _attCtrl = Get.isRegistered<AttendanceController>()
      ? Get.find<AttendanceController>()
      : Get.put(AttendanceController());
  final PaymentController _payCtrl = Get.isRegistered<PaymentController>()
      ? Get.find<PaymentController>()
      : Get.put(PaymentController());
  late final TextEditingController _searchCtrl;
  List<Group> _groups = [];
  bool _gridMode = false;
  StudentSort _sortBy = StudentSort.name;
  bool _sortAscending = true;

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
    if (_attCtrl.attendance.isEmpty) _attCtrl.loadAttendance();
    if (_payCtrl.payments.isEmpty) _payCtrl.loadPayments();
  }

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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(
        context,
        title: 'الطلاب',
        actions: [
          const HelpButton(topicId: 'students'),
          IconButton(
            tooltip: _gridMode ? 'عرض قائمة' : 'عرض شبكة',
            icon: Icon(
                _gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
          IconButton(
            tooltip: 'معرض QR',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => Get.toNamed(ROUTE_QR_GALLERY),
          ),
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'import':
                  showImportStudentsDialog(
                    context,
                    controller: controller,
                    groups: _groups,
                    onImported: () => controller.loadAllStudents(),
                  );
                case 'siblings':
                  Get.toNamed(ROUTE_SIBLINGS);
                case 'archive':
                  Get.toNamed(ROUTE_ARCHIVED_STUDENTS);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  Icon(Icons.upload_file_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('استيراد من إكسل'),
                ]),
              ),
              PopupMenuItem(
                value: 'siblings',
                child: Row(children: [
                  Icon(Icons.family_restroom_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('الإخوة'),
                ]),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(children: [
                  Icon(Icons.archive_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('الأرشيف'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddStudentSheet(context, controller: controller),
        backgroundColor: t.chalk,
        foregroundColor: t.onChalk,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('إضافة طالب'),
      ),
      body: ColoredBox(
        color: t.page,
        child: Obx(() {
          final students = sortStudents(
            students: controller.filteredStudents,
            sortBy: _sortBy,
            ascending: _sortAscending,
            groupOf: _groupOf,
            allAttendance: _attCtrl.attendance,
            allPayments: _payCtrl.payments,
          );

          // ── Empty ───────────────────────────────────────────────
          if (controller.students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: AppPanel(
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
              // ── السبورة + بحث + فلتر المجموعات ───────────────────
              _buildTopSection(context),

              // ── List / Grid ──────────────────────────────────────
              Expanded(
                child: students.isEmpty
                    ? Center(
                        child: Text(
                          'لا نتائج للبحث',
                          style: AppType.body.copyWith(color: t.inkSoft),
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
    final t = context.tokens;
    // ألوان الأرقام فوق السبورة: درجات الوضع الداكن لأن خلفيتها غامقة دايمًا.
    final on = AppTokens.dark;
    final total = controller.students.length;
    // طلاب مالهمش أي وسيلة تواصل مع ولي الأمر (مهم لواتساب وبوابة الأهالي).
    final noContact = controller.students
        .where((s) =>
            guardianPhoneForDisplay(s) == null &&
            (s.guardianWhatsapp ?? '').trim().isEmpty)
        .length;

    return Column(children: [
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
                  label: 'طالب', value: '$total', color: t.boardInk)),
          Expanded(
              child: BoardStat(
                  label: 'مجموعة',
                  value: '${_groups.length}',
                  color: on.positive)),
          Expanded(
              child: BoardStat(
                  label: 'بدون رقم ولي أمر',
                  value: '$noContact',
                  color: noContact > 0 ? t.chalk : t.boardInkSoft)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
        child: Column(children: [
          // Search bar + ترتيب (السيرش قابل للانكماش عشان الأيقونات تفضل
          // ظاهرة كاملة على الشاشات الضيقة بدل ما يحصل overflow)
          Row(
            children: [
              Expanded(
                child: CustomSearchBar(
                  controller: _searchCtrl,
                  hintText: 'ابحث عن طالب...',
                  onChanged: (v) => controller.searchStudents(v),
                  onClear: () {
                    _searchCtrl.clear();
                    controller.searchStudents('');
                  },
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              StudentSortBar(
                sortBy: _sortBy,
                ascending: _sortAscending,
                onChanged: _onSortTap,
              ),
            ],
          ),

          // Group filter chips
          if (_groups.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 44,
              child: Obx(() {
                final sel = controller.selectedGroupId.value;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Center(
                      child: AppFilterChip(
                        label: 'الكل',
                        selected: sel == null,
                        color: t.brand,
                        onTap: () => controller.setGroupFilter(null),
                      ),
                    ),
                    ..._groups.map((g) {
                      final color =
                          g.color != null ? Color(g.color!) : t.brand;
                      return Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: AppSpace.sm),
                        child: Center(
                          child: AppFilterChip(
                            label: g.name,
                            selected: sel == g.id,
                            color: color,
                            onTap: () => controller.setGroupFilter(g.id),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ),
          ],
          const SizedBox(height: AppSpace.sm),
        ]),
      ),
    ]);
  }

  // ── List ─────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context, List<Student> students) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xs, AppSpace.lg, 100),
      itemCount: students.length,
      itemBuilder: (_, i) => _StudentCard(
        student: students[i],
        group: _groupOf(students[i]),
        groupColor: _groupColor(students[i]),
        onTap: () => Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: students[i]),
        onQr: () => _showQRDialog(context, students[i]),
        onEdit: () => _showEditSheet(context, students[i]),
        onArchive: () => _confirmArchive(context, students[i]),
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────
  Widget _buildGrid(BuildContext context, List<Student> students) {
    return LayoutBuilder(
      builder: (context, box) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.xs, AppSpace.lg, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:
              adaptiveColumns(box.maxWidth, phone: 2, minTileWidth: 230, max: 5),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // ارتفاع ثابت بيكبر مع حجم الخط بدل نسبة ثابتة (عشان الاسم لسطرين).
          mainAxisExtent: 112 +
              105 * MediaQuery.textScalerOf(context).scale(14) / 14,
        ),
        itemCount: students.length,
        itemBuilder: (_, i) => _StudentGridTile(
          student: students[i],
          group: _groupOf(students[i]),
          groupColor: _groupColor(students[i]),
          onTap: () =>
              Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: students[i]),
          onQr: () => _showQRDialog(context, students[i]),
          onEdit: () => _showEditSheet(context, students[i]),
          onArchive: () => _confirmArchive(context, students[i]),
        ),
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

  // ── Archive ──────────────────────────────────────────────────────
  void _confirmArchive(BuildContext context, Student student) {
    if (student.id == null) return;
    showRemoveStudentDialog(
      context,
      student: student,
      canDelete: TeamModeService().canDeleteStudentsNow,
      onArchive: () => controller.archiveStudent(student.id!),
      onDeletePermanently: () => controller.deleteStudent(student.id!),
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
//  عناصر مشتركة بين كارت القايمة وبلاطة الشبكة
// ══════════════════════════════════════════════════════════════════
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, this.size = 46});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0] : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials,
            style: AppType.title.copyWith(color: color, fontSize: size * 0.4)),
      ),
    );
  }
}

class _GroupTag extends StatelessWidget {
  const _GroupTag({required this.group, required this.color});
  final Group group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: t.page,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption
                  .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  قايمة خيارات الطالب (عرض QR / تعديل / حذف) — مشتركة بين القايمة والشبكة
// ══════════════════════════════════════════════════════════════════
class _StudentMenu extends StatelessWidget {
  const _StudentMenu(
      {required this.onQr, required this.onEdit, required this.onArchive});
  final VoidCallback onQr, onEdit, onArchive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<String>(
      tooltip: 'خيارات الطالب',
      onSelected: (v) {
        if (v == 'qr') onQr();
        if (v == 'edit') onEdit();
        if (v == 'archive') onArchive();
      },
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control)),
      icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
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
          value: 'archive',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: t.danger),
            const SizedBox(width: 10),
            Text('حذف', style: TextStyle(color: t.danger)),
          ]),
        ),
      ],
    );
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
    required this.onArchive,
  });

  final Student student;
  final Group? group;
  final Color groupColor;
  final VoidCallback onTap;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.md),
        onTap: onTap,
        child: Row(
          children: [
            _Avatar(name: student.name, color: groupColor),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(student.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label.copyWith(color: t.ink)),
                    ),
                    if (student.isExempt) ...[
                      const SizedBox(width: AppSpace.sm),
                      ExemptBadge(student: student, compact: true),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (group != null)
                        _GroupTag(group: group!, color: groupColor),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(student.code,
                            style: AppType.caption.copyWith(color: t.inkSoft)),
                      ),
                    ],
                  ),
                  GuardianPhoneLine(student: student, color: t.inkSoft),
                ],
              ),
            ),
            _StudentMenu(onQr: onQr, onEdit: onEdit, onArchive: onArchive),
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
    required this.onArchive,
  });

  final Student student;
  final Group? group;
  final Color groupColor;
  final VoidCallback onTap;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPanel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Avatar(name: student.name, color: groupColor, size: 52),
                const SizedBox(height: AppSpace.sm),
                Text(student.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.label.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(student.code,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
                ),
                if (student.isExempt) ...[
                  const SizedBox(height: 4),
                  ExemptBadge(student: student, compact: true),
                ],
                if (group != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  _GroupTag(group: group!, color: groupColor),
                ],
              ],
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child:
                _StudentMenu(onQr: onQr, onEdit: onEdit, onArchive: onArchive),
          ),
        ],
      ),
    );
  }
}
