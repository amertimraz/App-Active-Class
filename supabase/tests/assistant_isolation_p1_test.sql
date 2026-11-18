-- supabase/tests/assistant_isolation_p1_test.sql
--
-- اختبار P1 (spec 058). بيشتغل كله جوّه transaction وبيتراجع (ROLLBACK) — **شغّله على قاعدة
-- تجريبية** (نسخة من مخطط الإنتاج) مش على الإنتاج. أي assertion فاشل بيرمي exception.
--   psql -U supabase_admin -d <scratch_db> -v ON_ERROR_STOP=1 -f supabase/tests/assistant_isolation_p1_test.sql

begin;

create temp table _ids (k text primary key, v uuid);

do $$
declare
  owner_u uuid := gen_random_uuid(); free_u uuid := gen_random_uuid();
  res_u uuid := gen_random_uuid();  other_u uuid := gen_random_uuid();
  t uuid; g_a uuid; g_b uuid; g_c uuid; g_none uuid; st uuid;
begin
  -- trigger handle_new_user بيعمل profile برقم تليفون فريد → نعطي كل مستخدم رقم مختلف.
  insert into auth.users (id, raw_user_meta_data) values
    (owner_u, '{"phone":"p1-owner"}'), (free_u, '{"phone":"p1-free"}'),
    (res_u, '{"phone":"p1-res"}'), (other_u, '{"phone":"p1-other"}');
  insert into public.teams (owner_id) values (owner_u) returning id into t;
  insert into public.team_members (team_id, user_id, is_owner) values (t, owner_u, true);
  insert into public.team_members (team_id, user_id) values (t, free_u), (t, res_u), (t, other_u);
  update public.team_members set groups_restricted = true where team_id = t and user_id in (res_u, other_u);

  -- مجموعات: A و B في «سنتر النور» (بمسافات زيادة)، C في «سنتر الأمل»، بلا سنتر.
  insert into public.groups (team_id, local_id, name, center) values (t, 1, 'A', '  سنتر   النور ') returning id into g_a;
  insert into public.groups (team_id, local_id, name, center) values (t, 2, 'B', 'سنتر النور') returning id into g_b;
  insert into public.groups (team_id, local_id, name, center) values (t, 3, 'C', 'سنتر الأمل') returning id into g_c;
  insert into public.groups (team_id, local_id, name) values (t, 4, 'D') returning id into g_none;

  insert into _ids values ('t', t), ('owner', owner_u), ('free', free_u), ('res', res_u), ('other', other_u),
    ('a', g_a), ('b', g_b), ('c', g_c), ('none', g_none);
end $$;

-- helper: نفّذ can_see_group بهوية مستخدم معيّن
create or replace function pg_temp.sees(_user text, _group text) returns boolean
language plpgsql as $$
declare u uuid; g uuid; t uuid; r boolean;
begin
  select v into u from _ids where k = _user;
  select v into t from _ids where k = 't';
  select v into g from _ids where k = _group;   -- null لو _group = 'null'
  perform set_config('request.jwt.claim.sub', u::text, true);
  select public.can_see_group(t, g) into r;
  return r;
end $$;

do $$
declare t uuid; res_u uuid; other_u uuid; g_a uuid; g_c uuid; g_none uuid;
begin
  select v into t from _ids where k='t'; select v into res_u from _ids where k='res';
  select v into other_u from _ids where k='other'; select v into g_a from _ids where k='a';
  select v into g_c from _ids where k='c'; select v into g_none from _ids where k='none';

  -- بدون أي منح: المالك والمساعد الحر يشوفوا كل حاجة (حتى null)، والمقيَّد ولا حاجة.
  assert pg_temp.sees('owner','a') and pg_temp.sees('owner','null'), 'owner sees all';
  assert pg_temp.sees('free','a') and pg_temp.sees('free','null'), 'free assistant sees all';
  assert not pg_temp.sees('res','a'), 'restricted w/o grants sees nothing';
  assert not pg_temp.sees('res','null'), 'restricted never sees null group';

  -- منح مجموعة صراحة: A بس.
  insert into public.team_member_groups values (t, res_u, g_a);
  assert pg_temp.sees('res','a'), 'explicit group grant';
  assert not pg_temp.sees('res','b'), 'other group in same center stays hidden';
  assert not pg_temp.sees('res','c'), 'other center hidden';
  delete from public.team_member_groups where user_id = res_u;

  -- منح سنتر (بصيغة متطبّعة): A و B (رغم اختلاف المسافات) ومش C ولا D.
  insert into public.team_member_centers values (t, other_u, 'سنتر النور');
  assert pg_temp.sees('other','a') and pg_temp.sees('other','b'), 'center grant covers normalized names';
  assert not pg_temp.sees('other','c') and not pg_temp.sees('other','none'), 'center grant does not leak';

  -- مجموعة جديدة تتضاف للسنتر → تظهر تلقائيًا. ونقلها برّه السنتر → تختفي.
  insert into public.groups (team_id, local_id, name, center) values (t, 5, 'E', 'سنتر النور');
  insert into _ids select 'e', id from public.groups where team_id = t and name = 'E';
  assert pg_temp.sees('other','e'), 'new group in center appears';
  update public.groups set center = 'سنتر الأمل' where team_id = t and name = 'E';
  assert not pg_temp.sees('other','e'), 'group moved out of center disappears';

  -- مجموعة محذوفة (soft delete) مش بتتفتح بالسنتر.
  -- الحذف يتطلّب صلاحية (check_delete_groups) → ننفّذه بهوية المالك.
  perform set_config('request.jwt.claim.sub', (select v::text from _ids where k = 'owner'), true);
  update public.groups set deleted_at = now() where team_id = t and name = 'A';
  assert not pg_temp.sees('other','a'), 'deleted group hidden';
  update public.groups set deleted_at = null where team_id = t and name = 'A';

  -- القيد: سنتر غير متطبّع مرفوض.
  begin
    insert into public.team_member_centers values (t, other_u, ' سنتر  غلط ');
    raise exception 'unnormalized center accepted';
  exception when check_violation then null;
  end;
end $$;

-- trigger الملء + نقل الطالب
do $$
declare t uuid; g_a uuid; g_c uuid; st uuid; att uuid; gid uuid;
begin
  select v into t from _ids where k='t'; select v into g_a from _ids where k='a'; select v into g_c from _ids where k='c';
  insert into public.students (team_id, local_id, group_remote_id) values (t, 1, g_a) returning id into st;
  insert into public.attendance (team_id, local_id, date, status, student_remote_id) values (t, 1, '2026-11-18', 'present', st) returning id into att;
  select group_remote_id into gid from public.attendance where id = att;
  assert gid = g_a, 'attendance.group_remote_id filled on insert';

  update public.students set group_remote_id = g_c where id = st;
  select group_remote_id into gid from public.attendance where id = att;
  assert gid = g_c, 'child rows follow student group transfer';
end $$;

rollback;
select 'P1 tests passed' as result;
