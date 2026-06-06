// lib/views/qr_scanner/code39_scanner_payment_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:flutter/services.dart';
import 'package:active_class/models/group_model.dart';
import 'qr_gallery_page.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class Code39ScannerPaymentPage extends StatefulWidget {
  const Code39ScannerPaymentPage({super.key});

  @override
  State<Code39ScannerPaymentPage> createState() => _Code39ScannerPaymentPageState();
}

class _Code39ScannerPaymentPageState extends State<Code39ScannerPaymentPage> with WidgetsBindingObserver {
  late MobileScannerController scannerController;
  late final QRController controller;
  String? _lastScan;
  DateTime? _lastScanAt;
  DateTime? _lastOcrAt;
  final DatabaseService _db = DatabaseService();
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scannerController = MobileScannerController(
      formats: const [BarcodeFormat.code39],
      returnImage: true,
      detectionSpeed: DetectionSpeed.normal,
      autoStart: false,
    );
    controller = Get.isRegistered<QRController>() ? Get.find<QRController>() : Get.put(QRController());
    controller.mode.value = QRMode.payment;
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scannerController.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scannerController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح Code 39 للدفع'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'إدخال كود يدويًا',
            icon: const Icon(Icons.keyboard),
            onPressed: () async {
              final code = await showDialog<String?>(
                context: context,
                builder: (ctx) {
                  final c = TextEditingController();
                  return AlertDialog(
                    title: const Text('أدخل الكود'),
                    content: TextField(controller: c, decoration: const InputDecoration(hintText: 'الكود')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('تأكيد')),
                    ],
                  );
                },
              );
              if (code != null && code.isNotEmpty) {
                await _handle(code);
              }
            },
          ),
          IconButton(
            tooltip: 'معرض QR',
            icon: const Icon(Icons.grid_view),
            onPressed: () => Get.to(() => const QrGalleryPage()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) async {
                    bool handled = false;
                    for (final barcode in capture.barcodes) {
                      final value = barcode.rawValue;
                      if (value != null) {
                        handled = true;
                        await _handle(value);
                        break;
                      }
                    }
                    if (!handled) {
                      await _maybeRunInlineOcr(capture.image, capture.size);
                    }
                  },
                  errorBuilder: (context, error) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          const Text('تعذر الوصول للكاميرا'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => scannerController.start(),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(color: Colors.black.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: Obx(() {
              final student = controller.scannedStudent.value;
              final months = controller.upcomingMonths;
              final selected = controller.selectedMonths;
              final total = controller.totalAmount.value;
              final processing = controller.isProcessing.value;
              return SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(PADDING_NORMAL),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    border: Border(top: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.15))),
                  ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ValueListenableBuilder<MobileScannerState>(
                              valueListenable: scannerController,
                              builder: (context, state, _) {
                                final on = state.torchState == TorchState.on;
                                return IconButton(
                                  tooltip: on ? 'إطفاء الفلاش' : 'تشغيل الفلاش',
                                  icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                                  onPressed: () => scannerController.toggleTorch(),
                                );
                              },
                            ),
                            const SizedBox(width: SPACING_NORMAL),
                            ValueListenableBuilder<MobileScannerState>(
                              valueListenable: scannerController,
                              builder: (context, state, _) {
                                return IconButton(
                                  tooltip: 'تبديل الكاميرا',
                                  icon: const Icon(Icons.flip_camera_ios),
                                  onPressed: () => scannerController.switchCamera(),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: SPACING_NORMAL),
                        if (student == null) ...[
                          Text(
                            'امسح كود الطالب لعرض تفاصيل الدفع',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ] else ...[
                          Text(
                            student.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: SPACING_SMALL),
                          FutureBuilder<Group?>(
                            future: _db.getGroup(student.groupId),
                            builder: (ctx, snap) {
                              final g = snap.data;
                              final isSiblings = student.siblingId != null && student.siblingsTotal != null;
                              final price = isSiblings ? (student.siblingsTotal ?? student.price) : student.price;
                              return Text(
                                '${g?.name ?? '—'} • سعر الشهر: ${FormatHelper.formatCurrency(price)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            },
                          ),
                          const SizedBox(height: SPACING_SMALL),
                          Text(
                            'آخر شهر مدفوع: ${controller.lastPaidMonthText}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: SPACING_NORMAL),
                          Text(
                            'الشهور القادمة',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: SPACING_SMALL),
                          if (months.isEmpty)
                            Text(
                              'لا توجد شهور متاحة',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 4.2,
                              ),
                              itemCount: months.length,
                              itemBuilder: (context, index) {
                                final month = months[index];
                                final label = controller.formatMonth(month);
                                final isSelected = selected.any((m) => m.year == month.year && m.month == month.month);
                                return InkWell(
                                  onTap: () => controller.toggleMonth(month),
                                  child: Row(
                                    children: [
                                      Checkbox(value: isSelected, onChanged: (_) => controller.toggleMonth(month)),
                                      Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: SPACING_NORMAL),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'المبلغ الإجمالي: ${FormatHelper.formatCurrency(total)}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final amtCtrl = TextEditingController(text: total.toStringAsFixed(2));
                                  final noteCtrl = TextEditingController(text: controller.overrideNote.value);
                                  final res = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تعديل السعر/ملاحظة'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: amtCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(labelText: 'المبلغ المطلوب'),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: noteCtrl,
                                            decoration: const InputDecoration(labelText: 'ملاحظة (مثال: نصف شهر)'),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
                                      ],
                                    ),
                                  );
                                  if (res == true) {
                                    final parsed = double.tryParse(amtCtrl.text.trim());
                                    if (parsed != null && parsed > 0) {
                                      controller.setOverride(amount: parsed, note: noteCtrl.text);
                                    } else {
                                      ToastHelper.error('قيمة غير صالحة');
                                    }
                                  }
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('تعديل السعر/ملاحظة'),
                              ),
                              if (controller.overrideAmount.value != null)
                                TextButton(
                                  onPressed: () => controller.setOverride(amount: null, note: ''),
                                  child: const Text('إعادة التعيين'),
                                ),
                            ],
                          ),
                          const SizedBox(height: SPACING_SMALL),
                          if (student.siblingId != null && student.siblingsTotal != null)
                            FutureBuilder<Student?>(
                              future: DatabaseService().getStudent(student.siblingId!),
                              builder: (ctx, snap) {
                                final sibName = (snap.data)?.name ?? '—';
                                final each = (total / 2).toStringAsFixed(2);
                                return Text('عرض الإخوة مع: $sibName • نصيب كل واحد: ${FormatHelper.formatCurrency(double.tryParse(each) ?? 0)}');
                              },
                            ),
                          const SizedBox(height: SPACING_NORMAL),
                          CustomButton(
                            label: 'تأكيد الدفع',
                            onPressed: () async {
                              if (student.siblingId != null && student.siblingsTotal != null) {
                                if (!mounted) return;
                                final sib = await DatabaseService().getStudent(student.siblingId!);
                                if (!context.mounted) return;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('تأكيد عرض الإخوة'),
                                    content: Text('سيتم تطبيق عرض الإخوة بين ${student.name} و ${sib?.name ?? "الأخ"} بمبلغ إجمالي ${FormatHelper.formatCurrency(total)}'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                                      ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد')),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                              }
                              final success = await controller.confirmPayment();
                              if (!mounted) return;
                              if (success) {
                                HapticFeedback.mediumImpact();
                                await Future.delayed(const Duration(milliseconds: 150));
                                scannerController.start();
                              }
                            },
                            isEnabled: selected.isNotEmpty && !processing,
                            isLoading: processing,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeRunInlineOcr(Uint8List? bytes, Size size) async {
    final now = DateTime.now();
    if (bytes == null) return;
    if (_lastOcrAt != null && now.difference(_lastOcrAt!).inMilliseconds < 1200) return;
    _lastOcrAt = now;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/_ocr_frame.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final input = InputImage.fromFile(file);
      final result = await _textRecognizer.processImage(input);
      final buffer = StringBuffer();
      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }
      final text = buffer.toString();
      final match = RegExp(r"[0-9٠-٩]{3,}").firstMatch(text);
      final raw = match?.group(0)?.trim() ?? '';
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      final digits = raw.split('').map((c) {
        final i = arabic.indexOf(c);
        if (i >= 0) return '$i';
        return RegExp(r'[0-9]').hasMatch(c) ? c : '';
      }).join();
      if (digits.isNotEmpty) {
        await _handle(digits);
      }
    } catch (_) {
      // ignore OCR errors silently to keep stream smooth
    }
  }

  Future<void> _handle(String code) async {
    if (controller.isProcessing.value) return;
    final now = DateTime.now();
    if (_lastScan == code && _lastScanAt != null && now.difference(_lastScanAt!).inMilliseconds < 1500) {
      return;
    }
    _lastScan = code;
    _lastScanAt = now;
    await scannerController.stop();
    await controller.handleScan(code);
    if (!mounted) return;
    if (controller.scannedStudent.value == null) {
      scannerController.start();
    } else {
      HapticFeedback.selectionClick();
    }
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color color;
  _ScannerOverlayPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    final s = size.shortestSide * 0.7;
    final left = (size.width - s) / 2;
    final top = (size.height - s) / 2.5;
    final hole = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, s, s), const Radius.circular(16));
    final path = Path()..addRect(r);
    final holePath = Path()..addRRect(hole);
    final overlay = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(overlay, paint);
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(hole, border);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
