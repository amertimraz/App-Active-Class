// lib/utils/hardware_scan_buffer.dart
//
// محرّك يجمّع ضغطات المفاتيح القادمة من جهاز قارئ باركود خارجي يعمل
// بوضع لوحة مفاتيح (HID) ويميّزها عن الكتابة اليدوية للمدرّس.
//
// الفكرة: جهاز HID "يكتب" الكود بسرعة عالية جدًا (فواصل ميلي-ثوانٍ
// قليلة بين الحرف والتالي) وينهيه بـ Enter أو Tab. أي تتابع أبطأ من
// ذلك = إدخال بشري ويُتجاهَل. لا مكتبات، لا أذونات — فقط KeyEvent.
//
// spec 027 — راجع specs/027-hardware-barcode-scanner/contracts/hardware-scan-buffer.md
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HardwareScanBuffer {
  HardwareScanBuffer({
    required this.onScan,
    this.maxInterKeyGap = const Duration(milliseconds: 50),
    this.idleReset = const Duration(milliseconds: 150),
    this.minLength = 2,
  });

  /// يُستدعى عند اكتمال مسح صالح (تتابع سريع + علامة نهاية + طول كافٍ).
  final void Function(String code) onScan;

  /// أقصى فاصل زمني مقبول بين حرفين ليُعدّ الإدخال قادمًا من جهاز.
  final Duration maxInterKeyGap;

  /// خمول بلا علامة نهاية أطول من ذلك → تصفية ما تجمّع.
  final Duration idleReset;

  /// أقل طول نص مقبول بعد trim.
  final int minLength;

  final StringBuffer _chars = StringBuffer();
  DateTime? _lastKeyAt;
  Timer? _idleTimer;

  /// حقن ساعة للاختبار فقط.
  DateTime Function()? _nowOverride;
  @visibleForTesting
  set nowOverride(DateTime Function()? fn) => _nowOverride = fn;

  DateTime get _now => _nowOverride?.call() ?? DateTime.now();

  /// تُستدعى لكل KeyEvent من Focus.onKeyEvent.
  /// ترجع true لو استهلكت الحدث (مسح جهاز محتمل) بحيث تقدر الشاشة
  /// ترجع KeyEventResult.handled وتمنع تسرّبه لودجت أخرى.
  bool feedKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      if (_chars.isEmpty) return false;
      _flush();
      return true;
    }

    final ch = event.character;
    if (ch == null || ch.length != 1 || _isControlChar(ch)) return false;

    final now = _now;
    if (_lastKeyAt != null &&
        now.difference(_lastKeyAt!).abs() > maxInterKeyGap) {
      // فجوة كبيرة = بداية تتابع جديد؛ ما قبله كان بشريًا/قديمًا.
      _resetBuffer();
    }
    _chars.write(ch);
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
    _resetBuffer();
    if (code.length >= minLength) onScan(code);
  }

  void _resetBuffer() {
    _chars.clear();
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
