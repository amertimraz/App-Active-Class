-- supabase/migration_homework.sql
--
-- إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على السيرفر —
-- شغّله لوحده مرة واحدة. بيضيف مشاركة حالة الواجب (عمل/لم يعمل) بين
-- المدرس والمساعدين، بنفس شكل جدول الحضور بالظبط (نفس أعمدة
-- team_id/origin_device_id/local_id/student_remote_id/updated_at/
-- deleted_at)، وبيستخدم نفس صلاحية "حذف الحضور" (delete_attendance)
-- بدل ما نضيف صلاحية مستقلة جديدة للواجب.

create table if not exists public.homework (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  student_remote_id uuid references public.students(id) on delete cascade,
  date text, status text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.homework enable row level security;

create policy "homework_select" on public.homework for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "homework_insert" on public.homework for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "homework_update" on public.homework for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- لا يوجد DELETE policy عمدًا (نفس منطق باقي الجداول المشتركة) —
-- الحذف بيتم عن طريق soft-delete (تحديث deleted_at) بس.
create or replace function public.check_delete_homework()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_attendance') then
      raise exception 'not authorized to delete this homework record';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_homework on public.homework;
create trigger trg_check_delete_homework before update on public.homework
  for each row execute function public.check_delete_homework();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'homework'
  ) then
    execute 'alter publication supabase_realtime add table public.homework';
  end if;
end $$;
