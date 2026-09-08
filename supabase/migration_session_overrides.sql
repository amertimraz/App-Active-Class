-- supabase/migration_session_overrides.sql
--
-- spec 032 — إلغاء حصة اليوم وتعويضها: مزامنة استثناءات الحصص بين أجهزة
-- الفريق. إضافة فوق team_schema.sql — شغّله مرة واحدة. idempotent.
-- يُطبَّق عبر SSH لحاوية قاعدة البيانات على الـVPS:
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_session_overrides.sql
--
-- جدول واحد: session_overrides — استثناء واحد لكل (مجموعة، يوم).
-- type ∈ {cancelled, makeup, extra}. الفوترة مبتتأثرش بالجدول ده
-- (كلها من صفوف الحضور). يعيد استخدام صلاحية حذف الحضور (delete_attendance)
-- ونفس نمط bank_questions/student_follow_ups.

create table if not exists public.session_overrides (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  group_remote_id uuid references public.groups(id) on delete cascade,
  date text not null,
  type text not null,
  compensates_date text,
  note text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.session_overrides enable row level security;

drop policy if exists "session_overrides_select" on public.session_overrides;
drop policy if exists "session_overrides_insert" on public.session_overrides;
drop policy if exists "session_overrides_update" on public.session_overrides;
create policy "session_overrides_select" on public.session_overrides for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "session_overrides_insert" on public.session_overrides for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "session_overrides_update" on public.session_overrides for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- لا DELETE policy عمدًا — الحذف soft (تحديث deleted_at). يعيد استخدام
-- صلاحية حذف الحضور.
create or replace function public.check_delete_session_overrides()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_attendance') then
      raise exception 'not authorized to delete this session override';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_session_overrides on public.session_overrides;
create trigger trg_check_delete_session_overrides before update on public.session_overrides
  for each row execute function public.check_delete_session_overrides();

-- spec 031 — وقت خادم موحّد لـ updated_at (يمنع فقدان تعديلات بسبب
-- انحراف ساعات الأجهزة). set_updated_at() مُعرَّفة في migration_server_updated_at.sql.
drop trigger if exists trg_set_updated_at on public.session_overrides;
create trigger trg_set_updated_at before insert or update on public.session_overrides
  for each row execute function public.set_updated_at();

alter table public.session_overrides replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'session_overrides'
  ) then
    execute 'alter publication supabase_realtime add table public.session_overrides';
  end if;
end $$;
