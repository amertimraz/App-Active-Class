# Phase 1 Data Model: بنك الأسئلة 025

## 1. ترقية SQLite (v27 → v28)

جدول جديد بالكامل — صفر ALTER على جداول موجودة. نمط `student_follow_ups` (spec 021).

### `bank_questions` (محلي)
```sql
CREATE TABLE IF NOT EXISTS bank_questions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  type           TEXT NOT NULL,          -- true_false | mcq
  text           TEXT NOT NULL,
  options        TEXT,                   -- JSON list<String>
  correct_index  INTEGER NOT NULL DEFAULT 0,
  points         REAL NOT NULL DEFAULT 1,
  image_url      TEXT,
  explanation    TEXT,
  subject        TEXT NOT NULL DEFAULT '',
  tags           TEXT,                   -- JSON list<String>؛ NULL/[] = بلا وسوم
  created_at     TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at     TEXT,                   -- COL_SYNC_UPDATED_AT
  remote_id      TEXT                    -- COL_SYNC_REMOTE_ID
);
CREATE INDEX IF NOT EXISTS idx_bank_questions_subject ON bank_questions(subject);
```

**ثوابت `constants.dart`**:
```
DATABASE_VERSION: 27 → 28
TABLE_BANK_QUESTIONS = 'bank_questions'
COL_BQ_ID='id', COL_BQ_TYPE='type', COL_BQ_TEXT='text', COL_BQ_OPTIONS='options',
COL_BQ_CORRECT_INDEX='correct_index', COL_BQ_POINTS='points', COL_BQ_IMAGE_URL='image_url',
COL_BQ_EXPLANATION='explanation', COL_BQ_SUBJECT='subject', COL_BQ_TAGS='tags',
COL_BQ_CREATED_AT='created_at'
ROUTE_QUESTION_BANK = '/question_bank'
```
(`COL_SYNC_UPDATED_AT` / `COL_SYNC_REMOTE_ID` موجودة.)

- `_onCreate`: `await db.execute(_bankQuestionsTableSql)` + الفهرس.
- `_onUpgrade`: `if (oldVersion < 28) { try { await db.execute(_bankQuestionsTableSql); await db.execute(_bankQuestionsIndexSql); } catch (_) {} }`

## 2. `BankQuestion` — الموديل

**ملف**: `lib/models/bank_question_model.dart` (جديد)

| الحقل | النوع | ملاحظات |
|---|---|---|
| `id` | `int?` | |
| `type` | `ExamQuestionType` | يُعاد استخدام enum من `exam_question_model.dart` |
| `text` | `String` | |
| `options` | `List<String>` | |
| `correctIndex` | `int` | |
| `points` | `double` | |
| `imageUrl` | `String?` | |
| `explanation` | `String?` | spec 023 |
| `subject` | `String` | افتراضي `''` |
| `tags` | `List<String>` | افتراضي `[]` |
| `createdAt` | `DateTime?` | |

**دوال**:
- `bool get isValid` — `text` غير فارغ، `options.length` بين 2 و6 وكلها غير فارغة، `correctIndex` في المدى، `points > 0`. **`subject` مش شرط.**
- `toMap()` / `fromMap()` — أعمدة `bank_questions`. `options`/`tags` عبر `jsonEncode`/`jsonDecode`.
- `copyWith({... Object? imageUrl = _unset, Object? explanation = _unset ...})` — نمط sentinel.
- `ExamQuestion toExamQuestion({required int examId, required int position})` — ينسخ المحتوى (بلا `subject`/`tags`) لصف `exam_questions`.
- `factory BankQuestion.fromExamQuestion(ExamQuestion q, {String subject = '', List<String> tags = const []})`.

## 3. `bank_questions` — الجدول البعيد (Supabase)

```sql
create table if not exists public.bank_questions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  origin_device_id text not null,
  local_id integer not null,
  type text not null,
  text text not null,
  options text,
  correct_index integer not null default 0,
  points double precision not null default 1,
  image_url text,
  explanation text,
  subject text not null default '',
  tags text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (team_id, origin_device_id, local_id)
);
```
- RLS: `*_select`/`*_insert`/`*_update` = `is_team_member(team_id) and is_team_license_active(team_id)`.
- لا DELETE policy — soft-delete عبر `deleted_at`.
- trigger `trg_check_delete_bank_questions` يعيد استخدام `public.check_delete_exams()` (صلاحية `delete_attendance`).
- `alter publication supabase_realtime add table public.bank_questions` (داخل `do $$ if not exists`).

## 4. mapping في `sync_engine.dart`

