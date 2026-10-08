# Tasks: درجة التسميع أثناء الحصة

**Tests**: اختبارات وحدة للدوال الصرفة + تحقق يدوي. **DB v38 + migration Supabase (يُطبَّق بعد موافقة المستخدم).**

## Phase 1: المنطق الصرف والنموذج
- [x] T001 [P] `lib/utils/recitation.dart`: `kRecitationMin/Max`, `normalizeRecitation`, `canRecordRecitation`, `recitationAverage`, `recitationCount`, `recitationAverageLabel` حسب `contracts/recitation.md`
- [x] T002 [P] `test/recitation_test.dart`
- [x] T003 `constants.dart`: `COL_ATTENDANCE_RECITATION` + `DATABASE_VERSION = 38`
- [x] T004 `attendance_model.dart`: حقل `recitation` + toMap/fromMap + `copyWith(recitation, clearRecitation)`
- [x] T005 **CHECKPOINT**: analyze + `flutter test test/recitation_test.dart`

## Phase 2: قاعدة البيانات والمزامنة (US4)
- [x] T006 `database_service.dart`: العمود في CREATE TABLE attendance + `oldVersion < 38` (ALTER)
- [x] T007 `sync_engine.dart`: `'recitation'` في payload attendance (إرسال/استقبال)
- [x] T008 `supabase/migration_attendance_recitation.sql`
- [x] T009 **CHECKPOINT**: analyze + test

## Phase 3: الإدخال (US1, US2)
- [x] T010 `attendance_controller.dart`: `setRecitation(...)` + مسح الدرجة عند التحويل لغائب في `setAttendanceStatus`
- [x] T011 `attendance_page.dart`: `recitationMap` + `_RecitationRow` (10 أزرار toggle) داخل `_StudentAttendanceChip` للحاضر/المتأخر فقط
- [x] T012 مراجعة مسارات تحويل لغائب أخرى (`toggleAttendance`، `qr_controller`، `auto_absent_service`) للتأكد إن الدرجة ما تعيش مع غائب
- [x] T013 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart 1–5)

## Phase 4: العرض والمتوسط (US3)
- [x] T014 `student_details_page.dart`: شارة الدرجة بجانب اليوم + بطاقة متوسط الشهر والإجمالي (تظهر فقط لو فيه درجات)
- [x] T015 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart 6–7)

## Phase 5: Polish
- [x] T016 [P] `flutter analyze` + `flutter test` كاملين
- [x] T017 بناء release وتثبيته، تطبيق migration على الخادم بعد موافقة المستخدم، تحقق الفريق (quickstart 8)، تحديث `HANDOFF.md` والذاكرة

## Dependencies
T001/T002/T003 بالتوازي ← T004 ← T005. T006 بعد T003+T004. T007 بعد T004. T010 بعد T004. T011 بعد T010. T014 بعد T001+T004.
