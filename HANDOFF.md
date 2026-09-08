# Active Class — Handoff (محادثة جديدة)

> آخر تحديث: 2026-09-08 (مساءً). المشروع: `C:\repo\active_class` — تطبيق Flutter عربي/RTL للمدرّسين الخصوصيين.
> كلّمني عربي (مصري). Flutter 3.38.1 / Dart 3.5.4، GetX، sqflite، Firebase (بوابة أولياء الأمور + امتحانات أونلاين)، Supabase self-hosted على VPS (مزامنة وضع الفريق).

---

## ✅ اللي اتعمل في الجلسة الحالية

### spec 033 — تنظيف رقم ولي الأمر + واتساب (متنفّذ + **مدفوع**، migration مطبّق، **تحقّق جهازي لسه**)

**Commits:** `6fc07a8` سبيك · `60fbedb` خطة · `3f26046` مهام · `23893ed` تنفيذ · `aeb0ac6`+`ca981e9` وصل الإرسال · `05d7e8c` آخر 3 شاشات · **4 مراجعات:** `f3c1643`+`aeff70f` (أرقام دولية، regression `groupsForDay`) · `3694ae5` (normalizers مكسورة فاتوا في settings/reports/auth/db) · `51b49a6` (حذف كود ميت) — كلها مدفوعة.

**الباج:** دالة تطبيع الرقم القديمة `replaceAll(RegExp(r'[^0-9+]'), '')` كانت بتمسح الأرقام العربية (٠١٢٣) بالكامل → واتساب يفتح فاضي. + حقل الرقم RTL بلا `textDirection` → الرقم يتعرض معكوس.

**اللي اتعمل:**
- **`lib/utils/phone_helper.dart`** (جديد، نقي): `PhoneHelper` — `toLatinDigits` (عربي/فارسي→لاتيني)، `cleanForStorage` (يشيل علامات الاتجاه/المسافات/الرموز، يوحّد `+`/`00`)، `waMe(raw, dial)` (رقم دولي صريح — بـ`+` أو `00` أو تسلسل ≥11 خانة بلا صفر — يُحترم؛ غيره + رمز الدولة)، `displayIntl` (‎+20 …، ومايفترضش مصر لرقم دولي مختلف)، `isLikelyValid`، `parseWhatsappHandle` → `WhatsappHandle{kind,value}` (waLink/phone/username/invalid). **36 اختبار** (`test/phone_helper_test.dart`).
- **`lib/utils/phone_format.dart`**: **اتشال** (كان غلاف `normalizeWhatsappPhone` — بقى بلا مستدعين بعد ما كل النقاط اتوصلت بـ`whatsapp_launcher`).
- **`CustomTextField`**: + `textDirection`/`textAlign`/`inputFormatters` اختيارية (صفر تأثير على القائم).
- **`lib/widgets/phone_field.dart`** (جديد): `PhoneSanitizerFormatter` + `PhoneField` — LTR + تنظيف لحظي + معاينة «هيتبعت على: ‎+20 …» + تحذير «الرقم يبدو غير مكتمل» (غير معطِّل).
- **`add_student_sheet` + `edit_student_sheet`**: `PhoneField` بدل الحقل القديم + حقل `_whatsappCtrl` LTR جديد «واتساب ولي الأمر (رابط/username)».
- **`lib/utils/whatsapp_launcher.dart`** (جديد): `launchGuardianWhatsapp({phone, whatsapp, message, dialCode})` — أولوية: رابط `wa.me` → رقم → username (+نسخ الرسالة + توست). **موصول في كل نقاط إرسال واتساب لولي الأمر** (12 موضع): `student_details_page`، `attendance_page` (×3)، `group_details_page` (×2)، `payments_report_page`، `reports_page`، `settings_page` (إرسال جماعي)، `student_exam_history_page`، `exam_grades_page` (×2)، `online_exam_results_page`، `at_risk_students_page`. **كل الـnormalizers المحلية المكسورة (7) اتشالت.**
- **`auth_service.dart`** (تسجيل دخول الفريق) + **`database_service.dart`** (allowed exam students، last4) بقوا يمرّوا الرقم عبر `PhoneHelper.toLatinDigits` قبل الاقتطاع.
- **US3 عمود:** `students.guardian_whatsapp TEXT`، **DB v29→v30**، `Student.guardianWhatsapp` (toMap/fromMap/copyWith)، مُزامَن في `sync_engine` (`_buildRemoteRow`/`_toLocalMap` لـTABLE_STUDENTS). `supabase/migration_guardian_whatsapp.sql` **مطبّق عبر SSH كـ`-U supabase_admin`** (جدول students مملوك لـsupabase_admin مش postgres — اتوثّق في memory).
- **`contact_picker_service._normalize`** + **`parent_portal_service._last4`**: يمرّوا عبر `PhoneHelper` (تحويل الأرقام العربية).
- **التخزين يفضل صيغة بشرية** (`01…`)؛ التطبيع للـ`wa.me` لحظة الإرسال — صفر ترحيل بيانات، صفر موجة مزامنة.
- **اختبارات:** `flutter test` 149 ✅، `flutter analyze` 34 (baseline).

