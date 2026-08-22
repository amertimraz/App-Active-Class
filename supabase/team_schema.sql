-- supabase/team_schema.sql
--
-- "وضع الفريق" — مشاركة بيانات المجموعات/الطلاب/الحضور/المدفوعات
-- بين المدرس (owner) والمساعدين، فوق نفس نظام تسجيل الدخول
-- المستقل (auth.users + public.profiles من schema.sql).
--
-- طبّقه بعد schema.sql على نفس قاعدة البيانات.

-- ── الفرق ─────────────────────────────────────────────────────────
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text,
  created_at timestamptz not null default now(),
  -- أقصى عدد مساعدين (غير المالك) مسموح لهم ينضموا — افتراضي 1،
  -- قابل للتعديل يدويًا من لوحة الإدارة لأي مدرس معيّن (upsell).
  max_assistants integer not null default 1,
  -- كود ترخيص المدرس (Firebase) وقت إنشاء الفريق — بيتقرا من أجهزة
  -- المساعدين عند الانضمام عشان تتسجّل أجهزتهم في Firestore مربوطة
  -- بنفس الترخيص، فيظهروا في تفاصيله بلوحة الأدمن.
  license_code text,
  -- آخر حالة معروفة لترخيص المدرس الحقيقي (Firebase) — بيدفعها جهاز
  -- المدرس فورًا لما حالة ترخيصه تتغيّر محليًا (TeamModeService).
  -- لازم تتفحص في RLS الجداول المشتركة عشان لو الترخيص خلص/اتوقف،
  -- كل أعضاء الفريق (مش بس المدرس) يتقفلوا فورًا.
  owner_license_active boolean not null default true,
  -- اسم/جنس المدرس (من ملفه المحلي في الإعدادات) — بيتقرا من جهاز
  -- المساعد عشان يقدر يوضّح "أنت مساعد لدى مستر/مس فلان" بدل ما
  -- يظهرله بروفايل المدرس وكأنه بروفايله هو (كانا منفصلين تمامًا
  -- لأن الإعدادات مش من ضمن الجداول المتزامنة أصلاً).
  teacher_name text,
  teacher_gender text
);

-- عضوية الفريق + صلاحيات دقيقة قابلة للتخصيص لكل مساعد (بدل دورين
-- ثابتين) — المدرس يحددها من شاشة "المستخدمين" في التطبيق.
create table if not exists public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_owner boolean not null default false,
  can_delete_attendance boolean not null default true,
  can_delete_payments boolean not null default true,
  can_delete_students boolean not null default false, -- وده كمان بيغطي حذف المجموعات
  can_manage_members boolean not null default false,
  -- صلاحيات عرض (مش حذف) — بتتفحص في التطبيق نفسه بس (client-side)،
  -- مش عن طريق RLS، لأن البيانات الأساسية (المدفوعات مثلاً) لازم
  -- تفضل متاحة تقنيًا للمساعد أصلاً عشان يقدر يسجّل عليها، إحنا بس
  -- بنخفي شاشات/كروت معيّنة عنه في الواجهة.
  can_view_financials boolean not null default true,
  can_view_academics boolean not null default true,
  -- جهاز واحد بس مسموح لكل مساعد — أول جهاز يسجّل دخول بيه بيتربط
  -- بيه تلقائيًا (claim_device)، وأي جهاز تاني بنفس الحساب يترفض لحد
  -- ما المدرس يفك الارتباط يدويًا (reset_member_device). المالك نفسه
  -- مش مقيّد بالقيد ده — عادةً بيستخدم أكتر من جهاز لشغله هو.
  bound_device_id text,
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- أكواد دعوة قصيرة الأجل — منفصلة عن كود الترخيص لأسباب أمنية.
create table if not exists public.team_invites (
  code text primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  max_uses integer not null default 1,
  used_count integer not null default 0,
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);

-- ── دوال مساعدة (security definer عشان تتجنب recursion في RLS) ─────
create or replace function public.is_team_member(_team_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.team_members
    where team_id = _team_id and user_id = auth.uid()
  );
$$;

create or replace function public.team_permission(_team_id uuid, _perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select is_owner or case _perm
      when 'delete_attendance' then can_delete_attendance
      when 'delete_payments'   then can_delete_payments
      when 'delete_students'   then can_delete_students
      when 'manage_members'    then can_manage_members
      else false
    end
    from public.team_members
    where team_id = _team_id and user_id = auth.uid()
  ), false);
