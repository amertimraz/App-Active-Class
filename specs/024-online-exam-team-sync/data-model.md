# Phase 1 Data Model: مزامنة الامتحانات الإلكترونية عبر الفريq 024

## 1. ترقية SQLite المحلية

**النسخة**: `DATABASE_VERSION` الحالي + 1 (v26→v27 لو spec 023 نزل الأول، وإلا v25→v26).

### `exam_questions` — أعمدة مزامنة جديدة
```
ALTER TABLE exam_questions ADD COLUMN sync_updated_at TEXT;
ALTER TABLE exam_questions ADD COLUMN sync_remote_id  TEXT;
```
(الثوابت `COL_SYNC_UPDATED_AT` / `COL_SYNC_REMOTE_ID` موجودة بالفعل.)

### `exam_submissions` — أعمدة مزامنة جديدة
```
ALTER TABLE exam_submissions ADD COLUMN sync_updated_at TEXT;
ALTER TABLE exam_submissions ADD COLUMN sync_remote_id  TEXT;
```

- `_examQuestionsTableSql` / `_examSubmissionsTableSql` (للقواعد الجديدة) يضيفوا العمودين كذلك.
- أسئلة/تسليمات قديمة: `sync_* = NULL` → تُدفَع في أول دورة مزامنة (نمط أي صف جديد).

## 2. `exam_questions` — الجدول البعيد (Supabase)

```sql
create table public.exam_questions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  exam_remote_id uuid references public.exams(id) on delete cascade,
  position integer not null default 0,
  type text not null,                 -- true_false | mcq
  text text not null,
  options text,                       -- JSON list<String>
  correct_index integer not null default 0,
  points double precision not null default 1,
  image_url text,
  explanation text,                   -- spec 023 (nullable — يشتغل قبل/بعد 023)
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);
```

**mapping** (`sync_engine.dart`):
- `_pkCol`: `TABLE_EXAM_QUESTIONS => COL_EQ_ID`
- `_buildRemoteRow`: يحلّ `exam_remote_id` من `_localRemoteId(TABLE_EXAMS, COL_EXAM_ID, examLocalId)` — `return null` لو لسه ملوش remote_id (الامتحان الأب لسه ما اتزامنش). باقي الحقول من `payload[COL_EQ_*]`. `options` نص JSON زي ما هو. `explanation`: `payload[COL_EQ_EXPLANATION]` (قد يكون مفتاح غير موجود لو spec 023 لسه — `?? null`).
- `_toLocalMap`: يحلّ `COL_EQ_EXAM_ID` من `_localIdForRemote(TABLE_EXAMS, ...)` — `return null` لو الامتحان الأب مش محلي. `is_absent`-style: مفيش boolean هنا. `correct_index`/`points` أرقام مباشرة.
- `_refreshUiForTable`: `ExamController.loadExams()`.
- **بلا dedup خاص** — السؤال بيتعرّف بـ`remote_id` (تحديث) أو insert جديد؛ مفيش UNIQUE محلي غير الـPK.

## 3. `exam_submissions` — الجدول البعيد (Supabase)

```sql
create table public.exam_submissions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  exam_remote_id uuid references public.exams(id) on delete cascade,
  student_remote_id uuid references public.students(id) on delete cascade,
  started_at text,
  submitted_at text,
  answers_json text,
  auto_score double precision,
  final_grade double precision,
  status text not null default 'pending',   -- pending | approved | not_submitted | voided
  auto_submitted boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);
```

**mapping**:
- `_pkCol`: `TABLE_EXAM_SUBMISSIONS => COL_ES_ID`
- `_buildRemoteRow`: يحلّ `exam_remote_id` + `student_remote_id` (الاتنين `return null` لو الأب لسه ما اتزامنش — نمط `exam_grades`). `auto_submitted`: `(payload[COL_ES_AUTO_SUBMITTED] as int? ?? 0) == 1` → boolean. **`pulled_at` مش موجود** (محلي، R3).
- `_toLocalMap`: يحلّ `COL_ES_EXAM_ID` + `COL_ES_STUDENT_ID` من `_localIdForRemote` (`return null` لو أي أب مفقود). `COL_ES_AUTO_SUBMITTED: (remote['auto_submitted'] as bool? ?? false) ? 1 : 0`. `COL_ES_PULLED_AT` **مش متضمّن** (يفضل NULL على الجهاز المستقبِل).
- **dedup وارد**: قبل `_insertWithCodeRetry` في `_applyRemoteRow` — فحص `WHERE exam_id=? AND student_id=?`؛ لو موجود، `debugPrint` + `return` (نمط `TABLE_EXAM_GRADES`).
- `_refreshUiForTable`: `ExamController.loadExams()`.

