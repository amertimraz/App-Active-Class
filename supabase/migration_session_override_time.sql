-- supabase/migration_session_override_time.sql
--
-- spec 032 — عمود ميعاد الحصة التعويضية/الإضافية (HH:mm، اختياري) على
-- session_overrides. idempotent. جدول session_overrides مملوك لـpostgres
-- (أنشأناه في migration_session_overrides.sql) فـ-U postgres كافٍ:
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_session_override_time.sql

alter table public.session_overrides add column if not exists session_time text;
