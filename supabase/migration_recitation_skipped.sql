-- supabase/migration_recitation_skipped.sql
--
-- «حضر وما سمّعش»: بيتخزّن على سجل الحضور كـ attendance.recitation = 0 (مع
-- recitation_max زي ما هو). القيمة 0 بتتقرا في كل الشاشات كـ«مفيش درجة» (الدالة
-- recitationGradeOf بترجّع null لأي قيمة < 1)، فمش بتتحسب صفر في المتوسطات والتقارير
-- والشهادات، والنسخ القديمة من التطبيق بتتجاهلها من نفسها.
--
-- القيد القديم كان recitation >= 1، فلو الجهاز بعت 0 كانت المزامنة هتفشل (23514)
-- للصف ده. التعديل: >= 0. لازم يتطبّق **قبل** ما أي جهاز يستخدم الخيار.
--
-- idempotent. بيتطبّق عبر SSH بدور مالك الجدول (supabase_admin):
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_recitation_skipped.sql

alter table public.attendance drop constraint if exists attendance_recitation_range;
alter table public.attendance add constraint attendance_recitation_range
  check (
    recitation is null
    or (recitation >= 0
        and recitation <= coalesce(recitation_max, 10)
        and coalesce(recitation_max, 10) between 1 and 100)
  ) not valid;
-- not valid + validate: قفل أقصر على جدول كبير (الصفوف الحالية كلها أصلًا 1..max).
alter table public.attendance validate constraint attendance_recitation_range;
