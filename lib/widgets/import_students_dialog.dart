// lib/widgets/import_students_dialog.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/services/excel_import_service.dart';
import 'package:active_class/widgets/app_toast.dart';

/// يفتح مودال استيراد طلاب من ملف Excel لمجموعة واحدة.
/// [preselectedGroup] : لو موجودة يتم تخطي خطوة اختيار المجموعة.
/// [onImported]        : بينادَى بعد استيراد ناجح (ولو جزئي).
Future<void> showImportStudentsDialog(
  BuildContext context, {
  required StudentController controller,
  required List<Group> groups,
  Group? preselectedGroup,
  VoidCallback? onImported,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: _ImportStudentsDialog(
        controller: controller,
        groups: groups,
        preselectedGroup: preselectedGroup,
        onImported: onImported,
      ),
    ),
  );
}

enum _Step { pickGroup, uploadOrTemplate, preview, importing, result }

class _ImportStudentsDialog extends StatefulWidget {
  final StudentController controller;
  final List<Group> groups;
  final Group? preselectedGroup;
  final VoidCallback? onImported;

  const _ImportStudentsDialog({
    required this.controller,
    required this.groups,
    this.preselectedGroup,
    this.onImported,
  });

  @override
  State<_ImportStudentsDialog> createState() => _ImportStudentsDialogState();
}

class _ImportStudentsDialogState extends State<_ImportStudentsDialog> {
  late _Step _step;
  Group? _selectedGroup;
  List<ImportRowResult> _rows = [];
  bool _busy = false;
  String? _busyMessage;
  int _importedCount = 0;
  final List<String> _failures = [];

