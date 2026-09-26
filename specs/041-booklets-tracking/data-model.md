# Phase 1 Data Model: الملازم والكتب

كل الجداول بأعمدة المزامنة القياسية (`sync_updated_at`, `sync_remote_id`) زي باقي الجداول المتزامنة. التسمية تتبع نمط `TABLE_*`/`COL_*` في `constants.dart`.

## SQLite (محلي، DB v35)

### `booklets`
| العمود | النوع | ملاحظة |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `name` | TEXT NOT NULL | اسم الملزمة/الكتاب |
| `price` | REAL NOT NULL DEFAULT 0 | ≥ 0؛ 0 = مجانية |
| `created_at` | TEXT | ISO-8601 |
| `sync_updated_at`, `sync_remote_id` | TEXT | |

### `booklet_groups` (ربط ملزمة ↔ مجموعات)
| العمود | النوع | ملاحظة |
|---|---|---|
| `id` | INTEGER PK | |
| `booklet_id` | INTEGER NOT NULL | FK → booklets ON DELETE CASCADE |
| `group_id` | INTEGER NOT NULL | FK → groups ON DELETE CASCADE |
| sync cols | | |
UNIQUE INDEX `(booklet_id, group_id)`.

### `booklet_records` (كسولة — تسليم/استثناء)
| العمود | النوع | ملاحظة |
|---|---|---|
| `id` | INTEGER PK | |
| `booklet_id` | INTEGER NOT NULL | FK → booklets CASCADE |
| `student_id` | INTEGER NOT NULL | FK → students CASCADE |
| `delivered` | INTEGER NOT NULL DEFAULT 0 | 0/1 |
| `delivered_at` | TEXT | ISO-8601، NULL لو لم يُسلَّم |
| `excluded` | INTEGER NOT NULL DEFAULT 0 | 0/1 |
| sync cols | | |
UNIQUE INDEX `(booklet_id, student_id)`. غياب الصف ≡ (delivered=0, excluded=0).

### `booklet_payments`
| العمود | النوع | ملاحظة |
|---|---|---|
| `id` | INTEGER PK | |
| `booklet_id` | INTEGER NOT NULL | FK → booklets CASCADE |
| `student_id` | INTEGER NOT NULL | FK → students CASCADE |
| `amount` | REAL NOT NULL | > 0 |
| `date` | TEXT NOT NULL | ISO-8601 |
| sync cols | | |
INDEX `(booklet_id, student_id)`.

## Postgres (Supabase)
نفس الأعمدة + `team_id uuid`, `origin_device_id text`, `local_id integer`, `updated_at`, `deleted_at`، والمراجع كـuuid: `booklet_remote_id`, `group_remote_id`, `student_remote_id` (FK → الجداول المقابلة ON DELETE CASCADE). `unique(team_id, origin_device_id, local_id)`. تفاصيل RLS/triggers في research.md #5.

## الكيانات في Dart (`lib/models/booklet_model.dart`)
`Booklet{id,name,price,createdAt}`، `BookletRecord{id,bookletId,studentId,delivered,deliveredAt,excluded}`، `BookletPayment{id,bookletId,studentId,amount,date}` — كلها `toMap/fromMap/copyWith` بنمط `Payment`/`Attendance`.

## القيم المشتقة (لا تُخزَّن — `booklet_math.dart`)
| القيمة | التعريف |
|---|---|
| المدفوع | Σ `booklet_payments.amount` لنفس (booklet, student) |
| المتبقي | `max(0, price − paid)` |
| زيادة الدفع | `max(0, paid − price)` |
| حالة الدفع | `full` لو `price==0` أو `paid ≥ price`؛ `partial` لو `0<paid<price`؛ `none` غير ذلك |
| مؤهَّل | الطالب في مجموعة من `booklet_groups`، غير مؤرشف، و`excluded==0` |
| "متبقي ملازم" للطالب | Σ المتبقي على كل ملزمة هو مؤهَّل لها |

## قواعد صلاحية
- `price ≥ 0`، `name` غير فارغ.
- دفعة: `amount > 0` وغير أكبر من المتبقي وقت التسجيل (FR-013)؛ رفض/تنبيه صريح عند التجاوز.
- استثناء لا يمسح دفعات.
- تحويل التسليم قابل للتراجع في أي اتجاه، ولا يؤثر على الدفع.

## انتقالات الحالة
- تسليم: `لم يُسلَّم ⇄ تم` مستقل تمامًا عن الدفع.
- دفع: مشتق — يتحرك تلقائيًا بإضافة/حذف دفعة أو تعديل السعر.
