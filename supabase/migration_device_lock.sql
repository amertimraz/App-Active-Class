-- supabase/migration_device_lock.sql
--
-- إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على السيرفر —
-- شغّله لوحده بعد ما تخلّص migration_view_permissions.sql (الاتنين
-- مستقلين عن بعض، الترتيب مش مهم، بس الاتنين لازم يتشغّلوا).
--
-- الغرض: قفل كل مساعد على جهاز واحد بس — أول جهاز يسجّل دخول بيه
-- بيتربط بيه تلقائيًا، وأي جهاز تاني بنفس حساب المساعد يترفض لحد ما
-- المدرس يفك الارتباط يدويًا من شاشة "إدارة الأعضاء".

alter table public.team_members
  add column if not exists bound_device_id text;

create or replace function public.claim_device(_team_id uuid, _device_id text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  m record;
begin
  select is_owner, bound_device_id into m
    from public.team_members
    where team_id = _team_id and user_id = auth.uid();

  if not found then
    return false;
  end if;
  if m.is_owner then
    return true;
  end if;
  if m.bound_device_id is null then
    update public.team_members set bound_device_id = _device_id
      where team_id = _team_id and user_id = auth.uid();
    return true;
  end if;
  return m.bound_device_id = _device_id;
end;
$$;
