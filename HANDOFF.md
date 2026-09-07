# Active Class — Handoff (محادثة جديدة)

> آخر تحديث: 2026-09-07. المشروع: `C:\repo\active_class` — تطبيق Flutter عربي/RTL للمدرّسين الخصوصيين.
> كلّمني عربي (مصري). Flutter 3.38.1 / Dart 3.5.4، GetX، sqflite، Firebase (بوابة أولياء الأمور + امتحانات أونلاين)، Supabase self-hosted على VPS (مزامنة وضع الفريق).

---

## ✅ اللي اتعمل في الجلسة الحالية

### spec 027 — دعم جهاز قارئ باركود خارجي (HID) في شاشتَي الحضور والدفع (متنفّذ بالكامل، لسه ماتعملّوش commit)

**الفكرة:** جهاز قارئ باركود 2D (USB-OTG أو بلوتوث) بوضع HID = كيبورد: بيـ«كتب» الكود بسرعة + Enter. صفر مكتبات/أذونات/DB/مزامنة.

**اللي اتعمل:**
- **`lib/config/constants.dart`**: `SETTING_HARDWARE_SCANNER_ENABLED = 'hardware_scanner_enabled'`.
- **`lib/controllers/settings_controller.dart`**: `RxBool hardwareScannerEnabled` (افتراضي false، محلي، غير مُزامن)، يُحمَّل في `_loadHideQrSettings`، + `setHardwareScannerEnabled`.
- **`lib/utils/hardware_scan_buffer.dart`** (جديد): `HardwareScanBuffer` — يجمّع `KeyDownEvent`، يُصدر `onScan(code)` عند Enter/Tab/numpadEnter لو: طول ≥2 بعد trim **و متوسط الزمن/حرف على التتابع كله ≤50ms** (متوسط مش فاصل بين كل حرفين — عشان jank لحظي في الـUI ميكسرش الكشف). فجوة >250ms → تتابع جديد؛ خمول >300ms → تصفير. `nowOverride` للاختبار.
- **`test/hardware_scan_buffer_test.dart`** (جديد، 10 اختبارات كلها تعدّي).
- **`lib/widgets/hardware_reader_widgets.dart`** (جديد): `HardwareActiveBadge` (شارة "القارئ نشط • آخر مسح ..." بعد أول مسح ناجح)، `ReaderReadyPanel` (بديل الكاميرا في الوضع الخالص)، `HardwareScannerTestTile` ("جرّب القارئ" في الإعدادات — يمسك مسح واحد، يعرض النص + "✅ HID"، صفر أثر بيانات)، + `relativeScanText`.
- **`qr_scanner_attendance_page.dart` + `qr_scanner_payment_page.dart`**: `HardwareKeyboard.instance.addHandler(_hwKeyHandler)` في initState (مش `Focus` — عشان الفوكس ممكن ميبقاش على الشاشة)، بيتشال في dispose. حواجز الـhandler: تاب index==0 + `ModalRoute.isCurrent` + mounted. يغذّي `_scanBuffer` → `_handleQR(code, fromHardware:true)` / `_handle(...)` (حارس التكرار + الصوت + الاهتزاز مُعاد استخدامها). `_pureScannerMode = hardwareEnabled && hideQr` → الكاميرا متتشغّلش خالص + `ReaderReadyPanel`. `_qrTabVisible = !hideQr || pureMode`. الشارة تشتغل بس مع `fromHardware` (مش إدخال يدوي). buffer.reset() عند تبديل التاب.
- **`settings_page.dart`**: سطر Switch "قارئ باركود خارجي" بعد "إخفاء ماسح QR في الحضور" + `HardwareScannerTestTile` تحته لما مفعّل.

**التحقّق:** كل `flutter test` (63 = 53 قديمة + 10 جديدة) يعدّي، `flutter analyze` = 34 issue (نفس الـbaseline بالظبط، صفر جديد).

**قرار مهم موثّق في السبيك:** مفيش «زر ربط» ولا عرض اسم الجهاز — مستحيل مع HID (الجهاز كيبورد بالنسبة للـOS). الجاهزية تُستنتج من نجاح مسح فعلي (الشارة + "جرّب القارئ").

**خارج النطاق (follow-ups):** طباعة باركود 1D على الكروت، وضع «الموبايل مقفول/الخلفية» (محتاج Bluetooth SPP).

