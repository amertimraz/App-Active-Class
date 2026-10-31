# Contract: Supabase web access (055)

> مسودة للمراجعة — **لم تُطبّق**. تتطبق بعد موافقة المستخدم عبر SSH كـ `supabase_admin` (نفس طريقة spec 033).

## 1. الأعمدة (`supabase/migration_web_access.sql`)

```sql
alter table public.teams
  add column if not exists web_enabled boolean not null default false,
  add column if not exists web_expires_at timestamptz,
  add column if not exists web_last_seen_at timestamptz;

-- العميل (authenticated) ماينفعش يعدّل الأعمدة دي — service_role بس (لوحة الأدمن).
revoke update (web_enabled, web_expires_at) on public.teams from authenticated, anon;
```

> ملحوظة تنفيذ: لو فيه سياسة update عامة على `teams` للمالك، الـ column-level revoke كافي؛ لو الكتابة بتتم بس عبر RPCs security definer، نتأكد إن مفيش RPC بيلمس الأعمدة دي.

## 2. دالة الأهلية

```sql
create or replace function public.web_access_active(_team_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select web_enabled and (web_expires_at is null or web_expires_at > now())
    from public.teams where id = _team_id), false);
$$;

create or replace function public.get_web_entitlement()
returns json language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select t.id as team_id, m.is_owner, t.license_code, t.owner_license_active,
         t.web_enabled, t.web_expires_at
    into r
    from public.team_members m join public.teams t on t.id = m.team_id
   where m.user_id = auth.uid()
   limit 1;
  if not found then
    return json_build_object('member', false);
  end if;
  if public.web_access_active(r.team_id) then
    update public.teams set web_last_seen_at = now() where id = r.team_id;
  end if;
  return json_build_object(
    'member', true,
    'team_id', r.team_id,
    'role', case when r.is_owner then 'owner' else 'assistant' end,
    'license_code', r.license_code,
    'owner_license_active', r.owner_license_active,
    'web_enabled', r.web_enabled,
    'web_expires_at', r.web_expires_at,
    'web_active', public.web_access_active(r.team_id));
end; $$;
grant execute on function public.get_web_entitlement() to authenticated;
```

القرار في العميل (دالة صرفة `decideWebAccess` في `lib/utils/web_entitlement.dart`):

| الشرط (بالترتيب) | النتيجة |
|---|---|
| `member == false` | `notInTeam` → "فعّل وضع الفريق من الموبايل" |
| `web_active == false` | `webDisabled` (أو `webExpired` لو `web_expires_at` عدّى) |
| ترخيص Firestore `status == suspended` | `licenseSuspended` |
| ترخيص منتهي أو `owner_license_active == false` | `licenseExpired` |
| ترخيص `deviceId` فاضي (عمره ما اتفعّل على موبايل) | `licenseNotActivated` |
| غير ذلك | `allowed(plan)` |

## 3. الطبقة الإجبارية على السيرفر (FR-013 — حسب Q5)

```sql
-- Origin بيحطه المتصفح (forbidden header) ومايتغيّرش من JS الصفحة.
create or replace function public.request_is_web_app()
returns boolean language sql stable as $$
  select coalesce(
    (current_setting('request.headers', true)::json ->> 'origin')
      = 'https://app.active-class.online', false);
$$;

create or replace function public.web_gate_ok(_team_id uuid)
returns boolean language sql stable as $$
  select (not public.request_is_web_app()) or public.web_access_active(_team_id);
$$;
```

ويتضاف `and public.web_gate_ok(team_id)` لكل سياسة select/insert/update/delete على جداول الفريق (نفس المواضع اللي فيها `is_team_license_active(team_id)` حاليًا في `team_schema.sql` وكل migration بعده).

**حدود الطبقة دي (معروفة ومقبولة):** عميل غير متصفح (curl) يقدر يبعت أي Origin — بس ده مش "الويب"، ومحتاج حساب عضو أصلًا (RLS العضوية لسه شغّالة). قنوات Realtime مش بتوصلها `request.headers` بنفس الطريقة → الإشعارات بالتغيير ممكن توصل، لكن **السحب الفعلي للبيانات** عبر REST هيترفض.

## 4. لوحة الأدمن (زي بوابة ولي الأمر)

```dart
// LicenseService — المصدر اللي الأدمن بيشوفه ويعدّله (نفس parentPortal*)
Future<void> setWebEnabled(String code, bool enabled);          // licenses/{code}.webEnabled
Future<void> setWebExpiresAt(String code, DateTime? expiresAt); // licenses/{code}.webExpiresAt

// AccountsService — نسخة للسيرفر في نفس الحفظ (نفس نمط setMaxAssistants)
Future<List<Map<String, dynamic>>> teamsByLicenseCode(String code);
Future<void> setTeamWebAccess(String teamId, {required bool enabled, DateTime? expiresAt});
// PATCH /rest/v1/teams?id=eq.<teamId>  {web_enabled, web_expires_at}  بـ service_role
```

## 5. فريق يتعمل بعد التفعيل

`create_team` (أو trigger بعده) يقرأ القيم من الأدمن مش من العميل: الأبسط إن الموبايل وقت إنشاء الفريق يبعت إشارة بس، والأدمن يعيد الحفظ؛ أو جدول `web_entitlements(license_code, enabled, expires_at)` يكتبه الأدمن بـ service_role والـ trigger ينسخه للفريق الجديد. **المقترح: الجدول + trigger** عشان مايعتمدش على تدخّل يدوي.

## 6. المساعدين

`get_web_entitlement()` بترجع نفس النتيجة للمالك والمساعد (الأهلية على مستوى الفريق). الويب **لا يستدعي** `claim_device`، فـ `bound_device_id` للمساعد يفضل لموبايله.

## 7. اختبارات SQL (تتشغل على السيرفر بعد التطبيق)

1. عضو فريق `web_enabled=false` → `get_web_entitlement()->>'web_active' = false`.
2. نفس العضو بـ header `origin: https://app.active-class.online` → select على `students` يرجّع 0 صف؛ من غير header (موبايل) → الصفوف كاملة.
3. `web_enabled=true, web_expires_at = now() - 1 day` → مرفوض.
4. `update teams set web_enabled = true` بـ JWT authenticated → خطأ صلاحية.
