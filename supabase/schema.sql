-- supabase/schema.sql
--
-- نظام تسجيل الدخول المستقل (رقم تليفون + باسورد) — منفصل تمامًا عن
-- نظام الترخيص الحالي (Firebase). Supabase's built-in `auth.users`
-- بيدير بيانات الاعتماد فعليًا؛ الجدول ده بيخزّن رقم التليفون الحقيقي
-- (البريد الصناعي المستخدم داخليًا للمصادقة تفصيلة تقنية مش لازم تظهر
-- للمستخدم أبدًا).
--
-- طبّق الملف ده مرة واحدة على قاعدة بيانات Supabase (عبر SQL editor
-- في Supabase Studio، أو psql مباشرة على الـ VPS).

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text unique not null,
  display_name text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- كل مستخدم يقدر يقرأ/يعدّل بروفايله هو بس.
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);

-- إنشاء صف profiles تلقائيًا لحظة إنشاء حساب جديد في auth.users،
-- باستخدام رقم التليفون واسم العرض المبعوتين وقت signUp() (data:{...}).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, phone, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'phone', ''),
    new.raw_user_meta_data->>'display_name'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
