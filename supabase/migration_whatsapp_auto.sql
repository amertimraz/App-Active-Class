-- supabase/migration_whatsapp_auto.sql
--
-- spec 056 — إرسال واتساب تلقائي. جداول الطلبات/الموافقات/الحصة/الإعدادات.
-- التطبيق (جهاز المالك فقط) بيكتب طلبات في wa_outbox، وخدمة wa-worker
-- (بتتصل كـ service/superuser) هي الوحيدة اللي بتغيّر الحالة وتخصم الحصة.
-- المفتاح owner_id = auth.uid() (المدرس صاحب الحساب) مش team_id، لأن مش كل
-- مدرس عنده فريق. idempotent — شغّله مرة واحدة بعد الموافقة:
--   docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres \
--     < supabase/migration_whatsapp_auto.sql

-- ───── إعدادات عامة (يكتبها الأدمن/الـ service فقط) ─────
create table if not exists public.wa_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
insert into public.wa_config (key, value) values
  ('default_free_limit', '100'),
  ('rate_per_min', '30'),
  ('send_from_hour', '8'),
  ('send_to_hour', '22'),
  ('kill_switch', 'false')
on conflict (key) do nothing;

-- ───── إعدادات المدرس ─────
create table if not exists public.wa_teacher_settings (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  kinds jsonb not null default '{"absence":true,"late_payment":true,"receipt":true}',
  paused_by_admin boolean not null default false,
  free_limit_override integer,
  updated_at timestamptz not null default now()
);

-- ───── الموافقات ─────
create table if not exists public.wa_consents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  student_local_id integer not null,
  phone text not null,
  status text not null default 'granted' check (status in ('granted','stopped')),
  granted_at timestamptz not null default now(),
  granted_by text,
  stopped_at timestamptz,
  unique (owner_id, student_local_id, phone)
);
create index if not exists wa_consents_phone_idx on public.wa_consents (phone);

-- ───── طلبات/سجل الرسايل ─────
create table if not exists public.wa_outbox (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  student_local_id integer not null,
  student_name text,
  to_phone text not null,
  kind text not null check (kind in ('absence','late_payment','receipt','test')),
  vars jsonb not null default '{}',
  dedupe_key text not null unique,
  status text not null default 'pending'
    check (status in ('pending','sending','sent','delivered','read','failed','blocked')),
  fail_reason text,
  attempts integer not null default 0,
  not_before timestamptz not null default now(),
  provider_msg_id text,
  charged boolean not null default false,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz
);
create index if not exists wa_outbox_pending_idx on public.wa_outbox (not_before) where status = 'pending';
create index if not exists wa_outbox_owner_idx on public.wa_outbox (owner_id, created_at desc);
create index if not exists wa_outbox_provider_idx on public.wa_outbox (provider_msg_id);

-- ───── الحصة والرصيد (شهريًا) ─────
create table if not exists public.wa_quota (
  owner_id uuid not null references auth.users(id) on delete cascade,
  month date not null,
  free_limit integer not null,
  used integer not null default 0,
  extra_balance integer not null default 0,
  primary key (owner_id, month)
);

-- ───── خصم الحصة ذريًا: بيرجّع 'free' أو 'extra' أو null (نفدت) ─────
create or replace function public.wa_reserve_quota(_owner uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
  _default integer;
  _limit integer;
begin
  select (value)::text::integer into _default from public.wa_config where key = 'default_free_limit';
  select coalesce(
    (select free_limit_override from public.wa_teacher_settings where owner_id = _owner),
    _default, 100) into _limit;

  insert into public.wa_quota (owner_id, month, free_limit)
  values (_owner, _month, _limit)
  on conflict (owner_id, month) do nothing;

  update public.wa_quota set used = used + 1
   where owner_id = _owner and month = _month and used < free_limit;
  if found then return 'free'; end if;

  update public.wa_quota set extra_balance = extra_balance - 1
   where owner_id = _owner and month = _month and extra_balance > 0;
  if found then return 'extra'; end if;

  return null;
end;
$$;

-- رد الخصم لو الرسالة فشلت ولم تُحاسَب: _kind = ناتج wa_reserve_quota
create or replace function public.wa_release_quota(_owner uuid, _kind text)
returns void language plpgsql security definer set search_path = public as $$
declare _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
begin
  if _kind = 'free' then
    update public.wa_quota set used = greatest(used - 1, 0)
     where owner_id = _owner and month = _month;
  elsif _kind = 'extra' then
    update public.wa_quota set extra_balance = extra_balance + 1
     where owner_id = _owner and month = _month;
  end if;
end;
$$;

-- الدوال دي للـ service فقط
revoke all on function public.wa_reserve_quota(uuid) from public, anon, authenticated;
revoke all on function public.wa_release_quota(uuid, text) from public, anon, authenticated;

-- ───── RLS ─────
alter table public.wa_config enable row level security;
alter table public.wa_teacher_settings enable row level security;
alter table public.wa_consents enable row level security;
alter table public.wa_outbox enable row level security;
alter table public.wa_quota enable row level security;

-- المدرس يقرأ الإعدادات العامة (للحصة والتحذيرات) — الكتابة للـ service فقط
drop policy if exists wa_config_select on public.wa_config;
create policy wa_config_select on public.wa_config for select to authenticated using (true);

drop policy if exists wa_teacher_settings_select on public.wa_teacher_settings;
create policy wa_teacher_settings_select on public.wa_teacher_settings for select
  using (owner_id = auth.uid());
drop policy if exists wa_teacher_settings_insert on public.wa_teacher_settings;
create policy wa_teacher_settings_insert on public.wa_teacher_settings for insert
  with check (owner_id = auth.uid() and paused_by_admin = false and free_limit_override is null);
drop policy if exists wa_teacher_settings_update on public.wa_teacher_settings;
create policy wa_teacher_settings_update on public.wa_teacher_settings for update
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- الموافقات: المدرس يقرأ ويضيف/يعدّل بتاعته (الإيقاف بيجي من الـ service)
drop policy if exists wa_consents_select on public.wa_consents;
create policy wa_consents_select on public.wa_consents for select using (owner_id = auth.uid());
drop policy if exists wa_consents_insert on public.wa_consents;
create policy wa_consents_insert on public.wa_consents for insert
  with check (owner_id = auth.uid() and status = 'granted');

-- الطلبات: المدرس يقرأ ويضيف بتاعته، وبس يلغي pending → blocked
drop policy if exists wa_outbox_select on public.wa_outbox;
create policy wa_outbox_select on public.wa_outbox for select using (owner_id = auth.uid());
drop policy if exists wa_outbox_insert on public.wa_outbox;
create policy wa_outbox_insert on public.wa_outbox for insert
  with check (owner_id = auth.uid() and status = 'pending' and attempts = 0 and charged = false);
drop policy if exists wa_outbox_update on public.wa_outbox;
create policy wa_outbox_update on public.wa_outbox for update
  using (owner_id = auth.uid() and status = 'pending')
  with check (owner_id = auth.uid() and status = 'blocked' and fail_reason = 'cancelled');

-- الحصة: قراءة فقط
drop policy if exists wa_quota_select on public.wa_quota;
create policy wa_quota_select on public.wa_quota for select using (owner_id = auth.uid());

-- ───── تنظيف السجل بعد 90 يوم (يُستدعى من الـ worker يوميًا) ─────
create or replace function public.wa_purge_old()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  delete from public.wa_outbox where created_at < now() - interval '90 days';
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.wa_purge_old() from public, anon, authenticated;
