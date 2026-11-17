-- supabase/migration_recitation_zero.sql
--
-- الصفر بقى درجة تسميع حقيقية، و«حضر وما سمّعش» اتنقل من 0 إلى -1.
-- القيد القديم (>= 0) بيرفض -1، فبنوسّعه لـ >= -1، وبنحوّل أي 0 اتسجّل «ما سمّعش»
-- (من 1.2.89) لـ -1. لازم يتطبّق قبل ما أي جهاز يشتغل بالإصدار الجديد.
-- idempotent. بيتطبّق عبر SSH بدور supabase_admin (زي migration_recitation_skipped.sql).

alter table public.attendance drop constraint if exists attendance_recitation_range;
alter table public.attendance add constraint attendance_recitation_range
  check (
    recitation is null
    or (recitation >= -1
        and recitation <= coalesce(recitation_max, 10)
        and coalesce(recitation_max, 10) between 1 and 100)
  ) not valid;
alter table public.attendance validate constraint attendance_recitation_range;

update public.attendance set recitation = -1 where recitation = 0;
