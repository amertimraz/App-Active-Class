# Data Model: إلغاء حصة اليوم وتعويضها

## 1. جدول `session_overrides` (جديد — DB v29)

### SQLite

| العمود | النوع | ملاحظة |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `group_id` | INTEGER NOT NULL | FK → `groups(id)` ON DELETE CASCADE |
| `date` | TEXT NOT NULL | `YYYY-MM-DD` (بلا وقت) |
| `type` | TEXT NOT NULL | `cancelled` / `makeup` / `extra` |
| `compensates_date` | TEXT | `YYYY-MM-DD` — للـ`makeup` فقط، وإلا NULL |
| `note` | TEXT | اختياري |
| `created_at` | TEXT | ISO |
| `sync_updated_at` | TEXT | مزامنة (spec 031 = وقت خادم بعد أول تعديل) |
| `sync_remote_id` | TEXT | مزامنة |

**فهرس فريد**: `UNIQUE(group_id, date)` — استثناء واحد لكل مجموعة/يوم (FR-012).

### Supabase `public.session_overrides`

`id uuid pk default gen_random_uuid()`, `team_id uuid`, `origin_device_id text`, `local_id bigint`, `group_remote_id uuid`, `date text`, `type text`, `compensates_date text`, `note text`, `updated_at timestamptz default now()`, `deleted_at timestamptz`, `UNIQUE(team_id, origin_device_id, local_id)`.
RLS: select/insert/update = `is_team_member(team_id) AND is_team_license_active(team_id)`. `REPLICA IDENTITY FULL` + realtime publication + `trg_set_updated_at`.

## 2. النموذج `SessionOverride` (`lib/models/session_override_model.dart`)

```dart
enum SessionOverrideType { cancelled, makeup, extra }

class SessionOverride {
  final int? id;
  final int groupId;
  final DateTime date;              // اليوم (منزوع الوقت)
  final SessionOverrideType type;
  final DateTime? compensatesDate;  // للـmakeup
  final String? note;
  final DateTime? createdAt;
  // toMap/fromMap: type ↔ 'cancelled'/'makeup'/'extra'، التواريخ ↔ 'YYYY-MM-DD'
}
```

`type` ↔ string: `SessionOverrideType.name` / `SessionOverrideType.values.byName(...)`.

## 3. المشتقّات (override-aware schedule)

| الدالة | التعديل |
|---|---|
| `AttendanceController.groupHasSessionOnDay(g, day)` | `cancelled` → false؛ `makeup`/`extra` → true؛ لا استثناء → المنطق القائم |
| `_countExpectedForGroup(g, range)` | `n = عدّ الجدول - عدد cancelled ضمن range + عدد (makeup∪extra) ضمن range التي تواريخها ليست يوم جدول` |
| `groupsForDay(groups, day)` | مجموعة تظهر لو `groupHasSessionOnDay(g, day)` |
| `getExpectedSessionsPerGroup` | يستدعي `_countExpectedForGroup` المعدَّلة |

**دالة نقية للاختبار**: `bool resolveHasSession({required bool scheduleSays, SessionOverride? override})`.

## 4. حالة runtime — `SessionOverrideController` (GetX)

| الحقل/الدالة | الوصف |
|---|---|
| `RxList<SessionOverride> overrides` | كل الاستثناءات المحمّلة (تُحمَّل عند فتح شاشة الحضور / تفاصيل الطالب) |
| `SessionOverride? overrideFor(int groupId, DateTime day)` | بحث `(groupId, ymd)` |
| `Future<void> load()` | من `DatabaseService.getAllSessionOverrides()` |
| `Future<String?> cancelSession(...)` / `createMakeup(...)` / `createExtra(...)` / `deleteOverride(...)` | CRUD + قواعد التحقّق (قرار 7) → رسالة خطأ أو null |

## 5. دوال `DatabaseService` جديدة

- `Future<List<SessionOverride>> getAllSessionOverrides()`
- `Future<SessionOverride?> getSessionOverride(int groupId, DateTime day)`
- `Future<int> insertSessionOverride(SessionOverride o)` (+ `_queueSync`)
- `Future<int> deleteSessionOverride(int id)` (+ `_queueDelete`)
- `Future<int> countAttendanceForGroupOnDay(int groupId, DateTime day)` — للحوار "هيتمسح N"
- `Future<int> deleteAttendanceForGroupOnDay(int groupId, DateTime day)` — عند تأكيد الإلغاء (+ `_queueDelete` لكل صف)

## 6. لا تأثير

- `PricingHelper` — صفر تغيير.
- صفوف الحضور القائمة — لا صفوف وهمية للاستثناءات؛ سجل الطالب دمج عرض فقط.
- `attendance`/`groups` schema — بلا تغيير.
