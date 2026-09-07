# Contract: `HardwareScanBuffer`

ملف جديد: `lib/utils/hardware_scan_buffer.dart`. لا اعتماد على GetX ولا Flutter widgets — فقط `dart:async` و`package:flutter/services.dart` (لأنواع `KeyEvent`). قابل للاختبار بمعزل.

## الواجهة العامة

```dart
class HardwareScanBuffer {
  HardwareScanBuffer({
    required this.onScan,
    this.maxInterKeyGap  = const Duration(milliseconds: 35),
    this.idleReset       = const Duration(milliseconds: 120),
    this.minLength       = 2,
  });

  final void Function(String code) onScan;
  final Duration maxInterKeyGap;
  final Duration idleReset;
  final int minLength;

  /// تُستدعى لكل KeyEvent من Focus.onKeyEvent.
  /// ترجع true لو "استهلكت" الحدث (مسح جهاز محتمل) — عشان الشاشة
  /// تقدر ترجع KeyEventResult.handled وتمنع تسرّب الحدث لودجت تانية.
  bool feedKey(KeyEvent event);

  /// تصفير يدوي (عند resume من الخلفية، أو تبديل تبويب).
  void reset();

  void dispose();

  // اختبار فقط: حقن ساعة
  @visibleForTesting
  set nowOverride(DateTime Function()? fn);
}
```

## سلوك `feedKey`

| الحدث | الشرط | الإجراء | الإرجاع |
|---|---|---|---|
| ليس `KeyDownEvent` | — | لا شيء | `false` |
| `enter` / `numpadEnter` / `tab` | الـbuffer غير فارغ | `_flush()` | `true` |
| `enter` / `numpadEnter` / `tab` | الـbuffer فارغ | لا شيء | `false` |
| حرف قابل للطباعة (`event.character` طوله 1، ليس تحكّمًا) | الفاصل عن آخر ضغطة `> maxInterKeyGap` | `reset()` ثم إضافة الحرف، ضبط الوقت والمؤقّت | `true` |
| حرف قابل للطباعة | الفاصل `<= maxInterKeyGap` أو أول حرف | إضافة الحرف، ضبط الوقت، إعادة تسليح المؤقّت | `true` |
| غير ذلك (تحكّم، `character == null`) | — | لا شيء | `false` |

## سلوك `_flush`

1. `code = buffer.trim()`
2. إن `code.length >= minLength` → استدعاء `onScan(code)`
3. استدعاء `reset()` (دائمًا)

## سلوك المؤقّت (`idleReset`)

- يُعاد تسليحه مع كل حرف مقبول.
- عند انطلاقه → `reset()` بلا استدعاء `onScan` (الإدخال البشري البطيء أو المسح المقطوع يُهمَل — FR-010).

## ثوابت لا يجوز كسرها

- لا يستدعي `onScan` أبدًا بكود أقصر من `minLength` بعد `trim`.
- لا يستدعي `onScan` أبدًا بدون علامة نهاية صريحة (Enter/Tab).
- تتابع أحرف بطيء (فواصل بشرية ~150ms) لا يُنتج `onScan` حتى مع Enter نهائي — لأن `reset()` يقع عند كل فجوة تتجاوز `maxInterKeyGap` فيبقى الـbuffer قصيرًا/فارغًا. (يحقّق SC-003.)
- لا حالة داخلية مشتركة بين نسختين — كل شاشة تُنشئ نسختها.

## حارس التكرار

**خارج هذا العقد.** يبقى في `_handleQR` (شاشة الحضور) وما يقابله (شاشة الدفع): `_lastScan` + `_lastScanAt` + نافذة 1500ms.