**متبقّي:** T031 (تحقّق جهازي — quickstart 1–11: لصق من سجل مكالمات حقيقي، جهازين للمزامنة). سبيك: `specs/033-guardian-phone-cleanup/`.

**باج قديم (مش من spec 033):** تعديل طالب وإفراغ حقل الرقم مابيتحفظش — `Student.copyWith` مفهوش `clearGuardianPhone` (زيّ ما `guardianWhatsapp` بقى ليه `clearGuardianWhatsapp`).

### spec 032 — إلغاء حصة اليوم وتعويضها (متنفّذ + **مدفوع** على `main`، migration مطبّق عبر SSH، **تحقّق جهازي لسه**)

**Commits:** `15d940d` خطة+مهام · `04230b4` تنفيذ · `c5f9e2b` T018 (إخفاء القائمة للحصة الملغاة) · `aeff70f` مراجعة (regression `groupsForDay`). مدفوعين.

**الفكرة:** مفيش كيان "حصة" — الحصص مشتقّة من `Group.schedule` + التاريخ. جدول جديد `session_overrides` (مفتاح منطقي `(group_id, date)`، `type ∈ {cancelled, makeup, extra}`, `compensates_date` للـmakeup).

**اللي اتعمل:**
- **`constants.dart`**: `TABLE_SESSION_OVERRIDES` + `COL_SO_*` + `DATABASE_VERSION = 29`.
- **`models/session_override_model.dart`** (جديد): `SessionOverride` + `SessionOverrideType` + `toMap/fromMap` (تاريخ ↔ `YYYY-MM-DD`، نوع مجهول → `cancelled`).
- **`utils/session_schedule_resolver.dart`** (جديد، نقي): `resolveHasSession({scheduleSays, overrideType})` + `expectedCountDelta({overridesInRange, scheduleHasDay})`.
- **`services/database_service.dart`**: `_sessionOverridesTableSql` (+ UNIQUE index `(group_id,date)`) في `_createTables` + `_onUpgrade` v29. CRUD: `getAllSessionOverrides`/`getSessionOverride`/`insertSessionOverride`(+`_queueSync`)/`deleteSessionOverride`(+`_queueDelete`). `countAttendanceForGroupOnDay`/`deleteAttendanceForGroupOnDay` (JOIN students بالـgroup، txn + `_queueDelete` لكل صف).
- **`services/sync_engine.dart`**: `TABLE_SESSION_OVERRIDES` في `_tables`+`_coreTables`+`_pkCol`+`_buildRemoteRow` (group_id محلي → `group_remote_id` uuid)+`_toLocalMap`+`_refreshUiForTable`. كتلة dup على `(group_id,date)` → `_reconcileDuplicate` (spec 031).
- **`controllers/session_override_controller.dart`** (جديد، GetX، `permanent` في main.dart، `onInit`→`load()`): `overrides` RxList، `overrideFor`/`overridesForGroupInRange`/`cancelledForGroup`، طفرات `cancelToday`/`addMakeup`/`addExtra`/`removeOverride` (ترجع `String?` خطأ، تطبّق قواعد التحقّق).
- **`controllers/attendance_controller.dart`**: استخرجت `_scheduleWeekdays` + `_scheduleCountForGroup` (جدول فقط). `groupHasSessionOnDay`/`_countExpectedForGroup`/`groupsForDay` بقوا override-aware. جديد: `groupsForDayWithOverrides` (بيسيب كارت المجموعة الملغاة ظاهر عشان التراجع)، `sessionOverrideFor`، `groupHasSessionOnDayScheduleOnly`.
- **`widgets/session_override_widgets.dart`** (جديد): `SessionOverrideMenuButton` (⋮ في رأس موديل الحضور: إلغاء/تعويضية/إضافية/تراجع — الإلغاء متبوّب بـ`canDeleteAttendanceNow` + حوار "هيتمسح N")، `SessionOverrideBanner`، `showAddSessionOverrideFlow` (من `_NoSessionsToday`).
- **`views/attendance/attendance_page.dart`**: القائمة + البانر في الموديل، شارة "ملغاة/تعويضية/إضافية" على `_GroupSummaryCard`، `_RegisterTabState.initState`→`load()`. **حصة ملغاة → موديل الحضور يخفي قائمة الطلاب ويعرض زر "تراجع عن الإلغاء" فقط** (منع تسجيل حضور بالغلط). إحصاءات الشريط اليومي تحسب المجموعات النشطة فقط.
- **`views/students/student_details_page.dart`**: `_SessionOverridesSection` (عرض فقط، فوق قائمة الشهور — مش بيتحسب في النِسبة).
- **`supabase/migration_session_overrides.sql`** (جديد): جدول + RLS (`is_team_member AND is_team_license_active`) + `check_delete_session_overrides` (صلاحية `delete_attendance`) + `trg_set_updated_at` + `replica identity full` + realtime publication. **مطبّق عبر SSH + متحقَّق**.
- **الفوترة: صفر تغيير** (`PricingHelper` ملمسناهوش — كلها من صفوف الحضور).
- **اختبارات:** `test/session_override_model_test.dart` + `test/session_schedule_override_test.dart` (15 اختبار). `flutter test` 149 ✅، `flutter analyze` 34.
- **مراجعة (`aeff70f`):** `groupsForDay` كان بيعرض المجموعات بلا جدول كل يوم (regression — `groupHasSessionOnDay` بترجّع true افتراضيًا) → رجّعنا السلوك القديم: مجموعة بلا جدول تظهر فقط لو ليها `makeup`/`extra` صريح لليوم ده. + `_toLocalMap` بيحط `created_at = updated_at` بدل null.