$$;

-- ── إنشاء فريق (المدرس = owner بكل الصلاحيات) ──────────────────────
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

-- بس المالك يقدر يستخدمها، وبتتنادى من جهاز المالك كل ما حالة
-- ترخيصه الحقيقي (Firebase) تتغيّر — عشان RLS على الجداول المشتركة
-- تقدر تقفل الفريق كله (المالك والمساعدين) فور ما الترخيص يخلص.
create or replace function public.set_team_license_active(_team_id uuid, _active boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.teams set owner_license_active = _active
    where id = _team_id and owner_id = auth.uid();
end;
$$;

create or replace function public.is_team_license_active(_team_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select owner_license_active from public.teams where id = _team_id), false);
$$;

-- بس المالك يقدر يستخدمها — بتتنادى لما يعدّل اسمه/جنسه في الإعدادات
-- وهو مفعّل وضع الفريق، عشان أجهزة المساعدين تفضل عارضة الاسم الصح.
create or replace function public.set_team_teacher_profile(
  _team_id uuid, _name text, _gender text
)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.teams set teacher_name = _name, teacher_gender = _gender
    where id = _team_id and owner_id = auth.uid();
end;
$$;

-- بس المالك يقدر يستخدمها — بتتنادى لما المدرس يعطّل "وضع الفريق"
-- عمدًا من الشاشة. بتحذف صف الفريق نفسه، وده بيسحب معاه team_members
-- وteam_invites تلقائيًا (on delete cascade) — فكل أجهزة المساعدين
-- هتكتشف إنها اتشالت من الفريق (نفس آلية _wasRemovedFromTeam
-- الموجودة أصلاً) في أول catchUpPull بعد كده، وهتتقفل عندهم برضو.
-- عمدًا مش بنعمل كده تلقائيًا وقت تسجيل خروج/تبديل حساب المدرس على
-- نفس الجهاز (TeamModeService.disable() العادية) — ده كان هيهدم
-- الفريق بالغلط لو المدرس بس عايز يسجّل خروج مؤقت، مع إن الفريق لسه
-- شغال وممكن يكون بيستخدمه من جهاز تاني.
create or replace function public.delete_team(_team_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.teams where id = _team_id and owner_id = auth.uid();
end;
$$;

-- ── توليد كود دعوة (owner أو أي حد عنده can_manage_members بس) ─────
create or replace function public.create_invite(_team_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  new_code text;
begin
  if not public.team_permission(_team_id, 'manage_members') then
    raise exception 'not authorized';
  end if;
  new_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
  insert into public.team_invites (code, team_id, created_by) values (new_code, _team_id, auth.uid());
  return new_code;
end;
$$;

-- ── استخدام كود دعوة (المساعد بعد ما يعمل حساب) ───────────────────
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

-- ── قفل جهاز واحد لكل مساعد ──────────────────────────────────────
-- بتتنادى من جهاز المساعد كل مرة يفتح فيها التطبيق (أو ينضم لأول
-- مرة) — لو مفيش جهاز مربوط لسه، بتربط الجهاز الحالي وترجع true. لو
-- فيه جهاز مربوط بالفعل، بترجع true بس لو نفس الجهاز ده، وfalse لو
-- جهاز مختلف (يعني الحساب اتفتح على جهاز تاني بالغلط/عمدًا).
-- المالك مستبعد من القيد ده تمامًا (بيرجع true دايمًا).
-- security definer ضروري هنا (عكس صلاحيات العرض) لأن القيد ده مرتبط
-- بحد تجاري (عدد الأجهزة لكل مساعد)، فلازم يتفرض من السيرفر مش يتوثق
-- فيه على التطبيق بس.
create or replace function public.claim_device(_team_id uuid, _device_id text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  m record;
begin
  select is_owner, bound_device_id into m
    from public.team_members
    where team_id = _team_id and user_id = auth.uid();

  if not found then
    return false; -- مش عضو في الفريق ده أصلاً
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

-- فحص قراءة بس (بدون أي ربط تلقائي) — بيتنادى دوريًا من الجهاز
-- المتصل بالفعل عشان يتأكد إنه لسه هو الجهاز المرتبط. عمدًا مختلفة
-- عن claim_device: لو استخدمنا claim_device هنا، وقفل الفريق كان
-- فكّ الارتباط عشان يسمح لجهاز جديد، الجهاز القديم (لسه شغال) كان
-- هيربط نفسه تاني تلقائيًا قبل ما الجهاز الجديد ياخد فرصته — بيلغي
-- الغرض من "فك الارتباط" تمامًا. الدالة دي بس بتقرا الحالة الحالية.
create or replace function public.is_device_still_bound(_team_id uuid, _device_id text)
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
  -- NULL = أي حاجة بترجع NULL في SQL مش false — لازم نتأكد صراحة إن
  -- bound_device_id مش فاضي قبل المقارنة، وإلا الفحص هيرجع NULL (مش
  -- false) فور ما المدرس يفكّ الارتباط، ولن يُكتشف كجهاز غير مرتبط
  -- إلا بعد ما جهاز جديد يرتبط فعليًا.
  return m.bound_device_id is not null and m.bound_device_id = _device_id;
end;
$$;

-- المالك (أو أي عضو) محتاج يشوف بيانات (تليفون/اسم) زمايله في نفس
-- الفريق — الـ policy الأصلية في schema.sql بتسمح للمستخدم يشوف
-- بروفايله هو بس.
create policy "profiles_select_teammates" on public.profiles for select
  using (
    exists (
      select 1 from public.team_members tm1
      join public.team_members tm2 on tm1.team_id = tm2.team_id
      where tm1.user_id = auth.uid() and tm2.user_id = profiles.id
    )
  );

alter table public.teams        enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invites enable row level security;

create policy "teams_select_member" on public.teams for select using (public.is_team_member(id));

create policy "team_members_select" on public.team_members for select
  using (public.is_team_member(team_id));
-- محدش (حتى عضو عنده can_manage_members) يقدر يعدّل أو يحذف صف
-- المدرس (owner) نفسه — using بيمنع استهداف صف الـ owner، وwith check
-- بيمنع كمان أي حد يترقّي لـ owner عن طريق تحديث.
create policy "team_members_update" on public.team_members for update
  using (public.team_permission(team_id, 'manage_members') and not is_owner)
  with check (not is_owner);
create policy "team_members_delete" on public.team_members for delete
  using (public.team_permission(team_id, 'manage_members') and not is_owner);

create policy "team_invites_select" on public.team_invites for select
  using (public.is_team_member(team_id));
create policy "team_invites_delete" on public.team_invites for delete
  using (public.team_permission(team_id, 'manage_members'));

-- ── الجداول المشتركة (نسخة مرآة من الجداول المحلية، بس اللي فعلاً
-- محتاجة تتشارك — الامتحانات والتقارير والإعدادات تفضل محلية بس) ───
-- ملحوظة مهمة: local_id لوحده مش فريد عالميًا — كل جهاز عنده مساحة
-- autoincrement مستقلة، فممكن جهازين يستخدموا نفس local_id لصفين
-- مختلفين تمامًا. القيد الفريد لازم يشمل origin_device_id (نفس
-- deviceId الموجود أصلاً في LicenseController) عشان نمنع تصادم/دمج
-- غلط بين بيانات جهازين مختلفين. remote_id (الـ id بتاع الصف هنا)
-- هو المرجع الأساسي اللي كل جهاز بيستخدمه للتعرّف على الصف لاحقًا.
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  -- color: bigint مش integer — قيم ألوان فلاتر ARGB الكاملة (32-bit)
  -- بتتجاوز حد integer الموقّع أحيانًا (مثلاً 4293212469).
  name text, code text, price numeric, color bigint, icon text,
  schedule text, pricing_type text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

-- الربط بالأب (المجموعة) بيتم بالـ remote UUID بتاعها (مش رقم محلي)
-- — رقم الـ id المحلي مش معناه حاجة لجهاز تاني، فبنستخدم نفس آلية
-- remote_id اللي كل جهاز بيحلّها لوحده قبل ما يبعت الابن، بعد ما
-- يبقى الأب اتزامن وله remote_id فعلي.
create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  group_remote_id uuid references public.groups(id) on delete set null,
  name text, code text, price numeric, guardian_phone text, birth_date text,
  attendance_start text, exempt_percent numeric default 0, exempt_reason text,
  -- ربط الإخوة بيشاور على طالب تاني في نفس الجدول — ممكن الاتنين
  -- يتزامنوا الأول من غير الربط ده (لسه محدش عنده remote_id للتاني)،
  -- فالعمود ده nullable عمدًا ومبيمنعش إدراج الطالب من غير القيمة دي،
  -- عكس group_remote_id اللي بيمنع (لازم مجموعة موجودة أصلاً).
  sibling_remote_id uuid references public.students(id) on delete set null,
  siblings_total numeric,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  student_remote_id uuid references public.students(id) on delete cascade,
  date text, status text, notes text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  student_remote_id uuid references public.students(id) on delete cascade,
  date text, amount numeric, note text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

-- الواجب — نفس شكل جدول الحضور بالظبط (حالة عمل/لم يعمل لكل طالب في
-- كل تاريخ)، وبيستخدم صلاحية "حذف الحضور" (delete_attendance) بدل ما
-- نضيف صلاحية مستقلة جديدة له.
create table if not exists public.homework (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  student_remote_id uuid references public.students(id) on delete cascade,
  date text, status text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);

alter table public.groups     enable row level security;
alter table public.students   enable row level security;
alter table public.attendance enable row level security;
alter table public.payments   enable row level security;
alter table public.homework   enable row level security;

-- ملحوظة: is_team_license_active(team_id) لازم تتفحص هنا كمان — لو
-- الترخيص الحقيقي (Firebase) بتاع المدرس خلص/اتوقف، is_team_member
-- لوحدها مش كفاية (لسه عضو رسمي بالفريق)، فبنقفل القراءة/الكتابة
-- كلها لحد ما المدرس يجدد.
create policy "groups_select" on public.groups for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "groups_insert" on public.groups for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "groups_update" on public.groups for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create policy "students_select" on public.students for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "students_insert" on public.students for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "students_update" on public.students for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create policy "attendance_select" on public.attendance for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "attendance_insert" on public.attendance for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "attendance_update" on public.attendance for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create policy "payments_select" on public.payments for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "payments_insert" on public.payments for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "payments_update" on public.payments for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

create policy "homework_select" on public.homework for select
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "homework_insert" on public.homework for insert
  with check (public.is_team_member(team_id) and public.is_team_license_active(team_id));
create policy "homework_update" on public.homework for update
  using (public.is_team_member(team_id) and public.is_team_license_active(team_id));

-- لا يوجد DELETE policy عمدًا على الأربعة جداول دي — الحذف بيتم عن
-- طريق soft-delete (تحديث deleted_at) بس، والـ triggers تحت بتتأكد
-- إن صاحب التحديث ده عنده الصلاحية المطلوبة قبل ما يسمح بالتحويل
-- لـ deleted (باقي التعديلات العادية — زي تغيير السعر — مسموحة لأي
-- عضو في الفريق من غير قيد إضافي).

create or replace function public.check_delete_students()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_students') then
      raise exception 'not authorized to delete this student';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_students on public.students;
create trigger trg_check_delete_students before update on public.students
  for each row execute function public.check_delete_students();

create or replace function public.check_delete_groups()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_students') then
      raise exception 'not authorized to delete this group';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_groups on public.groups;
create trigger trg_check_delete_groups before update on public.groups
  for each row execute function public.check_delete_groups();

create or replace function public.check_delete_attendance()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_attendance') then
      raise exception 'not authorized to delete this attendance record';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_attendance on public.attendance;
create trigger trg_check_delete_attendance before update on public.attendance
  for each row execute function public.check_delete_attendance();

create or replace function public.check_delete_payments()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_payments') then
      raise exception 'not authorized to delete this payment';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_payments on public.payments;
create trigger trg_check_delete_payments before update on public.payments
  for each row execute function public.check_delete_payments();

create or replace function public.check_delete_homework()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    if not public.team_permission(NEW.team_id, 'delete_attendance') then
      raise exception 'not authorized to delete this homework record';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_check_delete_homework on public.homework;
create trigger trg_check_delete_homework before update on public.homework
  for each row execute function public.check_delete_homework();

-- ── تفعيل Realtime على الجداول المشتركة ────────────────────────────
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array['groups','students','attendance','payments','homework','team_members']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
