-- supabase/migration_attendance_recitation_max.sql
--
-- التسميع بدرجة عظمى قابلة للضبط (مش لازم 10): عمود recitation_max على
-- attendance (الدرجة العظمى وقت التسجيل؛ NULL = 10 للسجلات القديمة) + توسيع
-- قيد النطاق. idempotent. يُطبَّق بدور مالك الجدول:
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_attendance_recitation_max.sql
-- لازم يتطبّق **قبل** نسخة التطبيق اللي بتبعت الحقل، وإلا مزامنة الحضور تفشل.

alter table public.attendance add column if not exists recitation_max integer;

alter table public.attendance drop constraint if exists attendance_recitation_range;
alter table public.attendance add constraint attendance_recitation_range
  check (
    recitation is null
    or (recitation >= 1
        and recitation <= coalesce(recitation_max, 10)
        and coalesce(recitation_max, 10) between 1 and 100)
  );
