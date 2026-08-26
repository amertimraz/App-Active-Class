-- supabase/migration_exams.sql
--
-- إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على السيرفر —
-- شغّله لوحده مرة واحدة. بتضيف مشاركة الامتحانات ودرجاتها بين المدرس
-- والمساعدين، بنفس شكل جدول الواجب بالظبط (نفس أعمدة
-- team_id/origin_device_id/local_id/updated_at/deleted_at)، وبتستخدم
-- نفس صلاحية "حذف الحضور" (delete_attendance) بدل ما نضيف صلاحية
-- مستقلة جديدة للامتحانات — زي ما عمل الواجب بالظبط. can_view_academics
-- مش مطبّقة هنا عمدًا (نفس منطق باقي الجداول): البيانات لازم تفضل
-- متاحة تقنيًا للمساعد عشان يقدر يسجّل عليها، إحنا بس بنخفي الشاشة
-- عنه في الواجهة لو الصلاحية دي متسحوبة منه.
--
-- ثلاث جداول: exams (الامتحان نفسه)، exam_groups (ربط الامتحان
-- بالمجموعات)، exam_grades (درجة كل طالب). الاتنين الأخيرين محتاجين
-- exam_remote_id عشان يربطوا بالامتحان الأب، بالإضافة لـ
-- group_remote_id / student_remote_id.

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  name text not null,
  exam_date text,
  max_grade double precision,
  passing_grade double precision,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

create table if not exists public.exam_groups (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  exam_remote_id uuid references public.exams(id) on delete cascade,
  group_remote_id uuid references public.groups(id) on delete cascade,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

create table if not exists public.exam_grades (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  exam_remote_id uuid references public.exams(id) on delete cascade,
  student_remote_id uuid references public.students(id) on delete cascade,
  grade double precision,
  notes text,
  is_absent boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.exams enable row level security;
alter table public.exam_groups enable row level security;
alter table public.exam_grades enable row level security;

create policy "exams_select" on public.exams for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exams_insert" on public.exams for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exams_update" on public.exams for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create policy "exam_groups_select" on public.exam_groups for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_groups_insert" on public.exam_groups for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_groups_update" on public.exam_groups for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create policy "exam_grades_select" on public.exam_grades for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_grades_insert" on public.exam_grades for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_grades_update" on public.exam_grades for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- لا يوجد DELETE policy عمدًا (نفس منطق باقي الجداول المشتركة) —
-- الحذف بيتم عن طريق soft-delete (تحديث deleted_at) بس.
create or replace function public.check_delete_exams()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_attendance') then
      raise exception 'not authorized to delete this exam record';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_exams on public.exams;
create trigger trg_check_delete_exams before update on public.exams
  for each row execute function public.check_delete_exams();
drop trigger if exists trg_check_delete_exam_groups on public.exam_groups;
create trigger trg_check_delete_exam_groups before update on public.exam_groups
  for each row execute function public.check_delete_exams();
drop trigger if exists trg_check_delete_exam_grades on public.exam_grades;
create trigger trg_check_delete_exam_grades before update on public.exam_grades
  for each row execute function public.check_delete_exams();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'exams'
  ) then
    execute 'alter publication supabase_realtime add table public.exams';
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'exam_groups'
  ) then
    execute 'alter publication supabase_realtime add table public.exam_groups';
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'exam_grades'
  ) then
    execute 'alter publication supabase_realtime add table public.exam_grades';
  end if;
end $$;
