-- supabase/migration_assistant_online_exams.sql
--
-- spec 044 — المساعد ينشئ ويدير الامتحانات الإلكترونية.
-- إضافة أعمدة + RPCs فوق team_schema.sql — idempotent. يُطبَّق عبر SSH:
--
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U <مالك الجداول> -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_assistant_online_exams.sql
--
-- (تأكد من مالك teams/team_members قبل التطبيق.)

-- صلاحية المساعد + هويته على Firebase (لتفويض الكتابة على الامتحانات).
alter table public.team_members
  add column if not exists can_manage_online_exams boolean not null default false,
  add column if not exists firebase_uid text;

-- حالة إضافة البوابة عند المدرس (بيدفعها جهاز المدرس فقط).
alter table public.teams
  add column if not exists portal_slug text,
  add column if not exists portal_enabled boolean not null default false,
  add column if not exists portal_expires_at timestamptz;

-- المالك فقط: يحدّث رابط الطلاب وحالة/انتهاء إضافة البوابة للفريق.
create or replace function public.set_team_portal(
  _team_id uuid, _slug text, _enabled boolean, _expires_at timestamptz
)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.teams
    set portal_slug = _slug,
        portal_enabled = coalesce(_enabled, false),
        portal_expires_at = _expires_at
    where id = _team_id and owner_id = auth.uid();
end;
$$;

-- أي عضو يسجّل Firebase uid جهازه هو (مش غيره).
create or replace function public.set_my_firebase_uid(_team_id uuid, _uid text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.team_members set firebase_uid = _uid
    where team_id = _team_id and user_id = auth.uid();
end;
$$;
