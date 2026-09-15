-- UUID ثابت مشترك بين أعضاء مجموعة الإخوة (2-3) — بديل sibling_group_id
-- المحلي (رقم = أصغر id محلي، بلا معنى عبر الأجهزة). العمود ده مجرد
-- تاج نصي بيتزامن زي أي حقل عادي، بلا أي ترجمة remote_id (مش مفتاح
-- أجنبي لصف تاني، مجرد قيمة مشتركة بين الإخوة).
alter table public.students add column if not exists sibling_group_uuid text;

notify pgrst, 'reload schema';