**سبيك كامل:** `specs/027-hardware-barcode-scanner/` — T001–T018 ✅، **T019 (تحقّق جهازي) + T020 (تحديث HANDOFF/memory — دلوقتي) لسه**.

**⚠️ لسه محتاج:** commit على `main` (بإذن)، وتحقّق جهازي بجهاز HID حقيقي (quickstart سيناريوهات 1–11).

---

## ✅ اللي اتعمل في جلسات سابقة

### 1) spec 026 — تحصيل المديونية المتراكمة من شاشة الدفع بالماسح (متنفّذ بالكامل)

**المشكلة:** شاشة `qr_scanner_payment_page.dart` للمجموعات **بالحصة** كانت بتحسب الحصص المستحقة ضمن **الشهر الحالي فقط** (`QRController._preparePayment` كان `start = nowMonth`)، فتتعارض مع `PricingHelper.accumulatedDebt` (المديونية المتراكمة الحقيقية) المعروضة في كارت تفاصيل الطالب. المدرس مش قادر يحصّل المتأخر القديم من الماسح.

**الحل (ملفّان مصدر + ملف اختبار، صفر تغيير DB/مزامنة):**

- **`lib/controllers/qr_controller.dart`**
  - `_preparePayment`: للمسار per-session `start = DateTime(joined.year, joined.month)` حيث `joined = student.attendanceStart ?? student.createdAt` (fallback `nowMonth`)؛ `selectedMonths` = كل الشهور من الانضمام حتى الشهر الحالي (شامل). المسار الشهري بلا تغيير.
  - `_buildUpcomingMonths(DateTime start, {bool perSession = false})`: توقيع جديد. per-session = من start للشهر الحالي فقط، سقف حارس 60 بدل 12.
  - getters جديدة: `_effPrice` (= `scannedStudent.value?.effectivePrice ?? 0`)، `scannedStudentDebtSessions` (= `_effPrice > 0 ? (scannedStudentDebt / _effPrice).floor() : 0`)، `sessionsCoveredBy(double amount)`، `debtRemainingAfter(double amount)` (clamp ≥ 0).
  - `bool applyDebtAmountPayment(double amount)`: يتحقق (`isPerSessionGroup`, student != null, `amount > 0`, `debt > 0.01`, `amount <= debt + 0.01`) + توست خطأ؛ عند القبول `setOverride(amount, note: 'دفعة من المديونية')` ثم `_sessionsCoveredByQuickPay = sessionsCoveredBy(amount)` (أعدت استخدام الحقل القائم بدل `_explicitSessionsForPayment` الجديد اللي في tasks.md — نفس دورة الحياة: يُصفَّر في `setOverride`، يُعاد ضبطه بعده، يُقرأ في `confirmPayment`).
  - كل getters العدّ القائمة (`unpaidSessionsCount` / `unpaidSessionDates` / `_paidSessionsInSelectedMonths` / `fullyPaidUp` / `effectiveSessionsSelected`) تتصحّح تلقائيًا عبر توسيع `selectedMonths` — بلا تعديل في كودها.

- **`lib/views/qr_scanner/qr_scanner_payment_page.dart`**
  - سطر المديونية (كان `if (!controller.isPerSessionGroup && !student.isFullyExempt)` عند ~1054) → `if (!student.isFullyExempt)` — يظهر للـper-session كمان + سطر ثانٍ «= N حصة» (per-session فقط، `scannedStudentDebtSessions >= 1`).
  - ويدجت جديد `_DebtAmountField` (StatefulWidget، آخر الملف قبل `_MonthChip`): `TextField` رقمي «ادفع مبلغًا من المديونية» + `Obx` معاينة («يغطّي N حصة • المتبقّي بعد الدفع: …» / تحذير أحمر لو `> debt` / لا شيء لو فارغ/0/غير رقمي) + زر «تطبيق» → `controller.applyDebtAmountPayment(parsed)`. يظهر per-session فقط عندما `!fullyPaid && scannedStudentDebt > 0.01 && student.effectivePrice > 0`.

- **`test/qr_payment_debt_test.dart`** (جديد، 14 اختبار، كلها تعدّي): `PricingHelper.accumulatedDebt` per-session عبر شهرين = 140 (مثال المستخدم الحرفي: 6 حصص أغسطس + 1 سبتمبر × 20)، دفعة 60 → 80؛ منطق تحويل floor؛ قواعد قبول المبلغ الحر.

