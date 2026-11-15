-- supabase/migration_group_center.sql
--
-- السنتر (spec 058، المرحلة أ — تنظيم فقط): اسم نصّي اختياري على المجموعة
-- (groups.center)، مُزامَن عبر الفريق زي whatsapp_link. مفيش أي عزل أو RLS هنا.
--
-- ⚠️ لازم يتطبّق على السيرفر **قبل** إصدار التطبيق اللي فيه الحقل ده: التطبيق
-- بيبعت العمود 'center' مع كل مجموعة، ولو العمود مش موجود هيرفض Supabase الدفع
-- (فريق الفريق وضع الفريق بيوقف مزامنة المجموعات لحد ما يتطبّق).
--
-- آمن لإعادة التشغيل (if not exists).

alter table public.groups add column if not exists center text;
