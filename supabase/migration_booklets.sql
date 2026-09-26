-- supabase/migration_booklets.sql
--
-- spec 041 — الملازم/الكتب: 4 جداول متزامنة (booklets, booklet_groups,
-- booklet_records, booklet_payments). مستقلة تمامًا عن payments.
-- idempotent. يُطبَّق عبر SSH بمستخدم supabase_admin (مالك الجداول):
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online --     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' --     < supabase/migration_booklets.sql
--
-- الحذف soft (deleted_at) ومحروس بصلاحية delete_payments.

create table if not exists public.booklets (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  name text not null,
  price numeric not null default 0,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.booklets enable row level security;

drop policy if exists "booklets_select" on public.booklets;
drop policy if exists "booklets_insert" on public.booklets;
drop policy if exists "booklets_update" on public.booklets;
create policy "booklets_select" on public.booklets for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklets_insert" on public.booklets for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklets_update" on public.booklets for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create or replace function public.check_delete_booklets()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_payments') then
      raise exception 'not authorized to delete this booklets row';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_booklets on public.booklets;
create trigger trg_check_delete_booklets before update on public.booklets
  for each row execute function public.check_delete_booklets();

drop trigger if exists trg_set_updated_at on public.booklets;
create trigger trg_set_updated_at before insert or update on public.booklets
  for each row execute function public.set_updated_at();

alter table public.booklets replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'booklets'
  ) then
    execute 'alter publication supabase_realtime add table public.booklets';
  end if;
end $$;

create table if not exists public.booklet_groups (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  booklet_remote_id uuid references public.booklets(id) on delete cascade,
  group_remote_id uuid references public.groups(id) on delete cascade,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.booklet_groups enable row level security;

drop policy if exists "booklet_groups_select" on public.booklet_groups;
drop policy if exists "booklet_groups_insert" on public.booklet_groups;
drop policy if exists "booklet_groups_update" on public.booklet_groups;
create policy "booklet_groups_select" on public.booklet_groups for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklet_groups_insert" on public.booklet_groups for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklet_groups_update" on public.booklet_groups for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create or replace function public.check_delete_booklet_groups()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_payments') then
      raise exception 'not authorized to delete this booklet_groups row';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_booklet_groups on public.booklet_groups;
create trigger trg_check_delete_booklet_groups before update on public.booklet_groups
  for each row execute function public.check_delete_booklet_groups();

drop trigger if exists trg_set_updated_at on public.booklet_groups;
create trigger trg_set_updated_at before insert or update on public.booklet_groups
  for each row execute function public.set_updated_at();

alter table public.booklet_groups replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'booklet_groups'
  ) then
    execute 'alter publication supabase_realtime add table public.booklet_groups';
  end if;
end $$;

create table if not exists public.booklet_records (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  booklet_remote_id uuid references public.booklets(id) on delete cascade,
  student_remote_id uuid references public.students(id) on delete cascade,
  delivered boolean not null default false,
  delivered_at text,
  excluded boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.booklet_records enable row level security;

drop policy if exists "booklet_records_select" on public.booklet_records;
drop policy if exists "booklet_records_insert" on public.booklet_records;
drop policy if exists "booklet_records_update" on public.booklet_records;
create policy "booklet_records_select" on public.booklet_records for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklet_records_insert" on public.booklet_records for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklet_records_update" on public.booklet_records for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create or replace function public.check_delete_booklet_records()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_payments') then
      raise exception 'not authorized to delete this booklet_records row';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_booklet_records on public.booklet_records;
create trigger trg_check_delete_booklet_records before update on public.booklet_records
  for each row execute function public.check_delete_booklet_records();

drop trigger if exists trg_set_updated_at on public.booklet_records;
create trigger trg_set_updated_at before insert or update on public.booklet_records
  for each row execute function public.set_updated_at();

alter table public.booklet_records replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'booklet_records'
  ) then
    execute 'alter publication supabase_realtime add table public.booklet_records';
  end if;
end $$;

create table if not exists public.booklet_payments (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  booklet_remote_id uuid references public.booklets(id) on delete cascade,
  student_remote_id uuid references public.students(id) on delete cascade,
  amount numeric not null,
  date text not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.booklet_payments enable row level security;

drop policy if exists "booklet_payments_select" on public.booklet_payments;
drop policy if exists "booklet_payments_insert" on public.booklet_payments;
drop policy if exists "booklet_payments_update" on public.booklet_payments;
create policy "booklet_payments_select" on public.booklet_payments for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklet_payments_insert" on public.booklet_payments for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "booklet_payments_update" on public.booklet_payments for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create or replace function public.check_delete_booklet_payments()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_payments') then
      raise exception 'not authorized to delete this booklet_payments row';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_booklet_payments on public.booklet_payments;
create trigger trg_check_delete_booklet_payments before update on public.booklet_payments
  for each row execute function public.check_delete_booklet_payments();

drop trigger if exists trg_set_updated_at on public.booklet_payments;
create trigger trg_set_updated_at before insert or update on public.booklet_payments
  for each row execute function public.set_updated_at();

alter table public.booklet_payments replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'booklet_payments'
  ) then
    execute 'alter publication supabase_realtime add table public.booklet_payments';
  end if;
end $$;