**متبقّي:** T024 (بوابة الأهل — مؤجّل: مستند Firestore + صفحة ويب منفصلة)، T029 + **تحقّق جهازي/جهازين** (quickstart 1–8). سبيك: `specs/032-cancel-makeup-session/`.

### spec 027 — دعم جهاز قارئ باركود خارجي (HID) في شاشتَي الحضور والدفع (متنفّذ + مدفوع على `main`)

**Commits:** `827a44d` (التنفيذ) + `6e5dc3f` (تحسين خوارزمية الكشف = متوسط الزمن). كلها مدفوعة.

**الفكرة:** جهاز قارئ باركود 2D (USB-OTG أو بلوتوث) بوضع HID = كيبورد: بيـ«كتب» الكود بسرعة + Enter. صفر مكتبات/أذونات/DB/مزامنة.

**اللي اتعمل:**
- **`lib/config/constants.dart`**: `SETTING_HARDWARE_SCANNER_ENABLED = 'hardware_scanner_enabled'`.
- **`lib/controllers/settings_controller.dart`**: `RxBool hardwareScannerEnabled` (افتراضي false، محلي، غير مُزامن)، يُحمَّل في `_loadHideQrSettings`، + `setHardwareScannerEnabled`.
- **`lib/utils/hardware_scan_buffer.dart`** (جديد): `HardwareScanBuffer` — يجمّع `KeyDownEvent`، يُصدر `onScan(code)` عند Enter/Tab/numpadEnter لو: طول ≥2 بعد trim **و متوسط الزمن/حرف على التتابع كله ≤50ms** (متوسط مش فاصل بين كل حرفين — عشان jank لحظي في الـUI ميكسرش الكشف). فجوة >250ms → تتابع جديد؛ خمول >300ms → تصفير. `nowOverride` للاختبار.
- **`test/hardware_scan_buffer_test.dart`** (جديد، 11 اختبار كلها تعدّي — يشمل حالة jank لحظي).
- **`lib/widgets/hardware_reader_widgets.dart`** (جديد): `HardwareActiveBadge` (شارة "القارئ نشط • آخر مسح ..." بعد أول مسح ناجح)، `ReaderReadyPanel` (بديل الكاميرا في الوضع الخالص)، `HardwareScannerTestTile` ("جرّب القارئ" في الإعدادات — يمسك مسح واحد، يعرض النص + "✅ HID"، صفر أثر بيانات)، + `relativeScanText`.
- **`qr_scanner_attendance_page.dart` + `qr_scanner_payment_page.dart`**: `HardwareKeyboard.instance.addHandler(_hwKeyHandler)` في initState (مش `Focus` — عشان الفوكس ممكن ميبقاش على الشاشة)، بيتشال في dispose. حواجز الـhandler: تاب index==0 + `ModalRoute.isCurrent` + mounted. يغذّي `_scanBuffer` → `_handleQR(code, fromHardware:true)` / `_handle(...)` (حارس التكرار + الصوت + الاهتزاز مُعاد استخدامها). `_pureScannerMode = hardwareEnabled && hideQr` → الكاميرا متتشغّلش خالص + `ReaderReadyPanel`. `_qrTabVisible = !hideQr || pureMode`. الشارة تشتغل بس مع `fromHardware` (مش إدخال يدوي). buffer.reset() عند تبديل التاب.
- **`settings_page.dart`**: سطر Switch "قارئ باركود خارجي" بعد "إخفاء ماسح QR في الحضور" + `HardwareScannerTestTile` تحته لما مفعّل.

