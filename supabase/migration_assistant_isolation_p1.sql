-- supabase/migration_assistant_isolation_p1.sql
--
-- spec 058 / المرحلة P1 — الأساس لعزل المساعد على مجموعات/سناتر معيّنة.
--
-- **إضافات فقط، من غير أي تغيير في السلوك الحالي**:
--   • ما بنغيّر ولا سياسة RLS موجودة (المساعد لسه بيشوف كل حاجة).
--   • العمود/الجداول/الدالة الجديدة مش مستخدمة في أي سياسة لحد P2.
--   • مفيش backfill هنا (عشان ما نبعتش آلاف أحداث Realtime/updated_at) — راجع
--     migration_assistant_isolation_p1_backfill.sql، بيتشغّل قبل P2 بس.
--
-- بيتطبّق عبر SSH بدور supabase_admin، وidempotent (آمن لو اتشغّل مرتين):
--   ssh -i ~/.ssh/ovh_key root@active-class.online \
--     'docker exec -i active-class-auth-db-1 psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1' \
--     < supabase/migration_assistant_isolation_p1.sql

begin;

-- ── ٠) تطبيع اسم السنتر: نفس normalizeCenter في التطبيق (trim + دمج المسافات) ──
create or replace function public.normalize_center(_c text)
returns text
language sql
immutable
as $$
  select nullif(btrim(regexp_replace(coalesce(_c, ''), '\s+', ' ', 'g')), '');
$$;

-- ── ١) مساعد مقيَّد؟ (الافتراضي false = يشوف كل المجموعات، زي دلوقتي) ─────────
alter table public.team_members
  add column if not exists groups_restricted boolean not null default false;

-- ── ٢) منح الرؤية: مجموعات معيّنة وسناتر معيّنة ─────────────────────────────
-- لو المساعد مقيَّد بيشوف الاتحاد: (مجموعات اتمنحت صراحة) ∪ (كل مجموعة سنترها
-- ضمن سناتره). مسح العضو من الفريق بيمسح منحه (cascade).
create table if not exists public.team_member_groups (
  team_id          uuid not null,
  user_id          uuid not null,
  group_remote_id  uuid not null references public.groups(id) on delete cascade,
  primary key (team_id, user_id, group_remote_id),
  foreign key (team_id, user_id)
    references public.team_members(team_id, user_id) on delete cascade
);
create index if not exists team_member_groups_group_idx
  on public.team_member_groups (group_remote_id);

create table if not exists public.team_member_centers (
  team_id  uuid not null,
  user_id  uuid not null,
  center   text not null check (center = public.normalize_center(center)),
  primary key (team_id, user_id, center),
  foreign key (team_id, user_id)
    references public.team_members(team_id, user_id) on delete cascade
);

-- RLS على الجدولين الجداد: المالك يقرا ويكتب، والعضو يقرا منحه هو بس.
alter table public.team_member_groups  enable row level security;
alter table public.team_member_centers enable row level security;

drop policy if exists tmg_select on public.team_member_groups;
create policy tmg_select on public.team_member_groups for select
  using (public.is_team_owner(team_id) or user_id = auth.uid());
drop policy if exists tmg_write on public.team_member_groups;
create policy tmg_write on public.team_member_groups for all
  using (public.is_team_owner(team_id))
  with check (public.is_team_owner(team_id));

drop policy if exists tmc_select on public.team_member_centers;
create policy tmc_select on public.team_member_centers for select
  using (public.is_team_owner(team_id) or user_id = auth.uid());
drop policy if exists tmc_write on public.team_member_centers;
create policy tmc_write on public.team_member_centers for all
  using (public.is_team_owner(team_id))
  with check (public.is_team_owner(team_id));

