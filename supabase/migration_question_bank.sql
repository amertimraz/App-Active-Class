-- supabase/migration_question_bank.sql
--
-- إضافة فوق migration_exams.sql — شغّله مرة واحدة. idempotent (create
-- if not exists / do-block). يُطبَّق عبر SSH لحاوية قاعدة البيانات على
-- الـVPS (مش لوحة تحكم Supabase):
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_question_bank.sql
--
-- ⚠️ ميزة بنك الأسئلة (spec 025) معطّلة وظيفيًا حتى تشغيل الملف ده —
-- لكن **مش هتكسر** مزامنة الواجب/الحضور/الدرجات لو ماتشغّلش: bank_questions
-- على قناة Realtime منفصلة (team-<id>-x) زي exam_questions/exam_submissions.
--
-- جدول واحد: bank_questions — أسئلة قابلة لإعادة الاستخدام، مستقلة عن أي
-- امتحان. بتحمل الإجابة الصحيحة/الدرجة/الشرح (مقبول داخل تخزين الفريق زي
-- exam_grades/exam_questions، مش زي مستند الطالب العام على Firestore).

create table if not exists public.bank_questions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  type text not null,
  text text not null,
  options text,
  correct_index integer not null default 0,
  points double precision not null default 1,
  image_url text,
  explanation text,
  subject text not null default '',
  tags text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.bank_questions enable row level security;

drop policy if exists "bank_questions_select" on public.bank_questions;
drop policy if exists "bank_questions_insert" on public.bank_questions;
drop policy if exists "bank_questions_update" on public.bank_questions;
create policy "bank_questions_select" on public.bank_questions for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "bank_questions_insert" on public.bank_questions for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "bank_questions_update" on public.bank_questions for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- لا DELETE policy عمدًا — الحذف soft (تحديث deleted_at). يعيد استخدام
-- نفس صلاحية حذف سجلات الامتحان (check_delete_exams، delete_attendance).
drop trigger if exists trg_check_delete_bank_questions on public.bank_questions;
create trigger trg_check_delete_bank_questions before update on public.bank_questions
  for each row execute function public.check_delete_exams();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'bank_questions'
  ) then
    execute 'alter publication supabase_realtime add table public.bank_questions';
  end if;
end $$;