- `_tables`: `TABLE_BANK_QUESTIONS` بعد `TABLE_EXAMS` (ملهوش أب فالموضع حر).
- `_extendedTables`: `[TABLE_EXAM_QUESTIONS, TABLE_EXAM_SUBMISSIONS, TABLE_BANK_QUESTIONS]`.
- `_pkCol`: `TABLE_BANK_QUESTIONS => COL_BQ_ID`.
- `_buildRemoteRow(TABLE_BANK_QUESTIONS, localId, payload)`:
  ```
  return {
    ...base,   // team_id, origin_device_id, local_id, updated_at من payload[COL_SYNC_UPDATED_AT]
    'type': payload[COL_BQ_TYPE], 'text': payload[COL_BQ_TEXT],
    'options': payload[COL_BQ_OPTIONS], 'correct_index': payload[COL_BQ_CORRECT_INDEX],
    'points': payload[COL_BQ_POINTS], 'image_url': payload[COL_BQ_IMAGE_URL],
    'explanation': payload[COL_BQ_EXPLANATION], 'subject': payload[COL_BQ_SUBJECT],
    'tags': payload[COL_BQ_TAGS],
  };
  ```
- `_toLocalMap(TABLE_BANK_QUESTIONS, remote)`:
  ```
  return {
    COL_BQ_TYPE: remote['type'], COL_BQ_TEXT: remote['text'],
    COL_BQ_OPTIONS: remote['options'], COL_BQ_CORRECT_INDEX: remote['correct_index'],
    COL_BQ_POINTS: remote['points'], COL_BQ_IMAGE_URL: remote['image_url'],
    COL_BQ_EXPLANATION: remote['explanation'], COL_BQ_SUBJECT: remote['subject'] ?? '',
    COL_BQ_TAGS: remote['tags'],
    COL_SYNC_UPDATED_AT: updatedAt, COL_SYNC_REMOTE_ID: remote['id'],
  };
  ```
- `_refreshUiForTable`: `case TABLE_BANK_QUESTIONS:` → `QuestionBankController.refresh()` (لو مسجّل).
- **بلا dedup** في `_applyRemoteRow` — ملوش UNIQUE محلي.

## 5. `DatabaseService` — دوال البنك

| دالة | السلوك |
|---|---|
| `getBankQuestions()` | كل الصفوف، مرتّبة `created_at DESC` → `List<BankQuestion>` |
| `insertBankQuestion(BankQuestion q)` | insert (+ `created_at`/`sync_updated_at` = now) → `_queueRowUpsert` → يرجّع id |
| `updateBankQuestion(BankQuestion q)` | update (+ `sync_updated_at` = now، بلا لمس `remote_id`) → `_queueRowUpsert` |
| `deleteBankQuestion(int id)` | جلب `remote_id` → delete → `_queueDelete` |
| `distinctSubjects()` | `SELECT DISTINCT subject ... WHERE subject != '' ORDER BY subject` → `List<String>` |

(الوسوم والبحث النصّي: يُحسبان في `QuestionBankController` من القائمة المحمّلة — R3.)

## 6. `duplicateExam` — ما يُنسخ / ما لا يُنسخ (US3)

`ExamController.duplicateExam(int examId)`:
1. `src = exams.firstWhere(id == examId)` — لازم `src.isOnline`.
2. `newId = await _db.insertExam(Exam(name: '${src.name} (نسخة)', date: DateTime.now(), maxGrade: src.maxGrade, passingGrade: src.passingGrade, reportMonth: src.reportMonth), const [], skipSync: true)`.
3. `await _db.setExamOnlineFields(newId, isOnline: true, status: OnlineExamStatus.draft, durationMinutes: src.durationMinutes)` — **بلا `opensAt`/`closesAt`**.
4. `final qs = await _db.getQuestionsForExam(examId); await _db.replaceExamQuestions(newId, qs.map((q) => q.copyWith(id: null, examId: newId)).toList())` — نسخ مستقل (id = null → صفوف جديدة).
5. `await loadExams(); return newId;` → المحرّر يفتح على `newId`.

| يُنسخ | لا يُنسخ |
|---|---|
| الاسم + " (نسخة)" | المجموعات المرتبطة (`groupIds = []`) |
| كل الأسئلة (نسخ مستقل) | المواعيد (`opensAt`/`closesAt`) |
| المدة | التسليمات (`exam_submissions`) |
| الدرجة الكلية / درجة النجاح | الدرجات (`exam_grades`) |
| الشهر المحسوب له | حالة النشر (تبدأ `draft`) |

## 7. ثابت — مستند Firestore العام

الأسئلة المنسوخة من البنك تدخل `exam_questions` كصفوف عادية. عند النشر، `ExamQuestion.toCloudMap()` (بلا `correctIndex`/`points`/`explanation`) — بلا تغيير. اختبار `exam_question_cloud_map_test.dart` (spec 023) يظل يفرض.

## الكيانات حسب القصة

| قصة | كيانات |
|---|---|
| US1 بنك | `bank_questions` (SQLite + Supabase) + `BankQuestion` + DB v28 + mapping مزامنة |
| US2 محرّر | لا كيان جديد — `BankQuestion.toExamQuestion` / `fromExamQuestion` + `pickRandom` |
| US3 تكرار | لا كيان جديد — `duplicateExam` يعيد استخدام `insertExam`/`replaceExamQuestions` |
