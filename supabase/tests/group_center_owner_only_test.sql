-- supabase/tests/group_center_owner_only_test.sql
-- اختبار: المساعد ما يغيّرش السنتر (تعديل/إنشاء/upsert)، والمالك يقدر. بيتراجع (ROLLBACK).
-- شغّله على قاعدة تجريبية بعد migration_group_center_owner_only.sql.
begin;
create temp table _ids (k text primary key, v uuid);
grant select on _ids to authenticated;

do $$
declare u_owner uuid := gen_random_uuid(); u_a uuid := gen_random_uuid(); t uuid; g uuid;
begin
  insert into auth.users (id, raw_user_meta_data) values (u_owner,'{"phone":"c-o"}'),(u_a,'{"phone":"c-a"}');
  insert into public.teams (owner_id) values (u_owner) returning id into t;
  insert into public.team_members (team_id,user_id,is_owner) values (t,u_owner,true);
  insert into public.team_members (team_id,user_id) values (t,u_a);
  insert into public.groups (team_id,origin_device_id,local_id,name,center) values (t,'d',1,'G','سنتر أ') returning id into g;
  insert into _ids values ('t',t),('owner',u_owner),('a',u_a),('g',g);
end $$;

create or replace function pg_temp.as_user(_k text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', (select v::text from _ids where k = _k), true);
  execute 'set local role authenticated';
end $$;

do $$
declare t uuid; g uuid; c text;
begin
  select v into t from _ids where k='t'; select v into g from _ids where k='g';

  -- المساعد يغيّر السنتر → يتجاهل ويفضل زي ما هو (والاسم يتغيّر عادي)
  perform pg_temp.as_user('a');
  update public.groups set center = 'سنتر ب', name = 'G2' where id = g;
  reset role;
  select center into c from public.groups where id = g;
  assert c = 'سنتر أ', 'assistant cannot change center';
  assert (select name from public.groups where id = g) = 'G2', 'other fields still update';

  -- المساعد يمسح السنتر → يفضل
  perform pg_temp.as_user('a');
  update public.groups set center = null where id = g;
  reset role;
  assert (select center from public.groups where id = g) = 'سنتر أ', 'assistant cannot clear center';

  -- مجموعة جديدة من المساعد: بدون سنتر
  perform pg_temp.as_user('a');
  insert into public.groups (team_id,origin_device_id,local_id,name,center) values (t,'d',2,'NEW','سنتر ج');
  reset role;
  assert (select center from public.groups where team_id = t and local_id = 2) is null, 'new group by assistant has no center';

  -- upsert (ON CONFLICT) من المساعد على مجموعة موجودة: السنتر ما يتمسحش
  perform pg_temp.as_user('a');
  insert into public.groups (team_id,origin_device_id,local_id,name,center) values (t,'d',1,'G3',null)
    on conflict (team_id, origin_device_id, local_id) do update set name = excluded.name, center = excluded.center;
  reset role;
  assert (select center from public.groups where id = g) = 'سنتر أ', 'upsert cannot wipe center';
  assert (select name from public.groups where id = g) = 'G3', 'upsert still updates name';

  -- المالك يغيّر السنتر عادي
  perform pg_temp.as_user('owner');
  update public.groups set center = 'سنتر ب' where id = g;
  reset role;
  assert (select center from public.groups where id = g) = 'سنتر ب', 'owner can change center';
end $$;

rollback;
select 'center guard tests passed' as result;
