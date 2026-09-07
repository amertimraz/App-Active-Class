// lib/utils/hardware_scan_buffer.dart
//
// محرّك يجمّع ضغطات المفاتيح القادمة من جهاز قارئ باركود خارجي يعمل
// بوضع لوحة مفاتيح (HID) ويميّزها عن الكتابة اليدوية للمدرّس.
//
// الفكرة: جهاز HID "يكتب" الكود بسرعة عالية جدًا وينهيه بـ Enter أو
// Tab. عند علامة النهاية نحسب متوسط الزمن لكل حرف على التتابع كله؛
// لو ≤ maxAvgGap فهو جهاز، غير كده كتابة بشرية → يُهمَل.
//
// نستخدم "المتوسط على التتابع كله" بدل "الفاصل بين كل حرفين" لأن
// jank لحظي في الـUI (كاميرا شغالة + rebuild) ممكن يزوّد فاصلًا
// واحدًا فيكسر الكشف لو اعتمدنا على فحص كل حرف على حدة.
//
// spec 027 — راجع specs/027-hardware-barcode-scanner/contracts/hardware-scan-buffer.md
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HardwareScanBuffer {
  HardwareScanBuffer({
    required this.onScan,
    this.maxAvgGap = const Duration(milliseconds: 50),
    this.idleReset = const Duration(milliseconds: 300),
    this.newSequenceGap = const Duration(milliseconds: 250),
    this.minLength = 2,
  });

  /// يُستدعى عند اكتمال مسح صالح (تتابع + علامة نهاية + سرعة جهاز).
  final void Function(String code) onScan;

  /// أقصى متوسط زمن لكل حرف (من أول حرف لعلامة النهاية) ليُعدّ جهازًا.
  final Duration maxAvgGap;

  /// خمول بلا علامة نهاية أطول من ذلك → تصفية ما تجمّع.
  final Duration idleReset;

  /// فاصل بين ضغطتين أكبر من ذلك = تتابع جديد تمامًا (نصفّي القديم أولًا).
  final Duration newSequenceGap;

  /// أقل طول نص مقبول بعد trim.
  final int minLength;

  final StringBuffer _chars = StringBuffer();
  int _count = 0;
  DateTime? _seqStart;
  DateTime? _lastKeyAt;
  Timer? _idleTimer;

  /// حقن ساعة للاختبار فقط.
  DateTime Function()? _nowOverride;
  @visibleForTesting
  set nowOverride(DateTime Function()? fn) => _nowOverride = fn;

  DateTime get _now => _nowOverride?.call() ?? DateTime.now();

  /// تُستدعى لكل KeyEvent من مستمع الكيبورد في الشاشة.
  /// ترجع true لو استهلكت الحدث (مسح جهاز محتمل).
  bool feedKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      if (_count == 0) return false;
      _flush();
      return true;
    }

    final ch = event.character;
    if (ch == null || ch.length != 1 || _isControlChar(ch)) return false;

    final now = _now;
    if (_lastKeyAt != null &&
        now.difference(_lastKeyAt!).abs() > newSequenceGap) {
      _resetBuffer(); // تتابع جديد؛ ما قبله قديم/بشري
    }
    _seqStart ??= now;
    _chars.write(ch);
    _count++;
    _lastKeyAt = now;
    _armIdleTimer();
    return true;
  }

  /// تصفير يدوي (resume من الخلفية، تبديل تبويب، إغلاق لوحة تجربة).
  void reset() => _resetBuffer();

  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  // ── داخلي ───────────────────────────────────────────────────────
  void _flush() {
    final code = _chars.toString().trim();
    final count = _count;
    final start = _seqStart;
    final end = _lastKeyAt ?? _now;
    _resetBuffer();

    if (code.length < minLength || count == 0 || start == null) return;
    // متوسط الزمن لكل حرف على التتابع كله.
    final avgMs = end.difference(start).inMicroseconds / count / 1000.0;
    if (avgMs <= maxAvgGap.inMilliseconds) onScan(code);
  }

  void _resetBuffer() {
    _chars.clear();
    _count = 0;
    _seqStart = null;
    _lastKeyAt = null;
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleReset, _resetBuffer);
  }

  bool _isControlChar(String ch) {
    final c = ch.codeUnitAt(0);
    return c < 0x20 || c == 0x7f;
  }
}
