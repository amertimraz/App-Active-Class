-- supabase/migration_view_permissions.sql
--
-- إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على السيرفر —
-- شغّل السكريبت ده لوحده (مينفعش تعيد تشغيل team_schema.sql كامل).
-- نفس التعديلات دي اتضافت في team_schema.sql كمان (لو حد طبّق
-- السكيما من الأول بعد التاريخ ده مش محتاج يشغّل الملف ده).
--
-- الغرض: صلاحيتان جديدتان (عرض بس، مش حذف) — can_view_financials
-- (المدفوعات/التقارير/كروت الأرقام المالية في الرئيسية) وcan_view_academics
-- (الامتحانات/الدرجات/لوحة الصدارة). بتتفحص في التطبيق نفسه بس (client-side)،
-- مش عن طريق RLS.

alter table public.team_members
  add column if not exists can_view_financials boolean not null default true,
  add column if not exists can_view_academics boolean not null default true;

create or replace function public.create_team(
  _license_code text default null,
  _teacher_name text default null,
  _teacher_gender text default null
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_team_id uuid;
begin
  insert into public.teams (owner_id, license_code, teacher_name, teacher_gender)
    values (auth.uid(), _license_code, _teacher_name, _teacher_gender)
    returning id into new_team_id;
  insert into public.team_members
    (team_id, user_id, is_owner, can_delete_attendance, can_delete_payments,
     can_delete_students, can_manage_members, can_view_financials, can_view_academics)
  values (new_team_id, auth.uid(), true, true, true, true, true, true, true);
  return new_team_id;
end;
$$;

create or replace function public.redeem_invite(_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  inv record;
  team_row record;
  current_assistants integer;
begin
  select * into inv from public.team_invites where code = upper(_code) for update;
  if inv is null then raise exception 'invalid invite code'; end if;
  if inv.expires_at < now() then raise exception 'invite expired'; end if;
  if inv.used_count >= inv.max_uses then raise exception 'invite already used'; end if;

  select * into team_row from public.teams where id = inv.team_id;
  select count(*) into current_assistants
    from public.team_members
    where team_id = inv.team_id and is_owner = false;
  if current_assistants >= team_row.max_assistants then
    raise exception 'team member limit reached';
  end if;

  insert into public.team_members
    (team_id, user_id, is_owner, can_delete_attendance, can_delete_payments,
     can_delete_students, can_manage_members, can_view_financials, can_view_academics)
  values (inv.team_id, auth.uid(), false, true, true, false, false, true, true)
  on conflict (team_id, user_id) do nothing;

  update public.team_invites set used_count = used_count + 1 where code = inv.code;
  return inv.team_id;
end;
$$;
