import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, ValueListenable;
import 'package:get/get.dart';
import 'package:active_class/utils/responsive.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/views/help/help_widgets.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';

class QrGalleryPage extends StatefulWidget {
  const QrGalleryPage({super.key});

  @override
  State<QrGalleryPage> createState() => _QrGalleryPageState();
}

enum _QrSort { name, code, newest }

class _QrGalleryPageState extends State<QrGalleryPage> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  List<Group> _groups = [];
  Map<int?, Group> _groupById = {};
  Map<int?, int> _groupCounts = {};
  List<String> _centers = [];
  List<Student> _all = [];
  List<Student> _filtered = [];
  Group? _selectedGroup;
  String? _selectedCenter;
  // فلتر فترة الانضمام: null = كل الطلاب
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _QrSort _sort = _QrSort.name;

  // التحديد: لو فيه طلاب محددين، التصدير بيشمل المحددين بس (حتى لو من
  // مجموعات مختلفة)، وإلا بيشمل كل المعروض.
  final Set<int> _selected = {};

  // محتوى البطاقة المطبوعة
  bool _showGroupOnCard = true;
  bool _showCodeOnCard = true;

  // كاش صور البطاقات: التصدير المتكرر (PDF ثم ZIP) ميرسمش من الأول.
  final Map<String, Uint8List> _pngCache = {};
  static const int _pngCacheMax = 300;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), _applyFilters);
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groups = await _db.getAllGroups();
    // معرض QR شغل يومي نشط (طباعة/تصدير أكواد) — الطلاب المؤرشفين
    // مستبعدين.
    final students =
        (await _db.getAllStudents()).where((s) => !s.isArchived).toList();
    if (!mounted) return;
    final counts = <int?, int>{};
    for (final s in students) {
      counts[s.groupId] = (counts[s.groupId] ?? 0) + 1;
    }
    final centers = {
      for (final g in groups)
        if (GroupController.normalizeCenter(g.center) != null)
          GroupController.normalizeCenter(g.center)!
    }.toList()
      ..sort();
    setState(() {
      _groups = groups;
      _groupById = {for (final g in groups) g.id: g};
      _groupCounts = counts;
      _centers = centers;
      if (_selectedCenter != null && !centers.contains(_selectedCenter)) {
        _selectedCenter = null;
      }
      _all = students;
      _loading = false;
      // نشيل من التحديد أي طالب اتحذف/اتأرشف من ساعة آخر تحميل.
      final live = {for (final s in students) s.id};
      _selected.removeWhere((id) => !live.contains(id));
    });
    _applyFilters();
  }

  /// المجموعات المعروضة كشرائح: كلها، أو اللي تحت السنتر المختار.
  List<Group> get _groupsInCenter => _selectedCenter == null
      ? _groups
      : _groups
          .where((g) =>
              GroupController.normalizeCenter(g.center) == _selectedCenter)
          .toList();

  void _setCenter(String? center) {
    _selectedCenter = center;
    // لو المجموعة المختارة مش تحت السنتر الجديد نرجع لـ«كل المجموعات».
    if (_selectedGroup != null &&
        center != null &&
        GroupController.normalizeCenter(_selectedGroup!.center) != center) {
      _selectedGroup = null;
    }
    _applyFilters();
  }

  void _setGroup(Group? g) {
    _selectedGroup = g;
    _applyFilters();
  }

  int _compareCodes(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  List<Student> _sorted(List<Student> list) {
    switch (_sort) {
      case _QrSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _QrSort.code:
        list.sort((a, b) => _compareCodes(a.code, b.code));
      case _QrSort.newest:
        DateTime key(Student s) =>
            s.attendanceStart ??
            s.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        list.sort((a, b) => key(b).compareTo(key(a)));
    }
    return list;
  }

  /// اللي هيتصدّر: المحددين لو فيه تحديد، وإلا كل المعروض.
  List<Student> get _exportList => _selected.isEmpty
      ? _filtered
      : _sorted(_all.where((s) => _selected.contains(s.id)).toList());

  void _applyFilters() {
    if (!mounted) return;
    List<Student> list = List.of(_all);
    if (_selectedGroup != null) {
      list = list.where((s) => s.groupId == _selectedGroup!.id).toList();
    } else if (_selectedCenter != null) {
      final ids = {for (final g in _groupsInCenter) g.id};
      list = list.where((s) => ids.contains(s.groupId)).toList();
    }
    if (_dateFrom != null || _dateTo != null) {
      list = list.where((s) {
        // attendanceStart هو تاريخ الانضمام الفعلي اللي المدرّس بيحدده
        // (بيتحدد دايمًا عند الإضافة)؛ createdAt احتياطي للبيانات
        // القديمة اللي معندهاش قيمة.
        final d = s.attendanceStart ?? s.createdAt;
        if (d == null) return false;
        if (_dateFrom != null && d.isBefore(_dateFrom!)) return false;
        if (_dateTo != null && d.isAfter(_dateTo!)) return false;
        return true;
      }).toList();
    }
    final q = _searchCtrl.text.trim();
    if (q.isNotEmpty) {
      list = list
          .where((s) => s.name.contains(q) || s.code.contains(q))
          .toList();
    }
    setState(() => _filtered = _sorted(list));
  }

  void _showDateRangeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DateRangeSheet(
        initialFrom: _dateFrom,
        initialTo: _dateTo,
        onApply: (from, to) {
          _dateFrom = from;
          _dateTo = to != null
              ? DateTime(to.year, to.month, to.day, 23, 59, 59)
              : null;
          _applyFilters();
        },
      ),
    );
  }

  // ─── QR image helpers (unchanged logic) ──────────────────────────────────

  Future<bool> _saveQrPng(Student s) async {
    try {
      final bytes = await _composeCardPng(s);
      if (bytes == null) return false;

      await Permission.storage.request();
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'ActiveClass';

      final tmpDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final safeName = s.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), '_');
      final tmpFile = File(
          '${tmpDir.path}/QR_${safeName}_${s.code}_$dateStr.png');
      await tmpFile.writeAsBytes(bytes, flush: true);

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
        try {
          final path = await MediaStore()
              .getFilePathFromUri(uriString: saveInfo!.uri.toString());
          if (path != null && path.isNotEmpty) {
            await _db.updateStudent(s.copyWith(qrPath: path));
          }
        } catch (_) {}
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// ينشئ PNG للطالب بدون toImage() وسطية — يرسم QR مباشرة على Canvas
  Future<Uint8List?> _composeCardPng(Student s) async {
    final key =
        '${s.code}|${s.name}|${_groupById[s.groupId]?.name}|$_showGroupOnCard|$_showCodeOnCard';
    final hit = _pngCache[key];
    if (hit != null) return hit;
    final bytes = await _composeCardPngRaw(s);
    if (bytes != null) {
      if (_pngCache.length >= _pngCacheMax) {
        _pngCache.remove(_pngCache.keys.first);
      }
      _pngCache[key] = bytes;
    }
    return bytes;
  }

  Future<Uint8List?> _composeCardPngRaw(Student s) async {
    try {
      // yield للـ event loop حتى لا يتعطل الـ UI
      await Future.delayed(Duration.zero);

      final groupName =
          _showGroupOnCard ? _groupById[s.groupId]?.name : null;
      const int qrSize = 700;
      const double padding = 40;
      const double spacing = 24;

      // نصوص
      const textStyleTitle = TextStyle(
          color: Colors.black, fontSize: 60,
          fontWeight: FontWeight.w600, fontFamily: 'Cairo');
      const textStyleSub = TextStyle(
          color: Colors.black, fontSize: 42, fontFamily: 'Cairo');

      final tpName = TextPainter(
        text: TextSpan(text: s.name, style: textStyleTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());

      final groupLine =
          groupName == null ? null : 'المجموعة: $groupName';
      final tpGroup = groupLine == null
          ? null
          : (TextPainter(
              text: TextSpan(text: groupLine, style: textStyleSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
            )..layout(maxWidth: qrSize.toDouble()));

      final tpCode = !_showCodeOnCard
          ? null
          : (TextPainter(
              text: TextSpan(text: 'الكود: ${s.code}', style: textStyleSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.ltr,
            )..layout(maxWidth: qrSize.toDouble()));

      final double textHeight = tpName.height +
          (tpGroup?.height ?? 0) +
          (tpCode?.height ?? 0) +
          spacing * 2;
      final int widthPx = (qrSize + padding * 2).round();
      final int heightPx =
          (padding + qrSize + spacing + textHeight + padding).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // خلفية بيضاء
      canvas.drawRect(
          Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
          Paint()..color = const Color(0xFFFFFFFF));

      // ارسم QR مباشرة على Canvas (لا toImage() وسطية)
      final qrLeft = (widthPx - qrSize) / 2;
      canvas.save();
      canvas.translate(qrLeft, padding);
      QrPainter(
        data: s.code,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF000000)),
      ).paint(canvas, Size(qrSize.toDouble(), qrSize.toDouble()));
      canvas.restore();

      // رسم النصوص
      double cursorY = padding + qrSize + spacing;
      tpName.paint(
          canvas, Offset((widthPx - tpName.width) / 2, cursorY));
      cursorY += tpName.height + 8;
      if (tpGroup != null) {
        tpGroup.paint(
            canvas, Offset((widthPx - tpGroup.width) / 2, cursorY));
        cursorY += tpGroup.height + 8;
      }
      tpCode?.paint(
          canvas, Offset((widthPx - tpCode.width) / 2, cursorY));

      // toImageSync: لا ينتظر الـ raster thread — يعمل على الـ UI thread مباشرة
      final picture = recorder.endRecording();
      final composed = picture.toImageSync(widthPx, heightPx);
      final byteData =
          await composed.toByteData(format: ui.ImageByteFormat.png);
      composed.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  // ─── Export flow ─────────────────────────────────────────────────────────

  void _showExportDialog() {
    final list = _exportList;
    if (list.isEmpty) {
      ToastHelper.error('لا يوجد طلاب لتصديرهم');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExportOptionsSheet(
        studentCount: list.length,
        groupName: _selected.isNotEmpty ? 'المحددين' : _selectedGroup?.name,
        students: list,
        groups: _groups,
        onExport: (cols, rows, margin) {
          Get.back();
          _exportPdf(perRow: cols, perCol: rows, pageMargin: margin);
        },
      ),
    );
  }

  Future<void> _exportPdf({int perRow = 3, int perCol = 4, double pageMargin = 14.0}) async {
    final list = _exportList;
    final progress = ValueNotifier<int>(0);
    // Progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(
          total: list.length,
          label: 'جاري إنشاء الـ PDF...',
          progress: progress),
    );

    try {
      // المرحلة الأولى: نرسم صور الـ QR على الـ UI isolate (لازم dart:ui)
      // مع yield بين كل طالب حتى تبقى الواجهة مستجيبة.
      final images = <String, Uint8List>{};
      for (final s in list) {
        final bytes = await _composeCardPng(s);
        if (bytes != null) images[s.code] = bytes;
        progress.value++;
      }

      // المرحلة الثانية: بناء وتجميع الـ PDF عملية Dart خالصة (بدون dart:ui)
      // ننفذها في isolate منفصل حتى لا تجمّد الواجهة أثناء save().
      final bytes = await compute(
        _buildQrPdfBytes,
        _QrPdfBuildArgs(
          codes: list.map((s) => s.code).toList(),
          images: images,
          perRow: perRow,
          perCol: perCol,
          pageMargin: pageMargin,
        ),
      );

      if (!mounted) return;
      Get.back(); // close progress

      await _savePdfBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      Get.back();
      ToastHelper.error('تعذر إنشاء ملف PDF: $e');
    } finally {
      progress.dispose();
    }
  }

  Future<void> _savePdfBytes(Uint8List bytes) async {
    final dateStr   = DateFormat('yyyyMMdd').format(DateTime.now());
    final groupPart = _selected.isNotEmpty
        ? '_selection'
        : _selectedGroup == null
        ? ''
        : '_${_selectedGroup!.name.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_')}';
    final fileName = 'students_qr${groupPart}_$dateStr.pdf';

    // احفظ في temp ثم شارك (يعمل على كل الأجهزة)
    final tmpDir  = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/$fileName');
    await tmpFile.writeAsBytes(bytes, flush: true);

    if (!mounted) return;

    // حاول حفظ في Downloads أولاً
    bool savedToDownloads = false;
    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
        await MediaStore.ensureInitialized();
        MediaStore.appFolder = 'ActiveClass';
        final info = await MediaStore().saveFile(
          tempFilePath: tmpFile.path,
          dirType: DirType.download,
          dirName: DirType.download.defaults,
        );
        savedToDownloads = info?.uri != null;
      } catch (_) {}
    }

    // MediaStore.saveFile() يحذف الملف المؤقت الأصلي بعد نسخه إلى
    // التنزيلات — بغض النظر عن قيمة savedToDownloads (اللي ممكن
    // تطلع غلط في نسخة الـ release بسبب تشويه أسماء الحقول عند تصغير
    // الكود؛ ده بيكسر تحويل JSON بتاع المكتبة). فبنتأكد من وجود
    // الملف مباشرة بدل ما نعتمد على الفلاج.
    if (!await tmpFile.exists()) {
      await tmpFile.writeAsBytes(bytes, flush: true);
    }

    if (!mounted) return;
    if (savedToDownloads) {
      ToastHelper.success('تم حفظ PDF في التنزيلات ✓');
    }

    // عرض modal المشاركة
    if (!mounted) return;
    await _showShareSheet(
      filePath: tmpFile.path,
      fileName: fileName,
      mimeType: 'application/pdf',
      icon: Icons.picture_as_pdf_rounded,
      color: const Color(0xFF6366F1),
      savedToDownloads: savedToDownloads,
    );
  }

  // ─── ZIP export ──────────────────────────────────────────────────────────

  Future<void> _exportZip() async {
    final list = _exportList;
    if (list.isEmpty) {
      ToastHelper.error('لا يوجد طلاب لتصديرهم');
      return;
    }

    final progress = ValueNotifier<int>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(
          total: list.length,
          label: 'جاري إنشاء ملف ZIP...',
          progress: progress),
    );

    try {
      final archive = Archive();

      for (int i = 0; i < list.length; i++) {
        final s     = list[i];
        final bytes = await _composeCardPng(s);
        progress.value++;
        if (bytes == null) continue;
        archive.addFile(ArchiveFile('${s.code}.png', bytes.length, bytes));
      }

      final zipBytes = await compute(_encodeZipBytes, archive);

      if (!mounted) return;
      Get.back(); // close progress

      final dateStr   = DateFormat('yyyyMMdd').format(DateTime.now());
      final groupPart = _selected.isNotEmpty
          ? '_selection'
          : _selectedGroup == null
          ? ''
          : '_${_selectedGroup!.name.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_')}';
      final fileName = 'qr_codes${groupPart}_$dateStr.zip';
      final tmpDir  = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/$fileName');
      await tmpFile.writeAsBytes(zipBytes, flush: true);

      if (!mounted) return;

      // حاول حفظ في Downloads
      bool savedToDownloads = false;
      if (Platform.isAndroid) {
        try {
          await Permission.storage.request();
          await MediaStore.ensureInitialized();
          MediaStore.appFolder = 'ActiveClass';
          final info = await MediaStore().saveFile(
            tempFilePath: tmpFile.path,
            dirType: DirType.download,
            dirName: DirType.download.defaults,
          );
          savedToDownloads = info?.uri != null;
        } catch (_) {}
      }

      // MediaStore.saveFile() يحذف الملف المؤقت الأصلي بعد نسخه إلى
      // التنزيلات — بغض النظر عن قيمة savedToDownloads (اللي ممكن
      // تطلع غلط في نسخة الـ release بسبب تشويه أسماء الحقول عند تصغير
      // الكود؛ ده بيكسر تحويل JSON بتاع المكتبة). فبنتأكد من وجود
      // الملف مباشرة بدل ما نعتمد على الفلاج.
      if (!await tmpFile.exists()) {
        await tmpFile.writeAsBytes(zipBytes, flush: true);
      }

      if (!mounted) return;

      // عرض modal المشاركة
      await _showShareSheet(
        filePath: tmpFile.path,
        fileName: fileName,
        mimeType: 'application/zip',
        icon: Icons.folder_zip_rounded,
        color: const Color(0xFF059669),
        savedToDownloads: savedToDownloads,
        subtitle: '${list.length} بطاقة QR',
      );
    } catch (e) {
      if (!mounted) return;
      Get.back();
      ToastHelper.error('تعذر إنشاء ZIP: $e');
    } finally {
      progress.dispose();
    }
  }

  // ─── Share result sheet ───────────────────────────────────────────────────

  Future<void> _showShareSheet({
    required String filePath,
    required String fileName,
    required String mimeType,
    required IconData icon,
    required Color color,
    bool savedToDownloads = false,
    String? subtitle,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareResultSheet(
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        icon: icon,
        color: color,
        savedToDownloads: savedToDownloads,
        subtitle: subtitle,
      ),
    );
  }

  // ─── Full-screen QR preview ───────────────────────────────────────────────

  /// بيشارك بطاقة طالب واحد كصورة (واتساب ولي الأمر مثلًا).
  Future<void> _shareQr(Student s) async {
    final bytes = await _composeCardPng(s);
    if (bytes == null) {
      ToastHelper.error('تعذر تجهيز البطاقة');
      return;
    }
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/QR_${s.code}.png');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: s.name);
  }

  void _showQrFullscreen(Student s, String? groupName) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              if (groupName != null) ...[
                const SizedBox(height: 4),
                Text(groupName,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade500)),
              ],
              const SizedBox(height: 16),
              QrImageView(
                data: s.code,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.code,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                      label: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareQr(s),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('مشاركة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Get.back();
                        _saveQrPng(s).then((ok) => ok
                            ? ToastHelper.success('تم حفظ الصورة')
                            : ToastHelper.error('تعذر الحفظ'));
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Selection helpers ────────────────────────────────────────────────────

  void _toggleSelect(Student s) {
    final id = s.id;
    if (id == null) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAllFiltered() {
    setState(() {
      for (final s in _filtered) {
        if (s.id != null) _selected.add(s.id!);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  String get _sortLabel => switch (_sort) {
        _QrSort.name => 'الاسم',
        _QrSort.code => 'الكود',
        _QrSort.newest => 'الأحدث انضمامًا',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selecting = _selected.isNotEmpty;
    final exportCount = _exportList.length;
    final centerGroups = _groupsInCenter;

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        backgroundColor: t.page,
        appBar: buildBoardAppBar(
          context,
          title: selecting ? 'محدد ${_selected.length}' : 'مكتبة QR',
          leading: selecting
              ? IconButton(
                  onPressed: _clearSelection,
                  tooltip: 'إلغاء التحديد',
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          actions: [
            IconButton(
              onPressed: _selectAllFiltered,
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'تحديد الكل',
            ),
            PopupMenuButton<String>(
              tooltip: 'خيارات البطاقة',
              icon: const Icon(Icons.tune_rounded),
              onSelected: (v) {
                setState(() {
                  if (v == 'group') _showGroupOnCard = !_showGroupOnCard;
                  if (v == 'code') _showCodeOnCard = !_showCodeOnCard;
                });
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'group',
                  checked: _showGroupOnCard,
                  child: const Text('اسم المجموعة على البطاقة'),
                ),
                CheckedPopupMenuItem(
                  value: 'code',
                  checked: _showCodeOnCard,
                  child: const Text('الكود على البطاقة'),
                ),
              ],
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
            const HelpButton(topicId: 'qr'),
          ],
        ),
        bottomNavigationBar: exportCount == 0
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(top: BorderSide(color: t.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _exportZip,
                          icon: const Icon(Icons.folder_zip_rounded),
                          label: Text('ZIP ($exportCount)'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _showExportDialog,
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: Text('PDF للطباعة ($exportCount)'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: t.chalk,
                              foregroundColor: t.onChalk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: Column(
          children: [
            // ─── السبورة: أرقام سريعة ───────────────────────────────
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
                        label: 'بطاقة',
                        value: '${_filtered.length}',
                        color: t.boardInk)),
                Expanded(
                    child: BoardStat(
                        label: 'محدد',
                        value: '${_selected.length}',
                        color: selecting ? t.chalk : t.boardInkSoft)),
                Expanded(
                    child: BoardStat(
                        label: 'مجموعة',
                        value: '${_groups.length}',
                        color: t.boardInk)),
              ]),
            ),

            // ─── البحث والترتيب ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
              child: Row(
                children: [
                  Expanded(
                    child: CustomSearchBar(
                      controller: _searchCtrl,
                      hintText: 'ابحث بالاسم أو الكود...',
                      onChanged: (_) {},
                      onClear: () {
                        _searchCtrl.clear();
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  PopupMenuButton<_QrSort>(
                    tooltip: 'ترتيب: $_sortLabel',
                    initialValue: _sort,
                    onSelected: (v) {
                      _sort = v;
                      _applyFilters();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: _QrSort.name, child: Text('ترتيب بالاسم')),
                      PopupMenuItem(
                          value: _QrSort.code, child: Text('ترتيب بالكود')),
                      PopupMenuItem(
                          value: _QrSort.newest,
                          child: Text('الأحدث انضمامًا')),
                    ],
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: t.line),
                      ),
                      child: Icon(Icons.sort_rounded, color: t.inkSoft),
                    ),
                  ),
                ],
              ),
            ),

            // ─── السناتر (لو فيه) ───────────────────────────────────
            if (_centers.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _FilterChip(
                        label: 'كل السناتر',
                        icon: Icons.apartment_rounded,
                        active: _selectedCenter == null,
                        onTap: () => _setCenter(null),
                      ),
                    ),
                    for (final c in _centers)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _FilterChip(
                          label: c,
                          icon: Icons.apartment_rounded,
                          active: _selectedCenter == c,
                          onTap: () => _setCenter(c),
                        ),
                      ),
                  ],
                ),
              ),

            // ─── المجموعات + فترة الانضمام ──────────────────────────
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _FilterChip(
                      label: 'كل المجموعات',
                      icon: Icons.groups_outlined,
                      active: _selectedGroup == null,
                      onTap: () => _setGroup(null),
                    ),
                  ),
                  for (final g in centerGroups)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _FilterChip(
                        label: '${g.name} (${_groupCounts[g.id] ?? 0})',
                        icon: Icons.group_outlined,
                        active: _selectedGroup?.id == g.id,
                        onTap: () => _setGroup(g),
                      ),
                    ),
                  _FilterChip(
                    label: _dateFrom == null && _dateTo == null
                        ? 'فترة الانضمام'
                        : _dateFrom != null && _dateTo != null
                            ? '${DateFormat('d/M', 'ar').format(_dateFrom!)} — ${DateFormat('d/M', 'ar').format(_dateTo!)}'
                            : _dateFrom != null
                                ? 'من ${DateFormat('d/M/yy', 'ar').format(_dateFrom!)}'
                                : 'حتى ${DateFormat('d/M/yy', 'ar').format(_dateTo!)}',
                    icon: Icons.date_range_rounded,
                    active: _dateFrom != null || _dateTo != null,
                    onTap: _showDateRangeSheet,
                    onClear: (_dateFrom == null && _dateTo == null)
                        ? null
                        : () {
                            _dateFrom = null;
                            _dateTo = null;
                            _applyFilters();
                          },
                  ),
                ],
              ),
            ),

            // ─── الشبكة ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.qr_code_2,
                          title: 'لا توجد نتائج',
                          subtitle: 'جرّب تعديل البحث أو المجموعة',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: adaptiveColumns(
                                MediaQuery.sizeOf(context).width,
                                phone: 2,
                                minTileWidth: 230,
                                max: 5),
                            crossAxisSpacing: AppSpace.md,
                            mainAxisSpacing: AppSpace.md,
                            childAspectRatio: 0.82,
                          ),
                          cacheExtent: 600,
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final s = _filtered[i];
                            final groupName = _groupById[s.groupId]?.name;
                            return _QrStudentCard(
                              key: ValueKey('qr-${s.id}'),
                              student: s,
                              groupName: groupName,
                              selecting: selecting,
                              selected: s.id != null && _selected.contains(s.id),
                              onTap: () => selecting
                                  ? _toggleSelect(s)
                                  : _showQrFullscreen(s, groupName),
                              onLongPress: () => _toggleSelect(s),
                              onSave: () => _saveQrPng(s).then((ok) => ok
                                  ? ToastHelper.success('تم حفظ الصورة')
                                  : ToastHelper.error('تعذر الحفظ')),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date range picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangeSheet extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final void Function(DateTime? from, DateTime? to) onApply;

  const _DateRangeSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.onApply,
  });

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_from ?? now) : (_to ?? now);
    // استخدم context جذر التطبيق عشان يلاقي MaterialLocalizations
    final rootContext = Get.context ?? context;
    final picked = await showDatePicker(
      context: rootContext,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: isFrom ? 'تاريخ البداية' : 'تاريخ النهاية',
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = DateTime(picked.year, picked.month, picked.day);
          // لو من > إلى، امسح إلى
          if (_to != null && _from!.isAfter(_to!)) _to = null;
        } else {
          _to = DateTime(picked.year, picked.month, picked.day);
          if (_from != null && _to!.isBefore(_from!)) _from = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fmt = DateFormat('d MMMM yyyy', 'ar');
    final hasFilter = _from != null || _to != null;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, color: primary),
                const SizedBox(width: 8),
                Text('فترة الانضمام',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // من
                Expanded(
                  child: _DatePickerTile(
                    label: 'من',
                    value: _from == null ? null : fmt.format(_from!),
                    icon: Icons.calendar_today_rounded,
                    onTap: () => _pickDate(isFrom: true),
                    onClear: _from == null
                        ? null
                        : () => setState(() => _from = null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_back_rounded,
                      color: Colors.grey.shade400, size: 20),
                ),
                // إلى
                Expanded(
                  child: _DatePickerTile(
                    label: 'إلى',
                    value: _to == null ? null : fmt.format(_to!),
                    icon: Icons.calendar_today_rounded,
                    onTap: () => _pickDate(isFrom: false),
                    onClear: _to == null
                        ? null
                        : () => setState(() => _to = null),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      _from != null && _to != null
                          ? 'طلاب مضافون من ${fmt.format(_from!)} حتى ${fmt.format(_to!)}'
                          : _from != null
                              ? 'طلاب مضافون من ${fmt.format(_from!)} فصاعداً'
                              : 'طلاب مضافون حتى ${fmt.format(_to!)}',
                      style: TextStyle(fontSize: 12, color: primary),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                if (hasFilter)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onApply(null, null);
                        Get.back();
                      },
                      child: const Text('مسح الفلتر'),
                    ),
                  ),
                if (hasFilter) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      widget.onApply(_from, _to);
                      Get.back();
                    },
                    child: const Text('تطبيق'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.25),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16,
                color: active ? primary : Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500)),
                  Text(
                    value ?? 'اختر تاريخ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: active ? primary : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 14, color: primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: active ? t.board : t.surface,
        shape:
            StadiumBorder(side: BorderSide(color: active ? t.board : t.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? t.boardInk : t.inkSoft),
                const SizedBox(width: AppSpace.xs),
                Text(label,
                    style: AppType.label.copyWith(
                        fontSize: 13, color: active ? t.boardInk : t.ink)),
                if (onClear != null) ...[
                  const SizedBox(width: AppSpace.xs),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded,
                        size: 16, color: active ? t.boardInk : t.inkSoft),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export options bottom sheet — cols × rows + live preview
// ─────────────────────────────────────────────────────────────────────────────

class _ExportOptionsSheet extends StatefulWidget {
  final int studentCount;
  final String? groupName;
  final List<Student> students;
  final List<Group> groups;
  final void Function(int cols, int rows, double margin) onExport;

  const _ExportOptionsSheet({
    required this.studentCount,
    required this.groupName,
    required this.students,
    required this.groups,
    required this.onExport,
  });

  @override
  State<_ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<_ExportOptionsSheet> {
  int _cols = 3;
  int _rows = 4;
  double _margin = 14.0; // mm هامش الصفحة بـ

  int get _perPage => _cols * _rows;
  int get _pageCount => (widget.studentCount / _perPage).ceil();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final previewStudents = widget.students.take(_cols * _rows).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      builder: (_, sc) => Column(
        children: [
          // handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
          // header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تصدير PDF للطباعة',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${widget.studentCount} طالب'
                        '${widget.groupName != null ? ' — ${widget.groupName}' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // ── Controls ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _CountControl(
                        label: 'أعمدة (عرض)',
                        value: _cols,
                        min: 1,
                        max: 5,
                        onChanged: (v) => setState(() => _cols = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _CountControl(
                        label: 'صفوف (طول)',
                        value: _rows,
                        min: 1,
                        max: 7,
                        onChanged: (v) => setState(() => _rows = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Margin slider ─────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.border_outer_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('هامش الصفحة',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${_margin.round()} mm',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: primary),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16),
                    activeTrackColor: primary,
                    thumbColor: primary,
                    inactiveTrackColor:
                        primary.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: _margin,
                    min: 4,
                    max: 30,
                    divisions: 26,
                    onChanged: (v) => setState(() => _margin = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('4 mm — أكثر بطاقات',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500)),
                    Text('30 mm — أكثر أماناً',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500)),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Stats row ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceAround,
                    children: [
                      _StatPill(
                          label: 'في الصفحة',
                          value: '$_perPage بطاقة'),
                      Container(
                          width: 1, height: 30,
                          color: primary.withValues(alpha: 0.2)),
                      _StatPill(
                          label: 'عدد الصفحات',
                          value: '~$_pageCount صفحة'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Live preview label ────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.preview_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('معاينة الصفحة',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(
                      'كل بطاقة: QR + اسم + كود',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Live preview (A4 proportions) ─────────────────────
                LayoutBuilder(builder: (_, constraints) {
                  // نسبة الهامش بالنسبة لعرض A4 (210mm)
                  final previewPadding =
                      (_margin / 210) * constraints.maxWidth;
                  return AspectRatio(
                  aspectRatio: 1 / 1.414, // A4
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(previewPadding),
                      child: GridView.builder(
                        physics:
                            const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _cols,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          // نسبة تطابق بطاقة الـ PNG الفعلية (780×996)
                          childAspectRatio: 780 / 996,
                        ),
                        itemCount: _perPage,
                        itemBuilder: (_, i) {
                          final s = i < previewStudents.length
                              ? previewStudents[i]
                              : null;
                          final groupName = s == null
                              ? null
                              : widget.groups
                                  .firstWhereOrNull(
                                      (g) => g.id == s.groupId)
                                  ?.name;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 0.5),
                              borderRadius:
                                  BorderRadius.circular(3),
                              color: Colors.white,
                            ),
                            child: s == null
                                ? const SizedBox.shrink()
                                : Column(
                                    children: [
                                      // QR يأخذ ~70% من البطاقة
                                      Expanded(
                                        flex: 70,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets
                                                  .fromLTRB(
                                                      3, 3, 3, 1),
                                          child: QrImageView(
                                            data: s.code,
                                            version:
                                                QrVersions.auto,
                                            backgroundColor:
                                                Colors.white,
                                          ),
                                        ),
                                      ),
                                      // النصوص تأخذ ~30%
                                      Expanded(
                                        flex: 30,
                                        child: ClipRect(
                                          child: Padding(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                      horizontal:
                                                          2),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                            children: [
                                              Text(
                                                s.name,
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                textAlign:
                                                    TextAlign
                                                        .center,
                                                style: const TextStyle(
                                                    fontSize: 5,
                                                    fontWeight:
                                                        FontWeight
                                                            .w700,
                                                    color: Colors
                                                        .black),
                                              ),
                                              if (groupName !=
                                                  null)
                                                Text(
                                                  'المجموعة: $groupName',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis,
                                                  textAlign:
                                                      TextAlign
                                                          .center,
                                                  style: TextStyle(
                                                      fontSize: 4,
                                                      color: Colors
                                                          .grey
                                                          .shade600),
                                                ),
                                              Text(
                                                'الكود: ${s.code}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                textAlign:
                                                    TextAlign
                                                        .center,
                                                style: TextStyle(
                                                    fontSize: 4,
                                                    color: Colors
                                                        .grey
                                                        .shade500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                );
                }),
              ],
            ),
          ),

          // ── Export button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: FilledButton.icon(
              onPressed: () => widget.onExport(_cols, _rows, _margin),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                'تصدير $_perPage بطاقة/صفحة — حفظ في التنزيلات',
                style: const TextStyle(fontSize: 14),
              ),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountControl extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CountControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            _StepBtn(
              icon: Icons.remove,
              enabled: value > min,
              onTap: () => onChanged(value - 1),
            ),
            Expanded(
              child: Center(
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            _StepBtn(
              icon: Icons.add,
              enabled: value < max,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn(
      {required this.icon,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressDialog extends StatelessWidget {
  final int total;
  final String label;
  final ValueListenable<int> progress;
  const _ProgressDialog(
      {required this.total, required this.label, required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: t.line)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppType.title.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : (done / total).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: t.brand,
                  backgroundColor: t.line,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text('$done من $total بطاقة',
                  style: AppType.caption.copyWith(color: t.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student QR card
// ─────────────────────────────────────────────────────────────────────────────

class _QrStudentCard extends StatelessWidget {
  final Student student;
  final String? groupName;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSave;

  const _QrStudentCard({
    super.key,
    required this.student,
    required this.groupName,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: '${student.name}، كود ${student.code}',
      child: Material(
        color: selected ? t.rosterTint : t.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(
              color: selected ? t.brand : t.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الـQR دايمًا أسود على أبيض (حتى في الوضع الداكن) عشان يتقري.
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(
                            AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xs),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                          border: Border.all(color: t.line),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.sm),
                          child: RepaintBoundary(
                            child: QrImageView(
                              data: student.code,
                              version: QrVersions.auto,
                              backgroundColor: Colors.white,
                              gapless: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (selecting)
                      PositionedDirectional(
                        top: AppSpace.sm,
                        start: AppSpace.sm,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: selected ? t.brand : t.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected ? t.brand : t.inkFaint,
                                width: 1.5),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.md, 0, AppSpace.md, AppSpace.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.label
                                .copyWith(color: t.ink, fontSize: 13),
                          ),
                          Text(
                            groupName == null
                                ? student.code
                                : '$groupName • ${student.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(color: t.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    if (!selecting)
                      IconButton(
                        onPressed: onSave,
                        tooltip: 'حفظ الصورة',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.download_rounded,
                            size: 20, color: t.brand),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Share Result Bottom Sheet ────────────────────────────────────────────────

class _ShareResultSheet extends StatelessWidget {
  final String filePath;
  final String fileName;
  final String mimeType;
  final IconData icon;
  final Color color;
  final bool savedToDownloads;
  final String? subtitle;

  const _ShareResultSheet({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.icon,
    required this.color,
    required this.savedToDownloads,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (savedToDownloads)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Text('تم الحفظ في مجلد التنزيلات',
                      style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                try {
                  if (!await File(filePath).exists()) {
                    ToastHelper.error('الملف لم يعد موجودًا، جرّب تصدّره تاني');
                    return;
                  }
                  await Share.shareXFiles(
                    [XFile(filePath, mimeType: mimeType)],
                    subject: fileName,
                  );
                } catch (e) {
                  ToastHelper.error('تعذرت المشاركة: $e');
                }
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('مشاركة الملف',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('إغلاق',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background-isolate helpers (pure Dart — لا يعتمدان على dart:ui)
//
// pdf.save() و ZipEncoder().encode() عمليتان synchronous ثقيلتان بدون أي
// yield داخلي؛ تنفيذهما على الـ UI isolate هو سبب تجمّد الواجهة لعشرات
// الثواني مع أعداد كبيرة من الطلاب (وما يبدو بعدها كأن زر المشاركة
// "لا يستجيب"). ننقلهما إلى isolate منفصل عبر compute().
// ─────────────────────────────────────────────────────────────────────────────

class _QrPdfBuildArgs {
  final List<String> codes;
  final Map<String, Uint8List> images;
  final int perRow;
  final int perCol;
  final double pageMargin;

  const _QrPdfBuildArgs({
    required this.codes,
    required this.images,
    required this.perRow,
    required this.perCol,
    required this.pageMargin,
  });
}

Future<Uint8List> _buildQrPdfBytes(_QrPdfBuildArgs args) async {
  final pdf = pw.Document();
  final perPage = args.perRow * args.perCol;

  for (int i = 0; i < args.codes.length; i += perPage) {
    final chunkCodes = args.codes.skip(i).take(perPage).toList();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(args.pageMargin),
      build: (ctx) {
        const cardSpacing = 8.0;
        final availableWidth = PdfPageFormat.a4.width - args.pageMargin * 2;
        final availableHeight = PdfPageFormat.a4.height - args.pageMargin * 2;
        final cellWidth =
            (availableWidth - cardSpacing * (args.perRow - 1)) / args.perRow;
        final cardHeight =
            (availableHeight - cardSpacing * (args.perCol - 1)) / args.perCol;
        return pw.Wrap(
          spacing: cardSpacing,
          runSpacing: cardSpacing,
          children: [
            for (final code in chunkCodes)
              pw.Container(
                width: cellWidth,
                height: cardHeight,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border:
                      pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: args.images[code] == null
                    ? pw.SizedBox.shrink()
                    : pw.Center(
                        child: pw.Image(pw.MemoryImage(args.images[code]!),
                            fit: pw.BoxFit.contain)),
              ),
          ],
        );
      },
    ));
  }

  return pdf.save();
}

Uint8List _encodeZipBytes(Archive archive) {
  final bytes = ZipEncoder().encode(archive);
  if (bytes == null) throw Exception('فشل إنشاء ZIP');
  return Uint8List.fromList(bytes);
}
