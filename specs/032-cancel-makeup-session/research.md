# Research: إلغاء حصة اليوم وتعويضها

## قرار 1 — جدول `session_overrides` (مستقل نسبيًا، مُزامَن)

**القرار**: جدول جديد بأعمدة: `id` (PK)، `group_id` (FK → groups، ON DELETE CASCADE)، `date` (TEXT، `YYYY-MM-DD`)، `type` (TEXT: `cancelled`/`makeup`/`extra`)، `compensates_date` (TEXT nullable — للـmakeup)، `note` (TEXT nullable)، `created_at` (TEXT)، `sync_updated_at` (TEXT)، `sync_remote_id` (TEXT). فهرس فريد على `(group_id, date)` (يمنع استثناءين لنفس المجموعة/اليوم — FR-012).

**السبب**: نمط `bank_questions`/`student_follow_ups` — جدول جديد بأعمدة مزامنة من الإنشاء، صفر تأثير على جداول قائمة. الفهرس الفريد = المفتاح المنطقي للتوفيق في المزامنة.

**البدائل المرفوضة**: عمود JSON على `groups` — يصعّب الاستعلام بمدى تواريخ والمزامنة الحبيبية.

---

## قرار 2 — DB v28 → v29

**القرار**: `DATABASE_VERSION = 29`. في `_onUpgrade`: `if (oldVersion < 29) { await db.execute(_sessionOverridesTableSql); await db.execute(_sessionOverridesIndexSql); }` (try/catch صامت زي spec 025). الجدول يُنشَأ كذلك في `_createTables` للتثبيت الجديد.

---

## قرار 3 — migration Supabase

**القرار**: `supabase/migration_session_overrides.sql`:
- `CREATE TABLE public.session_overrides (id uuid default gen_random_uuid() primary key, team_id uuid not null, origin_device_id text not null, local_id bigint not null, group_remote_id uuid, date text not null, type text not null, compensates_date text, note text, updated_at timestamptz default now(), deleted_at timestamptz, unique(team_id, origin_device_id, local_id))`.
- RLS: `enable row level security` + 3 سياسات (`select`/`insert`/`update`) = `is_team_member(team_id) AND is_team_license_active(team_id)` (نسخ من `attendance`).
- `alter table session_overrides replica identity full;`
- `alter publication supabase_realtime add table session_overrides;`
- `trg_set_updated_at` (spec 031).
- يُطبَّق عبر SSH (نمط specs 021/024/025).

**ملاحظة**: `group_remote_id` (uuid) لا `group_id` (رقم محلي) — نفس نمط ربط الحضور بالطالب في `_buildRemoteRow`.

---

## قرار 4 — دوال الجدولة override-aware

**القرار**: `SessionOverrideController` يحمل `RxList<SessionOverride> overrides` ويوفّر:
```dart
SessionOverride? overrideFor(int groupId, DateTime day);  // بحث (groupId, ymd)
```
`AttendanceController` (بعد اكتساب `SessionOverrideController`):
- `groupHasSessionOnDay(group, day)`:
  ```
  final o = soCtrl.overrideFor(group.id!, day);
  if (o?.type == cancelled) return false;
  if (o != null && (o.type == makeup || o.type == extra)) return true;
  // بلا استثناء → المنطق القائم (schedule)
  ```
- `_countExpectedForGroup(group, range)`: بعد العدّ من الجدول، اطرح عدد `cancelled` لهذه المجموعة ضمن `range`، وأضف عدد `makeup`+`extra` ضمن `range` **التي تواريخها ليست في الجدول أصلًا** (لتفادي العدّ المزدوج لو التعويض صادف يوم جدول).
- `groupsForDay(groups, day)`: مجموعة تظهر لو `groupHasSessionOnDay` (بعد الأخذ في الاعتبار الاستثناءات).

**السبب**: `SessionOverrideController` منفصل يبقي `AttendanceController` نظيفًا؛ الـhelper نقطة واحدة.

**استخراج للاختبار**: دالة `resolveHasSession({bool scheduleSays, SessionOverride? override})` نقية + `expectedCountDelta(overrides, range, scheduleWeekdays)` — قابلة للعزل.

---

## قرار 5 — سجل الطالب: دمج عرض فقط

**القرار**: في `student_details_page` قسم الحضور و`parent_portal_service.buildStudentSummary`:
- ابنِ قائمة موحّدة: عناصر `Attendance` القائمة + عناصر مشتقّة من `overrides` لمجموعة الطالب الحالية (`type == cancelled` → عنصر "الحصة اتلغت" بتاريخه).
- لعناصر الحضور: لو تاريخها يطابق override `makeup`/`extra` لمجموعة الطالب → أضف لِيبل ("• حصة معوّضة عن يوم X" / "• حصة إضافية").
- رتّب بالتاريخ تنازليًا. `cancelled` لا يُحتسب في عدّادات النِسب.

**السبب**: صفر صفوف وهمية مخزَّنة = صفر تعقيد في الفوترة/المزامنة/الإحصاء الأساسي. FR-013/FR-014.

**قيد**: طالب انتقل بين المجموعات يرى استثناءات مجموعته الحالية فقط (موثّق).

---

## قرار 6 — الفوترة: صفر كود

**القرار**: لا لمس `PricingHelper`. طالب per-session: ملغية = مفيش صف حضور = مفيش رسم؛ معوّضة/إضافية محضورة = صف حضور = `monthlyDue` per-session يعدّه كحصة عادية. رصيد مقدّم لحصة أُلغيت + اتمسح حضورها = المديونية تنزل تلقائيًا (`_remainingThrough` يعيد الحساب) → رصيد FIFO للحصة التالية.

**السبب**: الفوترة كلها مبنية على صفوف الحضور بالفعل (spec 026). الإلغاء = حذف صفوف، التعويض = صفوف جديدة.

---

## قرار 7 — قواعد التحقّق

| القاعدة | السلوك |
|---|---|
| إلغاء لمجموعة/يوم بلا حصة مجدولة | يُرفض ("مفيش حصة مجدولة اليوم") — FR-002 |
| إلغاء لمجموعة بلا جدول مُدخَل | يُرفض (`groupHasSessionOnDay` true افتراضيًا → الإلغاء بلا معنى) — افتراض |
| إلغاء وفيه حضور مسجّل | حوار "هيتمسح N سجل" → عند التأكيد يمسحهم ثم ينشئ `cancelled` — FR-003 |
| تعويض بتاريخ فيه `cancelled` لنفس المجموعة | يُرفض — FR-010 |
| حذف `cancelled` وله `makeup` قائم | يُرفض ("احذف التعويض الأول") — افتراض |
| حذف `makeup`/`extra` وفيه حضور | حوار تأكيد بالعدد — FR-011 |

---

## ملخّص الحسم

| # | الموضوع | القرار |
|---|---|---|
| 1 | الجدول | `session_overrides` مستقل، مُزامَن، فهرس فريد `(group_id, date)` |
| 2 | DB | v28 → v29، جدول جديد فقط |
| 3 | Supabase | migration عبر SSH: جدول + RLS + realtime + trigger |
| 4 | الجدولة | `SessionOverrideController` + 3 دوال `AttendanceController` override-aware |
| 5 | سجل الطالب | دمج عرض فقط، صفر صفوف وهمية |
| 6 | الفوترة | صفر كود — من صفوف الحضور |
| 7 | التحقّق | 6 قواعد (إلغاء بلا جدول يُرفض، حذف إلغاء له تعويض يُرفض) |
