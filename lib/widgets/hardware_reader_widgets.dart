// lib/widgets/hardware_reader_widgets.dart
//
// عناصر واجهة مشتركة لدعم جهاز قارئ الباركود الخارجي (HID) في شاشتَي
// الحضور والدفع. spec 027.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:active_class/utils/hardware_scan_buffer.dart';

/// نص نسبي مختصر لتوقيت آخر مسح ناجح من القارئ الخارجي.
String relativeScanText(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 15) return 'الآن';
  if (d.inSeconds < 60) return 'قبل لحظات';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
  return 'قبل ${d.inDays} يوم';
}

/// شريط رفيع يؤكد أن القارئ الخارجي نشط + توقيت آخر مسح.
class HardwareActiveBadge extends StatelessWidget {
  const HardwareActiveBadge({super.key, required this.lastScanAt});
  final DateTime lastScanAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF0C4A6E),
      child: Row(children: [
        const Icon(Icons.barcode_reader, color: Color(0xFF7DD3FC), size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'القارئ الخارجي نشط • آخر مسح ${relativeScanText(lastScanAt)}',
            style: const TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF7DD3FC),
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

/// بديل الكاميرا في وضع "القارئ الخالص" (hardware + إخفاء ماسح QR).
class ReaderReadyPanel extends StatelessWidget {
  const ReaderReadyPanel({super.key, this.lastScanAt});
  final DateTime? lastScanAt;

  @override
  Widget build(BuildContext context) {
    final scanned = lastScanAt != null;
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.barcode_reader,
                size: 46, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(height: 16),
          Text(
            scanned ? 'القارئ الخارجي نشط' : 'القارئ الخارجي جاهز',
            style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            scanned
                ? 'آخر مسح ${relativeScanText(lastScanAt!)}'
                : 'امسح كرت الطالب — سيظهر التأكيد فورًا',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

/// سطر "جرّب القارئ" في شاشة الإعدادات — يفتح حوارًا يلتقط مسحًا واحدًا
/// من الجهاز ويعرض النص المقروء ومؤشّر نجاح، بلا أي تسجيل حضور/دفع أو
/// أثر على البيانات. حوار modal عشان التقاط الكيبورد يكون معزولًا عن
/// باقي شاشة الإعدادات (وإلا كان بيسدّ الكتابة في أي حقل تاني). spec 027 (US4).
class HardwareScannerTestTile extends StatelessWidget {
  const HardwareScannerTestTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sensors_rounded, color: Color(0xFF0EA5E9)),
      title: const Text('جرّب القارئ',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _HardwareScannerTestDialog(),
      ),
    );
  }
}

class _HardwareScannerTestDialog extends StatefulWidget {
  const _HardwareScannerTestDialog();

  @override
  State<_HardwareScannerTestDialog> createState() =>
      _HardwareScannerTestDialogState();
}

class _HardwareScannerTestDialogState
    extends State<_HardwareScannerTestDialog> {
  bool _success = false;
  String? _lastReadText;
  late final HardwareScanBuffer _buffer;

  bool _keyHandler(KeyEvent e) => _buffer.feedKey(e);

  @override
  void initState() {
    super.initState();
    _buffer = HardwareScanBuffer(onScan: (code) {
      if (!mounted) return;
      setState(() {
        _success = true;
        _lastReadText = code;
      });
    });
    HardwareKeyboard.instance.addHandler(_keyHandler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    _buffer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final c = _success ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('جرّب القارئ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                _success
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                color: c,
                size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _success
                    ? 'الجهاز يعمل كلوحة مفاتيح (HID) ✅'
                    : 'امسح أي باركود بالجهاز الآن…',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: onSurface),
              ),
            ),
          ]),
          if (_lastReadText != null) ...[
            const SizedBox(height: 8),
            Text('النص المقروء: $_lastReadText',
                style: TextStyle(
                    fontSize: 11, color: onSurface.withValues(alpha: 0.6))),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تمام')),
      ],
    );
  }
}
