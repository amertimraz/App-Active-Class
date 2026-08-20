-- supabase/migration_device_unbind_check.sql
--
-- إضافة جديدة فوق migration_device_lock.sql (لازم يكون الملف ده
-- اتشغّل قبل كده). شغّل السكريبت ده لوحده.
--
-- الغرض: فحص قراءة بس بيتأكد إن الجهاز الحالي لسه هو المرتبط بحساب
-- المساعد — بدون أي ربط تلقائي (عكس claim_device). من غيره، لما
-- المدرس يفكّ ارتباط مساعد عشان يسمح لجهاز جديد، جهاز المساعد القديم
-- (لو لسه شغال) كان هيربط نفسه تاني تلقائيًا قبل الجهاز الجديد.

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
  -- NULL = أي حاجة بترجع NULL في SQL مش false — لو سبناها زي ما هي،
  -- اللحظة اللي المفروض الفحص يرجع false فيها (فوق ما المدرس يفكّ
  -- الارتباط مباشرة، bound_device_id لسه NULL) كانت بترجع NULL بدل
  -- false، والتطبيق بيتعامل مع فشل التحويل ده كـ"الفحص فشل، سيبه"
  -- بدل "الجهاز مش مرتبط، اقفل عليه" — يعني القفل الفوري مكانش بيحصل
  -- أصلاً إلا بعد ما جهاز جديد يرتبط فعليًا.
  return m.bound_device_id is not null and m.bound_device_id = _device_id;
end;
$$;
