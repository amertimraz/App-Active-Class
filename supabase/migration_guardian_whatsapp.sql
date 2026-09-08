-- supabase/migration_guardian_whatsapp.sql
--
-- spec 033 — عمود واتساب ولي الأمر (رابط wa.me أو اسم مستخدم) على students.
-- مُزامَن عبر الفريق زي guardian_phone بالضبط. idempotent.
-- يُطبَّق عبر SSH — ⚠️ جدول students مملوك لـ supabase_admin، فلازم -U supabase_admin
-- (مش postgres) لأي ALTER عليه:
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_guardian_whatsapp.sql
--
-- trg_set_updated_at على students موجود من spec 031. RLS موروثة (صفوف الطالب).

alter table public.students add column if not exists guardian_whatsapp text;