-- ── ٣) دالة الرؤية (مش مستخدمة في أي سياسة لحد P2) ──────────────────────────
-- true لو: المالك، أو عضو غير مقيَّد، أو مجموعة اتمنحت له صراحة، أو سنترها ضمن
-- سناتره. _group_id = null (طالب/صف بلا مجموعة) → للمالك والمساعد الحر بس.
create or replace function public.can_see_group(_team_id uuid, _group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_team_owner(_team_id)
    or exists (
      select 1 from public.team_members m
       where m.team_id = _team_id and m.user_id = auth.uid()
         and not m.groups_restricted)
    or (_group_id is not null and (
      exists (
        select 1 from public.team_member_groups g
         where g.team_id = _team_id and g.user_id = auth.uid()
           and g.group_remote_id = _group_id)
      or exists (
        select 1
          from public.team_member_centers c
          join public.groups gr on gr.id = _group_id and gr.team_id = c.team_id
         where c.team_id = _team_id and c.user_id = auth.uid()
           and gr.deleted_at is null
           and public.normalize_center(gr.center) = c.center)
    ));
$$;

-- ── ٤) group_remote_id مكرَّر على صفوف الطالب (عشان RLS/Realtime بلا join تقيل) ──
-- بيتملي تلقائيًا بـtrigger من مجموعة الطالب. nullable، ومحدّش من التطبيق
-- بيكتبه (الـupsert بيتجاهله). الصفوف القديمة بتتملي في ملف الـbackfill.
alter table public.attendance        add column if not exists group_remote_id uuid;
alter table public.payments          add column if not exists group_remote_id uuid;
alter table public.homework          add column if not exists group_remote_id uuid;
alter table public.exam_grades       add column if not exists group_remote_id uuid;
alter table public.exam_submissions  add column if not exists group_remote_id uuid;
alter table public.booklet_records   add column if not exists group_remote_id uuid;
alter table public.booklet_payments  add column if not exists group_remote_id uuid;

create index if not exists attendance_group_idx       on public.attendance (team_id, group_remote_id);
create index if not exists payments_group_idx         on public.payments (team_id, group_remote_id);
create index if not exists homework_group_idx         on public.homework (team_id, group_remote_id);
create index if not exists exam_grades_group_idx      on public.exam_grades (team_id, group_remote_id);
create index if not exists exam_submissions_group_idx on public.exam_submissions (team_id, group_remote_id);
create index if not exists booklet_records_group_idx  on public.booklet_records (team_id, group_remote_id);
create index if not exists booklet_payments_group_idx on public.booklet_payments (team_id, group_remote_id);

-- يملا group_remote_id من الطالب. مفيش exceptions: لو الطالب مش موجود → null.
create or replace function public.fill_group_from_student()
returns trigger
language plpgsql
as $$
begin
  if new.student_remote_id is null then
    new.group_remote_id := null;
  else
    select s.group_remote_id into new.group_remote_id
      from public.students s where s.id = new.student_remote_id;
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['attendance','payments','homework','exam_grades',
                           'exam_submissions','booklet_records','booklet_payments']
  loop
    execute format('drop trigger if exists trg_fill_group on public.%I', t);
    -- الاسم بيبدأ بـ«trg_f» فبيتنفّذ قبل trg_set_updated_at (ترتيب أبجدي).
    execute format(
      'create trigger trg_fill_group before insert or update of student_remote_id '
      'on public.%I for each row execute function public.fill_group_from_student()', t);
  end loop;
end $$;

-- نقل طالب لمجموعة تانية → نحدّث group_remote_id على صفوفه (نادر، ومهم للعزل).
create or replace function public.propagate_student_group()
returns trigger
language plpgsql
as $$
begin
  if new.group_remote_id is distinct from old.group_remote_id then
    update public.attendance       set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.payments         set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.homework         set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.exam_grades      set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.exam_submissions set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.booklet_records  set group_remote_id = new.group_remote_id where student_remote_id = new.id;
    update public.booklet_payments set group_remote_id = new.group_remote_id where student_remote_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_propagate_student_group on public.students;
create trigger trg_propagate_student_group
  after update of group_remote_id on public.students
  for each row execute function public.propagate_student_group();

commit;

-- PostgREST يعيد قراءة المخطط (الأعمدة/الجداول الجديدة).
notify pgrst, 'reload schema';