**التحقّق:** كل `flutter test` (64) يعدّي، `flutter analyze` = 34 issue (نفس الـbaseline بالظبط، صفر جديد).

**قرار مهم موثّق في السبيك:** مفيش «زر ربط» ولا عرض اسم الجهاز — مستحيل مع HID (الجهاز كيبورد بالنسبة للـOS). الجاهزية تُستنتج من نجاح مسح فعلي (الشارة + "جرّب القارئ").

**خارج النطاق (follow-ups):** طباعة باركود 1D على الكروت، وضع «الموبايل مقفول/الخلفية» (محتاج Bluetooth SPP).

**سبيك كامل:** `specs/027-hardware-barcode-scanner/` — T001–T018 + T020 ✅، **T019 (تحقّق جهازي بجهاز HID حقيقي — quickstart سيناريوهات 1–11) لسه ماتعملش**.

### ريليس v1.2.51 (منشور بالكامل — يضم specs 028/029/030/031/032/033)

- **`pubspec.yaml`** + `android/local.properties`: `1.2.50+4068` → **`1.2.51+4069`**.
- **Commit `1e4b3ab`** + **tag `v1.2.51`** مدفوعين.
- **GitHub Release** (latest، مش draft/pre): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.51
  - أصول: `-arm64-v8a.apk` (sha256 `29ec4836fd0376a1239eb401cac5e7a911fd90b7a90975f20d938280135ad14a`)، `-armeabi-v7a.apk` (`d4e7b0cb…`)، `-x86_64.apk` (`038fb996…`)، `-play.aab` (`6f1db283…`). كلها versionCode **4069**، توقيع release صحيح (`5f74fe10…`)، universal (كل الـABIs). محليًا في `release_assets/ActiveClass-v1.2.51-*`.
