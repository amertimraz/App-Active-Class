# Tasks: سجل أرشفة الطالب داخل سجل الحضور

**Tests**: اختبارات وحدة للدوال الصرفة + تحقق يدوي. **DB v37 + migration Supabase (يُطبَّق بعد موافقة المستخدم).**

## Phase 1: النموذج والمنطق الصرف
- [x] T001 [P] `lib/models/archive_event_model.dart`: `ArchiveEvent` (id, studentId, type, at) + toMap/fromMap + `isArchive`/`isRestore`
- [x] T002 [P] `lib/utils/archive_history.dart`: ثوابت النوعين، `archiveEventLabel`، `mergeAttendanceAndArchive` (+ `TimelineItem`)، `archiveEventVisible`، `shouldRecordArchiveEvent` حسب `contracts/archive-history.md`
- [x] T003 [P] `test/archive_history_test.dart`: الدمج/الترتيب، الصيغة (اليوم/أمس/تاريخ كامل)، shouldRecord، visible
- [x] T004 `constants.dart`: `TABLE_STUDENT_ARCHIVE_EVENTS` + `COL_SAE_*` + `DATABASE_VERSION = 37`
- [x] T005 **CHECKPOINT**: analyze + `flutter test test/archive_history_test.dart`

## Phase 2: قاعدة البيانات والتسجيل (US1, US4)
- [x] T006 `database_service.dart`: SQL إنشاء الجدول + الفهارس (onCreate) و`oldVersion < 37` (إنشاء + backfill من archived_at بدون `_queueSync`)
- [x] T007 `database_service.dart`: `insertArchiveEvent`, `getArchiveEventsByStudent`, `getAllArchiveEvents`؛ وتسجيل الحدث داخل `archiveStudent`/`unarchiveStudent` (try/catch منفصل + حارس الحالة + `_queueSync`)
- [x] T008 **CHECKPOINT**: analyze + test

## Phase 3: المزامنة (US3)
- [x] T009 `supabase/migration_student_archive_events.sql` (جدول + RLS + set_updated_at + realtime، بلا delete)
- [x] T010 `sync_engine.dart`: `_tables` + `_extendedTables` + `_pkCol` + payload الإرسال والاستقبال + `_refreshAfterPull` + توفيق التكرار بمفتاح (طالب، نوع، وقت)
- [x] T011 **CHECKPOINT**: analyze + test

## Phase 4: العرض (US1, US2)
- [x] T012 `attendance_controller.dart`: `archiveEvents` (RxList) + `loadArchiveEvents()` (يُستدعى مع `loadAttendance`)
- [x] T013 `lib/widgets/archive_event_tile.dart`: صف الحدث (أيقونة محايدة + `archiveEventLabel`)
- [x] T014 `student_details_page.dart` ← `_AttendanceTab`: دمج أحداث الطالب بين السجلات (التجميع الشهري)، بدون المساس بالعدّادات
- [x] T015 `attendance_page.dart` ← `_RecordsTab`: دمج الأحداث عند فلتر الحالة "الكل" فقط (يحترم البحث والمجموعة)، بدون المساس بالعدّادات
- [x] T016 **CHECKPOINT**: analyze + test + تحقق يدوي (quickstart 1–5, 7)

## Phase 5: Polish
- [x] T017 [P] `flutter analyze` + `flutter test` كاملين
- [x] T018 بناء release وتثبيته، تطبيق migration على الخادم بعد موافقة المستخدم، تحقق الفريق (quickstart 6)، تحديث `HANDOFF.md` والذاكرة

## Dependencies
T001/T002/T003 بالتوازي ← T004 ← T005. T006 ← T007. T009 مستقل. T010 بعد T004+T007. T012 بعد T007. T013 ← T014/T015.
