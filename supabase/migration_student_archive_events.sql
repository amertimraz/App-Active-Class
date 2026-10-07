-- supabase/migration_student_archive_events.sql
--
-- spec 047 — سجل أرشفة/استعادة الطالب: مزامنة أحداث الأرشفة بين أجهزة
-- الفريق. إضافة فوق team_schema.sql — شغّله مرة واحدة. idempotent.
-- يُطبَّق عبر SSH لحاوية قاعدة البيانات على الـVPS:
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_student_archive_events.sql
--
-- جدول واحد: student_archive_events — حدث لكل أرشفة/استعادة
-- (type ∈ {archived, restored}). للقراءة فقط: لا DELETE policy ولا trigger
-- حذف؛ بيتحذف تلقائيًا مع الطالب (on delete cascade).

create table if not exists public.student_archive_events (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  student_remote_id uuid references public.students(id) on delete cascade,
  type text not null,
  event_at text not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.student_archive_events enable row level security;

drop policy if exists "student_archive_events_select" on public.student_archive_events;
drop policy if exists "student_archive_events_insert" on public.student_archive_events;
drop policy if exists "student_archive_events_update" on public.student_archive_events;
create policy "student_archive_events_select" on public.student_archive_events for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "student_archive_events_insert" on public.student_archive_events for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "student_archive_events_update" on public.student_archive_events for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- spec 031 — وقت خادم موحّد لـ updated_at.
drop trigger if exists trg_set_updated_at on public.student_archive_events;
create trigger trg_set_updated_at before insert or update on public.student_archive_events
  for each row execute function public.set_updated_at();

alter table public.student_archive_events replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'student_archive_events'
  ) then
    execute 'alter publication supabase_realtime add table public.student_archive_events';
  end if;
end $$;
