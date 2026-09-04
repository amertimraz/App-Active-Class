-- supabase/migration_student_follow_ups.sql
--
-- spec 021 — طلاب محتاجين متابعة: مزامنة واقعة "تمّت المتابعة" بين
-- أجهزة الفريق. إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على
-- السيرفر — شغّله لوحده مرة واحدة. نفس شكل جدول homework بالظبط (نفس
-- أعمدة team_id/origin_device_id/local_id/student_remote_id/updated_at/
-- deleted_at)، وبيستخدم نفس صلاحية "حذف الحضور" (delete_attendance)
-- بدل ما نضيف صلاحية مستقلة جديدة (زي homework بالظبط).

create table if not exists public.student_follow_ups (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  student_remote_id uuid references public.students(id) on delete cascade,
  reason_types text, acknowledged_at text, note text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.student_follow_ups enable row level security;

create policy "student_follow_ups_select" on public.student_follow_ups for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "student_follow_ups_insert" on public.student_follow_ups for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "student_follow_ups_update" on public.student_follow_ups for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- لا يوجد DELETE policy عمدًا (نفس منطق باقي الجداول المشتركة) —
-- الحذف بيتم عن طريق soft-delete (تحديث deleted_at) بس.
create or replace function public.check_delete_student_follow_ups()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_attendance') then
      raise exception 'not authorized to delete this follow-up record';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_student_follow_ups on public.student_follow_ups;
create trigger trg_check_delete_student_follow_ups before update on public.student_follow_ups
  for each row execute function public.check_delete_student_follow_ups();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'student_follow_ups'
  ) then
    execute 'alter publication supabase_realtime add table public.student_follow_ups';
  end if;
end $$;
