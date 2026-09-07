---
description: "Task list for feature 027 — دعم جهاز قارئ باركود خارجي (HID)"
---

# Tasks: دعم جهاز قارئ باركود خارجي (HID) لتسجيل الحضور والدفع

**Input**: Design documents from `/specs/027-hardware-barcode-scanner/`

**Prerequisites**: plan.md ✅، spec.md ✅، research.md ✅، data-model.md ✅، contracts/ ✅، quickstart.md ✅

**Tests**: مطلوبة لمحرّك `HardwareScanBuffer` فقط (منطق قابل للاختبار بمعزل — قرار research 2). لا اختبارات widget.

**Organization**: مجمّعة حسب user story. MVP = US1 (حضور بالجهاز).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: ملفات مختلفة، بلا اعتماد متبادل — يمكن التوازي
- **[Story]**: US1 / US2 / US3

## Path Conventions

تطبيق Flutter مفرد: `lib/` و`test/` في جذر المستودع.

---

## Phase 1: Setup (بنية مشتركة)

**Purpose**: إضافة الإعداد وثابته — لا شيء يعمل بدونها.

- [X] T001 أضف `SETTING_HARDWARE_SCANNER_ENABLED = 'hardware_scanner_enabled'` في `lib/config/constants.dart` بجوار `SETTING_QR_AUTO_LATE_ENABLED`.
- [X] T002 في `lib/controllers/settings_controller.dart`: أضف `final RxBool hardwareScannerEnabled = false.obs;` بجوار `hideQrInAttendance`، وحمّله داخل `_loadHideQrSettings` (أو دالة تحميل إعدادات المسح) عبر `await _migrateBool(SETTING_HARDWARE_SCANNER_ENABLED) ?? false`، وأضف `Future<void> setHardwareScannerEnabled(bool v)` على نمط `setHideQrInAttendance` (سطر `_dbSet(..., v ? '1' : '0')` داخل try/catch). راجع [contracts/settings-hardware-scanner.md](./contracts/settings-hardware-scanner.md).

**Checkpoint**: الإعداد يُحفظ ويُقرأ؛ لا أثر UI بعد.

---

## Phase 2: Foundational (شرط حاجز لكل القصص)

**Purpose**: محرّك تجميع/تمييز المسح — تعتمد عليه القصص الثلاث.

**⚠️ CRITICAL**: لا يبدأ عمل أي user story قبل اكتمال هذه المرحلة.

- [X] T003 [P] أنشئ `lib/utils/hardware_scan_buffer.dart` — كلاس `HardwareScanBuffer` وفق [contracts/hardware-scan-buffer.md](./contracts/hardware-scan-buffer.md): مُنشئ بـ `onScan` + ثوابت `maxInterKeyGap`=35ms، `idleReset`=120ms، `minLength`=2؛ `bool feedKey(KeyEvent)`؛ `void reset()`؛ `void dispose()`؛ setter اختبار `nowOverride`. `KeyDownEvent` فقط؛ Enter/Tab/numpadEnter → `_flush`؛ فجوة > `maxInterKeyGap` → `reset` قبل الإضافة؛ `_idleTimer` يُعاد تسليحه ويُصفّر بلا `onScan`؛ `_flush` يعمل `trim` ويستدعي `onScan` فقط عند `length >= minLength`.
- [X] T004 [P] أنشئ `test/hardware_scan_buffer_test.dart` — يغطّي: (أ) تتابع سريع (فواصل 10ms) + Enter → `onScan` بالكود المقصوص؛ (ب) تتابع بطيء (فواصل 130ms) + Enter → لا `onScan`؛ (ج) Tab كعلامة نهاية → `onScan`؛ (د) `numpadEnter` → `onScan`؛ (هـ) كود بطول 1 بعد trim → لا `onScan`؛ (و) مسافات محيطة تُقصّ؛ (ز) خمول 120ms بلا نهاية → buffer يُصفّر، Enter لاحق لا يُنتج شيء؛ (ح) `feedKey` يرجع `false` لـ `KeyUpEvent` و`character == null`. استخدم `nowOverride` لحقن الزمن.

**Checkpoint**: `flutter test test/hardware_scan_buffer_test.dart` أخضر.

---

