# Contract: إعداد `hardwareScannerEnabled`

## `SettingsController`

```dart
// constants.dart
const String SETTING_HARDWARE_SCANNER_ENABLED = 'hardware_scanner_enabled';

// SettingsController
final RxBool hardwareScannerEnabled = false.obs;

// ضمن دالة تحميل إعدادات المسح القائمة (بجوار _loadHideQrSettings):
hardwareScannerEnabled.value =
    await _migrateBool(SETTING_HARDWARE_SCANNER_ENABLED) ?? false;

Future<void> setHardwareScannerEnabled(bool v) async {
  hardwareScannerEnabled.value = v;
  try {
    await _dbSet(SETTING_HARDWARE_SCANNER_ENABLED, v ? '1' : '0');
  } catch (_) {}
}
```

**ثوابت السلوك**:
- الافتراضي `false` عند غياب المفتاح أو أي خطأ قراءة.
- القيمة تستمر بعد إعادة تشغيل التطبيق.
- لا تُرسَل إلى Supabase؛ لا تظهر في أي `toCloudMap` / حمولة مزامنة.
- تعديلها لا يفشل أبدًا بشكل يوقف التطبيق (try/catch صامت مثل باقي الإعدادات).

## شاشة الإعدادات (`settings_page.dart`)

سطر `_buildSwitchTile` جديد ضمن قسم إعدادات المسح، بعد "إخفاء ماسح QR في الحضور" مباشرةً:

```
العنوان : "قارئ باركود خارجي"
الأيقونة: Icons.barcode_reader (أو Icons.qr_code_scanner_rounded)
اللون   : const Color(0xFF0EA5E9)  // مطابق لبقية إعدادات المسح
rxValue : settings.hardwareScannerEnabled
onChanged: (v) async => await settings.setHardwareScannerEnabled(v)
subtitle عند التفعيل   : "امسح كروت الطلاب بجهاز قارئ باركود موصول بالموبايل (سلكي/بلوتوث)"
subtitle عند التعطيل   : "الجهاز لازم يقرا QR ويشتغل كلوحة مفاتيح — والتطبيق مفتوح على شاشة الحضور/الدفع وقت المسح"
```

**ثابت**: تغيير هذا السطر لا يمسّ أي سطر إعداد آخر ولا ترتيبها.

## إجراء "جرّب القارئ" (FR-016, FR-017 — US4)

يظهر **فقط** عندما `settings.hardwareScannerEnabled.value == true`، أسفل سطر الـSwitch مباشرةً:

```
سطر قابل للنقر: "جرّب القارئ"  (Icons.wifi_tethering / Icons.sensors)
  ↓ عند النقر: يوسّع/يفتح لوحة تجربة (inline expand أو bottom sheet)
```

**لوحة التجربة** — `StatefulWidget` مخصّص:
- تُنشئ `HardwareScanBuffer` خاصًّا بها؛ `onScan(code)` → `setState`:
  - `_lastReadText = code`
  - `_success = true`
- تُغلِّف محتواها بـ `Focus(autofocus: true, onKeyEvent: ...)` يمرّر لـ `_testBuffer.feedKey`.
- العرض:
  - قبل أي مسح: "امسح أي باركود بالجهاز الآن..." + أيقونة انتظار.
  - بعد مسح ناجح: "✅ الجهاز يعمل كلوحة مفاتيح (HID)" + سطر رمادي `النص المقروء: <code>`.
- **ثوابت**:
  - لا استدعاء `qrCtrl.handleScan` ولا `DatabaseService` ولا أي كتابة.
  - لا يظهر `_success` إلا من مسار `onScan` (تتابع سريع + علامة نهاية) — الكتابة اليدوية لا تُنجحه (FR-017).
  - `dispose` على `_testBuffer` عند طيّ اللوحة أو مغادرة شاشة الإعدادات.

