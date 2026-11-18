-- supabase/migration_assistant_isolation_p2.sql
--
-- spec 058 / P2 — سياسات RLS للعزل. **بتغيّر سلوك السيرفر**: بعدها المساعد المقيَّد
-- (team_members.groups_restricted = true) بيشوف ويكتب على مجموعاته/سناتره بس.
-- المالك والمساعد غير المقيَّد (كل الأعضاء الحاليين) مفيش أي تغيير لهم.
--
-- شروط قبل التشغيل:
--   1) P1 مطبّق (migration_assistant_isolation_p1.sql).
--   2) الـbackfill اتشغّل (migration_assistant_isolation_p1_backfill.sql) — وإلا صفوف
--      الطلاب القديمة ما تظهرش للمساعد المقيَّد (المالك مش متأثر).
--   3) نسخة احتياطية من القاعدة.
-- رجوع فوري: migration_assistant_isolation_p2_rollback.sql
--
-- قرارات المستخدم (2026-11-18): المساعد المقيَّد ينشئ امتحانات/ملازم (created_by)،
-- بنك الأسئلة مشترك (bank_questions ما بنلمسوش)، مساعد مقيَّد بلا منح ممنوع يدخل
-- برسالة (التطبيق بيقرا my_team_access).
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_assistant_isolation_p2.sql

begin;

-- ── ١) دوال المجموعات (بتتحسب مرة لكل استعلام: IN (select f())) ───────────────
create or replace function public.my_full_access_teams() returns setof uuid
language sql stable security definer set search_path = public as $$
  select t.id from public.teams t where t.owner_id = auth.uid()
  union
  select m.team_id from public.team_members m
   where m.user_id = auth.uid() and not m.groups_restricted
$$;

create or replace function public.my_visible_groups() returns setof uuid
language sql stable security definer set search_path = public as $$
  select g.group_remote_id from public.team_member_groups g where g.user_id = auth.uid()
  union
  select gr.id from public.team_member_centers c
    join public.groups gr on gr.team_id = c.team_id
     and public.normalize_center(gr.center) = c.center
   where c.user_id = auth.uid() and gr.deleted_at is null
$$;

-- ── ٢) المنشئ على الامتحانات والملازم (من غير rewrite: default بعد الإضافة) ─────
alter table public.exams    add column if not exists created_by uuid;
alter table public.booklets add column if not exists created_by uuid;
alter table public.exams    alter column created_by set default auth.uid();
alter table public.booklets alter column created_by set default auth.uid();

create or replace function public.my_visible_exams() returns setof uuid
language sql stable security definer set search_path = public as $$
  select e.id from public.exams e where e.created_by = auth.uid()
  union
  select eg.exam_remote_id from public.exam_groups eg
   where eg.group_remote_id in (select public.my_visible_groups())
$$;

create or replace function public.my_visible_booklets() returns setof uuid
language sql stable security definer set search_path = public as $$
  select b.id from public.booklets b where b.created_by = auth.uid()
  union
  select bg.booklet_remote_id from public.booklet_groups bg
   where bg.group_remote_id in (select public.my_visible_groups())
$$;

grant execute on function public.my_full_access_teams(), public.my_visible_groups(),
  public.my_visible_exams(), public.my_visible_booklets() to authenticated;

-- ── ٣) student_archive_events: group_remote_id مكرَّر زي باقي صفوف الطالب ────────
alter table public.student_archive_events add column if not exists group_remote_id uuid;
create index if not exists student_archive_events_group_idx
  on public.student_archive_events (team_id, group_remote_id);
drop trigger if exists trg_fill_group on public.student_archive_events;
create trigger trg_fill_group before insert or update of student_remote_id
  on public.student_archive_events for each row execute function public.fill_group_from_student();

-- backfill للجدول ده بس (صغير): من غير تغيير updated_at.
alter table public.student_archive_events disable trigger trg_set_updated_at;
update public.student_archive_events t set group_remote_id = s.group_remote_id
  from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
alter table public.student_archive_events enable trigger trg_set_updated_at;