## Phase 3: User Story 1 — حضور بالجهاز (Priority: P1) 🎯 MVP

**Goal**: مسح كرت طالب بجهاز HID في شاشة الحضور يسجّل الحضور فورًا مع صوت/اهتزاز، ويعيد استخدام كل منطق `_handleQR` القائم.

**Independent Test**: تفعيل الإعداد، فتح شاشة الحضور، محاكاة/تنفيذ مسح جهاز لكرت طالب نشط → حضور مسجَّل + صوت نجاح (quickstart سيناريو 1). الكتابة اليدوية لا تسجّل (سيناريو 5).

### Implementation

- [X] T005 [US1] في `lib/views/qr_scanner/qr_scanner_attendance_page.dart` `initState`: اقرأ `_hardwareEnabled` من `SettingsController.hardwareScannerEnabled.value` (بحارس `Get.isRegistered`)، واحسب `_pureScannerMode = _hardwareEnabled && _hideQr`. لو `_hardwareEnabled` أنشئ `_scanBuffer = HardwareScanBuffer(onScan: _handleQR);` (حقل `HardwareScanBuffer? _scanBuffer`).
- [X] T006 [US1] نفس الملف: لفّ جسم `Scaffold` (أو أعلى ودجت مناسب تحت `Scaffold`) بـ `Focus(autofocus: _hardwareEnabled, onKeyEvent: (node, e) { if (!_hardwareEnabled || _tabController.index != 0) return KeyEventResult.ignored; return _scanBuffer!.feedKey(e) ? KeyEventResult.handled : KeyEventResult.ignored; }, child: ...)`. الشرط `_tabController.index != 0` يضمن عدم استهلاك إدخال تبويب "بحث يدوي". راجع [contracts/scanner-screens-integration.md](./contracts/scanner-screens-integration.md).
- [X] T007 [US1] نفس الملف `didChangeAppLifecycleState`: أضف `_scanBuffer?.reset();` في حالتَي `paused` و`resumed`. في `dispose`: أضف `_scanBuffer?.dispose();`.
- [X] T008 [US1] نفس الملف: اجعل `_safeStartScanner()` و`_safeStopScanner()` تبدأ بـ `if (_pureScannerMode) return;` وتخطَّ إنشاء `scannerController` / استدعاء `_safeStartScanner` في `initState` و`postFrameCallback` عند `_pureScannerMode` (حتى لا تُشغَّل الكاميرا إطلاقًا — FR-011). تأكّد أن باقي `_handleQR` (حارس التكرار، `SoundHelper`, `HapticFeedback`) يعمل دون تعديل.

**Checkpoint**: US1 يعمل — MVP قابل للتسليم. الكاميرا لسه تعمل معه لأن `hideQr` غالبًا OFF.

---

## Phase 4: User Story 2 — دفع بالجهاز (Priority: P2)

**Goal**: مسح كرت بجهاز HID في شاشة الدفع يحضّر تفاصيل الدفع للطالب (شهور/حصص/مديونية spec 026) مثل الكاميرا تمامًا.

**Independent Test**: تفعيل الإعداد، فتح "الدفع بالماسح"، مسح كرت طالب نشط → شاشة الدفع تُحضَّر للطالب الصحيح + صوت تأكيد (quickstart سيناريو 8).

### Implementation

- [X] T009 [US2] في `lib/views/qr_scanner/qr_scanner_payment_page.dart` `initState`: نفس نمط T005 — `_hardwareEnabled` من نفس الإعداد، `_pureScannerMode = _hardwareEnabled && settings.hideQrInPayment.value`، وإنشاء `_scanBuffer = HardwareScanBuffer(onScan: <معالج مسح الدفع الحالي>)` (نفس الدالة التي يناديها `MobileScanner.onDetect` في هذه الشاشة).
- [X] T010 [US2] نفس الملف: لفّ الجسم بـ `Focus` بنفس منطق T006 (مفعّل فقط في تبويب "مسح QR")، وأضف `_scanBuffer?.reset()` في lifecycle و`_scanBuffer?.dispose()` في `dispose`.
- [X] T011 [US2] نفس الملف: طبّق حارس `_pureScannerMode` على دوال بدء/إيقاف الكاميرا وإنشاء `scannerController` مثل T008، بحيث لا تُشغَّل الكاميرا في وضع القارئ الخالص.

