# Implementation Plan: سجل أرشفة الطالب داخل سجل الحضور

**Branch**: `047-student-archive-history` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary
جدول جديد متزامن `student_archive_events` (DB v37 + migration Supabase) يتسجّل فيه حدث عند `archiveStudent`/`unarchiveStudent` (نقطة واحدة)، مع backfill للمؤرشفين الحاليين. العرض بدمج الأحداث مع سجلات الحضور في تفاصيل الطالب وقائمة السجلات العامة (فلتر "الكل" فقط) عبر دوال صرفة. الأحداث لا تدخل أي حساب.

## Technical Context
Flutter 3.38 / Dart 3.5, GetX, sqflite (DB 36 → 37), Supabase self-hosted (RLS + realtime)، SyncEngine. اختبارات: `flutter test`. قيد: migration على الـVPS يحتاج موافقة المستخدم قبل التطبيق.

## Constitution Check
القالب غير مُعبَّأ → لا بوابات. ملتزم بالأنماط: دوال صرفة + اختبارات، migration idempotent، القناة الممتدة لجدول جديد.

## Project Structure
```
lib/models/archive_event_model.dart          (جديد)
lib/utils/archive_history.dart               (جديد، صرف)
lib/config/constants.dart                    (جدول/أعمدة + DATABASE_VERSION=37)
lib/services/database_service.dart           (create + onUpgrade v37 + backfill + record/get + hooks في archive/unarchive)
lib/services/sync_engine.dart                (_tables, _extendedTables, _pkCol, payload push/pull, refresh, reconcile)
lib/controllers/attendance_controller.dart   (تحميل الأحداث rx + تحديث)
lib/views/students/student_details_page.dart (_AttendanceTab: دمج + صف حدث)
lib/views/attendance/attendance_page.dart    (_RecordsTab: دمج + صف حدث عند فلتر الكل)
lib/widgets/archive_event_tile.dart          (جديد، صف مشترك)
supabase/migration_student_archive_events.sql (جديد)
test/archive_history_test.dart               (جديد)
```

## Design notes
- تسجيل الحدث بعد نجاح الأرشفة/الاستعادة داخل try/catch منفصل؛ `_queueSync` للحدث (insert).
- مفتاح فريد (student,type,event_at) محليًا + توفيق التكرار في SyncEngine.
- الأحداث لا تمر على قائمة `attendance` إطلاقًا → أي حساب موجود لا يتأثر.
- الـmigration يُطبَّق عبر SSH بعد موافقة المستخدم (نمط migration_session_overrides.sql).
