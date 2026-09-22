-- supabase/migration_student_interaction.sql
--
-- spec 040 — عمود تفاعل الطالب (إيموجي بسيط: نشيط/عادي/غير متفاعل) على
-- attendance. مُزامَن عبر الفريق زي status/notes بالضبط. idempotent.
-- يُطبَّق عبر SSH — تحقّق أولاً من الدور المالك لجدول attendance
-- (نفس نمط students المملوك لـ supabase_admin في migration_guardian_whatsapp.sql)
-- قبل التنفيذ، ثم:
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_student_interaction.sql
--
-- trg_set_updated_at على attendance موجود من spec 031. RLS موروثة.

alter table public.attendance add column if not exists interaction text;