- **VPS:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` (backup `.bak-1.2.50`). التحقق: `curl -sI` → 200، 47829184 بايت، sha256 مطابق (`29ec4836…`).
- **`/releases/latest`** يرجّع v1.2.51 → التحديث الذاتي داخل التطبيق شغّال.
- **درس البناء:** `flutter build apk --release --flavor direct` (بلا target-platform) = fat 99MB. الصح: `--target-platform android-arm64` (~48MB، universal فعليًا) ثم `android-arm` ثم `android-x64`، انسخ فورًا. AAB: `flutter build appbundle --release --flavor play`. ~5 دقايق لكل بناء، صفر OOM.
- **⏳ متبقّي على المستخدم:** رفع `release_assets/ActiveClass-v1.2.51-play.aab` على Play Console يدويًا.

### ريليس v1.2.50 (منشور بالكامل)

- **`pubspec.yaml`** + `android/local.properties`: `1.2.49+4067` → **`1.2.50+4068`**.
- **Commit `79ad6d3`** + **tag `v1.2.50`** مدفوعين.
- **GitHub Release** (latest): https://github.com/amertimraz/App-Active-Class/releases/tag/v1.2.50 — أصول: `-arm64-v8a.apk` (sha256 `546d11891c260974f33673ca12cdb0e9d18b68d519b910008f9af277ec4c1679`)، `-armeabi-v7a.apk`، `-x86_64.apk`، `-play.aab`. الثلاث APK **universal** (كل الـABIs) versionCode 4068، توقيع release صحيح (`5f74fe10...`). محليًا في `release_assets/ActiveClass-v1.2.50-*`.
- **VPS:** `/var/www/active-class.online/downloads/ActiveClass-arm64-v8a.apk` (backup `.bak-1.2.49`). التحقق: `curl -sI` → 200، 48228892 بايت، sha256 مطابق.
- **booking_site:** `booking_site/downloads_ready/ActiveClass-arm64-v8a.apk` محدّث (ضمن `79ad6d3`).
- **release notes:** `scratchpad/release_notes_v1.2.50.md`.
- **درس البناء تأكّد تاني:** `--split-per-abi` = OOM. الحل: `flutter build apk --release --flavor direct --target-platform android-arm64` (وبعده `android-arm`، `android-x64`) — بيكتب فوق `build/app/outputs/flutter-apk/app-direct-release.apk` (universal فعليًا مش ABI واحد) فانسخه فورًا. الـAAB: `flutter build appbundle --release --flavor play`. كل بناء ~4.5–6 دقايق، مفيش OOM المرة دي.

### spec 029 — تنبيه "متأخر في الدفع" في شاشة الحضور (متنفّذ + **مدفوع** `220305f`)

**القاعدة:** بادج تحذير بصري جنب اسم الطالب وقت تسجيل حضوره:
- شهري / بلا مجموعة → `PricingHelper.isOverdue(...)` (بمهلة السماح `paymentGraceDays`)
- بالحصة → `accumulatedDebt − (حصص النهاردة × effectivePrice) > 0.01` (يعني عليه رصيد لحصص أقدم من اليوم؛ حصة اليوم طبيعي)
- معفى بالكامل → لا

**اللي اتعمل:**
- `constants.dart`: `SETTING_ATTENDANCE_OVERDUE_WARNING = 'attendance_overdue_warning'`.
- `settings_controller.dart`: `RxBool attendanceOverdueWarning` (افتراضي **true**، محلي)، يُحمَّل في `_loadLateAttendanceSettings`، + setter.
- `pricing_helper.dart`: `showsAttendanceOverdueWarning({student, group, allAttendance, payments, graceDays, siblingGroupMembers})` + `sessionsAttendedOn({student, day, allAttendance})` (يحسب "متأخر" كحضور).
- `test/attendance_overdue_warning_test.dart` (جديد، 10 اختبارات).
- `lib/widgets/overdue_warning_badge.dart` (جديد): `OverdueWarningBadge({debtAmount, compact})` (غبي) + `OverdueWarningFor({student, compact})` (يحلّ كل الكونترولرز عبر Get، `Obx` يتحدّث بعد دفعة).
- `qr_scanner_attendance_page.dart`: `payCtrl.loadPayments()` في postFrame؛ `OverdueWarningFor` في `_AttendancePanel` (كامل) و `_StudentSearchCard` (compact).
- `attendance_page.dart`: `OverdueWarningFor(compact)` تحت اسم الطالب في `_StudentAttendanceChip` (`PaymentController` موجود هناك أصلاً).
- `settings_page.dart`: سطر Switch "تنبيه المتأخر في شاشة الحضور" قبل "تسجيل متأخر تلقائيًا عبر QR".

**التحقّق:** `flutter test` (74) يعدّي، `flutter analyze` = 34 (baseline، صفر جديد).

**سبيك كامل:** `specs/029-attendance-overdue-warning/` — T001–T014 + T016 ✅، **T015 (تحقّق جهازي — quickstart 1–10) لسه**.

**⚠️ لسه محتاج:** commit + تحقّق جهازي.

### spec 031 — اتساق تعارضات المزامنة (متنفّذ + **مدفوع** `62d88dc` + migration مطبّق)

بعد مراجعة أعمق للمزامنة: سببان لـ"المدرّس والمساعد مش متطابقين":

1. **LWW كان بيقارن `updated_at` من ساعة كل موبايل** → جهاز بساعة منحرفة تعديلاته تخسر دايمًا. **الحل:** `supabase/migration_server_updated_at.sql` — دالة `set_updated_at()` + trigger `trg_set_updated_at` (BEFORE INS/UPD) على 11 جدول متزامن يفرض `NEW.updated_at = now()`. **اتطبّق عبر SSH — متحقَّق (11 جدول).**
2. **الصف المكرّر الوارد كان بيتجاهل بصمت** → المدرّس "حاضر"، المساعد "متأخر"، خلاف دائم. **الحل:** `_reconcileDuplicate` في `sync_engine.dart` بدل الـ5 كتل `if(dup.isNotEmpty){return;}` (attendance/homework/exam_groups/exam_grades/exam_submissions) → LWW على البيانات (الأحدث بوقت الخادم يفوز)، **`remote_id` المحلي ثابت** (تغييره بيربك outbox)، الصف الخاسر على الخادم بيفضل يعيد البثّ ويخسر LWW (اتساق نهائي).

- `lib/utils/sync_conflict.dart` (جديد): `syncConflictIncomingWins(...)` نقية (وقت + tie-break بالمعرّف الأصغر معجميًا). 6 اختبارات.
- صفر تغيير schema محلي (v28)، صفر تغيير RLS، الـtrigger يضبط `updated_at` فقط.

**التحقّق:** `flutter test` + `analyze` نظيف. **لسه:** تحقّق جهازين (ساعة منحرفة، حضور/درجة مزدوجة).

**⚠️ توافق رجعي:** البيانات القديمة على الخادم طوابعها المحلية القديمة تبقى لحد أول تعديل يمرّ عبر الخادم فيأخذ الوقت الموحّد. أثر انتقالي بسيط أول أيام.

### spec 030 — تقوية مزامنة وضع الفريق (متنفّذ + **مدفوع** `9540952` + مراجعات `31d77ed`/`d4268fe`)

**3 باجات في `sync_engine.dart` بلّغ عنها مساعد** (بيانات مش بتوصل / بتتأخّر / تسجيل خروج تلقائي):

1. **طابور الإرسال بيتجوّع من صفوف مسمومة** — `drainOutbox` كان `WHERE synced=0 ... LIMIT 50`؛ صف بيفشل دايمًا بيتراكم في المقدمة وأول ما يوصلوا 50 → صفر تقدّم. **الحل:** `Map _outboxFails` في الذاكرة، صف تجاوز 5 فشل → `WHERE id NOT IN (poison)` (يُعاد المحاولة كل 20 جولة)، لوج واحد عبر `_loggedPoison`.
2. **مفيش سحب دوري** — السحب بس عند البدء وعند Realtime `subscribed`. **الحل:** `_catchUpTimer = Timer.periodic(50s → catchUpPull)` + `SyncEngine with WidgetsBindingObserver` → `catchUpPull` عند `resumed`. يُلغى في `stop()`.
3. **`_wasRemovedFromTeam` بيسجّل خروج على استعلام فاضٍ واحد** — RLS بترجّع فاضي على توكن قرب يخلص. **الحل:** `_sessionUsable()` (`currentSession` صالحة، وإلا `refreshSession` + تأجيل) + `_emptyMembershipStreak >= 3` قبل `onRemovedFromTeam`. نفس المبدأ لـ`_wasDeviceUnbound`. `_wasLicenseDeactivated` += حارس الجلسة فقط.

- `lib/utils/sync_retry_policy.dart` (جديد): `shouldAttemptOutboxRow` + `shouldFireTeamExit` (دوال نقية) + ثوابت `kMaxOutboxFails=5`/`kPoisonRetryEvery=20`/`kTeamExitStreak=3`.
- `test/sync_retry_policy_test.dart` (جديد، 8 اختبارات).
- `team_mode_service.dart`: `_startEngine` بقى ينادي `_engine?.stop()` الأول (SyncEngine بقى بيسجّل observer + تايمر).

**التحقّق:** `flutter test` (91) يعدّي، `flutter analyze` = 34 (baseline). صفر تغيير DB/خادم/بروتوكول.

**سبيك:** `specs/030-team-sync-hardening/` — T001–T014 + T016 ✅، **T015 (تحقّق جهازين — quickstart) لسه**.

**⚠️ لسه محتاج:** commit + تحقّق جهازين (هبّة شبكة لا تسجّل خروج، إزالة فعلية تسجّله، مزامنة ثنائية كاملة).

### spec 028 — حذف السجلات بمدى تواريخ (متنفّذ + **مدفوع** `3aa0d20` + `5588c99`)

- `lib/models/deletable_record_type.dart` (جديد): `enum DeletableRecordType` (attendance/payments/examGrades/exams/homework/reportLogs) + `label`/`mainTable`/`dateColumn`/`pkColumn`/`isTeamSynced`؛ `rangeIsoBounds(from,to)` → `[fromIso, toIso)` (يوم البداية 00:00 حتى نهاية يوم النهاية)؛ ثوابت `kBulkDeleteThreshold=100` / `kDeleteConfirmWord='حذف'`.
- `database_service.dart`: `countDeletableRecordsInRange(...)` (معاينة) + `deleteRecordsInRange(...)` — يجمّع `(table,id,remote_id)` للصفوف المُزامَنة قبل الحذف، `db.transaction` يحذف كل الأنواع، ثم `_queueDelete` لكل صف مُزامَن (وضع الفريق فقط). `report_logs` → حذف محلي بلا queue. الامتحانات: `DELETE exams WHERE id IN (...)` + FK CASCADE للتوابع (زي `deleteExam`). درجات منفصلة: `exam_id IN (امتحانات المدى)`. **درجات الامتحانات تُفلتَر بتاريخ الامتحان الأب** (`exam_grades` مالوش تاريخ ذاتي).
- `delete_records_controller.dart` (جديد): `GetxController` — المدى/الأنواع/المعاينة، `runPreview()`، `runDelete()` → نسخة احتياطية إجبارية (`BackupService().createBackup()`، فشل → `DeleteBackupFailed` بلا حذف) ثم `deleteRecordsInRange` ثم تحديث `Attendance/Payment/Exam/Dashboard` كونترولرز. `DeleteOutcome` = `DeleteSuccess`/`DeleteBackupFailed`/`DeleteError`.
- `delete_records_page.dart` (جديد): رأس تحذيري + تاريخَي من/إلى (`showDatePicker`) + `CheckboxListTile` لكل نوع + معاينة + حوار تأكيد (كتابة "حذف" لو الإجمالي > 100) + `ProgressDialog`. تحذير مزامنة الفريق لو `teamModeEnabled && previewTotal > 500`.
- `settings_page.dart`: سطر "حذف سجلّات بمدى تواريخ" في قسم النسخ الاحتياطي، **بلا** `requireTeamOwnerIfTeamMode` (المساعد يقدر يحذف — الحذف يتزامن اتجاهين).
- **fix صلاحيات (بعد مراجعة المزامنة):** `DeleteRecordsController.isTypeAllowed` — في وضع الفريق، عضو بلا `canDeleteAttendanceNow`/`canDeletePaymentsNow` ميقدرش يختار "الحضور"/"الدفعات" (Supabase triggers `check_delete_*` بترفض soft-delete من عضو بلا صلاحية → صف outbox مسموم). checkbox معطّل + "مالكش صلاحية". باقي الأنواع مفيهاش trigger.
- `test/delete_records_range_test.dart` (جديد، 9 اختبارات — `rangeIsoBounds` + خصائص الـenum + عتبة التأكيد؛ تنفيذ الحذف على القاعدة يُتحقَّق يدويًا لعدم وجود بنية اختبار DB in-memory).

**التحقّق:** `flutter test` (83) يعدّي، `flutter analyze` = 34 (baseline، صفر جديد).

**سبيك كامل:** `specs/028-delete-records-by-date-range/` — T001–T012 + T014 ✅، **T013 (تحقّق جهازي — quickstart 1–9) لسه**.

**⚠️ لسه محتاج:** commit + تحقّق جهازي (خصوصًا فشل النسخة الاحتياطية → إلغاء، وجهازين للمزامنة).

### hotfix — سجل جلسة الدفع كان بيعرض عرض الإخوة عنصر واحد بالمبلغ الكامل (Commit `47cf022`، مدفوع)

كان سجل "دفعوا اليوم" الحيّ يضيف عنصرًا واحدًا باسم الطالب الممسوح وبالمبلغ الإجمالي (150) بدل عنصر لكل أخ بنصيبه (75+75). القاعدة كانت مضبوطة والـhydrate بعد إعادة التشغيل صح — الخطأ في `_session.add` الحيّ فقط.
- `QRController.lastSiblingSplit`: قائمة صف لكل أخ (paymentId/الاسم/المبلغ/هاتف)، تُملأ داخل حلقة الإخوة، تُصفَّر أول كل `confirmPayment`.
- `qr_scanner_payment_page._confirmPayment`: لو `lastSiblingSplit` مش فاضية → عنصر سجل لكل أخ بنصيبه؛ غير كده السلوك القديم.
- الإجمالي مكانش غلط (150 = الفعلي)؛ العدد بقى +2 بدل +1 = أدق ومتطابق مع ما بعد إعادة التشغيل.

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

1. **رفع الـAAB على Play Console** (خطوة يدوية على المستخدم): `release_assets/ActiveClass-v1.2.51-play.aab`.
2. **ريليس v1.2.51 اتنشر** (`1e4b3ab` + tag) — يضم 028–033. التحقّق الجهازي تحت (اتعمل بعد النشر).
3. **تحقّق جهازي — كله منشور في v1.2.51، لسه محتاج جهاز/جهازين للتأكيد:**
   - **spec 027 T019** — قارئ HID حقيقي (quickstart 1–11).
   - **spec 028** — حذف بمدى تواريخ (quickstart 1–9): فشل النسخة الاحتياطية → إلغاء، جهازين، عدم انحدار الروستر.
   - **spec 029** — تحذير تأخّر الدفع (quickstart 1–10).
   - **spec 030** — تقوية المزامنة (3 باجات SyncEngine): outbox poison، سحب دوري، عدم auto-logout كاذب.
   - **spec 031** — اتساق التعارضات (`62d88dc`): ساعة منحرفة، حضور/درجة مزدوجة، عدم انحدار.
   - **spec 032** — إلغاء/تعويض الحصة (quickstart 1–8): إلغاء/تراجع، تعويضية/إضافية، فوترة per-session، سجل الطالب، مزامنة `(group,date)` جهازين. **T024 (بوابة الأهل) مؤجّل.**
   - **spec 033** — تنظيف الرقم + واتساب (quickstart 1–11): لصق من سجل مكالمات حقيقي بلغة عربية، معاينة، رابط/username، جهازين لعمود `guardian_whatsapp`.
   - **spec 026 T016** — عدم انحدار المجموعات الشهرية في شاشة الدفع بالماسح + الدفعة الجزئية جهازين.
4. **مؤجَّلات قديمة (مش عاجلة):** `migration_student_follow_ups.sql` لسه ماتطبّقش (لو هنعيد تفعيل مزامنة `student_follow_ups`)؛ تحقّق جهازين لـ024 + 025.
5. **باج قديم:** `Student.copyWith` مفهوش `clearGuardianPhone` → إفراغ رقم ولي الأمر في التعديل مابيتحفظش.

---

## 🔑 حقائق ثابتة للجلسة الجديدة

- **git push فقط بإذن صريح.** الـspecs بتتعمل commit على `main` مباشرة (عرف المشروع).
- **التوقيع:** نفس keystore كل مرة (`android/key.properties` + `RELEASE_SIGNING_INFO.md` — الاتنين gitignored، فيهم باسورد `gG1lrhvSog96kQbwCYtyoRxN`، **متتعملش commit ولا expose**). SHA-256 = `5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b`. مزج debug/release أو إلغاء-وإعادة تثبيت = مسح بيانات محلية (slug بوابة الأهل + الرخصة).
- **SSH VPS:** `ssh -i ~/.ssh/ovh_key root@active-class.online` — شغّال من الساندبوكس. حاوية Supabase: `active-class-auth-db-1`، compose في `/opt/active-class-auth/docker`. تطبيق migration: `ssh ... 'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' < supabase/migration_X.sql`. ⚠️ **`ALTER TABLE public.students`** لازم `-U supabase_admin` (الجدول مملوك لـsupabase_admin مش postgres) — spec 033.
- **DB version = 30** (v28 bank_questions → v29 session_overrides (spec 032) → **v30 students.guardian_whatsapp (spec 033)**). spec 026/029/030/031 **مازادوش النسخة**.
- **مزامنة الفريق (`SyncEngine`):** قناتان Realtime — `_channel` (`_coreTables`، وفيها دلوقتي `TABLE_SESSION_OVERRIDES` — spec 032) + `_channelX` (`_extendedTables` = `[TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS, TABLE_BANK_QUESTIONS]`). CHANNEL_ERROR في واحدة معزول عن التانية (إصلاح دائم لحادثة `student_follow_ups`). تعارض الصف المكرّر → `_reconcileDuplicate` (LWW، spec 031) للجداول ذات مفتاح منطقي: attendance/homework/exam_groups/exam_grades/exam_submissions/**session_overrides**.
- **وقت الخادم (spec 031):** `trg_set_updated_at` على 12 جدول متزامن (11 + `session_overrides`) يفرض `updated_at = now()` — LWW متسق رغم انحراف ساعات الأجهزة.
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
