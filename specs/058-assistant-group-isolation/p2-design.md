# P2 — سياسات RLS للعزل (تصميم تفصيلي، لسه ما اتكتبتش الـmigration)

**الحالة**: الـmigration والاختبار **مكتوبين ومتجرّبين على قاعدة تجريبية** (2026-11-18)، لكن **ما اتطبّقوش على الإنتاج**. القرارات اتحسمت (تحت).

## حالة التنفيذ

| المرحلة | الحالة |
|---|---|
| P1 migration | **اتطبّق على الإنتاج 2026-11-18** (نسخة احتياطية: `/opt/backups/pre-p1-20261118-1015.dump` على السيرفر). مفيش أي تغيير في السلوك. الـtrigger اتأكد من كتابات حضور حقيقية (group_remote_id بيتملي). |
| P1 backfill | لسه ما اتشغّلش (70 ألف صف، وقت هادي، قبل P2 بس) |
| P2 | `migration_assistant_isolation_p2.sql` + `supabase/tests/assistant_isolation_p2_test.sql` + `..._p2_rollback.sql`: **متجرّبين على قاعدة تجريبية**، غير مطبّقين على الإنتاج |

## قياس الأداء (على قاعدة تجريبية: فريق واحد، 60 ألف صف حضور، 20 مجموعة)

سياسة `select` على `attendance`، بعد `select count(*)` على كل الجدول (بدور `authenticated`):

| السياسة | المالك | مساعد مقيَّد بسنتر (15 ألف صف ظاهر) |
|---|---|---|
| الحالية (`is_team_member AND is_team_license_active`) | 1,555 ms | — |
| `can_see_group(team_id, group_remote_id)` لكل صف | **10,419 ms** (6.7 ضعف أبطأ) | 11,385 ms |
| **مجموعة IDs مرة واحدة** (الأنسب) | **774 ms** (أسرع من الحالية) | **153 ms** |

**الدرس**: ما نستدعيش `can_see_group` لكل صف. نستخدم دوال ترجّع **مجموعة** (`setof uuid`) في `IN (select ...)` فبتتحسب مرة واحدة للاستعلام:

```sql
create function public.my_full_access_teams() returns setof uuid ... security definer stable as $$
  select t.id from teams t where t.owner_id = auth.uid()
  union
  select m.team_id from team_members m where m.user_id = auth.uid() and not m.groups_restricted $$;

create function public.my_visible_groups() returns setof uuid ... security definer stable as $$
  select group_remote_id from team_member_groups where user_id = auth.uid()
  union
  select gr.id from team_member_centers c
    join groups gr on gr.team_id = c.team_id and normalize_center(gr.center) = c.center
   where c.user_id = auth.uid() and gr.deleted_at is null $$;

-- نمط السياسة (مثال attendance):
using ( is_team_license_active(team_id)
        and ( team_id in (select my_full_access_teams())
              or group_remote_id in (select my_visible_groups()) ) )
```

الدالتين دول مش في P1 — بيتضافوا في migration P2 (مع `grant execute ... to authenticated`).
`can_see_group` بتفضل لفحص صف واحد (RPCs).

## السياسات الجديدة لكل جدول

الجداول التسعة الأولى بتتصرّف بنفس النمط (`select`/`insert`/`update`، كلهم بنفس الشرط):

| الجدول | العمود اللي بنقيّد عليه |
|---|---|
| groups | `id` (`id in (select my_visible_groups())`) |
| students | `group_remote_id` |
| attendance، payments، homework، exam_grades، exam_submissions، booklet_records، booklet_payments | `group_remote_id` (المكرَّر بالـtrigger) |
| session_overrides، exam_groups، booklet_groups | `group_remote_id` الأصلي |
| student_archive_events | عن طريق الطالب (`student_remote_id in (select id from students ...)`) أو عمود مكرَّر جديد (قرار تنفيذ) |
| exam_questions | عن طريق الامتحان |
| exams، booklets | شوف «أسئلة P2» (مشكلة الإنشاء) |
| bank_questions | يفضل لكل أعضاء الفريق (مشترك) |

المالك والمساعد غير المقيَّد: `team_id in (select my_full_access_teams())` يمرّر كل صفوف فريقهم، فمفيش تغيير لهم.

## مشاكل لازم تتحل قبل التطبيق

