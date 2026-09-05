# Contract: supabase/migration_online_exam_sync.sql

## الملف

`supabase/migration_online_exam_sync.sql` — نسخة من نمط `supabase/migration_exams.sql` بالحرف.

## ترويسة التعليق (إلزامية — نمط الملفات الحالية)

```sql
-- supabase/migration_online_exam_sync.sql
--
-- إضافة فوق migration_exams.sql (المفروض متطبّق على السيرفر) —
-- شغّله لوحده مرة واحدة على SQL Editor في لوحة Supabase قبل
-- توزيع نسخة التطبيق اللي فيها مزامنة الامتحانات الإلكترونية.
--
-- ⚠️ الميزة (المساعد يشوف/يصحّح امتحانات إلكترونية عملها المدرس)
-- معطّلة وظيفيًا حتى تشغيل الملف ده — لكن **مش هتكسر** مزامنة
-- الواجب/الحضور/الدرجات لو ماتشغّلش (قناة Realtime منفصلة للجداول
-- دي — spec 024 US3).
--
-- بيضيف:
--   1. جدول exam_questions (أسئلة الامتحان — بتحمل الإجابة الصحيحة،
--      مقبول داخل تخزين الفريق زي exam_grades، مش زي مستند الطالب
--      العام على Firestore).
--   2. جدول exam_submissions (تسليمات الطلاب + حالتها).
--   3. أعمدة أونلاين على exams الموجود (is_online, online_status,
--      opens_at, closes_at, duration_minutes).
--   4. RLS (is_team_member + is_team_license_active)، soft-delete
--      trigger (صلاحية delete_attendance)، وإضافة للـsupabase_realtime.
```

## المحتوى (ملخص — التفاصيل في [data-model.md](../data-model.md) §2،§3،§4،§5)

1. `create table if not exists public.exam_questions (...)` — الأعمدة في data-model §2
2. `create table if not exists public.exam_submissions (...)` — data-model §3
3. `alter table public.exams add column if not exists is_online boolean not null default false;` + الأربعة الباقيين (data-model §4)
4. `enable row level security` + `*_select/*_insert/*_update` policies للجدولين (نسخ صياغة `migration_exams.sql`)
5. `create or replace function public.check_delete_online_exam_sync()` (نسخة من `check_delete_exams` — صلاحية `delete_attendance`) + triggers على الجدولين
6. `do $$ ... alter publication supabase_realtime add table ... if not exists ...` للجدولين

## اختبار قبول النشر

- شغّل الملف على قاعدة اختبار → صفر أخطاء، الجداول موجودة، في الـpublication.
- شغّله تاني → صفر أخطاء (`if not exists` / `create or replace` — idempotent).
- شخص غير مطّلع على الكود ينفّذه من الترويسة في < 5 دقائق (SC-006): نسخ الملف → SQL Editor → Run.

## بعد النشر

- FR-015: التطبيق ما يحتاجش أي خطوة — `_channelX` تعيد الاتصال تلقائيًا وتبدأ تزامن الجدولين، و`_drainOutbox` يدفع صفوفهم المتراكمة.
