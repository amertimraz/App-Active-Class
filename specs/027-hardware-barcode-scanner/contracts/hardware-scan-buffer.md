# Contract: `HardwareScanBuffer`

ملف: `lib/utils/hardware_scan_buffer.dart`. لا اعتماد على GetX ولا Flutter widgets — فقط `dart:async` و`package:flutter/foundation.dart` و`package:flutter/services.dart` (لأنواع `KeyEvent`). قابل للاختبار بمعزل.

## الواجهة العامة

```dart
class HardwareScanBuffer {
  HardwareScanBuffer({
    required this.onScan,
    this.maxAvgGap        = const Duration(milliseconds: 50),
    this.idleReset        = const Duration(milliseconds: 300),
    this.newSequenceGap   = const Duration(milliseconds: 250),
    this.minLength        = 2,
  });

  final void Function(String code) onScan;
  final Duration maxAvgGap;      // أقصى متوسط زمن/حرف ليُعدّ جهازًا
  final Duration idleReset;      // خمول بلا نهاية → تصفية
  final Duration newSequenceGap; // فجوة أكبر منها = تتابع جديد
  final int minLength;

  /// تُستدعى لكل KeyEvent من مستمع الكيبورد في الشاشة.
  /// ترجع true لو "استهلكت" الحدث (مسح جهاز محتمل).
  bool feedKey(KeyEvent event);

  void reset();     // تصفير يدوي (resume، تبديل تبويب، إغلاق لوحة تجربة)
  void dispose();

  @visibleForTesting
  set nowOverride(DateTime Function()? fn); // اختبار فقط
}
```

## سلوك `feedKey`

| الحدث | الشرط | الإجراء | الإرجاع |
|---|---|---|---|
| ليس `KeyDownEvent` | — | لا شيء | `false` |
| `enter` / `numpadEnter` / `tab` | التتابع غير فارغ (`_count > 0`) | `_flush()` | `true` |
| `enter` / `numpadEnter` / `tab` | التتابع فارغ | لا شيء | `false` |
| حرف قابل للطباعة (`event.character` طوله 1، ليس تحكّمًا) | الفاصل عن آخر ضغطة `> newSequenceGap` | تصفير أولًا، ثم إضافة الحرف | `true` |
| حرف قابل للطباعة | غير ذلك (أو أول حرف) | إضافة الحرف، ضبط `_seqStart` لو null، إعادة تسليح المؤقّت | `true` |
| غير ذلك (تحكّم، `character == null`) | — | لا شيء | `false` |

## سلوك `_flush`

1. `code = buffer.trim()` ؛ التقط `count`, `seqStart`, `end (= آخر ضغطة)`
2. تصفير الحالة **دائمًا**
3. لو `code.length < minLength` أو `count == 0` → توقّف بلا `onScan`
4. `avgMs = (end - seqStart) / count`
5. لو `avgMs <= maxAvgGap` → `onScan(code)`

## سلوك المؤقّت (`idleReset`)

- يُعاد تسليحه مع كل حرف مقبول.
- عند انطلاقه → تصفير بلا `onScan` (إدخال بشري بطيء / مسح مقطوع يُهمَل — FR-010).

## ثوابت لا يجوز كسرها

- لا `onScan` أبدًا بكود أقصر من `minLength` بعد `trim`.
- لا `onScan` أبدًا بدون علامة نهاية صريحة (Enter/Tab).
- لا `onScan` أبدًا لتتابع متوسط زمنه لكل حرف أبطأ من `maxAvgGap` — يشمل كتابة بشرية لكود كامل حتى مع Enter نهائي (يحقّق SC-003).
- **jank لحظي** (فاصل واحد 80–200ms وسط تتابع سريع) لا يكسر الكشف — المتوسط على التتابع كله يمتصّه.
- لا حالة داخلية مشتركة بين نسختين — كل شاشة/لوحة تُنشئ نسختها وتتخلّص منها.

## حارس التكرار

**خارج هذا العقد.** يبقى في `_handleQR` (شاشة الحضور) وما يقابله (شاشة الدفع): `_lastScan` + `_lastScanAt` + نافذة 1500ms.
