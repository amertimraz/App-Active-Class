-- supabase/migration_team_settings.sql
--
-- الإعدادات المشتركة بين المدرس (المالك) والمساعدين: المدرس هو اللي بيكتب،
-- وكل أعضاء الفريق بيقروا وبيطبّقوها محليًا (المساعد ما يقدرش يعدّلها).
-- إضافة فوق team_schema.sql — شغّله مرة واحدة. idempotent.
-- يُطبَّق عبر SSH لحاوية قاعدة البيانات على الـVPS:
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_team_settings.sql
--
-- key = مفتاح app_settings المحلي، value = قيمته كنص (null = الافتراضي).

create table if not exists public.team_settings (
  team_id uuid not null references public.teams(id) on delete cascade,
  key text not null,
  value text,
  updated_at timestamptz not null default now(),
  primary key (team_id, key)
);

alter table public.team_settings enable row level security;

create or replace function public.is_team_owner(_team_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.teams
    where id = _team_id and owner_id = auth.uid()
  );
$$;

drop policy if exists "team_settings_select" on public.team_settings;
drop policy if exists "team_settings_insert" on public.team_settings;
drop policy if exists "team_settings_update" on public.team_settings;
create policy "team_settings_select" on public.team_settings for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
-- الكتابة للمالك فقط.
create policy "team_settings_insert" on public.team_settings for insert
  with check (public.is_team_owner(team_id));
create policy "team_settings_update" on public.team_settings for update
  using (public.is_team_owner(team_id));

-- لا DELETE policy عمدًا (الرجوع للافتراضي = value null).

-- وقت خادم موحّد (spec 031) — set_updated_at() من migration_server_updated_at.sql.
drop trigger if exists trg_set_updated_at on public.team_settings;
create trigger trg_set_updated_at before insert or update on public.team_settings
  for each row execute function public.set_updated_at();