-- نقل طالب لمجموعة تانية يحدّث الجدول ده كمان.
create or replace function public.propagate_student_group()
returns trigger language plpgsql as $fn$
begin
  if new.group_remote_id is distinct from old.group_remote_id then
    update public.attendance             set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.payments               set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.homework               set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.exam_grades            set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.exam_submissions       set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.booklet_records        set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.booklet_payments       set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.student_archive_events set group_remote_id = new.group_remote_id where student_remote_id = new.id;
  end if;
  return new;
end;
$fn$;

-- ── ٤) حارس: المالك بس يغيّر groups_restricted (وإلا مساعد عنده manage_members يفكّ قيد نفسه) ──
-- الأدوار اللي بتجي من التطبيق (authenticated) بس بتتفحص؛ أدمن قاعدة البيانات مش متأثر.
create or replace function public.guard_groups_restricted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.groups_restricted is distinct from old.groups_restricted
     and not public.is_team_owner(new.team_id)
     and current_setting('role', true) in ('authenticated', 'anon') then
    raise exception 'only the team owner can change groups_restricted';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_guard_groups_restricted on public.team_members;
create trigger trg_guard_groups_restricted before update of groups_restricted
  on public.team_members for each row execute function public.guard_groups_restricted();

-- ── ٥) ملخّص وصول المستخدم الحالي (التطبيق بيستخدمه لرسالة «لسه ما حدّدش لك مجموعات») ──
create or replace function public.my_team_access(_team_id uuid)
returns table (is_owner boolean, restricted boolean, visible_groups integer)
language sql stable security definer set search_path = public as $$
  select public.is_team_owner(_team_id),
         coalesce((select m.groups_restricted from public.team_members m
                    where m.team_id = _team_id and m.user_id = auth.uid()), false),
         (select count(*)::int from public.groups g
           where g.team_id = _team_id and g.deleted_at is null
             and g.id in (select public.my_visible_groups()))
$$;
grant execute on function public.my_team_access(uuid) to authenticated;

-- ── ٦) السياسات ─────────────────────────────────────────────────────────────

-- ── groups: المساعد المقيَّد يشوف ويعدّل مجموعاته بس، ومينشئش مجموعة جديدة ──
drop policy if exists groups_select on public.groups;
drop policy if exists groups_insert on public.groups;
drop policy if exists groups_update on public.groups;
create policy groups_select on public.groups for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or id in (select public.my_visible_groups())));
create policy groups_insert on public.groups for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or id in (select public.my_visible_groups())));
create policy groups_update on public.groups for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or id in (select public.my_visible_groups())));

-- ── الطلاب وكل صفوفهم (group_remote_id مكرَّر بالـtrigger) ──
drop policy if exists students_select on public.students;
drop policy if exists students_insert on public.students;
drop policy if exists students_update on public.students;
create policy students_select on public.students for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy students_insert on public.students for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy students_update on public.students for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists attendance_select on public.attendance;
drop policy if exists attendance_insert on public.attendance;
drop policy if exists attendance_update on public.attendance;
create policy attendance_select on public.attendance for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy attendance_insert on public.attendance for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy attendance_update on public.attendance for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists payments_select on public.payments;
drop policy if exists payments_insert on public.payments;
drop policy if exists payments_update on public.payments;
create policy payments_select on public.payments for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy payments_insert on public.payments for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy payments_update on public.payments for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists homework_select on public.homework;
drop policy if exists homework_insert on public.homework;
drop policy if exists homework_update on public.homework;
create policy homework_select on public.homework for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy homework_insert on public.homework for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy homework_update on public.homework for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists exam_grades_select on public.exam_grades;
drop policy if exists exam_grades_insert on public.exam_grades;
drop policy if exists exam_grades_update on public.exam_grades;
create policy exam_grades_select on public.exam_grades for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy exam_grades_insert on public.exam_grades for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy exam_grades_update on public.exam_grades for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists exam_submissions_select on public.exam_submissions;
drop policy if exists exam_submissions_insert on public.exam_submissions;
drop policy if exists exam_submissions_update on public.exam_submissions;
create policy exam_submissions_select on public.exam_submissions for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy exam_submissions_insert on public.exam_submissions for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy exam_submissions_update on public.exam_submissions for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists booklet_records_select on public.booklet_records;
drop policy if exists booklet_records_insert on public.booklet_records;
drop policy if exists booklet_records_update on public.booklet_records;
create policy booklet_records_select on public.booklet_records for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy booklet_records_insert on public.booklet_records for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy booklet_records_update on public.booklet_records for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists booklet_payments_select on public.booklet_payments;
drop policy if exists booklet_payments_insert on public.booklet_payments;
drop policy if exists booklet_payments_update on public.booklet_payments;
create policy booklet_payments_select on public.booklet_payments for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy booklet_payments_insert on public.booklet_payments for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy booklet_payments_update on public.booklet_payments for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists student_archive_events_select on public.student_archive_events;
drop policy if exists student_archive_events_insert on public.student_archive_events;
drop policy if exists student_archive_events_update on public.student_archive_events;
create policy student_archive_events_select on public.student_archive_events for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy student_archive_events_insert on public.student_archive_events for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy student_archive_events_update on public.student_archive_events for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