1. **إنشاء امتحان/ملزمة بواسطة مساعد مقيَّد**: الصف بيتكتب قبل صفوف `exam_groups`، فالـ`select` (اللازم لـ`upsert ... returning`) هيرفضه. الحل المقترح: عمود `created_by uuid default auth.uid()` على `exams` و`booklets`، والسياسة تسمح لمنشئها يشوفها حتى تتربط بمجموعات.
2. **طالب بلا مجموعة**: المساعد المقيَّد ما يقدرش يضيفه ولا يشوفه (`group_remote_id` null). لازم الواجهة (P4) تفرض اختيار مجموعة، وإلا الـoutbox يتسمّم (RLS reject).
3. **`upsert` من مساعد مقيَّد على صف مش بتاعه**: بيترفض. محرك المزامنة لازم يميّز رفض RLS (42501) عن خطأ شبكة ويشيل الصف من الـoutbox (P3).
4. **تغيير سنتر مجموعة / منح جديد**: المساعد مش هيتبلّغ بالتغيير، ولا بيحصل purge على جهازه تلقائيًا → ده شغل P3.
5. **`delete_team` و`RPC`ز اللي بتقرا الجداول مباشرة** (security definer) بتعدّي RLS — لازم تتراجع واحدة واحدة إن كانت بتكشف بيانات لمساعد مقيَّد.
6. **Realtime**: لازم نتأكد إن `postgres_changes` مع السياسات الجديدة بتوصّل الصف الصح للمساعد الصح، وإن تغيّر رؤية صف (نقل مجموعة) مش بيسرّب النسخة القديمة.

## خطة التطبيق (أمان قبل أي حاجة)

1. **الـbackfill** (وقت هادي): `migration_assistant_isolation_p1_backfill.sql`.
2. **فريق تجريبي**: مدرس ومساعد بترخيص تجريبي على الإنتاج، فيه 3 سناتر و15 مجموعة. الاختبار: مساعد مقيَّد بسنتر يقرا بتوكنه الحقيقي عبر REST صف من مجموعة تانية = صفر.
3. **تطبيق P2 على الإنتاج** بعد نسخة احتياطية: `migration_assistant_isolation_p2.sql` (لسه ما اتكتبتش).
4. **الرجوع الفوري** لو أي مشكلة: `migration_assistant_isolation_p2_rollback.sql` (مكتوب ومتحفوظ، بيرجّع السياسات الأصلية للـ17 جدول).
5. مراقبة بعدها: أخطاء PostgREST، أوقات الـselect للفرق الكبيرة، شكاوى فقدان بيانات.

## القرارات (من المستخدم، 2026-11-18)

1. **المساعد المقيَّد ينشئ امتحانات/ملازم**: اتنفّذ بعمود `created_by` (default `auth.uid()`) والسياسة بتفحصه على الصف نفسه.
2. **بنك الأسئلة مشترك**: `bank_questions` ما اتلمسش.
3. **مقيَّد بلا منح**: ممنوع يدخل برسالة. السيرفر بيوفّر `my_team_access(team_id)` (is_owner / restricted / visible_groups)؛ **منع الدخول والرسالة نفسها شغل التطبيق (P4)**. لحد ما يتنفّذ، المساعد ده بيشوف شاشة فاضية (RLS بيرجّعله صفر).
4. `student_archive_events`: عمود `group_remote_id` مكرَّر جديد (اتنفّذ في migration P2 مع backfill صغير).

## نتايج الاختبار على القاعدة التجريبية

- أعداد الرؤية لكل الجداول الـ13 (مالك، مساعد حر، مقيَّد بسنتر، مقيَّد بلا منح).
- كتابة المقيَّد: حضور لمجموعته يعدّي ويتملي بالـtrigger، لمجموعة تانية مرفوض، طالب بلا مجموعة مرفوض، مجموعة جديدة مرفوضة.
- امتحان ينشئه مقيَّد: بيشوفه قبل ربطه، وبيربطه بمجموعته بس.
- مساعد مقيَّد عنده `manage_members` ما يقدرش يفكّ قيد نفسه (الحارس `guard_groups_restricted`)، والمالك يقدر.
- نقل مجموعة لسنتر تاني بيغيّر الرؤية فورًا.
- **الرجوع**: ملف الرجوع اتطبّق على القاعدة التجريبية وبصمة نصوص السياسات (md5) بقت **مطابقة** لسياسات الإنتاج الحالية.
- migration P2 idempotent (اتشغّل مرتين من غير أخطاء).
- **اكتشاف أثناء الاختبار**: `INSERT ... RETURNING` على `exams` فشل لو السياسة بتعتمد على دالة بتقرا الجدول (الصف الجديد مش ظاهر للـsubselect)، فاتعالج بفحص `created_by = auth.uid()` على الصف نفسه.

## أسئلة P2 (اتحسمت فوق)

1. **الامتحان/الملزمة من مساعد مقيَّد**: نضيف `created_by` (المقترح)، ولا نمنع المساعد المقيَّد من إنشاء امتحانات خالص؟
2. **`student_archive_events`**: عمود مكرَّر جديد `group_remote_id` (أسرع، يحتاج trigger وbackfill)، ولا فحص عن طريق الطالب (أبطأ)؟
3. هل بنك الأسئلة يفضل مشترك؟ (المقترح: أيوه.)
4. بعد P2، المساعد المقيَّد بدون أي منح: يشوف شاشة فاضية، ولا نمنعه من تسجيل الدخول؟