## 4. `exams` — أعمدة أونلاين جديدة (البعيد)

```sql
alter table public.exams add column if not exists is_online boolean not null default false;
alter table public.exams add column if not exists online_status text;
alter table public.exams add column if not exists opens_at text;
alter table public.exams add column if not exists closes_at text;
alter table public.exams add column if not exists duration_minutes integer;
```

**mapping** (يُضاف لـ`_buildRemoteRow(TABLE_EXAMS)` و`_toLocalMap(TABLE_EXAMS)` الموجودين):
- `_buildRemoteRow`: `'is_online': (payload[COL_EXAM_IS_ONLINE] as int? ?? 0) == 1`, `'online_status': payload[COL_EXAM_ONLINE_STATUS]`, `'opens_at': payload[COL_EXAM_OPENS_AT]`, `'closes_at': payload[COL_EXAM_CLOSES_AT]`, `'duration_minutes': payload[COL_EXAM_DURATION_MIN]`.
- `_toLocalMap`: `COL_EXAM_IS_ONLINE: (remote['is_online'] as bool? ?? false) ? 1 : 0`, والباقي مباشرة.
- **دوال الكتابة**: `setExamOnlineFields` و`setExamOnlineStatus` (وأي دالة بتلمس الأعمدة دي) تنادي `_queueSync(TABLE_EXAMS, examId, 'update', payload: <صف exams المحدَّث>)` — دلوقتي مش بتعمل queue.

## 5. RLS + soft-delete + publication (نسخ `migration_exams.sql`)

لكل جدول جديد:
- `enable row level security`
- `*_select` / `*_insert` / `*_update` policies = `is_team_member(team_id) and is_team_license_active(team_id)`
- لا DELETE policy — soft-delete عبر `deleted_at`
- trigger `check_delete_*` يستخدم صلاحية `delete_attendance` (زي الامتحانات)
- `alter publication supabase_realtime add table public.exam_questions` / `... exam_submissions` (داخل `do $$ ... if not exists ...`)
- أعمدة `exams` الجديدة: الجدول أصلاً في الـpublication، مفيش خطوة إضافية.

## 6. `_tables` — الترتيب الجديد

```
TABLE_GROUPS,
TABLE_STUDENTS,
TABLE_ATTENDANCE,
TABLE_PAYMENTS,
TABLE_HOMEWORK,
TABLE_EXAMS,
TABLE_EXAM_QUESTIONS,   // جديد — بعد exams
TABLE_EXAM_GROUPS,
TABLE_EXAM_GRADES,
TABLE_EXAM_SUBMISSIONS, // جديد — بعد exams + students
```

- `exam_questions` بعد `exams` (محتاج `exam_remote_id`).
- `exam_submissions` بعد `exams` و`students` (محتاج الاتنين). موضعه في آخر القائمة آمن.

## 7. الكيانات حسب القصة

| قصة | تغييرات البيانات |
|---|---|
| US1 أسئلة | `exam_questions` sync cols + جدول بعيد + mapping؛ حقول أونلاين على `exams` (sync + أعمدة بعيدة) |
| US2 تسليمات | `exam_submissions` sync cols + جدول بعيد + mapping + dedup |
| US3 مرونة | صفر بيانات — قناة Realtime ثانية + تثبيت FR-016 |

## 8. ثابت — مستند Firestore العام

`ExamQuestion.toCloudMap()` بلا تغيير: `{id, type, text, options, imageUrl?}` — لا `correctIndex` ولا `points` ولا `explanation`. اختبار وحدة يفرض. المزامنة الجديدة كلها في Supabase (تخزين الفريq)، منفصلة تمامًا عن مسار Firestore.
