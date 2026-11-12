# Data Model: إنشاء امتحان من ملف أو صورة

## على Supabase (`supabase/migration_ai_exam.sql`)

### ai_jobs — طلبات الذكاء الاصطناعي
| العمود | النوع | ملاحظة |
|---|---|---|
| id | uuid pk | يولّده التطبيق (idempotency) |
| owner_id | uuid → auth.users | |
| mode | text | `convert` / `generate` |
| params | jsonb | `{count, difficulty, language, pages}` بدون محتوى |
| status | text | `queued` → `running` → `done` / `failed` / `rejected` |
| fail_reason | text | `unreadable`, `not_educational`, `quota`, `provider_error`, `too_large`, `timeout`, `bad_output` |
| provider | text | اللي اشتغل فعلًا (للتكلفة والمراقبة) |
| result | jsonb | `{questions:[…], skipped:n, notes:[…]}` — تُحذف بعد 24 ساعة |
| charged | text | `free` / `extra` / null |
| created_at / started_at / finished_at | timestamptz | |

### ai_quota — الحصة والرصيد
`owner_id, month (date), free_limit, used, extra_balance` — unique(owner_id, month). نفس منطق `wa_quota`. الدوال `ai_reserve(owner)` و`ai_release(owner, kind)` (service-only).

### ai_config — إعدادات عامة (key/value jsonb)
`default_free_limit=10`, `default_provider='groq'`, `fallback_provider='claude'`, `max_images=10`, `max_bytes=15728640`, `max_questions=30`, `concurrency=3`, `kill_switch=false`, `groq_model`, `claude_model`.

### ai_teacher_settings
`owner_id, paused_by_admin, free_limit_override` (الأدمن فقط يكتب).

### RLS
المدرس يقرأ `ai_jobs` الخاصة به (الحالة والنتيجة) و`ai_quota` الخاصة به و`ai_config` للقراءة؛ كل الكتابة من الـ service (الـ worker). التطبيق مايكتبش في الجداول دي مباشرة.

## على الجهاز (SQLite، DB v44)

### exam_questions + `review_flags` (integer، افتراضي 0)
bitmask: 1 = `needs_review`، 2 = `has_figure`، 4 = `duplicate`. محلي فقط، لا يُزامَن ولا يدخل `toCloudMap`، ويتصفّر عند تعديل المدرس للسؤال (علامة مراجَع).

## كائنات التطبيق (بدون تخزين)
- **AiDraftQuestion**: `text, options[], correctIndex?, explanation?, needsReview, hasFigure, duplicate, sourcePage?`
- **AiExamRequest**: mode, images (bytes مضغوطة), count, difficulty, text?

## قواعد
- 2 ≤ options ≤ 6؛ `correct_index` ∈ [0, options.length) أو null.
- `count` ∈ [1, 30].
- حالات الطلب: `queued→running→done|failed|rejected`؛ `failed/rejected` = لا خصم.
- التكرار: نفس `job_id` يرجّع نفس النتيجة ولا يخصم تاني.
