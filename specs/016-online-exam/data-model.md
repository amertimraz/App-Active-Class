# Phase 1 — Data Model: امتحان إلكتروني

## تغييرات قاعدة البيانات المحلية (sqflite)

`DATABASE_VERSION`: **22 → 23**. migration صاعد فقط (`_onUpgrade`, `if (oldVersion < 23)`), نمط v9–v22: `ALTER TABLE ADD COLUMN` و`CREATE TABLE IF NOT EXISTS` داخل `try/catch`.

### 1. أعمدة جديدة على `exams`

| العمود | النوع | افتراضي | المعنى |
|---|---|---|---|
| `is_online` | INTEGER | 0 | 1 = امتحان إلكتروني |
| `online_status` | TEXT | NULL | `draft` / `published` / `stopped` / `removed` (NULL للامتحانات الورقية) |
| `opens_at` | TEXT | NULL | ISO-8601 UTC — بداية النافذة |
| `closes_at` | TEXT | NULL | ISO-8601 UTC — نهاية النافذة |
| `duration_minutes` | INTEGER | NULL | مدة الحل لكل طالب |

**قواعد تحقق** (تُفرَض في `ExamController` قبل النشر — FR-007/FR-009):
- `opens_at < closes_at`
- `duration_minutes > 0`
- `duration_minutes ≤ (closes_at - opens_at) / 60`
- سؤال واحد على الأقل، مجموعة واحدة على الأقل

**انتقالات الحالة** (`online_status`):
```
(جديد) → draft
draft → published            [نشر — يرفع للسحابة]
published → draft             [إلغاء نشر — يشيل من السحابة؛ التسليمات المحلية تبقى]
published → stopped           [إيقاف الآن — closesAt effective = now]
published|stopped → removed   [حذف من الويب — يمسح السحابة؛ الدرجات المعتمَدة تبقى]
```
الامتحان الورقي: `is_online = 0`, `online_status = NULL` — صفر تغيير سلوك.

### 2. جدول جديد `exam_questions`

```
id                INTEGER PRIMARY KEY AUTOINCREMENT
exam_id           INTEGER NOT NULL          → exams(id) ON DELETE CASCADE
position          INTEGER NOT NULL          ترتيب العرض في التطبيق (الطالب يشوف ترتيبًا مخلوطًا)
type              TEXT NOT NULL             'true_false' | 'mcq'
text              TEXT NOT NULL             نص السؤال
options           TEXT                      JSON list<String> — للـ mcq (2..6)؛ للـ true_false: NULL أو ["صح","خطأ"]
correct_index     INTEGER NOT NULL          فهرس الإجابة الصحيحة داخل options (true_false: 0=صح 1=خطأ)
points            REAL NOT NULL DEFAULT 1   درجة السؤال (> 0)
created_at        TEXT
```
فهرس: `idx_exam_questions_exam_id (exam_id, position)`.
**لا أعمدة مزامنة** — خارج `sync_engine` في v1 (R7). `correct_index`/`options` **لا تُرفع للسحابة أبدًا**.

### 3. جدول جديد `exam_submissions`

```
id                INTEGER PRIMARY KEY AUTOINCREMENT
exam_id           INTEGER NOT NULL          → exams(id) ON DELETE CASCADE
student_id        INTEGER NOT NULL          → students(id) ON DELETE CASCADE
started_at        TEXT                      من attempts.startedAt السحابي (UTC)
submitted_at      TEXT                      من submissions.submittedAt السحابي (UTC)؛ NULL = لم يسلّم
answers_json      TEXT                      JSON map<questionId(String), chosenIndex(int)>
auto_score        REAL                      الدرجة المحسوبة تلقائيًا وقت السحب
final_grade       REAL                      الدرجة بعد تعديل المدرس (تبدأ = auto_score)
status            TEXT NOT NULL             'pending' | 'approved' | 'not_submitted'
auto_submitted    INTEGER NOT NULL DEFAULT 0
pulled_at         TEXT
```
فهرس فريد: `idx_exam_submissions_unique (exam_id, student_id)` — يضمن idempotency السحب (R9).

**انتقالات الحالة**:
```
(سحب تسليم) → pending
(طالب مسموح بلا تسليم بعد closesAt) → not_submitted
pending → approved            [المدرس اعتمد → يكتب final_grade في exam_grades]
not_submitted → approved      [المدرس علّمه غائبًا → exam_grades.is_absent = 1]
approved → pending            [المدرس ضغط "إعادة حساب" صراحةً فقط]
```

### 4. `exam_grades` — بدون تغيير

