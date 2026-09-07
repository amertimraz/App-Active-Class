# Implementation Plan: دعم جهاز قارئ باركود خارجي (HID) لتسجيل الحضور والدفع

**Branch**: `027-hardware-barcode-scanner` | **Date**: 2026-09-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/027-hardware-barcode-scanner/spec.md`

## Summary

إضافة دعم اختياري لجهاز قارئ باركود خارجي يعمل بوضع لوحة مفاتيح (HID) في شاشتَي "تسجيل الحضور بـ QR" و"الدفع بالماسح". الجهاز يُدخل نص كود الطالب بسرعة عالية متبوعًا بـ Enter؛ نلتقط هذا الإدخال عبر `HardwareKeyboard` / `Focus` خفي داخل كل شاشة، ونميّزه عن الكتابة اليدوية عبر **سرعة التتابع + علامة نهاية (Enter/Tab)**، ثم نمرّر الكود المكتمل إلى نفس `QRController.handleScan()` المستخدَم للكاميرا — فيُعاد استخدام كل منطق البحث/الرفض/التأخر/تحضير الدفع كما هو. إعداد محلي جديد واحد `hardwareScannerEnabled` في `SettingsController` (نمط `hideQrInAttendance`)، صفر تغيير DB/مزامنة، صفر مكتبات جديدة.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX (state)، `flutter/services.dart` (`HardwareKeyboard`, `KeyEvent`) — **مضمّنة، لا إضافة جديدة**. `mobile_scanner` الحالي يبقى كما هو للكاميرا. `audioplayers` عبر `SoundHelper` الحالي.

**Storage**: مخزن الإعدادات المحلي القائم في `SettingsController` (`_dbSet` / `_migrateBool` — جدول `app_settings` المحلي). لا جداول جديدة، DB version يبقى **28**.

**Testing**: `flutter test` — اختبارات وحدة لمحرّك تمييز المسح (buffer + timing + terminator) بمعزل عن الـ widgets.

**Target Platform**: Android (جهاز المدرّس MIUI أساسًا)؛ الكود لا يعتمد منصة محددة.

**Project Type**: تطبيق موبايل Flutter (هيكل مفرد `lib/`).

**Performance Goals**: التقاط مسح كامل ومعالجته خلال < 1s من لحظة قراءة الجهاز؛ لا تأثير محسوس على fps الشاشة عند تعطيل الإعداد (المستمع لا يُركَّب أصلًا).

**Constraints**: التطبيق في المقدمة على شاشة الحضور/الدفع لالتقاط الإدخال (قيد موثّق). لا تغيير DB، لا تغيير مزامنة، لا مكتبات جديدة. إعادة استخدام أقصى ما يمكن من `QRController` والشاشتين.

**Scale/Scope**: 2 شاشتان مُعدّلتان، 1 عنصر خدمة/محرّك جديد صغير (`HardwareScanBuffer`)، 1 إعداد + سطر UI واحد في الإعدادات، ~1 ملف اختبار.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

ملف الدستور `.specify/memory/constitution.md` لا يزال قالبًا فارغًا (placeholders غير مُعبّأة) — لا مبادئ قابلة للإنفاذ. نطبّق أعراف المشروع الفعلية المستخلصة من HANDOFF والسبيكات السابقة:

| عرف المشروع | الحالة |
|---|---|
| صفر تغيير DB إلا بترقية نسخة صريحة | ✅ PASS — لا تغيير |
| صفر تغيير في مزامنة الفريق إلا بحاجة مبرّرة | ✅ PASS — الإعداد محلي، لا حقول مزامنة |
| لا مكتبات جديدة بدون داعٍ | ✅ PASS — `HardwareKeyboard` مضمّن |
| إعادة استخدام المنطق القائم | ✅ PASS — نقطة دخول موحّدة `handleScan()` |
| اختبارات تغطّي المنطق الجديد + `flutter analyze` نظيف | ✅ مخطّط لها |
| git push بإذن صريح فقط؛ commit على `main` | ✅ ملحوظ |

**النتيجة: PASS** — لا انتهاكات، جدول Complexity Tracking غير مطلوب.

## Project Structure

### Documentation (this feature)

```text
specs/027-hardware-barcode-scanner/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — 7 قرارات محسومة
├── data-model.md        # Phase 1 — كيانات (إعداد + حالة runtime، لا سكيمة)
├── quickstart.md        # Phase 1 — 6 سيناريوهات تحقّق
├── contracts/
│   ├── settings-hardware-scanner.md      # عقد الإعداد + إجراء "جرّب القارئ"
│   ├── hardware-scan-buffer.md           # عقد محرّك تمييز/تجميع المسح
│   └── scanner-screens-integration.md    # عقد دمج الشاشتين + مصفوفة الأوضاع + شارة "القارئ نشط"
└── tasks.md             # Phase 2 — /speckit-tasks (ليس من هذا الأمر)
```

### Source Code (repository root)

```text
lib/
├── controllers/
│   ├── settings_controller.dart        # + hardwareScannerEnabled + setHardwareScannerEnabled + تحميل
│   └── qr_controller.dart              # بلا تغيير جوهري (نقطة الدخول handleScan تكفي)
├── config/
│   └── constants.dart                  # + SETTING_HARDWARE_SCANNER_ENABLED
├── utils/
│   └── hardware_scan_buffer.dart       # جديد — محرّك تجميع ضغطات المفاتيح + تمييز المسح
├── views/
│   ├── qr_scanner/
│   │   ├── qr_scanner_attendance_page.dart   # + Focus خفي + وضع "قارئ خالص" + شارة "القارئ نشط"
│   │   └── qr_scanner_payment_page.dart      # نفس الدمج + الشارة
│   └── settings/
│       └── settings_page.dart          # + سطر Switch "قارئ باركود خارجي" + إجراء "جرّب القارئ"

test/
└── hardware_scan_buffer_test.dart      # جديد — وحدة: timing، terminator، طول، تصفية، تكرار
```

**Structure Decision**: هيكل Flutter المفرد القائم. المنطق الجديد الوحيد القابل للاختبار بمعزل (`HardwareScanBuffer`) يوضع في `lib/utils/` بجانب `helpers.dart`. الشاشتان تستضيفان مستمع لوحة المفاتيح فقط عند تفعيل الإعداد، وتفوّضان الكود المكتمل إلى `qrCtrl.handleScan()` — نفس مسار الكاميرا. لا `QRController` جديد ولا تعديل جوهري فيه.

## Complexity Tracking

> لا انتهاكات دستورية — لا شيء يُبرَّر.
