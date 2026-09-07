# Data Model: دعم جهاز قارئ باركود خارجي (HID)

لا كيانات قاعدة بيانات جديدة. DB version يبقى **28**. لا حقول مزامنة. لا `toCloudMap` متأثّر.

## 1. إعداد محلي: `hardwareScannerEnabled`

| الخاصية | القيمة |
|---|---|
| المكان | `SettingsController` (Rx)، مخزَّن عبر `_dbSet` في جدول الإعدادات المحلي القائم |
| المفتاح | `SETTING_HARDWARE_SCANNER_ENABLED` في `lib/config/constants.dart` (نصيًا `'hardware_scanner_enabled'`) |
| النوع | `RxBool` |
| الافتراضي | `false` |
| التحميل | `await _migrateBool(SETTING_HARDWARE_SCANNER_ENABLED) ?? false` ضمن دالة تحميل إعدادات المسح |
| الحفظ | `setHardwareScannerEnabled(bool v)` → `hardwareScannerEnabled.value = v; await _dbSet(key, v ? '1' : '0')` |
| المزامنة | لا — محلي لكل جهاز (مثل `hideQrInAttendance`) |
| قيود التحقّق | لا شيء (قيمة منطقية) |

**العلاقة بالإعدادات القائمة**: يُقرأ مع `hideQrInAttendance` / `hideQrInPayment` لتحديد وضع التشغيل (انظر contract الدمج).

## 2. حالة runtime: `HardwareScanBuffer` (كائن غير مُخزَّن)

محرّك في الذاكرة داخل كل شاشة مسح؛ لا يُسرَّد ولا يُخزَّن.

| الحقل | النوع | الوصف |
|---|---|---|
| `_chars` | `StringBuffer` | الأحرف المتجمّعة من المسح الجاري |
| `_lastKeyAt` | `DateTime?` | وقت آخر ضغطة — لحساب الفاصل الزمني |
| `_idleTimer` | `Timer?` | يُصفّر الـbuffer بعد خمول > `idleReset` |
| `onScan` | `void Function(String code)` | callback يُستدعى عند مسح مكتمل صالح |

**ثوابت مضبوطة داخليًا** (غير معروضة للمستخدم):

| الثابت | القيمة | المعنى |
|---|---|---|
| `maxInterKeyGap` | `50ms` | أقصى فاصل بين حرفين ليُعدّ إدخال جهاز |
| `idleReset` | `150ms` | خمول بلا نهاية → تصفير |
| `minLength` | `2` | أقل طول نص مقبول بعد trim |

**دورة الحياة**:
1. `feedKey(KeyEvent e)` — تُستدعى من `HardwareKeyboard` handler في الشاشة:
   - `KeyDownEvent` فقط؛ تجاهل up/repeat.
   - Enter/Tab/numpadEnter → `_flush()`.
   - حرف عادي (`e.character` غير فارغ وغير تحكّم):
     - لو `_lastKeyAt != null` والفاصل `> maxInterKeyGap` → `_reset()` (بداية تتابع جديد؛ الإدخال السابق كان بشريًا/قديمًا).
     - `_chars.write(char)`؛ `_lastKeyAt = now`؛ إعادة تسليح `_idleTimer`.
2. `_flush()`:
   - `code = _chars.toString().trim()`.
   - لو `code.length >= minLength` → `onScan(code)`.
   - `_reset()` دائمًا بعدها.
3. `_reset()` — تفريغ `_chars`، `_lastKeyAt = null`، إلغاء `_idleTimer`.
4. `dispose()` — إلغاء المؤقّت.

**ملاحظة**: حارس التكرار (نفس الكود خلال 1.5s) **ليس** مسؤولية المحرّك — يبقى في `_handleQR` بالشاشة كما هو (قرار 5).

## 2.b حالة runtime: شارة "القارئ نشط" (غير مخزَّنة)

| الحقل | النوع | الوصف |
|---|---|---|
| `_lastHardwareScanAt` | `DateTime?` (`setState` في الشاشة، أو `Rxn<DateTime>` في `QRController`) | يُضبط على `DateTime.now()` عند كل مسح جهاز **ناجح** (طالب موجود وغير مؤرشف). `null` = لم يحدث مسح بعد هذه الجلسة. |

- تُقرأ لعرض شارة: `_lastHardwareScanAt == null` → لا شارة "نشط" (أو "بانتظار أول مسح")؛ غير ذلك → شارة "القارئ الخارجي نشط • آخر مسح <نص نسبي>".
- النص النسبي: إعادة استخدام أي helper توقيت نسبي قائم، أو حساب بسيط (منذ لحظات / منذ N دقيقة).
- لا تُخزَّن ولا تُزامَن؛ تُصفَّر بإغلاق الشاشة.
- تحديث دوري خفيف للنص (كل ~30s) اختياري — يكفي التحديث عند كل مسح.

## 2.c حالة runtime: حقل "جرّب القارئ" في الإعدادات (غير مخزَّنة)

عنصر `StatefulWidget` صغير داخل `settings_page.dart` يظهر فقط عند `hardwareScannerEnabled == true` والمستخدم فتح "جرّب القارئ":

| الحقل | النوع | الوصف |
|---|---|---|
| `_testBuffer` | `HardwareScanBuffer` | نسخة مخصّصة لحقل التجربة، `onScan` يضبط الحقول أدناه فقط |
| `_lastReadText` | `String?` | آخر نص خام مقروء |
| `_success` | `bool` | صار `true` بعد أول مسح جهاز صالح |

- `onScan(code)` → `setState(() { _lastReadText = code; _success = true; })` — **لا** استدعاء `qrCtrl.handleScan`، لا بحث طالب، لا أثر بيانات.
- يُغلَق/يُتخلَّص منه عند طيّ القسم أو مغادرة الشاشة.

## 3. مصفوفة أوضاع التشغيل (مشتقّة، لكل شاشة)

| `hardwareScannerEnabled` | `_hideQr` (للشاشة) | كاميرا مُنشأة؟ | مستمع الجهاز؟ | واجهة تبويب "مسح QR" |
|---|---|---|---|---|
| false | false | نعم | لا | الكاميرا (الحالي) |
| false | true | لا | لا | يُخفى التبويب (الحالي) |
| true | false | نعم | نعم | الكاميرا + التقاط جهاز صامت |
| true | true | لا | نعم | بطاقة "بانتظار المسح من القارئ الخارجي" |
