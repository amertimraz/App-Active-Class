-- supabase/migration_online_exam_sync.sql
--
-- إضافة فوق migration_exams.sql (المفروض متطبّق على السيرفر) — شغّله
-- لوحده مرة واحدة على SQL Editor في لوحة Supabase، **قبل** توزيع نسخة
-- التطبيق اللي فيها مزامنة الامتحانات الإلكترونية (spec 024). آمن للتشغيل
-- أكتر من مرة (كله create if not exists / add column if not exists /
-- create or replace / do-block idempotent).
--
-- الترتيب: بعد team_schema.sql و migration_exams.sql. مستقل عن
-- migration_homework.sql و migration_student_follow_ups.sql.
--
-- ⚠️ الميزة (المساعد يشوف/يصحّح امتحانات إلكترونية عملها المدرس) معطّلة
-- وظيفيًا حتى تشغيل الملف ده — لكن **مش هتكسر** مزامنة الواجب/الحضور/
-- الدرجات لو ماتشغّلش: أسئلة/تسليمات الامتحان الإلكتروني على قناة
-- Realtime منفصلة (team-<id>-x)، فشلها معزول عن القناة الأساسية.
--
-- بيضيف:
--   1. exam_questions (أسئلة الامتحان — بتحمل الإجابة الصحيحة/الدرجة/
--      الشرح؛ مقبول داخل تخزين الفريق زي exam_grades، مش زي مستند
--      الطالب العام على Firestore اللي بيفضل بلا مفاتيح تصحيح).
--   2. exam_submissions (تسليمات الطلاب + حالتها: pending/approved/
--      not_submitted/voided).
--   3. أعمدة أونلاين على exams الموجود (is_online, online_status,
--      opens_at, closes_at, duration_minutes) — عشان المساعد يشوف
--      الامتحان كـ"أونلاين" أصلاً بحالته وميعاده.
--   4. RLS (is_team_member + is_team_license_active)، soft-delete
--      trigger (صلاحية delete_attendance)، وإضافة للـsupabase_realtime.

-- ── 1) exam_questions ────────────────────────────────────────────────
create table if not exists public.exam_questions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  exam_remote_id uuid references public.exams(id) on delete cascade,
  position integer not null default 0,
  type text not null,
  text text not null,
  options text,
  correct_index integer not null default 0,
  points double precision not null default 1,
  image_url text,
  explanation text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

-- ── 2) exam_submissions ─────────────────────────────────────────────
create table if not exists public.exam_submissions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  exam_remote_id uuid references public.exams(id) on delete cascade,
  student_remote_id uuid references public.students(id) on delete cascade,
  started_at text,
  submitted_at text,
  answers_json text,
  auto_score double precision,
  final_grade double precision,
  status text not null default 'pending',
  auto_submitted boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

-- ── 3) أعمدة أونلاين على exams ──────────────────────────────────────
alter table public.exams add column if not exists is_online boolean not null default false;
alter table public.exams add column if not exists online_status text;
alter table public.exams add column if not exists opens_at text;
alter table public.exams add column if not exists closes_at text;
alter table public.exams add column if not exists duration_minutes integer;

-- ── 4) RLS ─────────────────────────────────────────────────────────
alter table public.exam_questions enable row level security;
alter table public.exam_submissions enable row level security;

drop policy if exists "exam_questions_select" on public.exam_questions;
drop policy if exists "exam_questions_insert" on public.exam_questions;
drop policy if exists "exam_questions_update" on public.exam_questions;
create policy "exam_questions_select" on public.exam_questions for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_questions_insert" on public.exam_questions for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_questions_update" on public.exam_questions for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

drop policy if exists "exam_submissions_select" on public.exam_submissions;
drop policy if exists "exam_submissions_insert" on public.exam_submissions;
drop policy if exists "exam_submissions_update" on public.exam_submissions;
create policy "exam_submissions_select" on public.exam_submissions for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_submissions_insert" on public.exam_submissions for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "exam_submissions_update" on public.exam_submissions for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- ── soft-delete trigger (نفس صلاحية migration_exams.sql) ────────────
-- لا DELETE policy عمدًا — الحذف soft (تحديث deleted_at) بس.
drop trigger if exists trg_check_delete_exam_questions on public.exam_questions;
create trigger trg_check_delete_exam_questions before update on public.exam_questions
  for each row execute function public.check_delete_exams();
drop trigger if exists trg_check_delete_exam_submissions on public.exam_submissions;
create trigger trg_check_delete_exam_submissions before update on public.exam_submissions
  for each row execute function public.check_delete_exams();

-- ── إضافة للـsupabase_realtime publication ─────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'exam_questions'
  ) then
    execute 'alter publication supabase_realtime add table public.exam_questions';
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'exam_submissions'
  ) then
    execute 'alter publication supabase_realtime add table public.exam_submissions';
  end if;
end $$;
