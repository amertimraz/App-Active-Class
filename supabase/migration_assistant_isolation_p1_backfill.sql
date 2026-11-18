-- supabase/migration_assistant_isolation_p1_backfill.sql
--
-- spec 058 — يملا group_remote_id على الصفوف القديمة (بعد migration_assistant_isolation_p1.sql
-- وقبل P2). بيتشغّل **مرة واحدة في وقت هادي**:
--   • بنفصل الجداول من نشر Realtime طول الـtransaction (وإلا آلاف أحداث UPDATE تتبعت لكل
--     الأجهزة المتصلة)، وبنوقف trg_set_updated_at (وإلا updated_at يتغيّر فكل الأجهزة تسحب
--     الصفوف كلها تاني). الأجهزة بتسحب دوريًا فمفيش حاجة بتضيع.
--   • بيحوّل بس الصفوف اللي القيمة فيها ناقصة/غلط، فتشغيله تاني آمن (idempotent).
--   • بياخد قفل قصير على كل جدول؛ شغّله وقت قليل الاستخدام.
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_assistant_isolation_p1_backfill.sql

begin;

alter publication supabase_realtime drop table
  public.attendance, public.payments, public.homework, public.exam_grades,
  public.exam_submissions, public.booklet_records, public.booklet_payments;

alter table public.attendance        disable trigger trg_set_updated_at;
alter table public.payments          disable trigger trg_set_updated_at;
alter table public.homework          disable trigger trg_set_updated_at;
alter table public.exam_grades       disable trigger trg_set_updated_at;
alter table public.exam_submissions  disable trigger trg_set_updated_at;
alter table public.booklet_records   disable trigger trg_set_updated_at;
alter table public.booklet_payments  disable trigger trg_set_updated_at;

update public.attendance t       set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
update public.payments t         set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
update public.homework t         set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
update public.exam_grades t      set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
update public.exam_submissions t set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
update public.booklet_records t  set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;
update public.booklet_payments t set group_remote_id = s.group_remote_id from public.students s
 where s.id = t.student_remote_id and t.group_remote_id is distinct from s.group_remote_id;

alter table public.attendance        enable trigger trg_set_updated_at;
alter table public.payments          enable trigger trg_set_updated_at;
alter table public.homework          enable trigger trg_set_updated_at;
alter table public.exam_grades       enable trigger trg_set_updated_at;
alter table public.exam_submissions  enable trigger trg_set_updated_at;
alter table public.booklet_records   enable trigger trg_set_updated_at;
alter table public.booklet_payments  enable trigger trg_set_updated_at;

alter publication supabase_realtime add table
  public.attendance, public.payments, public.homework, public.exam_grades,
  public.exam_submissions, public.booklet_records, public.booklet_payments;

commit;

-- تحقق: صفوف لسه ناقصة رغم إن طالبها له مجموعة (المفروض 0 لكل جدول).
-- select 'attendance', count(*) from public.attendance a join public.students s on s.id=a.student_remote_id
--  where s.group_remote_id is not null and a.group_remote_id is null;
