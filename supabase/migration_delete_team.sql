-- supabase/migration_delete_team.sql
--
-- إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على السيرفر —
-- شغّل السكريبت ده لوحده في SQL Editor بتاع Supabase (مينفعش تعيد
-- تشغيل team_schema.sql كامل تاني، لأن فيه create policy مش idempotent
-- وهيفشل على تكرار). نفس الدالة اتضافت في team_schema.sql كمان
-- (لو حد طبّق السكيما من الأول بعد التاريخ ده مش محتاج يشغّل الملف ده).
--
-- الغرض: تفعيل زر "تعطيل وضع الفريق" عند المدرس (owner) عشان يحذف
-- الفريق فعليًا من السيرفر (مش بس محليًا على جهازه) — فأجهزة
-- المساعدين تكتشف إنها اتقفلت وتتوقف عن عرض بيانات المدرس.

create or replace function public.delete_team(_team_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.teams where id = _team_id and owner_id = auth.uid();
end;
$$;
