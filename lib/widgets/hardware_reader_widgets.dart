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

/// سطر "جرّب القارئ" في شاشة الإعدادات — يظهر فقط عند تفعيل المفتاح.
/// يلتقط مسحًا واحدًا من الجهاز ويعرض النص المقروء ومؤشّر نجاح، بلا أي
/// تسجيل حضور/دفع أو أثر على البيانات. spec 027 (US4).
class HardwareScannerTestTile extends StatefulWidget {
  const HardwareScannerTestTile({super.key});

  @override
  State<HardwareScannerTestTile> createState() =>
      _HardwareScannerTestTileState();
}

class _HardwareScannerTestTileState extends State<HardwareScannerTestTile> {
  bool _open = false;
  bool _success = false;
  String? _lastReadText;
  HardwareScanBuffer? _buffer;

  bool _keyHandler(KeyEvent e) {
    if (!_open || _buffer == null) return false;
    return _buffer!.feedKey(e);
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _success = false;
        _lastReadText = null;
        _buffer = HardwareScanBuffer(onScan: (code) {
          if (!mounted) return;
          setState(() {
            _success = true;
            _lastReadText = code;
          });
        });
        HardwareKeyboard.instance.addHandler(_keyHandler);
      } else {
        HardwareKeyboard.instance.removeHandler(_keyHandler);
        _buffer?.dispose();
        _buffer = null;
      }
    });
  }

  @override
  void dispose() {
    if (_open) HardwareKeyboard.instance.removeHandler(_keyHandler);
    _buffer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.sensors_rounded, color: Color(0xFF0EA5E9)),
          title: const Text('جرّب القارئ',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          trailing: Icon(_open
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded),
          onTap: _toggle,
        ),
        if (_open)
          Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_success ? const Color(0xFF10B981) : const Color(0xFF0EA5E9))
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (_success
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0EA5E9))
                        .withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(
                  _success
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_empty_rounded,
                  color: _success
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0EA5E9),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _success
                            ? 'الجهاز يعمل كلوحة مفاتيح (HID) ✅'
                            : 'امسح أي باركود بالجهاز الآن…',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: onSurface),
                      ),
                      if (_lastReadText != null) ...[
                        const SizedBox(height: 3),
                        Text('النص المقروء: $_lastReadText',
                            style: TextStyle(
                                fontSize: 11,
                                color: onSurface.withValues(alpha: 0.6))),
                      ],
                    ],
                  ),
                ),
              ]),
          ),
      ],
    );
  }
}
