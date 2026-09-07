// test/hardware_scan_buffer_test.dart
//
// وحدة لـ HardwareScanBuffer (spec 027): تمييز مسح جهاز HID عن الكتابة
// اليدوية عبر سرعة التتابع + علامة النهاية + الطول.
import 'package:active_class/utils/hardware_scan_buffer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

KeyDownEvent _char(String c) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
      character: c,
    );

KeyDownEvent _key(LogicalKeyboardKey k) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.enter,
      logicalKey: k,
      timeStamp: Duration.zero,
    );

void main() {
  late DateTime clock;
  late List<String> scanned;
  late HardwareScanBuffer buf;

  setUp(() {
    clock = DateTime(2026, 1, 1, 12);
    scanned = [];
    buf = HardwareScanBuffer(
      onScan: scanned.add,
      idleReset: const Duration(milliseconds: 60),
    )..nowOverride = () => clock;
  });

  tearDown(() => buf.dispose());

  void feed(String text, {int gapMs = 8}) {
    for (final ch in text.split('')) {
      buf.feedKey(_char(ch));
      clock = clock.add(Duration(milliseconds: gapMs));
    }
  }

  test('تتابع سريع + Enter → onScan بالكود', () {
    feed('G1-07');
    buf.feedKey(_key(LogicalKeyboardKey.enter));
    expect(scanned, ['G1-07']);
  });

  test('تتابع بطيء (فواصل بشرية) + Enter → لا onScan', () {
    feed('G1-07', gapMs: 130);
    buf.feedKey(_key(LogicalKeyboardKey.enter));
    expect(scanned, isEmpty);
  });

  test('Tab كعلامة نهاية → onScan', () {
    feed('ABC12');
    buf.feedKey(_key(LogicalKeyboardKey.tab));
    expect(scanned, ['ABC12']);
  });

  test('numpadEnter → onScan', () {
    feed('X9');
    buf.feedKey(_key(LogicalKeyboardKey.numpadEnter));
    expect(scanned, ['X9']);
  });

  test('كود بطول 1 بعد trim → لا onScan', () {
    feed(' A ');
    buf.feedKey(_key(LogicalKeyboardKey.enter));
    expect(scanned, isEmpty);
  });

  test('المسافات المحيطة تُقصّ', () {
    feed('  G1-07  ');
    buf.feedKey(_key(LogicalKeyboardKey.enter));
    expect(scanned, ['G1-07']);
  });

  test('خمول بلا علامة نهاية → تصفية، Enter لاحق لا يُنتج شيء', () async {
    feed('G1-0');
    await Future<void>.delayed(const Duration(milliseconds: 90));
    buf.feedKey(_key(LogicalKeyboardKey.enter));
    expect(scanned, isEmpty);
  });

  test('feedKey يرجع false لـ KeyUpEvent و character == null', () {
    final up = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );
    expect(buf.feedKey(up), isFalse);
    expect(buf.feedKey(_key(LogicalKeyboardKey.shiftLeft)), isFalse);
  });

  test('Enter على buffer فارغ → false، لا onScan', () {
    expect(buf.feedKey(_key(LogicalKeyboardKey.enter)), isFalse);
    expect(scanned, isEmpty);
  });

  test('فجوة كبيرة وسط التتابع تعيد البدء', () {
    buf.feedKey(_char('X'));
    clock = clock.add(const Duration(milliseconds: 200)); // فجوة بشرية
    feed('G1-07');
    buf.feedKey(_key(LogicalKeyboardKey.enter));
    expect(scanned, ['G1-07']); // 'X' اتشال
  });
}
