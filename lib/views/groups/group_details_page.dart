// lib/views/groups/group_details_page.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/attendance_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'dart:async';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({super.key});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final StudentController studentController = Get.put(StudentController());
  Group? group;
  late final TextEditingController _searchCtrl;
  
  bool _isSelectionMode = false;
  final Set<int> _selectedStudents = {};
  final Set<int> _paidStudentIds = {};

  @override
  void initState() {
    super.initState();
    group = Get.arguments as Group?;
    _searchCtrl = TextEditingController(text: studentController.searchQuery.value)
      ..selection = TextSelection.fromPosition(ui.TextPosition(offset: studentController.searchQuery.value.length));
    _searchCtrl.addListener(() => studentController.searchStudents(_searchCtrl.text));
    final g = group;
    if (g != null && g.id != null) studentController.loadStudentsByGroup(g.id!);
    _loadPaidStudents();
  }

  Future<void> _loadPaidStudents() async {
    final paid = await DatabaseService().getPaidStudentIdsForMonth(DateTime.now());
    if (mounted) {
      setState(() {
        _paidStudentIds.clear();
        _paidStudentIds.addAll(paid);
      });
    }
  }

  void _toggleSelection(int studentId) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
        if (_selectedStudents.isEmpty) _isSelectionMode = false;
      } else {
        _selectedStudents.add(studentId);
      }
    });
  }

  Future<void> _recordBulkAttendance(String status) async {
    if (_selectedStudents.isEmpty) return;
    final now = DateTime.now();
    for (final id in _selectedStudents) {
      final a = Attendance(
        studentId: id,
        date: now,
        status: status,
      );
      try {
        await DatabaseService().insertAttendance(a);
      } catch (_) {} // Ignore unique constraint if already recorded
    }
    ToastHelper.success('تم تسجيل ${status == ATTENDANCE_PRESENT ? "الحضور" : "الغياب"} بنجاح');
    setState(() {
      _selectedStudents.clear();
      _isSelectionMode = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = group;

    if (g == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المجموعة')),
        body: const Center(child: Text('لم يتم العثور على بيانات المجموعة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedStudents.length} محدد')
            : const Text('تفاصيل المجموعة'),
        centerTitle: true,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedStudents.clear();
                }),
              )
            : null,
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
        onPressed: () => _gdShowAddStudentDialog(context, studentController, g),
        child: const Icon(Icons.person_add),
      ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _recordBulkAttendance(ATTENDANCE_PRESENT),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('حضور للجميع', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _recordBulkAttendance(ATTENDANCE_ABSENT),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('غياب للجميع', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: Obx(() {
        final List<Student> groupStudents = studentController.students
            .where((s) => s.groupId == g.id)
            .toList();
        final double totalFees = groupStudents
            .fold<double>(0.0, (sum, student) => sum + student.price);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(PADDING_SMALL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primaryColor,
                          child: const Icon(Icons.group, size: 22, color: Colors.white),
                        ),
                        title: Text(g.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 2),
                            Text('رمز المجموعة: ${g.code ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
                            Text('الرسوم: ${g.price != null ? FormatHelper.formatCurrency(g.price!) : '-'}', style: Theme.of(context).textTheme.bodySmall),
                            Obx(() {
                              final s = Get.find<SettingsController>();
                              String fmt(TimeOfDay t) {
                                if (s.use24hFormat.value) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
                              String display(String? raw) {
                                final r = raw?.trim() ?? '';
                                if (r.isEmpty) return '-';
                                final parts = r.split(',');
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
                                return mapped.isEmpty ? '-' : mapped;
                              }
                              return Text('المواعيد: ${display(g.schedule)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall);
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: SPACING_SMALL),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                Get.defaultDialog(
                                  title: 'حذف المجموعة',
                                  middleText: 'سيتم حذف المجموعة فقط دون طلابها. هل تريد المتابعة؟',
                                  textCancel: 'إلغاء',
                                  textConfirm: 'حذف',
                                  confirmTextColor: Colors.white,
                                  onConfirm: () async {
                                    await DatabaseService().deleteGroup(g.id!);
                                    Get.back();
                                    Get.back();
                                  },
                                );
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('حذف المجموعة'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                Get.defaultDialog(
                                  title: 'حذف الطلاب وتصفير الأكواد',
                                  middleText: 'سيتم حذف جميع الطلاب وسجلاتهم لهذه المجموعة، وسيبدأ الترقيم من البداية.',
                                  textCancel: 'إلغاء',
                                  textConfirm: 'متابعة',
                                  onConfirm: () async {
                                    await DatabaseService().deleteStudentsByGroup(g.id!);
                                    await studentController.loadStudentsByGroup(g.id!);
                                    Get.back();
                                    ToastHelper.success('تم حذف الطلاب وتصفير الأكواد');
                                  },
                                );
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('حذف الطلاب وتصفير الأكواد'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _startGroupWhatsappBatchSend(context, g.id!),
                              icon: const Icon(Icons.chat, color: Colors.green),
                              label: const Text('إرسال واتساب للمجموعة'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SPACING_NORMAL),
              Text(
                'الملخص',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: SPACING_NORMAL),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: SPACING_NORMAL,
                mainAxisSpacing: SPACING_NORMAL,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatsCard(
                    title: 'عدد الطلاب',
                    value: '${groupStudents.length}',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  StatsCard(
                    title: 'إجمالي الرسوم',
                    value: FormatHelper.formatCurrency(totalFees),
                    icon: Icons.attach_money,
                    color: Colors.green,
                    onTap: () => _gdShowFeesBreakdownDialog(context, groupStudents),
                  ),
                ],
              ),
              const SizedBox(height: SPACING_LARGE),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'قائمة الطلاب',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!_isSelectionMode && groupStudents.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                      icon: const Icon(Icons.checklist),
                      label: const Text('تحديد متعدد'),
                    ),
                ],
              ),
              const SizedBox(height: SPACING_NORMAL),
              Padding(
                padding: const EdgeInsets.only(bottom: SPACING_NORMAL),
                child: CustomSearchBar(
                  controller: _searchCtrl,
                  hintText: 'ابحث بالاسم أو الكود...',
                  onChanged: (v) => studentController.searchStudents(v),
                  onClear: () {
                    _searchCtrl.clear();
                    studentController.searchStudents('');
                  },
                ),
              ),
              if (groupStudents.isEmpty)
                const EmptyState(
                  icon: Icons.person_off,
                  title: 'لا توجد طلاب',
                  subtitle: 'ابدأ بإضافة طالب إلى المجموعة',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: studentController.filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = studentController.filteredStudents[index];
                    final isSelected = _selectedStudents.contains(student.id);
                    final hasPaid = _paidStudentIds.contains(student.id);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: SPACING_SMALL),
                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (v) {
                                  if (student.id != null) _toggleSelection(student.id!);
                                },
                              )
                            : null,
                        title: Row(
                          children: [
                            Text(student.name),
                            if (!hasPaid) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.circle, color: Colors.red, size: 10),
                            ],
                          ],
                        ),
                        subtitle: Text('الكود: ${student.code}'),
                        trailing: _isSelectionMode ? null : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'QR',
                              icon: const Icon(Icons.qr_code),
                              onPressed: () => _gdShowQRDialog(context, student),
                            ),
                            IconButton(
                              tooltip: 'تعديل',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _gdShowEditStudentDialog(context, studentController, student, g),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                if (student.id != null) studentController.deleteStudent(student.id!);
                              },
                            ),
                          ],
                        ),
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() => _isSelectionMode = true);
                          }
                          if (student.id != null) _toggleSelection(student.id!);
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            if (student.id != null) _toggleSelection(student.id!);
                          } else {
                            Get.toNamed(ROUTE_STUDENT_DETAILS, arguments: student);
                          }
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: SPACING_LARGE),
            ],
          ),
        );
      }),
    );
  }
}

