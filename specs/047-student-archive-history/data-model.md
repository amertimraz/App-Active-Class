# Data Model: student_archive_events

## محلي (sqflite) — DB v37
```sql
CREATE TABLE IF NOT EXISTS student_archive_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL,
  type TEXT NOT NULL,            -- 'archived' | 'restored'
  event_at TEXT NOT NULL,        -- ISO-8601 محلي
  sync_updated_at TEXT,
  sync_remote_id TEXT,
  FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_student_archive_events_key
  ON student_archive_events(student_id, type, event_at);
CREATE INDEX IF NOT EXISTS idx_student_archive_events_student
  ON student_archive_events(student_id);
```
- Backfill في onUpgrade (v37): لكل طالب `is_archived=1 AND archived_at IS NOT NULL` → (`archived`, archived_at).
- الثوابت: `TABLE_STUDENT_ARCHIVE_EVENTS`, `COL_SAE_ID/STUDENT_ID/TYPE/EVENT_AT`, `kArchiveEventArchived`, `kArchiveEventRestored`.

## Supabase (migration_student_archive_events.sql)
جدول `public.student_archive_events` بنفس نمط session_overrides: `id uuid, team_id, origin_device_id, local_id, student_remote_id uuid references students on delete cascade, type, event_at text, updated_at, deleted_at`، RLS (select/insert/update للأعضاء + ترخيص فعّال)، trigger `set_updated_at`، `replica identity full`، publication realtime، `unique (team_id, origin_device_id, local_id)`. لا delete policy ولا trigger (قراءة فقط).

## نموذج Dart
`ArchiveEvent { id, studentId, type, at }` + `isArchive` / `isRestore`.
