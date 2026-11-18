-- supabase/tests/assistant_isolation_p2_test.sql
--
-- اختبار P2 (spec 058): سياسات RLS الجديدة بدور `authenticated` الحقيقي. كله جوّه transaction
-- وبيتراجع (ROLLBACK) — **شغّله على قاعدة تجريبية** (مخطط الإنتاج + P1 + P2) مش على الإنتاج.
--   psql -U supabase_admin -d <scratch_db> -v ON_ERROR_STOP=1 -f supabase/tests/assistant_isolation_p2_test.sql

begin;

create temp table _ids (k text primary key, v uuid);
grant select on _ids to authenticated;

-- ── بيانات (بصلاحية الأدمن) ──
do $$
declare
  u_owner uuid := gen_random_uuid(); u_free uuid := gen_random_uuid();
  u_res uuid := gen_random_uuid();   u_none uuid := gen_random_uuid(); u_mgr uuid := gen_random_uuid();
  t uuid; ga1 uuid; ga2 uuid; gb1 uuid;
  sa1 uuid; sa2 uuid; sb1 uuid; ex_b uuid; ex_ab uuid;
begin
  insert into auth.users (id, raw_user_meta_data) values
    (u_owner,'{"phone":"p2-o"}'),(u_free,'{"phone":"p2-f"}'),(u_res,'{"phone":"p2-r"}'),
    (u_none,'{"phone":"p2-n"}'),(u_mgr,'{"phone":"p2-m"}');
  insert into public.teams (owner_id) values (u_owner) returning id into t;
  insert into public.team_members (team_id,user_id,is_owner) values (t,u_owner,true);
  insert into public.team_members (team_id,user_id) values (t,u_free);
  insert into public.team_members (team_id,user_id,groups_restricted) values (t,u_res,true),(t,u_none,true);
  insert into public.team_members (team_id,user_id,groups_restricted,can_manage_members) values (t,u_mgr,true,true);

  insert into public.groups (team_id,local_id,name,center) values (t,1,'A1','سنتر أ') returning id into ga1;
  insert into public.groups (team_id,local_id,name,center) values (t,2,'A2','سنتر أ') returning id into ga2;
  insert into public.groups (team_id,local_id,name,center) values (t,3,'B1','سنتر ب') returning id into gb1;
  insert into public.team_member_centers values (t,u_res,'سنتر أ');     -- res يشوف سنتر أ
  insert into public.team_member_groups values (t,u_mgr,gb1);          -- mgr يشوف B1 بس

  insert into public.students (team_id,local_id,group_remote_id) values (t,1,ga1) returning id into sa1;
  insert into public.students (team_id,local_id,group_remote_id) values (t,2,ga2) returning id into sa2;
  insert into public.students (team_id,local_id,group_remote_id) values (t,3,gb1) returning id into sb1;
  insert into public.attendance (team_id,local_id,date,status,student_remote_id) values
    (t,1,'2026-11-18','present',sa1),(t,2,'2026-11-18','present',sa2),(t,3,'2026-11-18','present',sb1);
  insert into public.payments (team_id,local_id,date,amount,student_remote_id) values
    (t,1,'2026-11-18',10,sa1),(t,2,'2026-11-18',20,sb1);
  insert into public.homework (team_id,origin_device_id,local_id,date,status,student_remote_id) values (t,'d',1,'2026-11-18','done',sb1);
  insert into public.student_archive_events (team_id,origin_device_id,local_id,student_remote_id,type,event_at) values
    (t,'d',1,sa1,'archived','2026-11-18'),(t,'d',2,sb1,'archived','2026-11-18');
  insert into public.session_overrides (team_id,origin_device_id,local_id,group_remote_id,date,type) values
    (t,'d',1,ga1,'2026-11-18','cancelled'),(t,'d',2,gb1,'2026-11-18','cancelled');
  -- امتحان للمجموعة B1 بس، وامتحان مشترك A1+B1 (من المالك)
  insert into public.exams (team_id,origin_device_id,local_id,name,created_by) values (t,'d',1,'EB',u_owner) returning id into ex_b;
  insert into public.exams (team_id,origin_device_id,local_id,name,created_by) values (t,'d',2,'EAB',u_owner) returning id into ex_ab;
  insert into public.exam_groups (team_id,origin_device_id,local_id,exam_remote_id,group_remote_id) values (t,'d',1,ex_b,gb1),(t,'d',2,ex_ab,ga1),(t,'d',3,ex_ab,gb1);
  insert into public.exam_questions (team_id,origin_device_id,local_id,exam_remote_id,type,text) values (t,'d',1,ex_b,'mcq','q'),(t,'d',2,ex_ab,'mcq','q');
  insert into public.bank_questions (team_id,origin_device_id,local_id,type,text) values (t,'d',1,'mcq','q'),(t,'d',2,'mcq','q');

  insert into _ids values ('t',t),('owner',u_owner),('free',u_free),('res',u_res),('none',u_none),('mgr',u_mgr),
    ('ga1',ga1),('ga2',ga2),('gb1',gb1),('sa1',sa1),('sb1',sb1),('ex_b',ex_b),('ex_ab',ex_ab);
