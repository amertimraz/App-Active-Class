# Tasks: الغياب التلقائي بعد انتهاء الحصة

**Tests**: اختبارات وحدة للدوال الصرفة + تحقق يدوي على جهاز.
**No DB / sync / migration.**

## Phase 1: المنطق الصرف
- [x] T001 [P] إنشاء `lib/utils/auto_absent.dart`: `kAutoAbsentNote`, `kAutoAbsentLookbackDays`, `kAutoAbsentMaxGrace`, `sessionEndFor`, `isSessionClosed`, `lookbackDays`, `sessionEligible`, `studentsToMarkAbsent`, `isAutoAbsent`, `pruneProcessed` حسب `contracts/auto-absent.md`
- [x] T002 [P] إنشاء `test/auto_absent_test.dart`: نهاية عادية، عابرة لمنتصف الليل، بلا نهاية/تنسيق خاطئ، حدود isSessionClosed، lookbackDays، sessionEligible (enabledAt وprocessed)، studentsToMarkAbsent (مؤرشف، attendanceStart، له سجل)، isAutoAbsent، pruneProcessed
- [x] T003 في `lib/config/constants.dart`: `SETTING_AUTO_ABSENT_ENABLED`, `SETTING_AUTO_ABSENT_GRACE_MINUTES`, `SETTING_AUTO_ABSENT_ENABLED_AT`, `SETTING_AUTO_ABSENT_PROCESSED`
- [x] T004 **CHECKPOINT**: `flutter analyze` + `flutter test test/auto_absent_test.dart`

## Phase 2: US4 — الإعداد والواجهة
- [x] T005 `SettingsController`: `autoAbsentEnabled` و`autoAbsentGraceMinutes` (RxBool/RxInt)، تحميلهم في `_loadLateAttendanceSettings`، `setAutoAbsentEnabled(bool)` (عند التفعيل يكتب `enabled_at`=الآن)، `setAutoAbsentGraceMinutes(int)` (clamp 0..180)
- [x] T006 `settings_page.dart`: بعد بند "متأخر" تلقائيًا — مفتاح "تسجيل الغياب تلقائيًا بعد انتهاء الحصة" بشرح، ولما يتفعّل منتقي "مهلة بعد نهاية الحصة" (0، 5، 10، 15، 20، 30، 45، 60، 90، 120، 180)
- [x] T007 **CHECKPOINT**: analyze + تحقق يدوي لحفظ المفتاح والمهلة

## Phase 3: US1/US2/US3 — الخدمة والتشغيل
- [x] T008 [US1] إنشاء `lib/services/auto_absent_service.dart`: `runOnce({now})` (حراسة `_running` + تحقق من الإعداد والـcontrollers)، يمر على `lookbackDays` ← المجموعات ذات الحصة (`groupHasSessionOnDay`) ← `sessionEndFor(sessionTimeForGroupOnDay)` ← `sessionEligible` ← `studentsToMarkAbsent` ← `insertAttendance` (بتاريخ يوم الحصة + ساعة الإغلاق، `notes: kAutoAbsentNote`) ← تعليم الحصة processed وحفظها؛ ثم تحديث القائمة مرة واحدة + `pushStudentSummary` للمتأثرين + `scheduleLatePaymentReminder`
- [x] T009 [US3] `start()`/`stop()` بـ`Timer.periodic(1 min)` + استدعاء `runOnce` عند البدء
- [x] T010 [US3] ربط التشغيل: `start()` بعد تهيئة الـcontrollers (نفس مكان تسجيل AttendanceController/الصفحة الرئيسية) و`runOnce` في المراقب `AppLifecycleState.resumed` في `main.dart`
- [x] T011 [US1] ضمان تحديث شاشة الحضور المفتوحة بعد التسجيل (إعادة تحميل `AttendanceController.loadAttendance`)
- [x] T012 **CHECKPOINT**: analyze + test

## Phase 4: US1 — المسح بعد الغياب التلقائي
- [x] T013 [US1] `QRController._recordAttendance`: قبل `addAttendance` — لو للطالب سجل اليوم `isAutoAbsent` → `updateAttendance(existing.copyWith(status: status, notes: 'تم عبر QR', clearInteraction: true))` + تحديث القائمة + `pushStudentSummary`، ثم الرجوع بدون المسار العادي؛ غير كده المسار الحالي بلا تغيير
- [x] T014 [US2] مراجعة (grep) أي مستهلك تاني بيفترض أن الغائب بلا ملاحظة، والتأكد إن التقارير ونسب الحضور بتعامله كغياب عادي
- [x] T015 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart بنود 2–7)

## Phase 5: Polish
- [x] T016 [P] `flutter analyze` + `flutter test` كاملين
- [x] T017 بناء release وتثبيته والتحقق النهائي، وتحديث `HANDOFF.md` بملخص spec 046 وملف الذاكرة

## Dependencies
T001/T002/T003 بالتوازي ← T004. T005 ← T006. T008 بعد T001+T003+T005 ← T009 ← T010 ← T011. T013 مستقل بعد T001.

## MVP
T001–T011 + T013 (المنطق + الإعداد + الخدمة + المسح). T014 للتأكد من الاتساق.
