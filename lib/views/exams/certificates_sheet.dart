// lib/views/exams/certificates_sheet.dart
//
// spec 018 — شاشة موحّدة لتوليد شهادات التقدير: قائمة طلاب قابلة
// للاختيار (كلها معلَّمة افتراضيًا) + منتقي قالب + معاينة قبل المشاركة.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/models/certificate_model.dart';
import 'package:active_class/services/certificate_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';

class CertificatesSheet extends StatefulWidget {
  final String title;
  final String fileName; // بدون امتداد
  final List<CertificateData> items;

  const CertificatesSheet({
    super.key,
    required this.title,
    required this.fileName,
    required this.items,
  });

  @override
  State<CertificatesSheet> createState() => _CertificatesSheetState();
}

class _CertificatesSheetState extends State<CertificatesSheet> {
  final _db = DatabaseService();
  late final Set<int> _selected;
  CertTemplate _template = CertTemplate.blueWhite;
  bool _busy = false;

  // معاينة حيّة لكل قالب — أول طالب في القائمة كعيّنة، تُرسم مرة وتُخزَّن.
  final Map<CertTemplate, Uint8List> _previews = {};
  bool _previewsLoading = true;

  @override
  void initState() {
    super.initState();
    _selected = {for (var i = 0; i < widget.items.length; i++) i};
    _init();
  }

  Future<void> _init() async {
    final v = await _db.getSetting(SETTING_CERT_TEMPLATE);
    if (mounted) setState(() => _template = CertTemplateX.fromStorage(v));
    await _renderPreviews();
  }

  Future<void> _renderPreviews() async {
    if (widget.items.isEmpty) {
      if (mounted) setState(() => _previewsLoading = false);
      return;
    }
    final sample = widget.items.first;
    for (final t in CertTemplate.values) {
      try {
        final pdf =
            await CertificateService().buildCertificatesPdf([sample], t);
        await for (final page
            in Printing.raster(pdf, pages: const [0], dpi: 96)) {
          _previews[t] = await page.toPng();
          break;
        }
        if (mounted) setState(() {});
      } catch (_) {/* يفضل fallback على صورة الخلفية */}
    }
    if (mounted) setState(() => _previewsLoading = false);
  }

  void _zoomTemplate(CertTemplate t) {
    final png = _previews[t];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(t.label,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 4,
                child: png != null
                    ? Image.memory(png)
                    : Image.asset('assets/images/${t.bgAsset}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    final chosen = [
      for (var i = 0; i < widget.items.length; i++)
        if (_selected.contains(i)) widget.items[i]
    ];
    if (chosen.isEmpty) {
      ToastHelper.info('اختَر طالبًا واحدًا على الأقل');
      return;
    }
    setState(() => _busy = true);
    try {
      await _db.setSetting(SETTING_CERT_TEMPLATE, _template.storageKey);
      final bytes =
          await CertificateService().buildCertificatesPdf(chosen, _template);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _CertPreviewPage(
          bytes: bytes,
          fileName: '${widget.fileName}.pdf',
          count: chosen.length,
        ),
      ));
    } catch (e) {
      if (mounted) ToastHelper.error('تعذّر إنشاء الشهادات — حاول تاني');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = widget.items.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: empty
          ? _empty(cs)
          : Column(
              children: [
                _templatePicker(cs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Text('${_selected.length}/${widget.items.length} مختار',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selected.length == widget.items.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(List.generate(widget.items.length, (i) => i));
                          }
                        }),
                        child: Text(
                            _selected.length == widget.items.length
                                ? 'إلغاء الكل'
                                : 'اختيار الكل',
                            style: const TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: widget.items.length,
                    itemBuilder: (_, i) {
                      final it = widget.items[i];
                      final on = _selected.contains(i);
                      return Card(
                        elevation: 0,
                        color: on
                            ? AppTheme.primaryColor.withValues(alpha: 0.06)
                            : cs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: cs.onSurface.withValues(alpha: 0.1)),
                        ),
                        child: CheckboxListTile(
                          value: on,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(i);
                            } else {
                              _selected.remove(i);
                            }
                          }),
                          title: Text(it.studentName,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: it.gradeText != null
                              ? Text(it.gradeText!,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.55)))
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomSheet: empty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                    top: BorderSide(
                        color: cs.onSurface.withValues(alpha: 0.08))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _generate,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.visibility_rounded, size: 18),
                  label: Text(_busy ? 'جاري التوليد...' : 'معاينة ومشاركة',
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                ),
              ),
            ),
    );
  }

  Widget _templatePicker(ColorScheme cs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(
              children: [
                Text('اختر القالب',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
                const SizedBox(width: 8),
                if (_previewsLoading)
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6)),
                const Spacer(),
                Text('دوس للتكبير 🔍',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: CertTemplate.values
                  .map((t) => Expanded(child: _templateCard(cs, t)))
                  .toList(),
            ),
          ),
        ],
      );

  Widget _templateCard(ColorScheme cs, CertTemplate t) {
    final on = t == _template;
    final png = _previews[t];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _template = t),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: on
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : cs.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: on
                    ? AppTheme.primaryColor
                    : cs.onSurface.withValues(alpha: 0.12),
                width: on ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AspectRatio(
                      aspectRatio: 1.414,
                      child: png != null
                          ? Image.memory(png, fit: BoxFit.cover)
                          : Container(
                              color: cs.onSurface.withValues(alpha: 0.06),
                              child: Image.asset(
                                  'assets/images/${t.bgAsset}',
                                  fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: GestureDetector(
                      onTap: () => _zoomTemplate(t),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.zoom_in_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  if (on)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.check_rounded,
                            size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(t.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: on ? AppTheme.primaryColor : cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎓', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text('مفيش طلاب فوق درجة النجاح',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.5))),
        ]),
      );
}

/// معاينة الشهادات المولَّدة (صفحة لكل طالب) مع أزرار مشاركة/طباعة/حفظ.
class _CertPreviewPage extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final int count;

  const _CertPreviewPage({
    required this.bytes,
    required this.fileName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة $count شهادة',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
      body: PdfPreview(
        build: (_) => bytes,
        initialPageFormat: PdfPageFormat.a4.landscape,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: fileName,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