end $$;

-- helper: نفّذ كمستخدم PostgREST (role authenticated + sub)
create or replace function pg_temp.as_user(_k text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', (select v::text from _ids where k = _k), true);
  execute 'set local role authenticated';
end $$;
create or replace function pg_temp.cnt(_tbl text) returns bigint language plpgsql as $$
declare n bigint; begin execute format('select count(*) from public.%I', _tbl) into n; return n; end $$;

-- ── ١) أعداد الرؤية لكل جدول ──
do $$
begin
  perform pg_temp.as_user('owner');
  assert pg_temp.cnt('groups') = 3 and pg_temp.cnt('students') = 3 and pg_temp.cnt('attendance') = 3
     and pg_temp.cnt('payments') = 2 and pg_temp.cnt('homework') = 1 and pg_temp.cnt('student_archive_events') = 2
     and pg_temp.cnt('session_overrides') = 2 and pg_temp.cnt('exams') = 2 and pg_temp.cnt('exam_groups') = 3
     and pg_temp.cnt('exam_questions') = 2, 'owner sees everything';

  perform pg_temp.as_user('free');
  assert pg_temp.cnt('groups') = 3 and pg_temp.cnt('attendance') = 3 and pg_temp.cnt('exams') = 2,
    'unrestricted assistant sees everything';

  -- res: سنتر أ (A1 + A2) فقط
  perform pg_temp.as_user('res');
  assert pg_temp.cnt('groups') = 2, 'res groups';
  assert pg_temp.cnt('students') = 2, 'res students';
  assert pg_temp.cnt('attendance') = 2, 'res attendance';
  assert pg_temp.cnt('payments') = 1, 'res payments (only sa1)';
  assert pg_temp.cnt('homework') = 0, 'res homework (sb1 hidden)';
  assert pg_temp.cnt('student_archive_events') = 1, 'res archive events';
  assert pg_temp.cnt('session_overrides') = 1, 'res overrides';
  assert pg_temp.cnt('exam_groups') = 1, 'res exam_groups: only the A1 link';
  assert pg_temp.cnt('exams') = 1, 'res exams: EAB (via A1) but not EB';
  assert pg_temp.cnt('exam_questions') = 1, 'res questions: EAB only';
  assert pg_temp.cnt('bank_questions') = 2, 'bank questions stay shared';

  -- none: مقيَّد بلا أي منح = صفر في كل حاجة (والبنك مشترك)
  perform pg_temp.as_user('none');
  assert pg_temp.cnt('groups') = 0 and pg_temp.cnt('students') = 0 and pg_temp.cnt('attendance') = 0
     and pg_temp.cnt('exams') = 0 and pg_temp.cnt('payments') = 0, 'restricted w/o grants sees nothing';
  assert (select visible_groups from public.my_team_access((select v from _ids where k='t'))) = 0, 'my_team_access visible=0';
  assert (select restricted from public.my_team_access((select v from _ids where k='t'))), 'my_team_access restricted';
  perform pg_temp.as_user('owner');
  assert (select is_owner and not restricted from public.my_team_access((select v from _ids where k='t'))), 'owner access summary';
  reset role;
end $$;

-- ── ٢) كتابة المقيَّد: على مجموعته ممكن، على مجموعة غيره ممنوع ──
do $$
declare t uuid; ga1 uuid; gb1 uuid; sa1 uuid; sb1 uuid; denied boolean; g uuid;
begin
  select v into t from _ids where k='t'; select v into ga1 from _ids where k='ga1';
  select v into gb1 from _ids where k='gb1'; select v into sa1 from _ids where k='sa1'; select v into sb1 from _ids where k='sb1';
  perform pg_temp.as_user('res');

  insert into public.attendance (team_id,local_id,date,status,student_remote_id) values (t,10,'2026-11-19','present',sa1);
  select group_remote_id into g from public.attendance where local_id = 10;
  assert g = ga1, 'insert into own group works and trigger fills group';

  denied := false;
  begin insert into public.attendance (team_id,local_id,date,status,student_remote_id) values (t,11,'2026-11-19','present',sb1);
  exception when insufficient_privilege then denied := true; end;
  assert denied, 'insert into another center is denied';

  denied := false;
  begin insert into public.students (team_id,local_id,group_remote_id) values (t,10,null);
  exception when insufficient_privilege then denied := true; end;
  assert denied, 'student without group is denied';
  insert into public.students (team_id,local_id,group_remote_id) values (t,11,ga1);  -- مع مجموعة: تمام

  denied := false;
  begin insert into public.groups (team_id,local_id,name,center) values (t,50,'NEW','سنتر أ');
  exception when insufficient_privilege then denied := true; end;
  assert denied, 'restricted assistant cannot create groups';

  -- update على صف مجموعة تانية بيتجاهل (0 صف) مش بيتغيّر
  update public.attendance set status = 'absent' where student_remote_id = sb1;
  reset role;
  assert (select count(*) from public.attendance where student_remote_id = sb1 and status = 'absent') = 0,
    'update on hidden group changes nothing';