عند الاعتماد: `upsertGrade(examId, studentId, grade: final_grade, notes: 'امتحان إلكتروني — تصحيح تلقائي', isAbsent: status == not_submitted && marked absent)`.
مسار `upsertGrade` الموجود (`database_service.dart:1843`) + `ParentPortalService().pushStudentSummary` الموجود (يُستدعى من `saveGrade`) → خط النتائج كله يشتغل بلا تعديل.

---

## نموذج البيانات السحابي (Firestore)

جذر: `online_exams/{slug}` — `{slug}` = نفس `ParentPortalService.ensureSlug()`.

### `online_exams/{slug}` (مستند المدرس)

```jsonc
{
  "ownerUid": "<anon uid>",          // نمط parent_portal
  "deviceId": "<device id>",
  "active": true,                    // false عند قفل/انتهاء بوابة الأهالي
  "updatedAt": <serverTimestamp>
}
```

### `online_exams/{slug}/exams/{examId}` (امتحان منشور — examId = id المحلي كنص)

```jsonc
{
  "title": "اختبار الوحدة 3",
  "questionCount": 15,
  "totalPoints": 30,
  "opensAt": "2026-09-10T15:00:00.000Z",   // UTC
  "closesAt": "2026-09-10T16:30:00.000Z",  // UTC
  "durationMinutes": 30,
  "allowedGroupNames": ["3 ثانوي - سبت"],  // للعرض فقط
  "allowedCodes": { "A05": true, "A06": true },  // فحص العضوية (مفتاح واحد)
  "questions": [
    { "id": "q17", "type": "mcq", "text": "...", "options": ["...","...","...","..."] },
    { "id": "q18", "type": "true_false", "text": "...", "options": ["صح","خطأ"] }
  ],
  // ⚠️ لا correct_index ولا أي مفتاح إجابة — إطلاقًا (FR-034)
  "status": "published",             // published | stopped
  "publishedAt": <serverTimestamp>,
  "updatedAt": <serverTimestamp>
}
```
`question.id` = `"q" + local exam_questions.id` — يربط إجابة الطالب بالسؤال المحلي وقت التصحيح.

### `online_exams/{slug}/exams/{examId}/attempts/{code}_{last4}` (create-only)

```jsonc
{
  "code": "A05",
  "startedAt": <serverTimestamp>     // يُثبَّت لحظة أول فتح
}
```

### `online_exams/{slug}/exams/{examId}/submissions/{code}_{last4}` (create-only)

```jsonc
{
  "code": "A05",
  "answers": { "q17": 2, "q18": 0 },   // questionId → فهرس اختيار الطالب
  "submittedAt": <serverTimestamp>,
  "autoSubmitted": false,
  "startedAtClient": "2026-09-10T15:04:11.000Z"  // مرجعي فقط؛ الحقيقة من attempts
}
```

---

## الكيانات في الكود (Dart)

| Model | ملف | ملاحظات |
|---|---|---|
| `Exam` (موسّع) | `lib/models/exam_model.dart` | + `bool isOnline`, `OnlineExamStatus? onlineStatus`, `DateTime? opensAt`, `DateTime? closesAt`, `int? durationMinutes` + toMap/fromMap/copyWith (sentinel لـ nullable زي `reportMonth`) |
| `ExamQuestion` | `lib/models/exam_question_model.dart` (جديد) | `enum ExamQuestionType { trueFalse, mcq }`؛ `List<String> options`, `int correctIndex`, `double points`؛ `toCloudMap()` **بدون** correctIndex |
| `ExamSubmission` | `lib/models/exam_submission_model.dart` (جديد) | `enum SubmissionStatus { pending, approved, notSubmitted }`؛ `Map<int,int> answers` (questionId→chosen)؛ `double autoScore, finalGrade`؛ getters: `correctCount`, `perQuestionResult` |

---

## قواعد Firestore (ملخص — التفصيل في contracts/)

بلوك جديد على نمط `parent_portal/{slug}`:
- `online_exams/{slug}`: `read: if true`؛ `create/update` لصاحب الرابط (`ownerUid` أو تطابق `deviceId`).
- `online_exams/{slug}/exams/{examId}`: `read: if true` (مقفول بمعرفة `{slug}`)؛ `write` لصاحب الرابط فقط.
- `.../attempts/{docId}`: `create: if !exists(...)` + تحقق شكل؛ `read` لصاحب الرابط؛ `update/delete: if false`.
- `.../submissions/{docId}`: `create: if !exists(...)` + تحقق شكل (answers is map، submittedAt == request.time)؛ `read` لصاحب الرابط؛ `update/delete: if false`.
