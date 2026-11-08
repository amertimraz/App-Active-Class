-- تاريخ سريان سعر الإخوة: الشهور قبله بالسعر الفردي، وبعده بسعر الإخوة.
-- null = على كل الشهور (السلوك القديم). عمود نصي عادي بيتزامن زي siblings_total.
alter table public.students add column if not exists siblings_from text;

notify pgrst, 'reload schema';