Future<bool> _gdSaveStudentQrImage(Student student) async {
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

    final textStyleTitle = const TextStyle(color: Colors.black, fontSize: 48, fontWeight: FontWeight.w600, fontFamily: 'Cairo');
    final textStyleSub = const TextStyle(color: Colors.black, fontSize: 36, fontFamily: 'Cairo');

    final tpName = TextPainter(
      text: TextSpan(text: student.name, style: textStyleTitle),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.rtl,
    )..layout(maxWidth: qrSize.toDouble());

    final groupLine = (groupName == null || groupName.isEmpty) ? null : 'المجموعة: $groupName';
    final TextPainter? tpGroup = groupLine == null
        ? null
        : (TextPainter(
            text: TextSpan(text: groupLine, style: textStyleSub),
            textAlign: TextAlign.center,
            textDirection: ui.TextDirection.rtl,
          )..layout(maxWidth: qrSize.toDouble()));

    final codeLine = 'الكود: ${student.code}';
    final tpCode = TextPainter(
      text: TextSpan(text: codeLine, style: textStyleSub),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: qrSize.toDouble());

    final double textHeight = tpName.height + (tpGroup?.height ?? 0) + tpCode.height + spacing * 2;

    final int widthPx = (qrSize + padding * 2).round();
    final int heightPx = (padding + qrSize + spacing + textHeight + padding).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bg = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()), bg);

    final double qrLeft = (widthPx - qrSize) / 2;
    final double qrTop = padding;
    final srcRect = Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble());
    final dstRect = Rect.fromLTWH(qrLeft, qrTop, qrSize.toDouble(), qrSize.toDouble());
    canvas.drawImageRect(qrImage, srcRect, dstRect, Paint());

    double cursorY = qrTop + qrSize + spacing;
    tpName.paint(canvas, Offset((widthPx - tpName.width) / 2, cursorY));
    cursorY += tpName.height + 8;
    if (tpGroup != null) {
      tpGroup.paint(canvas, Offset((widthPx - tpGroup.width) / 2, cursorY));
      cursorY += tpGroup.height + 8;
    }
    tpCode.paint(canvas, Offset((widthPx - tpCode.width) / 2, cursorY));

    final composed = await recorder.endRecording().toImage(widthPx, heightPx);
    final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return false;
    final bytes = byteData.buffer.asUint8List();

    await Permission.storage.request();
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = "ActiveClass";

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/student_qr_${student.code}.png');
    await tmpFile.writeAsBytes(bytes, flush: true);

    var saveInfo = await MediaStore().saveFile(
      tempFilePath: tmpFile.path,
      dirType: DirType.photo,
      dirName: DirType.photo.defaults,
    );

    if (saveInfo?.uri == null) {
      saveInfo = await MediaStore().saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.download,
        dirName: DirType.download.defaults,
      );
    }

    final success = saveInfo?.uri != null;
    if (success && saveInfo?.uri != null) {
      try {
        final sUri = saveInfo?.uri;
        if (sUri != null) {
          final path = await MediaStore().getFilePathFromUri(uriString: sUri.toString());
          if (path != null && path.isNotEmpty) {
            await DatabaseService().updateStudent(student.copyWith(qrPath: path));
          }
        }
      } catch (_) {}
    }
    return success;
  } catch (_) {
    return false;
  }
}

