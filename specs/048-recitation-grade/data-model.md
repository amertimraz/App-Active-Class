# Data Model: درجة التسميع

## محلي (sqflite) — DB v38
```sql
ALTER TABLE attendance ADD COLUMN recitation INTEGER;  -- 1..10 أو NULL
```
- onCreate: العمود ضمن CREATE TABLE attendance. القديم = NULL.
- الثابت: `COL_ATTENDANCE_RECITATION = 'recitation'`, `kRecitationMin = 1`, `kRecitationMax = 10`.

## Supabase (migration_attendance_recitation.sql)
```sql
alter table public.attendance add column if not exists recitation integer;
alter table public.attendance drop constraint if exists attendance_recitation_range;
alter table public.attendance add constraint attendance_recitation_range
  check (recitation is null or (recitation between 1 and 10));
```
trigger الوقت (spec 031) والـRLS موروثان. يُطبَّق بدور مالك الجدول (`-U supabase_admin`).

## نموذج Dart
`Attendance.recitation` (int?) + `copyWith(recitation, clearRecitation)` + `toMap/fromMap`. `canRecordRecitation(status)` = حاضر/متأخر.

## قواعد
- قيمة خارج 1..10 تُعتبر null عند القراءة (`normalizeRecitation`).
- تتمسح عند التحويل لغائب وعند حذف السجل.