**Checkpoint**: US1 + US2 يعملان مستقلين.

---

## Phase 5: User Story 3 — وضع القارئ الخالص + سطر الإعدادات (Priority: P3)

**Goal**: عند `hardwareScannerEnabled` + `hideQr` معًا، الكاميرا لا تُنشأ وتظهر بطاقة "القارئ الخارجي جاهز"؛ وإضافة سطر الـSwitch في شاشة الإعدادات ليتحكّم المدرّس بالميزة أصلًا.

**Independent Test**: تفعيل الإعدادين، فتح شاشة الحضور → لا كاميرا + بطاقة جاهزية + المسح بالجهاز يعمل (quickstart سيناريو 6). وتعطيل الإعداد → سلوك حالي تمامًا (سيناريو 7).

### Implementation

- [X] T012 [P] [US3] في `lib/views/settings/settings_page.dart`: أضف سطر `_buildSwitchTile` جديدًا بعد "إخفاء ماسح QR في الحضور" مباشرةً، مع `_buildDivider` قبله — العنوان "قارئ باركود خارجي"، الأيقونة `Icons.barcode_reader` (أو `Icons.qr_code_scanner_rounded`)، اللون `Color(0xFF0EA5E9)`، `rxValue: settings.hardwareScannerEnabled`، `onChanged: (v) async => await settings.setHardwareScannerEnabled(v)`، والنصّان الفرعيان من [contracts/settings-hardware-scanner.md](./contracts/settings-hardware-scanner.md).
- [X] T013 [US3] في `qr_scanner_attendance_page.dart`: عند `_pureScannerMode`، استبدل محتوى تبويب "مسح QR" (`MobileScanner` + overlay + أزرار الكاميرا) ببطاقة حالة: أيقونة `Icons.barcode_reader` كبيرة + "القارئ الخارجي جاهز" + نص فرعي "امسح كرت الطالب — سيظهر التأكيد فورًا". شريط الإحصاء وبانل النتيجة `_AttendancePanel` والتبويب اليدوي بلا تغيير.
- [X] T014 [P] [US3] في `qr_scanner_payment_page.dart`: نفس بطاقة "القارئ الخارجي جاهز" مكان الكاميرا عند `_pureScannerMode`؛ بقية الشاشة (تحضير الدفع، اختيار الشهور، المديونية) بلا تغيير.

**Checkpoint**: كل القصص تعمل مستقلة.

---

## Phase 6: User Story 4 — تأكيد اتصال القارئ (Priority: P3)

**Goal**: المدرّس يتحقق من أن الجهاز مقترن ويقرأ الأكواد قبل الحصة عبر "جرّب القارئ" في الإعدادات، ويرى أثناء الجلسة شارة تؤكد نشاط القارئ وتوقيت آخر مسح. (لا "زر ربط" ولا اسم جهاز — غير ممكن مع HID.)

**Independent Test**: الإعدادات → "جرّب القارئ" → مسح كود → نص مقروء + "✅ HID" (quickstart سيناريو 10). وشاشة الحضور: لا شارة قبل المسح، شارة "نشط • آخر مسح ..." بعده (سيناريو 11).

### Implementation

- [X] T015 [P] [US4] في `lib/views/settings/settings_page.dart`: أسفل سطر Switch القارئ (T012)، وبشرط `settings.hardwareScannerEnabled.value`، أضف سطر "جرّب القارئ" يفتح لوحة تجربة (`StatefulWidget` جديد بنفس الملف أو `lib/views/settings/`): `Focus(autofocus:true)` → `HardwareScanBuffer` خاص، `onScan` يضبط `_lastReadText` + `_success` عبر `setState` فقط (لا `handleScan`، لا DB). عرض: قبل المسح "امسح أي باركود بالجهاز الآن…"؛ بعده "✅ الجهاز يعمل كلوحة مفاتيح (HID)" + "النص المقروء: …". `dispose` للـbuffer عند الطيّ. راجع [contracts/settings-hardware-scanner.md](./contracts/settings-hardware-scanner.md).
- [X] T016 [US4] في `qr_scanner_attendance_page.dart`: أضف حقل `DateTime? _lastHardwareScanAt`؛ في `_handleQR` عند نجاح المسح (طالب موجود وغير مؤرشف) و`_hardwareEnabled` → `setState(() => _lastHardwareScanAt = DateTime.now())`. اعرض شريحة صغيرة (أيقونة `Icons.barcode_reader` + "القارئ الخارجي نشط • آخر مسح <نص نسبي>") أعلى الشاشة عندما `_lastHardwareScanAt != null`؛ في `_pureScannerMode` ادمج الحالة مع بطاقة "جاهز" (قبل المسح: "بانتظار المسح"؛ بعده: "نشط • ..."). راجع [contracts/scanner-screens-integration.md](./contracts/scanner-screens-integration.md).
- [X] T017 [P] [US4] في `qr_scanner_payment_page.dart`: نفس شارة "القارئ نشط" بنفس منطق T016.

