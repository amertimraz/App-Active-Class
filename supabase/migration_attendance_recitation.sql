-- supabase/migration_attendance_recitation.sql
--
-- spec 048 — درجة التسميع (1..10) على سجل الحضور. مُزامَن عبر الفريق زي
-- status/notes/interaction. idempotent.
-- يُطبَّق عبر SSH بدور مالك جدول attendance (supabase_admin — نفس نمط
-- migration_student_interaction.sql):
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_attendance_recitation.sql
--
-- trg_set_updated_at على attendance موجود من spec 031. RLS موروثة.

alter table public.attendance add column if not exists recitation integer;

alter table public.attendance drop constraint if exists attendance_recitation_range;
alter table public.attendance add constraint attendance_recitation_range
  check (recitation is null or (recitation between 1 and 10));