- **حالات محسومة (research.md):** floor مش round؛ منع الزيادة عن المديونية = سلوك v1 (مفيش رصيد مقدّم من الشاشة دي)؛ المبلغ الحر للمجموعات **الشهرية** خارج v1 (تفضل باختيار شهور كاملة، بس يظهر رقم المديونية)؛ سعر حصة = 0 → عرض بالجنيه بلا «= N حصة» + حقل المبلغ معطّل.

- **حالة معروفة مقبولة:** لو المدرس دخّل مبلغ **أقل من سعر حصة** (مثلاً 10 ج وسعر 20)، المبلغ يتسجّل صح لكن عدّاد `sessions` في الملاحظة يتقرّب لـ1 بدل 0 (فرق تجميلي في العدّ، الفلوس مضبوطة).

**Commit:** `dd5282e` على `main` (مدفوع). كل `flutter test` (53) + `flutter analyze` نظيف (صفر مشاكل جديدة — الـ34 info كلها baseline قديمة، منها 2 في `qr_scanner_payment_page.dart:179` و`:1487` مش من التعديل).

**سبيك كامل:** `specs/026-qr-payment-accumulated-debt/` (spec.md, plan.md, research.md, data-model.md, contracts/×3, quickstart.md, tasks.md — T001–T015 + T017–T020 ✅، **T016 لسه [ ]**).

### 2) ريليس v1.2.49 (منشور بالكامل)

- **`pubspec.yaml`**: `1.2.48+4066` → **`1.2.49+4067`**. `android/local.properties` كذلك (`flutter.versionCode=4067` — gitignored).
- **Commit:** `42f830a` على `main` (مدفوع). **Tag `v1.2.49`** مدفوع.
- **GitHub Release** (latest, مش draft/pre): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.49
  - أصول: `ActiveClass-v1.2.49-arm64-v8a.apk` (sha256 `9ce7f9eb2e9c4861e6b560daca0ffc0bc6931074c8abd66c9915d18e6f5e2158`)، `-armeabi-v7a.apk`، `-x86_64.apk`، `-play.aab`. كلها versionCode **4067**، توقيع release صحيح (`5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b`).
  - محلّيًا في `release_assets/ActiveClass-v1.2.49-*`.
- **VPS نشر:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` (backup `.bak-1.2.48`). التحقق: `curl -sI https://active-class.online/downloads/ActiveClass-arm64-v8a.apk` → 200، 48228892 بايت، sha256 مطابق. المستخدم بيثبّت **فوق** التطبيق (مايلغيش).
- **التحديث الذاتي داخل التطبيق** (`update_service.dart`): `/repos/amertimraz/App-Active-Class/releases/latest` → v1.2.49، يختار الأصل اللي فيه `arm64` في الاسم. شغّال.
- **release notes:** `scratchpad/release_notes_v1.2.49.md`.

**⚠️ درس البناء (محدَّث في `memory/release-build-versioncode.md`):**
- المشروع فيه `productFlavors { play; direct }` على بُعد `distribution` (فرق صلاحية `REQUEST_INSTALL_PACKAGES`). `flutter build appbundle --release` من غير `--flavor` يطلع رسالة "failed to produce an .aab file" رغم إن الـaab اتبنى فعلاً في `build/app/outputs/bundle/{play,direct}Release/`.
- **`--split-per-abi` بيقع OOM** على جهاز البناء (16GB، ~4GB فاضي). الحل: `--target-platform android-arm64` (وبعده `android-arm`، `android-x64`) — كل مرة بيكتب فوق `build/app/outputs/flutter-apk/app-direct-release.apk` فانسخه فورًا.
- v1.2.49 وقع 3 مرات OOM قبل ما DaVinci Resolve (~1.9GB) يتقفل.
- **قاعدة versionCode:** بناء عادي (بلا split) = versionCode = build# (4067). لازم يبقى > آخر ABI code قديم (كان 4066). التالي: `+4068` أو أعلى.

---

## ⏳ متبقّي / مفتوح

1. **رفع الـAAB على Play Console** (خطوة يدوية على المستخدم): `release_assets/ActiveClass-v1.2.49-play.aab`.
2. **T016 — تحقّق spec 026 جهازيًا** (لسه ماتعملش):
   - عدم انحدار المجموعات **الشهرية** في شاشة الدفع بالماسح (month chips، اختيار شهور، تحصيل، لا حقل مبلغ حرّ، لا سطر «= N حصة») — quickstart سيناريو 5.
   - اختبار جهازين (مدرس + مساعد): الدفعة الجزئية تظهر عند المساعد بمبلغها (مؤكَّد بالكود — بيمرّ بـ`insertPayment` بلا تفرّع، بس مش متأكَّد جهازيًا).
   - quickstart سيناريوهات 1–4 كلها على جهاز حقيقي.