**Checkpoint**: US4 يعمل — تشخيص وثقة كاملة.

---

## Phase 7: Polish & Cross-Cutting

- [X] T018 [P] شغّل `flutter test` كاملًا + `flutter analyze` — تأكّد صفر مشاكل جديدة فوق الـbaseline المعروفة (34 info).
- [ ] T019 نفّذ سيناريوهات [quickstart.md](./quickstart.md) 1–11 على جهاز أندرويد حقيقي مع جهاز قارئ باركود HID فعلي (يشمل: كتابة يدوية لا تسجّل، حارس التكرار، رجوع من الخلفية، عدم الانحدار عند التعطيل، "جرّب القارئ"، شارة "نشط").
- [X] T020 [P] حدّث `HANDOFF.md` و`memory/` بملخّص spec 027 (إعداد `hardwareScannerEnabled` محلي، `HardwareScanBuffer` في utils، صفر DB/مزامنة، الشاشتان + سطر الإعدادات + "جرّب القارئ" + شارة النشاط، لا ربط/اسم جهاز مع HID).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: تبدأ فورًا. T001 قبل T002.
- **Foundational (Phase 2)**: تبدأ بعد Phase 1. T003 و T004 متوازيان (لكن T004 يختبر T003 — اكتب T003 أولًا أو معًا).
- **US1 (Phase 3)**: بعد Phase 2. T005 → T006 → T007 → T008 (نفس الملف، تسلسلي).
- **US2 (Phase 4)**: بعد Phase 2. مستقل عن US1 (ملف مختلف). T009 → T010 → T011 تسلسلي.
- **US3 (Phase 5)**: T012 مستقل تمامًا (يمكن مبكرًا). T013 يعتمد US1 (نفس ملف الحضور، بعد T008). T014 يعتمد US2 (بعد T011).
- **US4 (Phase 6)**: بعد Phase 2. T015 يعتمد T012 (نفس ملف الإعدادات). T016 يعتمد US1 (نفس ملف الحضور، بعد T008/T013). T017 يعتمد US2 (بعد T011/T014).
- **Polish (Phase 7)**: بعد كل القصص المطلوبة.

### Parallel Opportunities

- T003 + T004 (منطق + اختباره).
- T012 (سطر الإعدادات) موازٍ لأي شيء بعد Phase 1 — عمليًا يمكن دمجه مع Phase 1.
- US1 و US2 يمكن لمطوّرَين مختلفَين بالتوازي (ملفان مختلفان) بعد Phase 2.
- T014 موازٍ لـ T013؛ T017 موازٍ لـ T016 (ملفان مختلفان).
- T015 (جرّب القارئ) موازٍ لعمل الشاشتين — يعتمد فقط T012.

---

## Implementation Strategy

### MVP (US1 فقط)

1. Phase 1 (T001–T002) → Phase 2 (T003–T004) → Phase 3 (T005–T008).
2. **قف وتحقّق**: quickstart سيناريو 1 + 5 على جهاز.
3. سلّم — المدرّس يقدر يسجّل حضور بالجهاز (الكاميرا لسه بديل موجود).

> ملاحظة: MVP يحتاج سطر الإعدادات T012 عمليًا ليفعّل المدرّس الميزة — انقله لـ Phase 1 لو هتسلّم MVP وحده.

### Incremental Delivery

Setup+Foundational → US1 (MVP) → US2 (دفع) → US3 (وضع خالص) → US4 (تأكيد اتصال) → Polish.
