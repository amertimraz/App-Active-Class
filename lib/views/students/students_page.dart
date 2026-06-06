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
import 'package:active_class/utils/helpers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:active_class/services/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final StudentController controller = Get.put(StudentController());
  late final TextEditingController _searchCtrl;
  Future<List<Group>>? _groupsFuture;
  bool _gridMode = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: controller.searchQuery.value);
    _searchCtrl.selection = TextSelection.fromPosition(ui.TextPosition(offset: _searchCtrl.text.length));
    _searchCtrl.addListener(() => controller.searchStudents(_searchCtrl.text));
    _groupsFuture = controller.loadAllGroups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _gridMode ? 'عرض قائمة' : 'عرض شبكة',
            icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _gridMode = !_gridMode),
          ),
          IconButton(
            tooltip: 'معرض QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => Get.toNamed(ROUTE_QR_GALLERY),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.students.isEmpty) {
          return EmptyState(
            icon: Icons.person_off,
            title: 'لا توجد طلاب',
            subtitle: 'ابدأ بإضافة طالب جديد',
            actionLabel: 'إضافة طالب',
            onActionPressed: () => _showAddStudentDialog(context, controller),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(PADDING_NORMAL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<List<Group>>(
                    future: _groupsFuture,
                    builder: (context, snapshot) {
                      final groups = snapshot.data ?? [];
                      return Obx(() {
                        final sel = controller.selectedGroupId.value;
                        return DropdownButtonFormField<int?>(
                          initialValue: sel,
                          decoration: const InputDecoration(labelText: 'المجموعة'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('كل المجموعات')),
                            ...groups.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
                          ],
                          onChanged: controller.setGroupFilter,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: SPACING_NORMAL),
                  CustomSearchBar(
                    controller: _searchCtrl,
                    hintText: 'ابحث عن طالب...',
                    onChanged: (value) => controller.searchStudents(value),
                    onClear: () {
                      _searchCtrl.clear();
                      controller.searchStudents('');
                    },
                  ),
                ],
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
                        childAspectRatio: 1.4,
                      ),
                      itemCount: controller.filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = controller.filteredStudents[index];
                        return _buildStudentGridTile(context, student, controller);
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
                      itemCount: controller.filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = controller.filteredStudents[index];
                        return _buildStudentCard(
                          context,
                          student,
                          controller,
                        );
                      },
                    ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStudentDialog(context, controller),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    Student student,
    StudentController controller,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: SPACING_SMALL),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(student.name),
        subtitle: Text('الكود: ${student.code}'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('عرض QR'),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  _showQRDialog(context, student);
                });
              },
            ),
            PopupMenuItem(
              child: const Text('تعديل'),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  _showEditStudentDialog(context, controller, student);
                });
              },
            ),
            PopupMenuItem(
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  _showDeleteConfirmDialog(context, controller, student);
                });
              },
            ),
          ],
        ),
        onTap: () => Get.toNamed(
          ROUTE_STUDENT_DETAILS,
          arguments: student,
        ),
      ),
    );
  }

  Widget _buildStudentGridTile(
    BuildContext context,
    Student student,
    StudentController controller,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: SPACING_SMALL),
      child: InkWell(
        onTap: () => Get.toNamed(
          ROUTE_STUDENT_DETAILS,
          arguments: student,
        ),
        child: Padding(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: SPACING_NORMAL),
              Text(
                student.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text('الكود: ${student.code}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context, StudentController controller) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final codeController = TextEditingController();
    final guardianPhoneController = TextEditingController();

    final groups = await controller.loadAllGroups();
    Group? selectedGroup = groups.isNotEmpty ? groups.first : null;

    final g0 = selectedGroup;
    if (g0 != null && g0.id != null && (g0.code?.isNotEmpty ?? false)) {
      codeController.text = await controller.generateNextStudentCode(
        groupPrefix: g0.code!,
        groupId: g0.id!,
      );
    }
    final g1 = selectedGroup;
    if (g1 != null && g1.price != null) {
      priceController.text = g1.price!.toStringAsFixed(2);
    } else {
      priceController.clear();
    }

    Student? selectedSibling;
    final siblingsTotalController = TextEditingController();
    DateTime? attendanceStart = DateTime.now();

    Get.dialog(
      StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('إضافة طالب جديد'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: nameController,
                    label: 'اسم الطالب',
                    validator: (value) => ValidationHelper.validateNotEmpty(value, 'اسم الطالب'),
                  ),
                  const SizedBox(height: SPACING_NORMAL),
                  CustomTextField(
                    controller: codeController,
                    label: 'الكود (تلقائي)',
                    enabled: false,
                    validator: (value) => ValidationHelper.validateNotEmpty(value, 'الكود'),
                  ),
                  const SizedBox(height: SPACING_NORMAL),
                  DropdownButtonFormField<Group>(
                    initialValue: selectedGroup,
                    decoration: const InputDecoration(labelText: 'المجموعة'),
                    items: groups
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g.name + (g.price != null ? ' • ${FormatHelper.formatCurrency(g.price)}' : '')),
                            ))
                        .toList(),
                    onChanged: (g) async {
                      selectedGroup = g;
                      if (selectedGroup?.price != null) {
                        final gp = selectedGroup!;
                        priceController.text = gp.price!.toStringAsFixed(2);
                      } else {
                        priceController.clear();
                      }
                      final sg = selectedGroup;
                      if (sg != null && sg.id != null && (sg.code?.isNotEmpty ?? false)) {
                        final next = await controller.generateNextStudentCode(
                          groupPrefix: sg.code!,
                          groupId: sg.id!,
                        );
                        setSt(() => codeController.text = next);
                      } else {
                        setSt(() => codeController.clear());
                      }
                    },
                  ),
                  const SizedBox(height: SPACING_NORMAL),
                  CustomTextField(
                    controller: priceController,
                    label: 'الرسوم',
                    keyboardType: TextInputType.number,
                    validator: (value) => ValidationHelper.validateNumber(value, fieldName: 'الرسوم'),
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
                  const SizedBox(height: SPACING_LARGE),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final all = await DatabaseService().getAllStudents();
                        if (!context.mounted) return;
                        Student? picked;
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('اختر الأخ'),
                            content: SizedBox(
                              width: 400,
                              height: 300,
                              child: ListView.builder(
                                itemCount: all.length,
                                itemBuilder: (c, i) {
                                  final s = all[i];
                                  return ListTile(
                                    title: Text(s.name),
                                    subtitle: Text('الكود: ${s.code}') ,
                                    onTap: () {
                                      picked = s;
                                      Navigator.of(c).pop();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                        if (picked != null) {
                          setSt(() => selectedSibling = picked);
                        }
                      },
                      icon: const Icon(Icons.group_add),
                      label: const Text('إضافة أخ'),
                    ),
                  ),
                  if (selectedSibling != null) ...[
                    Row(
                      children: [
                        Expanded(child: Text('الأخ: ${selectedSibling!.name} (${selectedSibling!.code})')),
                        IconButton(
                          onPressed: () => setSt(() => selectedSibling = null),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: SPACING_NORMAL),
                    CustomTextField(
                      controller: siblingsTotalController,
                      label: 'إجمالي الأخوين للشهر',
                      keyboardType: TextInputType.number,
                      validator: (v) => selectedSibling == null ? null : ValidationHelper.validateNumber(v, fieldName: 'الإجمالي'),
                    ),
                  ],
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
              label: 'إضافة',
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                final price = double.tryParse(priceController.text.trim());
                final siblingsTotal = double.tryParse(siblingsTotalController.text.trim());

                if (name.isEmpty || code.isEmpty || selectedGroup == null || price == null) return;
                if (selectedSibling != null && siblingsTotal == null) return;

                final student = Student(
                  name: name,
                  code: code,
                  groupId: selectedGroup!.id!,
                  price: price,
                  siblingId: selectedSibling?.id,
                  siblingsTotal: selectedSibling != null ? siblingsTotal : null,
                  attendanceStart: attendanceStart,
                  guardianPhone: guardianPhoneController.text.trim().isEmpty ? null : guardianPhoneController.text.trim(),
                );
                final created = await controller.addStudent(student);
                if (created != null && selectedSibling != null && siblingsTotal != null) {
                  final s1 = created.copyWith(siblingId: selectedSibling!.id, siblingsTotal: siblingsTotal);
                  await controller.updateStudent(s1);
                  final s2 = selectedSibling!.copyWith(siblingId: created.id, siblingsTotal: siblingsTotal);
                  await controller.updateStudent(s2);
                }

                nameController.clear();
                if (selectedGroup?.price != null) {
                  priceController.text = selectedGroup!.price!.toStringAsFixed(2);
                } else {
                  priceController.clear();
                }
                if (selectedGroup?.id != null && (selectedGroup!.code?.isNotEmpty ?? false)) {
                  final next = await controller.generateNextStudentCode(
                    groupPrefix: selectedGroup!.code!,
                    groupId: selectedGroup!.id!,
                  );
                  codeController.text = next;
                } else {
                  codeController.clear();
                }
                setSt(() {
                  selectedSibling = null;
                  siblingsTotalController.clear();
                  attendanceStart = DateTime.now();
                  guardianPhoneController.clear();
                });


              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(
    BuildContext context,
    StudentController controller,
    Student student,
  ) async {
    final nameController = TextEditingController(text: student.name);
    final priceController = TextEditingController(text: student.price.toString());
    final guardianPhoneController = TextEditingController(text: student.guardianPhone ?? '');

    final groups = await controller.loadAllGroups();
    Group? selectedGroup;
    for (final g in groups) {
      if (g.id == student.groupId) {
        selectedGroup = g;
        break;
      }
    }
    selectedGroup ??= (groups.isNotEmpty ? groups.first : null);

    Student? selectedSibling;
    if (student.siblingId != null) {
      selectedSibling = await DatabaseService().getStudent(student.siblingId!);
    }
    final siblingsTotalController = TextEditingController(
      text: student.siblingsTotal != null ? student.siblingsTotal!.toString() : '',
    );
    DateTime? attendanceStart = student.attendanceStart ?? DateTime.now();

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
                  DropdownButtonFormField<Group>(
                    initialValue: selectedGroup,
                    decoration: const InputDecoration(labelText: 'المجموعة'),
                    items: groups
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g.name + (g.price != null ? ' • ${FormatHelper.formatCurrency(g.price)}' : '')),
                            ))
                        .toList(),
                    onChanged: (g) => selectedGroup = g,
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
                  const SizedBox(height: SPACING_LARGE),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final all = await DatabaseService().getAllStudents();
                        if (!context.mounted) return;
                        final list = all.where((s) => s.id != student.id).toList();
                        Student? picked;
                        await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('اختر الأخ'),
                            content: SizedBox(
                              width: 400,
                              height: 300,
                              child: ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (c, i) {
                                  final s = list[i];
                                  return ListTile(
                                    title: Text(s.name),
                                    subtitle: Text('الكود: ${s.code}') ,
                                    onTap: () {
                                      picked = s;
                                      Navigator.of(c).pop();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                        if (picked != null) {
                          setSt(() => selectedSibling = picked);
                        }
                      },
                      icon: const Icon(Icons.group_add),
                      label: const Text('إضافة أخ'),
                    ),
                  ),
                  if (selectedSibling != null) ...[
                    Row(
                      children: [
                        Expanded(child: Text('الأخ: ${selectedSibling!.name} (${selectedSibling!.code})')),
                        IconButton(
                          onPressed: () => setSt(() => selectedSibling = null),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: SPACING_NORMAL),
                    CustomTextField(
                      controller: siblingsTotalController,
                      label: 'إجمالي الأخوين للشهر',
                      keyboardType: TextInputType.number,
                    ),
                  ],
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
              label: 'حفظ',
              onPressed: () async {
                final prevSiblingId = student.siblingId;
                final newTotal = selectedSibling != null
                    ? double.tryParse(siblingsTotalController.text.trim())
                    : null;
                if (selectedSibling != null && newTotal == null) {
                  ToastHelper.info('يرجى إدخال إجمالي الأخوين');
                  return;
                }

                final updated = student.copyWith(
                  name: nameController.text.trim(),
                  price: double.tryParse(priceController.text.trim()) ?? student.price,
                  groupId: selectedGroup?.id ?? student.groupId,
                  siblingId: selectedSibling?.id,
                  siblingsTotal: selectedSibling != null ? newTotal : null,
                  attendanceStart: attendanceStart,
                  guardianPhone: guardianPhoneController.text.trim().isEmpty ? null : guardianPhoneController.text.trim(),
                );

                await controller.updateStudent(updated);

                final db = DatabaseService();
                if (prevSiblingId != null && (selectedSibling == null || prevSiblingId != selectedSibling!.id)) {
                  final prev = await db.getStudent(prevSiblingId);
                  if (prev != null) {
                    final cleared = prev.copyWith(siblingId: null, siblingsTotal: null);
                    await db.updateStudent(cleared);
                    final idx = controller.students.indexWhere((s) => s.id == cleared.id);
                    if (idx != -1) controller.students[idx] = cleared;
                    controller.filterStudents();
                  }
                }

                if (selectedSibling != null) {
                  final sib = await db.getStudent(selectedSibling!.id!);
                  if (sib != null) {
                    final linked = sib.copyWith(siblingId: student.id, siblingsTotal: newTotal);
                    await db.updateStudent(linked);
                    final idx = controller.students.indexWhere((s) => s.id == linked.id);
                    if (idx != -1) controller.students[idx] = linked;
                    controller.filterStudents();
                  }
                }

                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    StudentController controller,
    Student student,
  ) {
    if (student.id == null) return;
    controller.deleteStudent(student.id!);
  }

  void _showQRDialog(BuildContext context, Student student) {
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
                    final ok = await _saveStudentQrImage(student);
                    if (!ctx.mounted) return;
                    if (ok) {
                      ToastHelper.success('تم حفظ صورة QR بنجاح');
                    } else {
                      ToastHelper.error('تعذر حفظ صورة QR');
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('حفظ الصورة'),
                )
              ],
            );
          },
        );
      },
    );
  }

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

      final textStyleTitle = const TextStyle(color: Colors.black, fontSize: 48, fontWeight: FontWeight.w600, fontFamily: 'Cairo');
      final textStyleSub = const TextStyle(color: Colors.black, fontSize: 36, fontFamily: 'Cairo');

      final tpName = TextPainter(
        text: TextSpan(text: student.name, style: textStyleTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());

      final groupLine = groupName == null || groupName.isNotEmpty == false ? null : 'المجموعة: $groupName';
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
}
