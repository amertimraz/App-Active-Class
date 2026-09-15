-- spec 035 — عدد أعضاء مجموعة الإخوة وقت آخر قرار واعي (ربط أولي، أو
-- تأكيد/تعديل بعد خروج عضو). عمود عادي بيتزامن كتاج نصي/رقمي، بلا أي
-- ترجمة remote_id (زي siblings_total بالظبط).
alter table public.students add column if not exists sibling_group_committed_count integer;

notify pgrst, 'reload schema';
