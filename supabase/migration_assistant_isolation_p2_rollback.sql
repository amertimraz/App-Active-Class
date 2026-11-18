-- supabase/migration_assistant_isolation_p2_rollback.sql
--
-- spec 058 / P2 — رجوع فوري لسياسات RLS الأصلية (قبل العزل) على الجداول الـ17 المتزامنة.
-- مولَّد من pg_policies الإنتاج بتاريخ 2026-11-18: كل جدول ليه 3 سياسات (select/insert/update)
-- بنفس الشرط `is_team_member(team_id) AND is_team_license_active(team_id)`. اتحفظ هنا عشان لو
-- migration P2 عملت مشكلة نرجّع الوضع القديم بأمر واحد من غير ما نخمّن.
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_assistant_isolation_p2_rollback.sql

begin;

drop policy if exists attendance_select on public.attendance;
drop policy if exists attendance_insert on public.attendance;
drop policy if exists attendance_update on public.attendance;
create policy attendance_select on public.attendance for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy attendance_insert on public.attendance for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy attendance_update on public.attendance for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists bank_questions_select on public.bank_questions;
drop policy if exists bank_questions_insert on public.bank_questions;
drop policy if exists bank_questions_update on public.bank_questions;
create policy bank_questions_select on public.bank_questions for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy bank_questions_insert on public.bank_questions for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy bank_questions_update on public.bank_questions for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists booklet_groups_select on public.booklet_groups;
drop policy if exists booklet_groups_insert on public.booklet_groups;
drop policy if exists booklet_groups_update on public.booklet_groups;
create policy booklet_groups_select on public.booklet_groups for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklet_groups_insert on public.booklet_groups for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklet_groups_update on public.booklet_groups for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists booklet_payments_select on public.booklet_payments;
drop policy if exists booklet_payments_insert on public.booklet_payments;
drop policy if exists booklet_payments_update on public.booklet_payments;
create policy booklet_payments_select on public.booklet_payments for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklet_payments_insert on public.booklet_payments for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklet_payments_update on public.booklet_payments for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists booklet_records_select on public.booklet_records;
drop policy if exists booklet_records_insert on public.booklet_records;
drop policy if exists booklet_records_update on public.booklet_records;
create policy booklet_records_select on public.booklet_records for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklet_records_insert on public.booklet_records for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklet_records_update on public.booklet_records for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists booklets_select on public.booklets;
drop policy if exists booklets_insert on public.booklets;
drop policy if exists booklets_update on public.booklets;
create policy booklets_select on public.booklets for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklets_insert on public.booklets for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy booklets_update on public.booklets for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists exam_grades_select on public.exam_grades;
drop policy if exists exam_grades_insert on public.exam_grades;
drop policy if exists exam_grades_update on public.exam_grades;
create policy exam_grades_select on public.exam_grades for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_grades_insert on public.exam_grades for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_grades_update on public.exam_grades for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists exam_groups_select on public.exam_groups;
drop policy if exists exam_groups_insert on public.exam_groups;
drop policy if exists exam_groups_update on public.exam_groups;
create policy exam_groups_select on public.exam_groups for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_groups_insert on public.exam_groups for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_groups_update on public.exam_groups for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists exam_questions_select on public.exam_questions;
drop policy if exists exam_questions_insert on public.exam_questions;
drop policy if exists exam_questions_update on public.exam_questions;
create policy exam_questions_select on public.exam_questions for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_questions_insert on public.exam_questions for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_questions_update on public.exam_questions for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists exam_submissions_select on public.exam_submissions;
drop policy if exists exam_submissions_insert on public.exam_submissions;
drop policy if exists exam_submissions_update on public.exam_submissions;
create policy exam_submissions_select on public.exam_submissions for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_submissions_insert on public.exam_submissions for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exam_submissions_update on public.exam_submissions for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists exams_select on public.exams;
drop policy if exists exams_insert on public.exams;
drop policy if exists exams_update on public.exams;
create policy exams_select on public.exams for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exams_insert on public.exams for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy exams_update on public.exams for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists groups_select on public.groups;
drop policy if exists groups_insert on public.groups;
drop policy if exists groups_update on public.groups;
create policy groups_select on public.groups for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy groups_insert on public.groups for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy groups_update on public.groups for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists homework_select on public.homework;
drop policy if exists homework_insert on public.homework;
drop policy if exists homework_update on public.homework;
create policy homework_select on public.homework for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy homework_insert on public.homework for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy homework_update on public.homework for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists payments_select on public.payments;
drop policy if exists payments_insert on public.payments;
drop policy if exists payments_update on public.payments;
create policy payments_select on public.payments for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy payments_insert on public.payments for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy payments_update on public.payments for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists session_overrides_select on public.session_overrides;
drop policy if exists session_overrides_insert on public.session_overrides;
drop policy if exists session_overrides_update on public.session_overrides;
create policy session_overrides_select on public.session_overrides for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy session_overrides_insert on public.session_overrides for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy session_overrides_update on public.session_overrides for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists student_archive_events_select on public.student_archive_events;
drop policy if exists student_archive_events_insert on public.student_archive_events;
drop policy if exists student_archive_events_update on public.student_archive_events;
create policy student_archive_events_select on public.student_archive_events for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy student_archive_events_insert on public.student_archive_events for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy student_archive_events_update on public.student_archive_events for update using (is_team_member(team_id) AND is_team_license_active(team_id));

drop policy if exists students_select on public.students;
drop policy if exists students_insert on public.students;
drop policy if exists students_update on public.students;
create policy students_select on public.students for select using (is_team_member(team_id) AND is_team_license_active(team_id));
create policy students_insert on public.students for insert with check (is_team_member(team_id) AND is_team_license_active(team_id));
create policy students_update on public.students for update using (is_team_member(team_id) AND is_team_license_active(team_id));

commit;
notify pgrst, 'reload schema';
