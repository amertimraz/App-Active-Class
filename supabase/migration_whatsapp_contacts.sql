-- supabase/migration_whatsapp_contacts.sql
--
-- رسائل واتساب: رقم الطالب نفسه (students.student_phone) ورابط جروب واتساب
-- المجموعة (groups.whatsapp_link). اختياريان ومُزامَنان عبر الفريق زي
-- guardian_phone/guardian_whatsapp. idempotent.
-- يُطبَّق عبر SSH — ⚠️ الجداول الأساسية مملوكة لـ supabase_admin فلازم
-- -U supabase_admin (مش postgres) لأي ALTER عليها:
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_whatsapp_contacts.sql
--
-- ⚠️ لازم يتطبّق **قبل** تثبيت نسخة التطبيق الجديدة على أي جهاز في فريق،
-- وإلا رفع الطلاب/المجموعات هيفشل (عمود غير موجود).
-- RLS وtrg_set_updated_at موروثين من الجداول.

alter table public.students add column if not exists student_phone text;
alter table public.groups add column if not exists whatsapp_link text;
