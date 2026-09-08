# Implementation Plan: إلغاء حصة اليوم وتعويضها

**Branch**: `032-cancel-makeup-session` | **Date**: 2026-09-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/032-cancel-makeup-session/spec.md`

## Summary

جدول جديد `session_overrides` (مفتاح منطقي `(group_id, date)`، `type ∈ {cancelled, makeup, extra}`، `compensates_date` للـmakeup). ثلاث دوال جدولة في `AttendanceController` تصير override-aware:
- `groupHasSessionOnDay` → `cancelled` = false، `makeup`/`extra` = true، غيرها = الجدول.
- `_countExpectedForGroup` / `getExpectedSessionsPerGroup` / `groupsForDay` → طرح `cancelled` وإضافة `makeup`/`extra` ضمن النطاق.

الفوترة **صفر تغيير** (كلها من صفوف الحضور). سجل الطالب = دمج طبقة عرض (لا صفوف حضور وهمية). المزامنة: جدول مُزامَن على القناة الأساسية، dup على `(group, date)` → `_reconcileDuplicate` (spec 031). DB v28 → **v29** + migration Supabase (جدول + RLS + realtime + `trg_set_updated_at`).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1؛ SQL للـmigration.

**Primary Dependencies**: GetX، sqflite، `supabase_flutter`، `SyncEngine` القائم. لا مكتبات جديدة.

**Storage**: SQLite محلي **v28 → v29** (جدول `session_overrides` + فهرس على `(group_id, date)`). Supabase: جدول `session_overrides` مطابق + RLS مثل باقي الجداول (`is_team_member AND is_team_license_active`) + `REPLICA IDENTITY FULL` + إضافته لـ`supabase_realtime` publication + `trg_set_updated_at` (spec 031).

**Testing**: `flutter test` — وحدة لدوال الجدولة override-aware (`groupHasSessionOnDay`/`_countExpectedForGroup` مع cancelled/makeup/extra، مع/بدون جدول) — تُستخرَج كدالة نقية `SessionScheduleResolver` أو تُختبَر عبر controller بحقن قائمة overrides.

**Target Platform**: Android + خادم Supabase.

**Project Type**: تطبيق موبايل Flutter + خادم.

**Performance Goals**: تحميل `session_overrides` مرة عند فتح شاشة الحضور (عدد صغير — استثناءات نادرة). `groupHasSessionOnDay` يضيف بحثًا في قائمة صغيرة في الذاكرة. صفر أثر على المسار الساخن.

**Constraints**: صفر تغيير في منطق `PricingHelper`. سجل الطالب دمج عرض فقط. الإلغاء يُرفض لمجموعة بلا جدول (`groupHasSessionOnDay` يرجع true افتراضيًا فالإلغاء بلا معنى واضح). حذف إلغاء له تعويض = يُمنع.

**Scale/Scope**: 1 نموذج + 1 جدول (+migration محلي +migration Supabase) + ~5 دوال `DatabaseService` + 1 controller + تعديل 3 دوال `AttendanceController` + إضافة الجدول لـ7 نقاط في `SyncEngine` + UI: زر/قائمة في شاشة الحضور، عرض "ملغية"، دمج في تفاصيل الطالب + بوابة الأهل. ~2 ملفات اختبار.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

الدستور قالب فارغ. أعراف المشروع:

| عرف | الحالة |
|---|---|
| ترقية DB بنسخة صريحة + migration | ✅ v28→v29، جدول جديد فقط (صفر تأثير على جداول قائمة) |
| migration Supabase عبر SSH (specs 021/024/025) | ✅ نفس النمط |
| RLS للجدول الجديد مثل الباقي | ✅ `is_team_member AND is_team_license_active` |
| لا تغيير في التسعير | ✅ الفوترة من صفوف الحضور |
| إعادة استخدام: schedule parsing، آلية المزامنة، `_reconcileDuplicate` (spec 031)، حوارات التأكيد | ✅ |
| اختبارات + `analyze` نظيف | ✅ مخطّط |
| git push بإذن؛ commit على `main` | ✅ ملحوظ |

**النتيجة: PASS** — لا انتهاكات.

## Project Structure

### Documentation (this feature)

```text
specs/032-cancel-makeup-session/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — 7 قرارات
├── data-model.md        # Phase 1 — session_overrides schema + المشتقّات
├── quickstart.md        # Phase 1 — سيناريوهات
├── contracts/
│   ├── session-override-model-db.md    # النموذج + جداول SQLite/Supabase + دوال DatabaseService
│   ├── schedule-override-aware.md       # عقد تعديل دوال AttendanceController
│   └── session-override-ui.md           # عقد الشاشات + دمج سجل الطالب
└── tasks.md             # Phase 2 — /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── config/constants.dart               # + TABLE_SESSION_OVERRIDES + COL_SO_* + DATABASE_VERSION=29
├── models/session_override_model.dart   # جديد — SessionOverride + SessionOverrideType
├── services/
│   ├── database_service.dart            # + _sessionOverridesTableSql + migration v29 + CRUD + get-by-group/date + get-in-range
│   └── sync_engine.dart                 # + TABLE_SESSION_OVERRIDES في _tables/_coreTables/_pkCol/_buildRemoteRow/_toLocalMap/_applyRemoteRow(dup)/_refreshUiForTable
├── controllers/
│   ├── session_override_controller.dart # جديد — GetX: قائمة overrides + CRUD + helpers (hasSessionOnDay/expectedDelta)
│   └── attendance_controller.dart       # groupHasSessionOnDay/_countExpectedForGroup/groupsForDay override-aware
├── views/
│   ├── attendance/attendance_page.dart  # زر "إلغاء حصة اليوم"/"تعويض"/"تراجع" + عرض "ملغية" + حوارات التأكيد
│   └── students/student_details_page.dart  # دمج overrides في قسم الحضور
└── services/parent_portal_service.dart  # + عناصر cancelled/makeup في attendanceHistory المدفوعة

supabase/
└── migration_session_overrides.sql      # جدول + RLS + realtime + trigger

test/
├── session_schedule_override_test.dart  # جديد — override-aware schedule logic
└── session_override_model_test.dart     # جديد — toMap/fromMap + type
```

**Structure Decision**: نموذج في `models/`، جدول/CRUD في `DatabaseService`، حالة + helpers في `SessionOverrideController` (GetX)، `AttendanceController` يستهلك الـhelpers. المزامنة تعيد استخدام نمط `bank_questions`/`student_follow_ups` (جدول مستقل نسبيًا). سجل الطالب دمج عرض في `student_details_page` + `parent_portal_service`.

## Complexity Tracking

> لا انتهاكات — لا شيء يُبرَّر.
