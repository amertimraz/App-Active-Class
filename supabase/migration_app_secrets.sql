-- supabase/migration_app_secrets.sql
--
-- مفاتيح الخدمات الخارجية (Groq/Claude/واتساب…) بتتحط من لوحة الأدمن بدل ما
-- تتكتب بالإيد على السيرفر. الجدول مقفول بـ RLS بلا أي policy: التطبيق
-- (anon/authenticated) مايقدرش يقرا ولا يكتب. الـ workers بتقرا مباشرة
-- بصلاحية السيرفر، ولوحة الأدمن بتتعامل بالدوال بس (service_role) —
-- والقيمة ما بترجعش للوحة أبدًا، بترجع آخر 4 أحرف كتلميح. idempotent:
--   docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres \
--     < supabase/migration_app_secrets.sql

create table if not exists public.app_secrets (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
alter table public.app_secrets enable row level security;
revoke all on public.app_secrets from public, anon, authenticated;

-- المفاتيح المسموحة بس (غير كده يترفض).
create or replace function public.app_secret_allowed(_key text)
returns boolean language sql immutable as $$
  select _key = any (array[
    'GROQ_API_KEY', 'ANTHROPIC_API_KEY',
    'WA_TOKEN', 'WA_PHONE_NUMBER_ID', 'WA_APP_SECRET', 'WA_VERIFY_TOKEN'
  ]);
$$;

-- الحالة: اسم المفتاح + آخر 4 أحرف + وقت التحديث (مش القيمة).
create or replace function public.app_secrets_status()
returns table (key text, hint text, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select s.key, right(s.value, 4), s.updated_at from public.app_secrets s order by s.key;
$$;

-- حفظ/تحديث مفتاح (قيمة فاضية = حذف).
create or replace function public.app_secret_set(_key text, _value text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.app_secret_allowed(_key) then
    raise exception 'unknown secret key';
  end if;
  if _value is null or btrim(_value) = '' then
    delete from public.app_secrets where key = _key;
  else
    insert into public.app_secrets (key, value, updated_at) values (_key, btrim(_value), now())
    on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;
end;
$$;

revoke all on function public.app_secrets_status() from public, anon, authenticated;
revoke all on function public.app_secret_set(text, text) from public, anon, authenticated;
grant execute on function public.app_secrets_status() to service_role;
grant execute on function public.app_secret_set(text, text) to service_role;
