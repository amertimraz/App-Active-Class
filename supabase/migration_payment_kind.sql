-- نوع الدفعة (collection / write_off). الصفوف القديمة بتتحدد من الملاحظة.
alter table public.payments add column if not exists kind text;
update public.payments set kind = 'write_off'
  where kind is null and note = 'إسقاط مديونية';
