-- supabase/migration_wa_admin.sql
--
-- spec 056 — تحكم الأدمن في واتساب التلقائي لكل مدرس (من إعدادات الترخيص في
-- لوحة الأدمن): حد شهري، رصيد إضافي، إيقاف/تشغيل. كلها دوال service_role فقط.
-- وتعديل wa_reserve_quota عشان تغيير الحد يسري فورًا (كان بيتقرا أول مرة في
-- الشهر بس). idempotent:
--   docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres \
--     < supabase/migration_wa_admin.sql

-- الحد الفعلي للمدرس (override أو الافتراضي)
create or replace function public.wa_effective_limit(_owner uuid)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce(
    (select free_limit_override from public.wa_teacher_settings where owner_id = _owner),
    (select (value)::text::integer from public.wa_config where key = 'default_free_limit'),
    100);
$$;

-- حجز رسالة: نفس المنطق السابق + تحديث الحد في صف الشهر دايمًا
create or replace function public.wa_reserve_quota(_owner uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
  _limit integer := public.wa_effective_limit(_owner);
begin
  insert into public.wa_quota (owner_id, month, free_limit)
  values (_owner, _month, _limit)
  on conflict (owner_id, month) do update set free_limit = excluded.free_limit;

  update public.wa_quota set used = used + 1
   where owner_id = _owner and month = _month and used < free_limit;
  if found then return 'free'; end if;

  update public.wa_quota set extra_balance = extra_balance - 1
   where owner_id = _owner and month = _month and extra_balance > 0;
  if found then return 'extra'; end if;

  return null;
end;
$$;

-- حالة المدرس (للوحة الأدمن)
create or replace function public.wa_admin_status(_owner uuid)
returns table (free_limit integer, used integer, extra_balance integer,
               override_limit integer, paused boolean, enabled boolean)
language plpgsql security definer set search_path = public as $$
declare _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
begin
  return query
    select public.wa_effective_limit(_owner),
           coalesce((select q.used from public.wa_quota q where q.owner_id = _owner and q.month = _month), 0),
           coalesce((select q.extra_balance from public.wa_quota q where q.owner_id = _owner and q.month = _month), 0),
           (select s.free_limit_override from public.wa_teacher_settings s where s.owner_id = _owner),
           coalesce((select s.paused_by_admin from public.wa_teacher_settings s where s.owner_id = _owner), false),
           coalesce((select s.enabled from public.wa_teacher_settings s where s.owner_id = _owner), false);
end;
$$;

-- ضبط الحد الشهري (null = الافتراضي) — بيسري فورًا على الشهر الحالي
create or replace function public.wa_admin_set_limit(_owner uuid, _limit integer)
returns void language plpgsql security definer set search_path = public as $$
declare _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
begin
  if _limit is not null and _limit < 0 then raise exception 'limit must be >= 0'; end if;
  insert into public.wa_teacher_settings (owner_id, free_limit_override, updated_at)
  values (_owner, _limit, now())
  on conflict (owner_id) do update set free_limit_override = excluded.free_limit_override, updated_at = now();
  update public.wa_quota set free_limit = public.wa_effective_limit(_owner)
   where owner_id = _owner and month = _month;
end;
$$;

-- إضافة (أو خصم) رصيد إضافي للشهر الحالي. الناتج ما يقلش عن صفر.
create or replace function public.wa_admin_add_balance(_owner uuid, _n integer)
returns integer language plpgsql security definer set search_path = public as $$
declare
  _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
  _res integer;
begin
  insert into public.wa_quota (owner_id, month, free_limit)
  values (_owner, _month, public.wa_effective_limit(_owner))
  on conflict (owner_id, month) do nothing;
  update public.wa_quota set extra_balance = greatest(extra_balance + _n, 0)
   where owner_id = _owner and month = _month
  returning extra_balance into _res;
  return _res;
end;
$$;

-- إيقاف/تشغيل المدرس من الأدمن (الإرسال التلقائي كله)
create or replace function public.wa_admin_set_paused(_owner uuid, _paused boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.wa_teacher_settings (owner_id, paused_by_admin, updated_at)
  values (_owner, _paused, now())
  on conflict (owner_id) do update set paused_by_admin = excluded.paused_by_admin, updated_at = now();
end;
$$;

revoke all on function public.wa_effective_limit(uuid) from public, anon, authenticated;
revoke all on function public.wa_reserve_quota(uuid) from public, anon, authenticated;
revoke all on function public.wa_admin_status(uuid) from public, anon, authenticated;
revoke all on function public.wa_admin_set_limit(uuid, integer) from public, anon, authenticated;
revoke all on function public.wa_admin_add_balance(uuid, integer) from public, anon, authenticated;
revoke all on function public.wa_admin_set_paused(uuid, boolean) from public, anon, authenticated;
grant execute on function public.wa_admin_status(uuid) to service_role;
grant execute on function public.wa_admin_set_limit(uuid, integer) to service_role;
grant execute on function public.wa_admin_add_balance(uuid, integer) to service_role;
grant execute on function public.wa_admin_set_paused(uuid, boolean) to service_role;