Future<void> _startGroupWhatsappBatchSend(BuildContext context, int groupId) async {
  final db = DatabaseService();
  final settings = Get.find<SettingsController>();
  final students = await db.getStudentsByGroup(groupId);
  final valid = students.where((s) => (s.guardianPhone ?? '').trim().isNotEmpty).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (valid.isEmpty) {
    ToastHelper.info('لا يوجد أولياء أمور بأرقام مسجلة');
    return;
  }
  if (!context.mounted) return;
  await _pickAndSend(context, valid, settings);
}

Future<void> _pickAndSend(BuildContext context, List<Student> all, SettingsController settings) async {
  final db = DatabaseService();
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final nextMonth = DateTime(now.year, now.month + 1, 1);
  final end = nextMonth.subtract(const Duration(days: 1));
  final sentMap = await db.getReportSentMap(all.map((s) => s.id!).toList(), start);

  String normalize(String input, String defaultDial) {
    var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith(defaultDial)) return p;
    if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
    p = p.replaceFirst(RegExp(r'^0+'), '');
    return defaultDial + p;
  }

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      List<Student> items = List.of(all);
      List<bool> sel = List<bool>.filled(items.length, true);
      bool sending = false;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('اختر أولياء الأمور'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 360,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final s = items[i];
                      final last = sentMap[s.id!];
                      return CheckboxListTile(
                        value: sel[i],
                        onChanged: sending ? null : (v) => setState(() => sel[i] = v ?? false),
                        title: Text(s.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.guardianPhone ?? '-'),
                            if (last != null)
                              Text(
                                'آخر إرسال: ${FormatHelper.formatDateTime(last)}',
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: sending ? null : () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: sending || !sel.any((e) => e)
                  ? null
                  : () async {
                      setState(() => sending = true);
                      for (int i = 0; i < items.length; i++) {
                        if (!sel[i]) continue;
                        final s = items[i];
                        final rawPhone = s.guardianPhone!.trim();
                        final phone = normalize(rawPhone, settings.countryDial.value);

                        final group = await db.getGroup(s.groupId);
                        final groupName = group?.name ?? '-';

                        final atts = await db.getAttendanceByStudent(s.id!);
                        final pays = await db.getPaymentsByStudent(s.id!);

                        final monthEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
                        final attsMonth = atts.where((a) => !a.date.isBefore(start) && !a.date.isAfter(monthEnd)).toList();
                        final paysMonth = pays.where((p) => !p.date.isBefore(start) && !p.date.isAfter(monthEnd)).toList();

                        final present = attsMonth.where((a) => a.status == ATTENDANCE_PRESENT).length;
                        final absent = attsMonth.where((a) => a.status == ATTENDANCE_ABSENT).length;
                        final total = present + absent;
                        final percent = total == 0 ? 0.0 : (present / total) * 100.0;
                        final totalPaid = paysMonth.fold<double>(0.0, (sum, p) => sum + p.amount);

                        final attsSorted = List.of(attsMonth)..sort((a, b) => b.date.compareTo(a.date));
                        final paysSorted = List.of(paysMonth)..sort((a, b) => b.date.compareTo(a.date));

                        final buffer = StringBuffer()
                          ..writeln('🧾 تقرير الشهر: ${DateFormat('MMMM yyyy', 'ar').format(start)}')
                          ..writeln('👤 الاسم: ${s.name}')
                          ..writeln('🆔 الكود: ${s.code}')
                          ..writeln('👥 المجموعة: $groupName')
                          ..writeln('📅 بداية الحضور: ${FormatHelper.formatDate(s.attendanceStart ?? s.createdAt)}')
                          ..writeln('')
                          ..writeln('📊 الحضور: ✅ حاضر $present • ❌ غياب $absent • نسبة ${percent.toStringAsFixed(1)}%');

                        if (attsSorted.isNotEmpty) {
                          buffer.writeln('');
                          buffer.writeln('📅 سجلات الحضور:');
                          for (final a in attsSorted.take(10)) {
                            final d = DateFormat('yyyy-MM-dd').format(a.date);
                            final st = a.status == ATTENDANCE_PRESENT ? '✅ حاضر' : '❌ غياب';
                            buffer.writeln('• $d — $st');
                          }
                          if (attsSorted.length > 10) buffer.writeln('• … ${attsSorted.length - 10} سجلات إضافية');
                        }

                        buffer
                          ..writeln('')
                          ..writeln('💰 المدفوعات: إجمالي ${FormatHelper.formatCurrency(totalPaid)}');

                        if (paysSorted.isNotEmpty) {
                          for (final p in paysSorted) {
                            final d = DateFormat('yyyy-MM-dd').format(p.date);
                            buffer.writeln('• $d — ${FormatHelper.formatCurrency(p.amount)}');
                          }
                        }

                        final tName = settings.teacherFullName.value.trim();
                        final tSpec = settings.teacherSpecialization.value.trim();
                        if (tName.isNotEmpty || tSpec.isNotEmpty) {
                          buffer
                            ..writeln('')
                            ..writeln('👨‍🏫 المعلم: ${tName.isNotEmpty ? tName : '-'}')
                            ..writeln('📘 التخصص: ${tSpec.isNotEmpty ? tSpec : '-'}');
                        }
                        buffer
                          ..writeln('')
                          ..writeln('تم الإرسال من تطبيق Active Class');

                        final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}');
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                        await _gdWaitForResume();

                        final sentAt = DateTime.now();
                        await db.upsertReportLog(s.id!, start, sentAt);
                        ToastHelper.success('تم إرسال التقرير لولي أمر الطالب ${s.name}');

                        setState(() {
                          sentMap[s.id!] = sentAt;
                          items.removeAt(i);
                          sel.removeAt(i);
                          i--;
                        });
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
              child: const Text('ابدأ الإرسال'),
            ),
          ],
        ),
      );
    },
  );
}

