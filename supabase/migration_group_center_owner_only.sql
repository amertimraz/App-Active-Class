-- supabase/migration_group_center_owner_only.sql
--
-- السناتر للمدرس (المالك) بس: المساعد ما يغيّرش سنتر مجموعة ولا يحدد سنتر لمجموعة جديدة، حتى لو
-- نسخة تطبيقه قديمة ولسه فيها واجهة السناتر. بدل ما نرفض الكتابة (وده كان يسمّم طابور رفع المساعد)
-- بنتجاهل السنتر بصمت: تعديل → بيرجع للقيمة القديمة، مجموعة جديدة → بدون سنتر. باقي تعديل المجموعة
-- بيعدّي عادي، وجهاز المساعد بيسحب السنتر الصح من السيرفر في أول مزامنة.
--
-- الأدوار اللي بتجي من التطبيق (authenticated/anon) بس بتتفحص؛ الأدمن مش متأثر.
-- idempotent. بيتطبّق عبر SSH بدور supabase_admin.
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_group_center_owner_only.sql

begin;

create or replace function public.guard_group_center() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('role', true) in ('authenticated', 'anon')
     and not public.is_team_owner(new.team_id) then
    if tg_op = 'INSERT' then
      new.center := null;
    elsif new.center is distinct from old.center then
      new.center := old.center;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_group_center on public.groups;
create trigger trg_guard_group_center
  before insert or update of center on public.groups
  for each row execute function public.guard_group_center();

commit;