  Color get _primary {
    final c = _selectedGroup?.color;
    return c != null ? Color(c) : const Color(0xFF1E88E5);
  }

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.preselectedGroup;
    _step = _selectedGroup != null ? _Step.uploadOrTemplate : _Step.pickGroup;
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, msg);
    } else {
      AppToast.success(context, msg);
    }
  }

  Future<void> _downloadTemplate() async {
    final group = _selectedGroup;
    if (group == null) return;
    setState(() => _busy = true);
    try {
      final file = await ExcelImportService().buildTemplateFile(group: group);
      final savedUri = await ExcelImportService().saveTemplateToDownloads(file);
      if (savedUri != null) {
        _toast('تم حفظ القالب في مجلد التنزيلات (ActiveClass)');
      } else {
        // فشل الحفظ المباشر (مثلاً صلاحيات مرفوضة) — نرجع لقائمة المشاركة.
        await ExcelImportService().shareTemplate(file, group: group);
      }
    } catch (_) {
      _toast('تعذر إنشاء القالب', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareTemplate() async {
    final group = _selectedGroup;
    if (group == null) return;
    setState(() => _busy = true);
    try {
      final file = await ExcelImportService().buildTemplateFile(group: group);
      await ExcelImportService().shareTemplate(file, group: group);
    } catch (_) {
      _toast('تعذر إنشاء القالب', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    final group = _selectedGroup;
    if (group == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final rows = ExcelImportService().parseFile(File(path), group: group);
      if (rows.isEmpty) {
        _toast('الملف فارغ أو لا يحتوي على بيانات', isError: true);
        return;
      }
      setState(() {
        _rows = rows;
        _step = _Step.preview;
      });
    } catch (_) {
      _toast('تعذر قراءة الملف — تأكد إنه بصيغة .xlsx وبنفس تنسيق القالب', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    final group = _selectedGroup;
    if (group == null || group.id == null) return;
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _step = _Step.importing;
      _importedCount = 0;
      _failures.clear();
    });

    for (var i = 0; i < validRows.length; i++) {
      final row = validRows[i];
      if (!mounted) return;
      setState(() => _busyMessage = 'جاري إضافة الطالب ${i + 1} من ${validRows.length}');

      final code = await widget.controller.generateNextStudentCode(
        groupPrefix: group.code ?? '',
        groupId: group.id!,
      );

      final student = Student(
        name: row.name,
        code: code,
        groupId: group.id!,
        price: row.price ?? group.price ?? 0,
        createdAt: DateTime.now(),
        attendanceStart: row.attendanceStart ?? DateTime.now(),
        guardianPhone: row.phone,
        birthDate: row.birthDate,
      );

      final created = await widget.controller.addStudent(student);
      if (created == null) {
        // فشل الإضافة (على الأغلب حد الترخيص) — نوقف الاستيراد فوراً.
        _failures.add('${row.name}: تعذّرت الإضافة (راجع حد الترخيص)');
        break;
      }
      _importedCount++;
    }

    if (mounted) {
      setState(() {
        _step = _Step.result;
        _busyMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 480,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 20),
            Flexible(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 4, 0),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.upload_file_rounded, color: _primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('استيراد طلاب من Excel',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            Text(
              _selectedGroup != null ? 'المجموعة: ${_selectedGroup!.name}' : 'اختر المجموعة أولاً',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ]),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ]),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_step) {
      case _Step.pickGroup:
        return _buildPickGroup(context);
      case _Step.uploadOrTemplate:
        return _buildUploadOrTemplate(context);
      case _Step.preview:
        return _buildPreview(context);
      case _Step.importing:
        return _buildImporting(context);
      case _Step.result:
        return _buildResult(context);
    }
  }

  // ── خطوة 1: اختيار المجموعة ────────────────────────────────────────
  Widget _buildPickGroup(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('اختر المجموعة اللي عايز تستورد لها الطلاب',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        if (widget.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('لا توجد مجموعات بعد — أنشئ مجموعة أولاً'),
          )
        else
          ...widget.groups.map((g) {
            final color = g.color != null ? Color(g.color!) : const Color(0xFF1E88E5);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  _selectedGroup = g;
                  _step = _Step.uploadOrTemplate;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    Icon(Icons.chevron_left_rounded, color: color),
                  ]),
                ),
              ),
            );
          }),
      ]),
    );
  }

  // ── خطوة 2: القالب والرفع ──────────────────────────────────────────
  Widget _buildUploadOrTemplate(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الأعمدة المطلوبة في الملف',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _primary)),
            const SizedBox(height: 8),
            _ColRow(label: 'اسم الطالب', required: true),
            _ColRow(label: 'رقم ولي الأمر', required: false),
            _ColRow(label: 'الرسوم (تُستخدم رسوم المجموعة لو فاضية)', required: false),
            _ColRow(label: 'تاريخ الميلاد (يوم/شهر/سنة)', required: false),
            _ColRow(label: 'تاريخ بداية الحضور (افتراضي: اليوم)', required: false),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _downloadTemplate,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('تحميل قالب Excel'),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _busy ? null : _shareTemplate,
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('أو شارك الملف بدل الحفظ', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: _busy ? null : _pickFile,
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.attach_file_rounded),
          label: const Text('اختيار ملف الطلاب المعبأ'),
        ),
      ]),
    );
  }

  // ── خطوة 3: المعاينة ──────────────────────────────────────────────
  Widget _buildPreview(BuildContext context) {
    final validCount = _rows.where((r) => r.isValid).length;
    final errorCount = _rows.length - validCount;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          _SummaryChip(label: '$validCount صالح', color: Colors.green),
          const SizedBox(width: 8),
          if (errorCount > 0) _SummaryChip(label: '$errorCount به خطأ', color: Colors.red),
        ]),
      ),
      const SizedBox(height: 10),
      Flexible(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          itemCount: _rows.length,
          itemBuilder: (_, i) {
            final row = _rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: row.isValid
                    ? Colors.green.withValues(alpha: 0.06)
                    : Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: row.isValid
                      ? Colors.green.withValues(alpha: 0.25)
                      : Colors.red.withValues(alpha: 0.25),
                ),
              ),
              child: Row(children: [
                Icon(
                  row.isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  size: 18,
                  color: row.isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      row.name.isEmpty ? 'صف ${row.rowNumber}' : row.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (row.isValid)
                      Text(
                        'الرسوم: ${row.price?.toStringAsFixed(0) ?? "رسوم المجموعة"}'
                        '${row.phone != null ? " • ${row.phone}" : ""}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      )
                    else
                      Text(row.error ?? '', style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = _Step.uploadOrTemplate),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('رجوع'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: validCount == 0 ? null : _confirmImport,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.upload_rounded),
              label: Text('استيراد $validCount طالب',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── خطوة 4: جاري التنفيذ ──────────────────────────────────────────
  Widget _buildImporting(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _primary),
        const SizedBox(height: 16),
        Text(_busyMessage ?? 'جاري الاستيراد...', style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── خطوة 5: النتيجة ───────────────────────────────────────────────
  Widget _buildResult(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          _importedCount > 0 ? Icons.check_circle_rounded : Icons.error_rounded,
          color: _importedCount > 0 ? Colors.green : Colors.red,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text('تم استيراد $_importedCount طالب بنجاح',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        if (_failures.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._failures.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(f, style: const TextStyle(fontSize: 12, color: Colors.red)),
              )),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onImported?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('تم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _ColRow extends StatelessWidget {
  final String label;
  final bool required;
  const _ColRow({required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(
          required ? Icons.star_rounded : Icons.circle_outlined,
          size: 12,
          color: required ? Colors.orange : Colors.grey,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