class _GDResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  _GDResumeObserver(this.onResume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

Future<void> _gdWaitForResume() {
  final c = Completer<void>();
  late _GDResumeObserver obs;
  obs = _GDResumeObserver(() {
    WidgetsBinding.instance.removeObserver(obs);
    if (!c.isCompleted) c.complete();
  });
  WidgetsBinding.instance.addObserver(obs);
  return c.future;
}

void _gdShowQRDialog(BuildContext context, Student student) {
  showDialog(
    context: context,
    builder: (ctx) {
      return FutureBuilder<Group?>(
        future: DatabaseService().getGroup(student.groupId),
        builder: (context, snapshot) {
          final groupName = snapshot.data?.name ?? '';
          return AlertDialog(
            title: const Text('QR Code'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (groupName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('المجموعة: $groupName'),
                  ],
                  const SizedBox(height: 12),
                  if (student.code.trim().isEmpty)
                    const Text('لا يوجد كود لعرضه', style: TextStyle(color: Colors.red))
                  else
                    QrImageView(
                      data: student.code,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  const SizedBox(height: 12),
                  Text('الكود: ${student.code}')
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق'),
              ),
              ElevatedButton.icon(
                onPressed: student.code.trim().isEmpty ? null : () async {
                  final ok = await _gdSaveStudentQrImage(student);
                  if (!ctx.mounted) return;
                  if (ok) {
                    ToastHelper.success('تم حفظ صورة QR بنجاح');
                  } else {
                    ToastHelper.error('تعذر حفظ صورة QR');
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('حفظ الصورة'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _gdShowAddStudentDialog(BuildContext context, StudentController controller, Group group) async {
  final nameController = TextEditingController();
  final guardianPhoneController = TextEditingController();
  DateTime? attendanceStart = DateTime.now();
  DateTime? birthDate;
  double? price = group.price ?? 0.0;
  String nextCode = '';

  // Generate initial code
  if ((group.code?.isNotEmpty ?? false) && group.id != null) {
    nextCode = await controller.generateNextStudentCode(groupPrefix: group.code!, groupId: group.id!);
  }

  Get.dialog(
    StatefulBuilder(
      builder: (context, setSt) {
        Future<void> addStudentAndReset() async {
          final name = nameController.text.trim();
          final guardianPhone = guardianPhoneController.text.trim();
          
          if (name.isEmpty || nextCode.isEmpty || group.id == null) {
            ToastHelper.error('يرجى إدخال اسم الطالب');
            return;
          }

          final student = Student(
            name: name,
            code: nextCode,
            groupId: group.id!,
            price: price,
            attendanceStart: attendanceStart,
            guardianPhone: guardianPhone.isEmpty ? null : guardianPhone,
            birthDate: birthDate,
          );

          await controller.addStudent(student);
          ToastHelper.success('تم إضافة الطالب $name بنجاح');

          // Reset only name and guardian phone
          nameController.clear();
          guardianPhoneController.clear();
          
          // Generate new code for next student
          if ((group.code?.isNotEmpty ?? false) && group.id != null) {
            nextCode = await controller.generateNextStudentCode(groupPrefix: group.code!, groupId: group.id!);
          }

          // Update UI
          setSt(() {});
        }

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('إضافة طالب جديد'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.group, size: 20, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'المجموعة: ${group.name}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // Student name
                  CustomTextField(
                    controller: nameController,
                    label: 'اسم الطالب *',
                    validator: (v) => ValidationHelper.validateNotEmpty(v, 'اسم الطالب'),
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // Code display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, size: 20, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'الكود: $nextCode',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // Guardian phone
                  CustomTextField(
                    controller: guardianPhoneController,
                    label: 'رقم ولي الأمر',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: SPACING_NORMAL),

                  // Date pickers row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000, 1, 1),
                              lastDate: DateTime.now(),
                              initialDate: birthDate ?? DateTime(2010, 1, 1),
                              helpText: 'تاريخ الميلاد',
                              confirmText: 'تأكيد',
                            );
                            if (picked != null) {
                              setSt(() => birthDate = DateTime(picked.year, picked.month, picked.day));
                            }
                          },
                          icon: const Icon(Icons.cake, size: 18),
                          label: Text(
                            birthDate != null 
                                ? '${birthDate!.day}/${birthDate!.month}' 
                                : 'تاريخ الميلاد',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: birthDate != null 
                                ? AppTheme.accentColor.withValues(alpha: 0.1) 
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                              initialDate: attendanceStart ?? DateTime.now(),
                              helpText: 'بداية الحضور',
                              confirmText: 'تأكيد',
                            );
                            if (picked != null) {
                              setSt(() => attendanceStart = DateTime(picked.year, picked.month, picked.day));
                            }
                          },
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            '${attendanceStart!.day}/${attendanceStart!.month}/${attendanceStart!.year}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(), 
              child: const Text('إغلاق'),
            ),
            ElevatedButton.icon(
              onPressed: addStudentAndReset,
              icon: const Icon(Icons.add),
              label: const Text('إضافة طالب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    ),
  );
}

void _gdShowEditStudentDialog(BuildContext context, StudentController controller, Student student, Group group) async {
  final nameController = TextEditingController(text: student.name);
  final priceController = TextEditingController(text: student.price.toString());
  final guardianPhoneController = TextEditingController(text: student.guardianPhone ?? '');
  DateTime? attendanceStart = student.attendanceStart ?? DateTime.now();
  DateTime? birthDate = student.birthDate;

  Get.dialog(
    StatefulBuilder(
      builder: (context, setSt) => AlertDialog(
        title: const Text('تعديل الطالب'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'اسم الطالب',
                ),
                const SizedBox(height: SPACING_NORMAL),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('المجموعة: ${group.name}'),
                ),
                const SizedBox(height: SPACING_NORMAL),
                CustomTextField(
                  controller: priceController,
                  label: 'الرسوم',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: SPACING_NORMAL),
                CustomTextField(
                  controller: guardianPhoneController,
                  label: 'رقم ولي الأمر',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: SPACING_NORMAL),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000, 1, 1),
                        lastDate: DateTime.now(),
                        initialDate: birthDate ?? DateTime(2010, 1, 1),
                        helpText: 'اختر تاريخ الميلاد',
                        confirmText: 'تأكيد',
                      );
                      if (picked != null) setSt(() => birthDate = DateTime(picked.year, picked.month, picked.day));
                    },
                    icon: const Icon(Icons.cake),
                    label: Text('تاريخ الميلاد: ${birthDate != null ? FormatHelper.formatDate(birthDate) : 'غير محدد'}'),
                  ),
                ),
                const SizedBox(height: SPACING_NORMAL),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 12, 31),
                        initialDate: attendanceStart ?? DateTime.now(),
                        helpText: 'اختر تاريخ بداية الحضور',
                        confirmText: 'تأكيد',
                      );
                      if (picked != null) setSt(() => attendanceStart = DateTime(picked.year, picked.month, picked.day));
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text('بداية الحضور: ${FormatHelper.formatDate(attendanceStart)}'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          CustomButton(
            label: 'حفظ التعديلات',
            onPressed: () async {
              final updatedStudent = student.copyWith(
                name: nameController.text.trim(),
                price: double.tryParse(priceController.text.trim()) ?? student.price,
                attendanceStart: attendanceStart,
                guardianPhone: guardianPhoneController.text.trim().isEmpty ? null : guardianPhoneController.text.trim(),
                birthDate: birthDate,
              );
              await controller.updateStudent(updatedStudent);
              Get.back();
            },
          ),
        ],
      ),
    ),
  );
}

void _gdShowFeesBreakdownDialog(BuildContext context, List<Student> students) {
  showDialog(
    context: context,
    builder: (ctx) {
      final db = DatabaseService();
      final settings = Get.find<SettingsController>();
      DateTime selected = DateTime(DateTime.now().year, DateTime.now().month, 1);

      String normalize(String input, String defaultDial) {
        var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
        if (p.startsWith('+')) p = p.substring(1);
        if (p.startsWith('00')) p = p.substring(2);
        if (p.startsWith(defaultDial)) return p;
        if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
        p = p.replaceFirst(RegExp(r'^0+'), '');
        return defaultDial + p;
      }

      Future<Map<String, dynamic>> load(DateTime monthStart) async {
        final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);
        final byId = {for (final s in students) if (s.id != null) s.id!: s};

        final Set<int> allowed = {};
        for (final s in students) {
          if (s.id == null) continue;
          final st = s.attendanceStart;
          if (st != null) {
            final sMonthStart = DateTime(st.year, st.month, 1);
            if (sMonthStart.isAfter(monthStart)) continue;
          }
          allowed.add(s.id!);
        }

        final Map<double, int> solo = {};
        final Map<double, int> pairs = {};
        final Set<int> paired = {};
        for (final id in allowed) {
          final s = byId[id]!;
          if (s.siblingId != null && s.siblingsTotal != null && allowed.contains(s.siblingId!) && !paired.contains(id)) {
            final sib = byId[s.siblingId!];
            if (sib != null && sib.siblingId == id && sib.siblingsTotal == s.siblingsTotal) {
              paired.add(id);
              paired.add(sib.id!);
              final t = s.siblingsTotal!;
              pairs[t] = (pairs[t] ?? 0) + 1;
            } else {
              final p = s.price;
              solo[p] = (solo[p] ?? 0) + 1;
            }
          } else {
            final p = s.price;
            solo[p] = (solo[p] ?? 0) + 1;
          }
        }

        double expected = 0;
        solo.forEach((price, count) => expected += price * count);
        pairs.forEach((total, count) => expected += total * count);

        int paidCount = 0;
        double paidAmount = 0;
        final key = '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}';
        final List<Student> unpaidStudents = [];

        for (final id in allowed) {
          final s = byId[id]!;
          final list = await db.getPaymentsByStudent(id);
          bool isPaid = false;
          double stuPaid = 0;
          for (final p in list) {
            final inRange = !p.date.isBefore(monthStart) && !p.date.isAfter(monthEnd);
            if (inRange) {
              stuPaid += p.amount;
              isPaid = true;
            } else {
              final note = p.note ?? '';
              if (note.startsWith('months=')) {
                final raw = note.split(';').first.substring(7).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
                if (raw.contains(key)) {
                  stuPaid += p.amount;
                  isPaid = true;
                }
              }
            }
          }
          if (isPaid) {
            paidCount++;
          } else {
            unpaidStudents.add(s);
          }
          paidAmount += stuPaid;
        }

        return {
          'solo': solo,
          'pairs': pairs,
          'expected': expected,
          'paidCount': paidCount,
          'unpaidCount': allowed.length - paidCount,
          'paidAmount': paidAmount,
          'month': DateFormat('MMMM yyyy', 'ar').format(monthStart),
          'key': key,
          'allowedTotal': allowed.length,
          'unpaidStudents': unpaidStudents,
        };
      }

      return StatefulBuilder(
        builder: (ctx, setSt) {
          return FutureBuilder<Map<String, dynamic>>(
            future: load(selected),
            builder: (context, snap) {
              final data = snap.data;
              final expected = (data?['expected'] as double?) ?? 0;
              final paidAmount = (data?['paidAmount'] as double?) ?? 0;
              final progress = expected > 0 ? (paidAmount / expected).clamp(0.0, 1.0) : 0.0;

              return AlertDialog(
                title: Row(
                  children: [
                    const Text('تفاصيل الرسوم'),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(2100, 12, 31),
                          initialDate: selected,
                          helpText: 'اختر أي تاريخ داخل الشهر',
                          confirmText: 'تأكيد',
                        );
                        if (picked != null) setSt(() => selected = DateTime(picked.year, picked.month, 1));
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(data == null ? '...' : data['month']),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 480,
                  height: 520,
                  child: snap.connectionState != ConnectionState.done
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('تحصيل: ${FormatHelper.formatCurrency(paidAmount)} / ${FormatHelper.formatCurrency(expected)}')),
                                const SizedBox(width: 8),
                                Text('${(progress * 100).toStringAsFixed(0)}%'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: expected > 0 ? progress : null, minHeight: 6),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if ((data?['solo'] as Map<double, int>?)?.isNotEmpty ?? false) ...[
                                      Text('أسعار فردية', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      ...((data!['solo'] as Map<double, int>).entries.toList()
                                            ..sort((a, b) => (b.key * b.value).compareTo(a.key * a.value)))
                                          .map((e) => Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Expanded(child: Text('${e.value} طالب × ${FormatHelper.formatCurrency(e.key)}')),
                                                    Text(FormatHelper.formatCurrency(e.key * e.value)),
                                                  ],
                                                ),
                                              )),
                                      const SizedBox(height: 12),
                                    ],
                                    if ((data?['pairs'] as Map<double, int>?)?.isNotEmpty ?? false) ...[
                                      Text('عروض الإخوة', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      ...((data!['pairs'] as Map<double, int>).entries.toList()
                                            ..sort((a, b) => (b.key * b.value).compareTo(a.key * a.value)))
                                          .map((e) => Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Expanded(child: Text('${e.value} زوج × ${FormatHelper.formatCurrency(e.key)}')),
                                                    Text(FormatHelper.formatCurrency(e.key * e.value)),
                                                  ],
                                                ),
                                              )),
                                      const SizedBox(height: 12),
                                    ],
                                    Divider(color: Colors.grey[300]),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(child: Text('مدفوع: ${data?['paidCount'] ?? 0}')),
                                        Expanded(child: Text('غير مدفوع: ${data?['unpaidCount'] ?? 0}')),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if ((data?['unpaidStudents'] as List<Student>?)?.isNotEmpty ?? false) ...[
                                      Text('غير المدفوعين', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      ...((data!['unpaidStudents'] as List<Student>)).map((s) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(s.name),
                                            subtitle: Text('الكود: ${s.code}'),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.message, color: Colors.green),
                                              onPressed: () async {
                                                final raw = (s.guardianPhone ?? '').trim();
                                                if (raw.isEmpty) return;
                                                final phone = normalize(raw, settings.countryDial.value);
                                                final msg = 'تذكير برسوم شهر ${data['month']} للطالب ${s.name}.';
                                                final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              },
                                            ),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
                ],
              );
            },
          );
        },
      );
    },
  );
}