end $$;

-- ── ٣) امتحان بينشئه مساعد مقيَّد ──
do $$
declare t uuid; ga1 uuid; gb1 uuid; ex uuid; denied boolean;
begin
  select v into t from _ids where k='t'; select v into ga1 from _ids where k='ga1'; select v into gb1 from _ids where k='gb1';
  perform pg_temp.as_user('res');
  insert into public.exams (team_id,origin_device_id,local_id,name) values (t,'d',20,'MINE') returning id into ex;   -- created_by = auth.uid()
  assert (select count(*) from public.exams where id = ex) = 1, 'creator sees own exam before linking groups';
  insert into public.exam_groups (team_id,origin_device_id,local_id,exam_remote_id,group_remote_id) values (t,'d',20,ex,ga1);
  insert into public.exam_questions (team_id,origin_device_id,local_id,exam_remote_id,type,text) values (t,'d',20,ex,'mcq','q');
  denied := false;
  begin insert into public.exam_groups (team_id,origin_device_id,local_id,exam_remote_id,group_remote_id) values (t,'d',21,ex,gb1);
  exception when insufficient_privilege then denied := true; end;
  assert denied, 'cannot attach own exam to a hidden group';
  reset role;
end $$;

-- ── ٤) حارس groups_restricted ──
do $$
declare t uuid; denied boolean;
begin
  select v into t from _ids where k='t';
  perform pg_temp.as_user('mgr');   -- مساعد مقيَّد وعنده manage_members
  denied := false;
  begin update public.team_members set groups_restricted = false
         where team_id = t and user_id = (select v from _ids where k='mgr');
  exception when others then denied := true; end;
  assert denied, 'manage_members assistant cannot lift his own restriction';
  reset role;
  assert (select groups_restricted from public.team_members where user_id = (select v from _ids where k='mgr')),
    'restriction unchanged';
  perform pg_temp.as_user('owner');
  update public.team_members set groups_restricted = false where team_id = t and user_id = (select v from _ids where k='none');
  reset role;
  assert not (select groups_restricted from public.team_members where user_id = (select v from _ids where k='none')),
    'owner can change it';
end $$;

-- ── ٥) ديناميكي: نقل مجموعة لسنتر تاني يغيّر الرؤية فورًا ──
do $$
declare t uuid;
begin
  select v into t from _ids where k='t';
  reset role;
  update public.groups set center = 'سنتر ب' where team_id = t and name = 'A2';
  perform pg_temp.as_user('res');
  assert pg_temp.cnt('groups') = 1, 'moved group disappears (A1 only now)';
  reset role;
end $$;

-- ── ٦) set_member_visibility (RPC ذرّي للمالك) ──
do $$
declare t uuid; ga1 uuid; gb1 uuid; denied boolean;
begin
  select v into t from _ids where k='t'; select v into ga1 from _ids where k='ga1'; select v into gb1 from _ids where k='gb1';
  -- مساعد (حتى لو عنده manage_members) ما يقدرش ينادي الدالة
  perform pg_temp.as_user('mgr');
  denied := false;
  begin perform public.set_member_visibility(t, (select v from _ids where k='free'), true, array[ga1], array[]::text[]);
  exception when others then denied := true; end;
  assert denied, 'non-owner cannot call set_member_visibility';

  perform pg_temp.as_user('owner');
  -- free يتقيّد بمجموعة B1 + سنتر (بمسافات زيادة)
  perform public.set_member_visibility(t, (select v from _ids where k='free'), true, array[gb1], array['  سنتر   أ ']);
  reset role;
  assert (select groups_restricted from public.team_members where user_id = (select v from _ids where k='free')), 'restricted set';
  assert (select count(*) from public.team_member_groups where user_id = (select v from _ids where k='free')) = 1, 'one group grant';
  assert (select center from public.team_member_centers where user_id = (select v from _ids where k='free')) = 'سنتر أ', 'center normalized';
  perform pg_temp.as_user('free');
  assert pg_temp.cnt('groups') = 2, 'free sees B1 (explicit) + A1 (center أ; A2 was moved to center ب earlier)';
  reset role;

  -- يتحوّل لغير مقيَّد: المنح تتمسح
  perform pg_temp.as_user('owner');
  perform public.set_member_visibility(t, (select v from _ids where k='free'), false);
  reset role;
  assert not (select groups_restricted from public.team_members where user_id = (select v from _ids where k='free')), 'unrestricted';
  assert (select count(*) from public.team_member_groups where user_id = (select v from _ids where k='free')) = 0
     and (select count(*) from public.team_member_centers where user_id = (select v from _ids where k='free')) = 0, 'grants cleared';

  -- المالك نفسه مش هدف
  perform pg_temp.as_user('owner');
  denied := false;
  begin perform public.set_member_visibility(t, (select v from _ids where k='owner'), true);
  exception when others then denied := true; end;
  assert denied, 'owner cannot be restricted';
  reset role;
end $$;

rollback;
select 'P2 tests passed' as result;
