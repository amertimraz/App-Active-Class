import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
// Added for Android gallery and Downloads saving
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:intl/intl.dart';

class QrGalleryPage extends StatefulWidget {
  const QrGalleryPage({super.key});

  @override
  State<QrGalleryPage> createState() => _QrGalleryPageState();
}

class _QrGalleryPageState extends State<QrGalleryPage> {
  final DatabaseService _db = DatabaseService();
  List<Group> _groups = [];
  List<Student> _all = [];
  List<Student> _filtered = [];
  Group? _selectedGroup;
  String _query = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _db.getAllGroups();
    final students = await _db.getAllStudents();
    setState(() {
      _groups = groups;
      _all = students..sort((a,b)=>a.name.compareTo(b.name));
    });
    _applyFilters();
  }

  void _applyFilters() {
    List<Student> list = List.of(_all);
    if (_selectedGroup != null) {
      list = list.where((s) => s.groupId == _selectedGroup!.id).toList();
    }
    if (_query.trim().isNotEmpty) {
      list = list.where((s) => s.name.contains(_query) || s.code.contains(_query)).toList();
    }
    if (_dateRange != null) {
      list = list.where((s) {
        final d = s.createdAt;
        if (d == null) return true;
        return d.isAfter(_dateRange!.start.subtract(const Duration(seconds:1))) && d.isBefore(_dateRange!.end.add(const Duration(seconds:1)));
      }).toList();
    }
    setState(() => _filtered = list);
  }

  Future<bool> _saveQrPng(Student s) async {
    try {
      // Resolve group name
      final groupName = _groups.firstWhereOrNull((g) => g.id == s.groupId)?.name;

      // Sizes
      const int qrSize = 700; // px
      const double padding = 40; // around content
      const double spacing = 24; // between QR and text

      // Prepare QR image (square, high resolution for better scanning)
      final painter = QrPainter(
        data: s.code,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
      );
      final qrImage = await painter.toImage(qrSize.toDouble());

      // Prepare texts
      final textStyleTitle = const TextStyle(color: Colors.black, fontSize: 60, fontWeight: FontWeight.w600, fontFamily: 'Cairo');
      final textStyleSub = const TextStyle(color: Colors.black, fontSize: 42, fontFamily: 'Cairo');

      final tpName = TextPainter(
        text: TextSpan(text: s.name, style: textStyleTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());

      final groupLine = groupName == null ? null : 'المجموعة: $groupName';
      final tpGroup = groupLine == null
          ? null
          : (TextPainter(
              text: TextSpan(text: groupLine, style: textStyleSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
            )..layout(maxWidth: qrSize.toDouble()));

      final codeLine = 'الكود: ${s.code}';
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

      // Draw QR centered on top portion
      final double qrLeft = (widthPx - qrSize) / 2;
      final double qrTop = padding;
      final srcRect = Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble());
      final dstRect = Rect.fromLTWH(qrLeft, qrTop, qrSize.toDouble(), qrSize.toDouble());
      canvas.drawImageRect(qrImage, srcRect, dstRect, Paint());

      // Draw texts centered below
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

      // Request storage permission (older Androids)
      await Permission.storage.request();

      // Save via MediaStore so it appears immediately in Gallery
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = "ActiveClass";
      final tmpDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final safeName = s.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '_');
      final tmpFile = File('${tmpDir.path}/QR_${safeName}_${s.code}_$dateStr.png');
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
              await _db.updateStudent(s.copyWith(qrPath: path));
            }
          }
        } catch (_) {}
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> _composeCardPng(Student s) async {
    try {
      final groupName = _groups.firstWhereOrNull((g) => g.id == s.groupId)?.name;
      const int qrSize = 700;
      const double padding = 40;
      const double spacing = 24;

      final painter = QrPainter(
        data: s.code,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
      );
      final qrImage = await painter.toImage(qrSize.toDouble());

      final textStyleTitle = const TextStyle(color: Colors.black, fontSize: 60, fontWeight: FontWeight.w600, fontFamily: 'Cairo');
      final textStyleSub = const TextStyle(color: Colors.black, fontSize: 42, fontFamily: 'Cairo');

      final tpName = TextPainter(
        text: TextSpan(text: s.name, style: textStyleTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());

      final groupLine = groupName == null ? null : 'المجموعة: $groupName';
      final tpGroup = groupLine == null
          ? null
          : (TextPainter(
              text: TextSpan(text: groupLine, style: textStyleSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
            )..layout(maxWidth: qrSize.toDouble()));

      final codeLine = 'الكود: ${s.code}';
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
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildPdf({required bool useCairo}) async {
    final pdf = pw.Document();

    const perRow = 4;
    const perCol = 5;
    const perPage = perRow * perCol;

    for (int i=0; i<_filtered.length; i+=perPage) {
      final chunk = _filtered.skip(i).take(perPage).toList();
      final images = <String, pw.MemoryImage>{};
      for (final s in chunk) {
        final bytes = await _composeCardPng(s);
        if (bytes != null) images[s.code] = pw.MemoryImage(bytes);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) {
            final spacing = 10.0;
            final cellWidth = (PdfPageFormat.a4.availableWidth - spacing * (perRow - 1)) / perRow;
            final cardHeight = cellWidth * 1.45;
            return pw.Wrap(
              alignment: pw.WrapAlignment.center,
              runAlignment: pw.WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final s in chunk)
                  pw.Container(
                    width: cellWidth,
                    height: cardHeight,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: images[s.code] == null
                        ? pw.SizedBox.shrink()
                        : pw.Center(child: pw.Image(images[s.code]!, fit: pw.BoxFit.contain)),
                  ),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  Future<void> _exportPdf() async {
    try {
      Uint8List bytes;
      try {
        bytes = await _buildPdf(useCairo: true);
      } catch (_) {
        bytes = await _buildPdf(useCairo: false);
      }

      if (Platform.isAndroid) {
        await Permission.storage.request();
        try { await Permission.manageExternalStorage.request(); } catch (_) {}
        await MediaStore.ensureInitialized();
        MediaStore.appFolder = "ActiveClass";

        final tmpDir = await getTemporaryDirectory();
        final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
        final groupPart = _selectedGroup == null ? '' : '_${_selectedGroup!.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '_')}';
        final tmpPdf = File('${tmpDir.path}/students_qr${groupPart}_$dateStr.pdf');
        await tmpPdf.writeAsBytes(bytes, flush: true);

        final saveInfo = await MediaStore().saveFile(
          tempFilePath: tmpPdf.path,
          dirType: DirType.download,
          dirName: DirType.download.defaults,
        );

        if (!mounted) return;
        if (saveInfo?.uri != null) {
          ToastHelper.success('تم إنشاء PDF في التنزيلات');
          return;
        }
      }

      final targetDir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final groupPart = _selectedGroup == null ? '' : '_${_selectedGroup!.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), '_')}';
      final file = File('${targetDir.path}/students_qr${groupPart}_$dateStr.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ToastHelper.success('تم إنشاء PDF: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      ToastHelper.error('تعذر إنشاء ملف PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معرض أكواد QR للطلاب'),
        actions: [
          IconButton(
            onPressed: _filtered.isEmpty ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PADDING_NORMAL),
            child: Row(
              children: [
                // Group filter
                Expanded(
                  child: DropdownButtonFormField<Group?>(
                    initialValue: _selectedGroup,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المجموعة'),
                    items: [
                      const DropdownMenuItem<Group?>(value: null, child: Text('الكل')),
                      ..._groups.map((g) => DropdownMenuItem<Group?>(value: g, child: Text(g.name))),
                    ],
                    onChanged: (g) {
                      setState(() => _selectedGroup = g);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Search
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'بحث بالاسم أو الكود'),
                    onChanged: (v) { _query = v; _applyFilters(); },
                  ),
                ),
                const SizedBox(width: 12),
                // Date filter
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final res = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: _dateRange,
                      );
                      if (res != null) {
                        setState(() => _dateRange = res);
                        _applyFilters();
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _dateRange == null
                          ? 'كل التواريخ'
                          : '${FormatHelper.formatDate(_dateRange!.start)} - ${FormatHelper.formatDate(_dateRange!.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('لا توجد نتائج'))
                : GridView.builder(
                    padding: const EdgeInsets.all(PADDING_NORMAL),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final s = _filtered[i];
                      final groupName = _groups.firstWhereOrNull((g) => g.id == s.groupId)?.name;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (ctx, c) {
                              const reserved = 120.0;
                              final maxQr = math.max(96.0, math.min(c.maxWidth - 24, c.maxHeight - reserved));
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (groupName != null) Text('المجموعة: $groupName', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: SizedBox(
                                          width: maxQr,
                                          height: maxQr,
                                          child: QrImageView(
                                            data: s.code,
                                            version: QrVersions.auto,
                                            size: maxQr,
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('الكود: ${s.code}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          _saveQrPng(s).then((ok) {
                                            if (ok) {
                                              ToastHelper.success('تم حفظ الصورة');
                                            } else {
                                              ToastHelper.error('تعذر الحفظ');
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.download),
                                        tooltip: 'حفظ الصورة',
                                      ),
                                    ],
                                  )
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
