-- supabase/migration_exam_question_images.sql
--
-- spec 043 — صورة شرح + صور اختيارات للسؤال (امتحان إلكتروني وبنك أسئلة).
-- إضافة أعمدة فقط فوق exam_questions (migration_online_exam_sync.sql) و
-- bank_questions (migration_question_bank.sql) — idempotent، بلا تغيير
-- RLS أو triggers الحاليين (الأعمدة الجديدة تتبع صلاحيات الصف القائمة).
-- يُطبَّق عبر SSH:
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_exam_question_images.sql
--
-- (تأكد الأول من مالك الجدولين — نفس مستخدم الإنشاء الأصلي لكل جدول.)

alter table public.exam_questions
  add column if not exists explanation_image_url text,
  add column if not exists option_image_urls text;

alter table public.bank_questions
  add column if not exists explanation_image_url text,
  add column if not exists option_image_urls text;