-- ── جداول مرتبطة بمجموعة مباشرة ──
drop policy if exists session_overrides_select on public.session_overrides;
drop policy if exists session_overrides_insert on public.session_overrides;
drop policy if exists session_overrides_update on public.session_overrides;
create policy session_overrides_select on public.session_overrides for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy session_overrides_insert on public.session_overrides for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy session_overrides_update on public.session_overrides for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists exam_groups_select on public.exam_groups;
drop policy if exists exam_groups_insert on public.exam_groups;
drop policy if exists exam_groups_update on public.exam_groups;
create policy exam_groups_select on public.exam_groups for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy exam_groups_insert on public.exam_groups for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy exam_groups_update on public.exam_groups for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

drop policy if exists booklet_groups_select on public.booklet_groups;
drop policy if exists booklet_groups_insert on public.booklet_groups;
drop policy if exists booklet_groups_update on public.booklet_groups;
create policy booklet_groups_select on public.booklet_groups for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy booklet_groups_insert on public.booklet_groups for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));
create policy booklet_groups_update on public.booklet_groups for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or group_remote_id in (select public.my_visible_groups())));

-- ── الامتحانات والملازم: مرئية لو مرتبطة بمجموعة مسموحة، أو لو المساعد هو منشئها ──
drop policy if exists exams_select on public.exams;
drop policy if exists exams_insert on public.exams;
drop policy if exists exams_update on public.exams;
create policy exams_select on public.exams for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or created_by = auth.uid() or id in (select public.my_visible_exams())));
create policy exams_insert on public.exams for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or created_by = auth.uid()));
create policy exams_update on public.exams for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or created_by = auth.uid() or id in (select public.my_visible_exams())));

drop policy if exists booklets_select on public.booklets;
drop policy if exists booklets_insert on public.booklets;
drop policy if exists booklets_update on public.booklets;
create policy booklets_select on public.booklets for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or created_by = auth.uid() or id in (select public.my_visible_booklets())));
create policy booklets_insert on public.booklets for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or created_by = auth.uid()));
create policy booklets_update on public.booklets for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or created_by = auth.uid() or id in (select public.my_visible_booklets())));

drop policy if exists exam_questions_select on public.exam_questions;
drop policy if exists exam_questions_insert on public.exam_questions;
drop policy if exists exam_questions_update on public.exam_questions;
create policy exam_questions_select on public.exam_questions for select
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or exam_remote_id in (select public.my_visible_exams())));
create policy exam_questions_insert on public.exam_questions for insert
  with check (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or exam_remote_id in (select public.my_visible_exams())));
create policy exam_questions_update on public.exam_questions for update
  using (public.is_team_license_active(team_id) and (team_id in (select public.my_full_access_teams()) or exam_remote_id in (select public.my_visible_exams())));

commit;

notify pgrst, 'reload schema';
