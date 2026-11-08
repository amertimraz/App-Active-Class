-- supabase/migration_device_status.sql
--
-- «حالة أجهزة الفريق»: كل جهاز (مدرّس أو مساعد) بيبعت نبضة بسيطة للسيرفر فيها
-- آخر رفع/سحب وعدد الصفوف المعلّقة وغير المتزامنة وآخر خطأ، والمدرّس بيشوفها
-- في شاشة وضع الفريق. من غيرها المدرّس ما كانش يقدر يعرف إن جهاز المساعد فيه
-- بيانات ما وصلتش السيرفر (بلاغ 2026-11-08: أرقام حضور مختلفة بين الجهازين).
-- بيانات تشغيلية بس (أرقام + آخر خطأ) — مفيش أسماء طلاب ولا محتوى.
-- idempotent. يُطبَّق عبر SSH:
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_device_status.sql
--
-- الجدول مقفول (RLS بلا policies)، والوصول كله من خلال دالتين SECURITY DEFINER.

create table if not exists public.team_device_status (
  team_id uuid not null references public.teams(id) on delete cascade,
  device_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  pending integer not null default 0,
  unsynced integer not null default 0,
  last_push_at timestamptz,
  last_pull_at timestamptz,
  last_error text,
  app_version text,
  updated_at timestamptz not null default now(),
  primary key (team_id, device_id)
);

alter table public.team_device_status enable row level security;
-- مفيش policies عمدًا: مفيش وصول مباشر للجدول، الدالتين تحت بس.

-- العضو بيسجّل حالة جهازه هو بس (user_id = auth.uid()). الوقت من الخادم.
create or replace function public.report_device_status(
  _team_id uuid,
  _device_id text,
  _pending integer,
  _unsynced integer,
  _last_push_at timestamptz,
  _last_pull_at timestamptz,
  _last_error text,
  _app_version text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_team_member(_team_id) then
    raise exception 'not a team member';
  end if;
  insert into public.team_device_status as s
    (team_id, device_id, user_id, pending, unsynced, last_push_at, last_pull_at,
     last_error, app_version, updated_at)
  values
    (_team_id, _device_id, auth.uid(), coalesce(_pending, 0), coalesce(_unsynced, 0),
     _last_push_at, _last_pull_at, left(_last_error, 300), left(_app_version, 40), now())
  on conflict (team_id, device_id) do update set
    user_id = auth.uid(),
    pending = excluded.pending,
    unsynced = excluded.unsynced,
    last_push_at = coalesce(excluded.last_push_at, s.last_push_at),
    last_pull_at = coalesce(excluded.last_pull_at, s.last_pull_at),
    last_error = excluded.last_error,
    app_version = excluded.app_version,
    updated_at = now();
end;
$$;

-- المالك بس بيقرا حالة كل أجهزة الفريق (مع اسم العضو). server_now عشان
-- الجهاز يحسب «من قد إيه» من غير ما يعتمد على ساعته.
create or replace function public.list_device_status(_team_id uuid)
returns table (
  device_id text, user_id uuid, display_name text, is_owner boolean,
  pending integer, unsynced integer, last_push_at timestamptz,
  last_pull_at timestamptz, last_error text, app_version text,
  updated_at timestamptz, server_now timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_team_owner(_team_id) then
    raise exception 'owner only';
  end if;
  return query
    select s.device_id, s.user_id, p.display_name, coalesce(m.is_owner, false),
           s.pending, s.unsynced, s.last_push_at, s.last_pull_at, s.last_error,
           s.app_version, s.updated_at, now()
    from public.team_device_status s
    left join public.profiles p on p.id = s.user_id
    left join public.team_members m on m.team_id = s.team_id and m.user_id = s.user_id
    where s.team_id = _team_id
    order by s.updated_at desc;
end;
$$;

grant execute on function public.report_device_status(uuid, text, integer, integer, timestamptz, timestamptz, text, text) to authenticated;
grant execute on function public.list_device_status(uuid) to authenticated;