3. **مؤجَّلات قديمة من جلسات سابقة (مش عاجلة):**
   - `supabase/migration_student_follow_ups.sql` لسه ماتطبّقش (بس لو هنعيد تفعيل مزامنة `student_follow_ups` — حاليًا متشالة من `_tables`).
   - تحقّق جهازين لـspecs 024 + 025.

---

## 🔑 حقائق ثابتة للجلسة الجديدة

- **git push فقط بإذن صريح.** الـspecs بتتعمل commit على `main` مباشرة (عرف المشروع).
- **التوقيع:** نفس keystore كل مرة (`android/key.properties` + `RELEASE_SIGNING_INFO.md` — الاتنين gitignored، فيهم باسورد `gG1lrhvSog96kQbwCYtyoRxN`، **متتعملش commit ولا expose**). SHA-256 = `5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b`. مزج debug/release أو إلغاء-وإعادة تثبيت = مسح بيانات محلية (slug بوابة الأهل + الرخصة).
- **SSH VPS:** `ssh -i ~/.ssh/ovh_key root@active-class.online` — شغّال من الساندبوكس. حاوية Supabase: `active-class-auth-db-1`، compose في `/opt/active-class-auth/docker`. تطبيق migration: `ssh ... 'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' < supabase/migration_X.sql`.
- **DB version = 28** (v26 explanation → v27 exam sync cols → v28 bank_questions). spec 026 **مازادش النسخة**.
- **مزامنة الفريق (`SyncEngine`):** قناتان Realtime — `_channel` (`_coreTables`) + `_channelX` (`_extendedTables` = `[TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS, TABLE_BANK_QUESTIONS]`). CHANNEL_ERROR في واحدة معزول عن التانية (إصلاح دائم لحادثة `student_follow_ups`).
- **`PricingHelper`:** `accumulatedDebt` = مجموع `monthlyDue` من شهر الانضمام لدلوقتي ناقص **كل** الدفعات (رصيد واحد FIFO). per-session: `monthlyDue = student.price * sessionsAttended(month)`. `billingArrears` / `prorateFirstMonth` static flags (per-session بيتجاهلهم). الإخوة: `siblingsTotal / count` عبر `siblingGroupMembers`.
- **`toCloudMap()` لـ`ExamQuestion`** لازم يفضل نضيف من `correctIndex`/`points`/`explanation` (اختبار `exam_question_cloud_map_test.dart` بيفرض ده — FR-034 spec 016). مفاتيح التصحيح بس في `results/{attemptKey}` بعد اعتماد المدرس.
- **الرخصة auto-rebind:** "سيبه زي ماهو" — متغيّرش. الإلغاء عبر `status: suspended`.
- **السر المضمّن في `booking_service.dart`** (`88657c22...`) مقصود وغير حساس (فيه تعليق).
- **جهاز المستخدم (MIUI):** كل جلسة بيعيد تفعيل "Install via USB" في خيارات المطوّر. `adb` أحيانًا offline → `& "F:/AndroidSDK/Sdk/platform-tools/adb.exe" kill-server; start-server`.
- **بناء R8 release بيقع OOM** ("daemon disappeared") — قوّل المستخدم يقفل Resolve/تطبيقات تقيلة. `--no-tree-shake-icons` بيخفّف شوية. `org.gradle.jvmargs=-Xmx2048m` (زيادتها لـ4096 زوّدت الـcrashes).

---

## 📂 ملفات السبيك 026 (لو محتاج تفاصيل)

```
specs/026-qr-payment-accumulated-debt/
├── spec.md          # 3 user stories، 17 FR، 6 SC
├── plan.md          # الملخص التقني + Constitution Check (PASS)
├── research.md      # 8 قرارات محسومة
├── data-model.md    # كيانات محسوبة، لا سكيمة
├── contracts/
│   ├── qr-controller-per-session-scope.md   # سلوك _preparePayment + جدول before/after
│   ├── debt-display.md                       # عقد عرض سطر المديونية
│   └── debt-amount-payment.md                # applyDebtAmountPayment + معاينة + note
├── quickstart.md    # 6 سيناريوهات تحقّق
└── tasks.md         # T001–T020
```
