-- supabase/migration_ai_exam.sql
--
-- spec 057 — إنشاء امتحان إلكتروني من صورة/ملف بالذكاء الاصطناعي. الجداول
-- بيكتبها خدمة ai-worker (service) والمدرس بيقرا بتاعه بس. الصور مابتتخزنش
-- أبدًا؛ result فيه الأسئلة المستخرجة بس وبيتحذف بعد 24 ساعة. idempotent:
--   docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres \
--     < supabase/migration_ai_exam.sql

-- ───── إعدادات عامة (الأدمن/الـ service فقط يكتب) ─────
create table if not exists public.ai_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
insert into public.ai_config (key, value) values
  ('default_free_limit', '10'),
  ('default_provider', '"groq"'),
  ('fallback_provider', '"claude"'),
  ('groq_model', '"qwen/qwen3.8-27b"'),
  ('claude_model', '"claude-sonnet-5-5"'),
  ('max_images', '10'),
  ('max_bytes', '15728640'),
  ('max_questions', '30'),
  ('concurrency', '3'),
  ('kill_switch', 'false')
on conflict (key) do nothing;

-- ───── إعدادات المدرس (الأدمن فقط) ─────
create table if not exists public.ai_teacher_settings (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  paused_by_admin boolean not null default false,
  free_limit_override integer,
  updated_at timestamptz not null default now()
);

-- ───── الطلبات ─────
create table if not exists public.ai_jobs (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  mode text not null check (mode in ('convert', 'generate')),
  params jsonb not null default '{}',
  status text not null default 'queued'
    check (status in ('queued', 'running', 'done', 'failed', 'rejected')),
  fail_reason text,
  provider text,
  progress jsonb,
  result jsonb,
  charged text check (charged in ('free', 'extra')),
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);
create index if not exists ai_jobs_owner_idx on public.ai_jobs (owner_id, created_at desc);

-- ───── الحصة والرصيد ─────
create table if not exists public.ai_quota (
  owner_id uuid not null references auth.users(id) on delete cascade,
  month date not null,
  free_limit integer not null,
  used integer not null default 0,
  extra_balance integer not null default 0,
  primary key (owner_id, month)
);

-- حجز عملية ذريًا: 'free' / 'extra' / null (نفدت)
create or replace function public.ai_reserve(_owner uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
  _default integer;
  _limit integer;
begin
  select (value)::text::integer into _default from public.ai_config where key = 'default_free_limit';
  select coalesce(
    (select free_limit_override from public.ai_teacher_settings where owner_id = _owner),
    _default, 10) into _limit;

  insert into public.ai_quota (owner_id, month, free_limit)
  values (_owner, _month, _limit)
  on conflict (owner_id, month) do nothing;

  update public.ai_quota set used = used + 1
   where owner_id = _owner and month = _month and used < free_limit;
  if found then return 'free'; end if;

  update public.ai_quota set extra_balance = extra_balance - 1
   where owner_id = _owner and month = _month and extra_balance > 0;
  if found then return 'extra'; end if;

  return null;
end;
$$;

-- رد الحجز عند فشل/رفض (بدون خصم صافي)
create or replace function public.ai_release(_owner uuid, _kind text)
returns void language plpgsql security definer set search_path = public as $$
declare _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
begin
  if _kind = 'free' then
    update public.ai_quota set used = greatest(used - 1, 0) where owner_id = _owner and month = _month;
  elsif _kind = 'extra' then
    update public.ai_quota set extra_balance = extra_balance + 1 where owner_id = _owner and month = _month;
  end if;
end;
$$;

create or replace function public.ai_purge_old()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update public.ai_jobs set result = null where result is not null and finished_at < now() - interval '24 hours';
  get diagnostics n = row_count;
  delete from public.ai_jobs where created_at < now() - interval '90 days';
  return n;
end;
$$;

revoke all on function public.ai_reserve(uuid) from public, anon, authenticated;
revoke all on function public.ai_release(uuid, text) from public, anon, authenticated;
revoke all on function public.ai_purge_old() from public, anon, authenticated;

-- ───── RLS ─────
alter table public.ai_config enable row level security;
alter table public.ai_teacher_settings enable row level security;
alter table public.ai_jobs enable row level security;
alter table public.ai_quota enable row level security;

-- المدرس يقرا الإعدادات العامة بس بدون المفاتيح (مفيش مفاتيح هنا أصلًا)
drop policy if exists ai_config_select on public.ai_config;
create policy ai_config_select on public.ai_config for select to authenticated using (true);

drop policy if exists ai_jobs_select on public.ai_jobs;
create policy ai_jobs_select on public.ai_jobs for select using (owner_id = auth.uid());

drop policy if exists ai_quota_select on public.ai_quota;
create policy ai_quota_select on public.ai_quota for select using (owner_id = auth.uid());

drop policy if exists ai_teacher_settings_select on public.ai_teacher_settings;
create policy ai_teacher_settings_select on public.ai_teacher_settings for select using (owner_id = auth.uid());
-- كل الكتابة من الـ service (لا policies للـ insert/update/delete)
