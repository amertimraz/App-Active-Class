-- supabase/migration_wa_activation.sql
--
-- واتساب التلقائي: «قفل افتراضي» — الخدمة ما بتشتغلش لمدرس غير لما الأدمن يفتحها
-- من لوحة التراخيص (admin_activated). المدرس يقدر يطلب التفعيل (activation_requested_at)
-- بس ما يقدرش يفتح لنفسه. وبنحمي أعمدة الأدمن (admin_activated / paused_by_admin /
-- free_limit_override) من تعديل المدرس مباشرة عبر الـAPI (كانت سياسة التحديث
-- بتسمح له يعدّل أي عمود في صفّه).
-- المدرسين اللي شغّالين فعلًا وقت أول تطبيق للـmigration بيتفتحلهم تلقائيًا
-- (مرة واحدة بس) علشان ما يتقطعش عنهم الإرسال. idempotent:
--   docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/migration_wa_activation.sql

alter table public.wa_teacher_settings
  add column if not exists admin_activated boolean not null default false,
  add column if not exists activation_requested_at timestamptz;

-- مرة واحدة: افتح للمدرسين اللي مفعّلين الخدمة بالفعل
do $$
begin
  if not exists (select 1 from public.wa_config where key = 'activation_grandfathered') then
    update public.wa_teacher_settings set admin_activated = true where enabled = true;
    insert into public.wa_config (key, value) values ('activation_grandfathered', 'true'::jsonb);
  end if;
end $$;

-- حماية أعمدة الأدمن: أي تعديل جاي من دور المدرس (authenticated/anon) بيرجّع
-- القيم القديمة (أو الافتراضية في الإدخال). دوال الأدمن security definer بتتنفّذ
-- بدور مالك الدالة فمش بتتأثر.
create or replace function public.wa_teacher_settings_guard()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.admin_activated := false;
      new.paused_by_admin := false;
      new.free_limit_override := null;
    else
      new.admin_activated := old.admin_activated;
      new.paused_by_admin := old.paused_by_admin;
      new.free_limit_override := old.free_limit_override;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists wa_teacher_settings_guard on public.wa_teacher_settings;
create trigger wa_teacher_settings_guard
  before insert or update on public.wa_teacher_settings
  for each row execute function public.wa_teacher_settings_guard();

-- فتح/قفل الخدمة لمدرس
create or replace function public.wa_admin_set_activated(_owner uuid, _on boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.wa_teacher_settings (owner_id, admin_activated, updated_at)
  values (_owner, _on, now())
  on conflict (owner_id) do update
    set admin_activated = excluded.admin_activated, updated_at = now();
end;
$$;

-- حالة المدرس (للوحة الأدمن) + التفعيل وطلبه
drop function if exists public.wa_admin_status(uuid);
create or replace function public.wa_admin_status(_owner uuid)
returns table (free_limit integer, used integer, extra_balance integer,
               override_limit integer, paused boolean, enabled boolean,
               activated boolean, requested_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
begin
  return query
    select public.wa_effective_limit(_owner),
           coalesce((select q.used from public.wa_quota q where q.owner_id = _owner and q.month = _month), 0),
           coalesce((select q.extra_balance from public.wa_quota q where q.owner_id = _owner and q.month = _month), 0),
           (select s.free_limit_override from public.wa_teacher_settings s where s.owner_id = _owner),
           coalesce((select s.paused_by_admin from public.wa_teacher_settings s where s.owner_id = _owner), false),
           coalesce((select s.enabled from public.wa_teacher_settings s where s.owner_id = _owner), false),
           coalesce((select s.admin_activated from public.wa_teacher_settings s where s.owner_id = _owner), false),
           (select s.activation_requested_at from public.wa_teacher_settings s where s.owner_id = _owner);
end;
$$;

revoke all on function public.wa_admin_set_activated(uuid, boolean) from public, anon, authenticated;
revoke all on function public.wa_admin_status(uuid) from public, anon, authenticated;
grant execute on function public.wa_admin_set_activated(uuid, boolean) to service_role;
grant execute on function public.wa_admin_status(uuid) to service_role;

-- قايمة كل المدرسين اللي ليهم إعدادات واتساب (لصفحة «واتساب» في لوحة الأدمن)
create or replace function public.wa_admin_list()
returns table (owner_id uuid, enabled boolean, activated boolean, paused boolean,
               requested_at timestamptz, free_limit integer, used integer,
               extra_balance integer, override_limit integer)
language plpgsql security definer set search_path = public as $$
declare _month date := date_trunc('month', now() at time zone 'Africa/Cairo')::date;
begin
  return query
    select s.owner_id, s.enabled, s.admin_activated, s.paused_by_admin,
           s.activation_requested_at, public.wa_effective_limit(s.owner_id),
           coalesce(q.used, 0), coalesce(q.extra_balance, 0), s.free_limit_override
      from public.wa_teacher_settings s
      left join public.wa_quota q on q.owner_id = s.owner_id and q.month = _month
     order by s.activation_requested_at desc nulls last, s.updated_at desc;
end;
$$;
revoke all on function public.wa_admin_list() from public, anon, authenticated;
grant execute on function public.wa_admin_list() to service_role;
