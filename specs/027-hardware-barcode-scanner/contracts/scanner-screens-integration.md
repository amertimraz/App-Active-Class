# Contract: دمج القارئ الخارجي في شاشتَي الحضور والدفع

## شاشة الحضور — `qr_scanner_attendance_page.dart`

### `initState`
```dart
_hardwareEnabled = Get.isRegistered<SettingsController>() &&
    Get.find<SettingsController>().hardwareScannerEnabled.value;

if (_hardwareEnabled) {
  _scanBuffer = HardwareScanBuffer(onScan: (code) => _handleQR(code));
}
```
- `_pureScannerMode = _hardwareEnabled && _hideQr` — الكاميرا لا تُنشأ.
- عند `_pureScannerMode`: تخطّي `scannerController = MobileScannerController(...)` و`_safeStartScanner()` (اجعلها no-op بشرط `if (_pureScannerMode) return;`).

### شجرة الودجت
- لفّ `Scaffold.body` (أو أعلى عنصر مناسب) بـ:
```dart
Focus(
  autofocus: _hardwareEnabled,
  onKeyEvent: (node, event) {
    if (!_hardwareEnabled) return KeyEventResult.ignored;
    return _scanBuffer.feedKey(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  },
  child: ...,
)
```
- **استثناء التبويب اليدوي**: عندما يكون تبويب "بحث يدوي" نشطًا وحقل البحث مركَّز، `feedKey` سيُهمل الكتابة البشرية تلقائيًا (بطيئة) — لا حاجة لتعطيل الـFocus. لكن يجب ألّا يُرجع `handled` لأحرف عادية بطيئة (المحرّك يرجع `true` لأي حرف طباعة!). **قرار**: في تبويب "بحث يدوي" مرّر `_hardwareEnabled && _tabController.index == 0` كشرط تفعيل `feedKey`، بحيث لا يُستهلك إدخال حقل البحث اليدوي إطلاقًا.

### وضع القارئ الخالص (`_pureScannerMode`)
- تبويب "مسح QR": استبدال `MobileScanner` + overlay بـبطاقة:
  - أيقونة `Icons.barcode_reader` كبيرة + نص "القارئ الخارجي جاهز".
  - نص فرعي "امسح كرت الطالب — سيظهر التأكيد فورًا".
  - مؤشّر نبض/أنيميشن بسيط اختياري (لا إلزام).
- شريط الإحصاء + بانل النتيجة (`_AttendancePanel`) + التبويب اليدوي: بلا تغيير.
- أزرار الكاميرا (فلاش/تبديل): تُخفى في هذا الوضع.

### `didChangeAppLifecycleState`
```dart
if (state == AppLifecycleState.paused)  _scanBuffer?.reset();
if (state == AppLifecycleState.resumed) _scanBuffer?.reset();
```

### `dispose`
```dart
_scanBuffer?.dispose();
```

### `_handleQR` — تعديلان
1. السطر الذي يستدعي `_safeStartScanner()` بعد فشل المسح: يبقى — `_safeStartScanner` صارت no-op في `_pureScannerMode`.
2. عند **نجاح** المسح (طالب موجود وغير مؤرشف) ومصدره الجهاز: `setState(() => _lastHardwareScanAt = DateTime.now());` — لشارة "القارئ نشط". (يمكن تمرير علم `fromHardware` من `_scanBuffer.onScan` لتمييز المصدر عن الكاميرا؛ أو ضبطها دائمًا عند تفعيل الإعداد.)

حارس التكرار والصوت والاهتزاز كلها تعمل كما هي لأن مسح الجهاز يدخل من نفس الباب.

### شارة "القارئ الخارجي نشط" (FR-018 — US4)
- تظهر فقط عندما `_hardwareEnabled == true`.
- `_lastHardwareScanAt == null` → لا تُعرض كـ"نشط" (تُخفى، أو في وضع القارئ الخالص تُدمج مع بطاقة "بانتظار المسح").
- `_lastHardwareScanAt != null` → شريحة صغيرة أعلى الشاشة (بجوار/تحت شريط عدد الحاضرين): أيقونة `Icons.barcode_reader` + "القارئ الخارجي نشط • آخر مسح <نص نسبي>".
- النص النسبي: helper توقيت نسبي قائم أو حساب بسيط؛ يُحدَّث عند كل مسح لاحق (وتحديث دوري ~30s اختياري).

---

## شاشة الدفع — `qr_scanner_payment_page.dart`

نفس النمط بالضبط:
- `_hardwareEnabled` من نفس الإعداد.
- `_pureScannerMode = _hardwareEnabled && settings.hideQrInPayment.value`.
- `HardwareScanBuffer(onScan: (code) => <معالج مسح الدفع الحالي>(code))` — المعالج نفسه الذي تناديه الكاميرا (يحتوي حارس التكرار + `qrCtrl.handleScan` + الصوت).
- `Focus` يلفّ الجسم، مفعّل فقط في تبويب "مسح QR".
- وضع القارئ الخالص: بطاقة "القارئ الخارجي جاهز" مكان الكاميرا؛ بقية الشاشة (تحضير الدفع، اختيار الشهور، المديونية — spec 026) بلا تغيير.

---

## مصفوفة القبول (تُستخدم في quickstart)

| # | الإعداد | الفعل | المتوقّع |
|---|---|---|---|
| 1 | hardware=on, hideQr=off | مسح كرت طالب نشط بالجهاز | حضور مسجَّل + صوت نجاح + بطاقة الطالب |
| 2 | hardware=on, hideQr=off | مسح كود غير موجود | صوت خطأ + رسالة "غير موجود" + لا تسجيل |
| 3 | hardware=on, hideQr=off | مسح كرت مرتين خلال <1.5s | تسجيل مرة واحدة |
| 4 | hardware=on, hideQr=off | كتابة يدوية "abc" + Enter في حقل البحث | لا تسجيل، البحث يعمل عادي |
| 5 | hardware=on, hideQr=on | فتح الشاشة | لا كاميرا، بطاقة "القارئ جاهز"، المسح بالجهاز يعمل |
| 6 | hardware=off | فتح الشاشة + محاكاة إدخال جهاز | سلوك حالي تمامًا، الإدخال يُتجاهَل |
| 7 | hardware=on | مسح كرت مؤرشف | رفض + رسالة "مؤرشف" + صوت خطأ |
| 8 | hardware=on (دفع) | مسح كرت طالب نشط | شاشة الدفع تُحضَّر للطالب الصحيح |
| 9 | hardware=on | فتح الشاشة، لا مسح بعد | لا شارة "نشط" |
| 10 | hardware=on | بعد أول مسح ناجح | شارة "القارئ نشط • آخر مسح ..." تظهر وتبقى وتحدّث التوقيت |
| 11 | إعدادات، hardware=on | "جرّب القارئ" + مسح باركود | نص مقروء + "✅ HID"، بلا أي تسجيل |
| 12 | إعدادات، hardware=on | "جرّب القارئ" + كتابة يدوية | لا مؤشّر نجاح |
