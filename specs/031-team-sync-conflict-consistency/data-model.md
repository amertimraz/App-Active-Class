# Data Model: اتساق تعارضات مزامنة الفريق

لا كيانات جديدة. لا تغيير في مخطط قاعدة البيانات المحلية (v28). لا عمود جديد على الخادم. لا تغيير RLS.

## 1. تغيير الخادم — trigger `updated_at`

```sql
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- لكل جدول من الـ11:
CREATE TRIGGER trg_set_updated_at BEFORE INSERT OR UPDATE ON public.<table>
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

الجداول: `groups`, `students`, `attendance`, `payments`, `homework`, `exams`, `exam_groups`, `exam_grades`, `exam_questions`, `exam_submissions`, `bank_questions`.

- `updated_at` بقى **مضبوطًا من الخادم دائمًا** بغضّ النظر عن قيمة الـclient.
- `deleted_at` (soft-delete) لا يتأثّر — يظل يُضبَط من الـclient.
- الـtriggers القائمة `check_delete_*` (spec: صلاحيات الحذف) تبقى كما هي — trigger منفصل.

## 2. منطق التوفيق (حالة runtime في `_applyRemoteRow`)

عند اكتشاف dup منطقي:

| المدخل | المصدر |
|---|---|
| `localUpdatedAt` | `sync_updated_at` للصف المحلي المكرّر (بعد الـmigration = وقت خادم) |
| `remoteUpdatedAt` | `remote['updated_at']` الوارد (وقت خادم) |
| `localRemoteId` | `sync_remote_id` للصف المحلي المكرّر |
| `remoteRemoteId` | `remote['id']` الوارد |

**الإخراج**: `bool incomingWins` → لو true، `db.update` لحقول البيانات (بلا `sync_remote_id`).

## 3. `sync_conflict.dart` — دالة نقية

```dart
bool syncConflictIncomingWins({
  DateTime? localUpdatedAt,
  DateTime? remoteUpdatedAt,
  required String localRemoteId,
  required String remoteRemoteId,
});
```

| localUpdatedAt | remoteUpdatedAt | النتيجة |
|---|---|---|
| أي | `null` | false |
| `null` | ليس null | true |
| t1 | t2 > t1 | true |
| t1 | t2 < t1 | false |
| t1 | t2 == t1 | `remoteRemoteId < localRemoteId` معجميًا |

## 4. جداول متأثّرة بالتوفيق (الفهارس المنطقية القائمة)

| الجدول | المفتاح المنطقي |
|---|---|
| `attendance` | `student_id` + `substr(date,1,10)` |
| `homework` | `student_id` + `substr(date,1,10)` |
| `exam_groups` | `exam_id` + `group_id` |
| `exam_grades` | `exam_id` + `student_id` |
| `exam_submissions` | `exam_id` + `student_id` |

`groups`/`students`/`payments`/`exams` → لا توفيق (بلا فهرس منطقي)، تستفيد فقط من trigger `updated_at`.

## 5. لا تأثير

- الـLWW القائم في `_applyRemoteRow` step 1 (صف بنفس `remote_id`) — بلا تغيير في المنطق، فقط الطوابع صارت موحّدة.
- `_toLocalMap` — بلا تغيير (يخزّن `remote['updated_at']` كما هو).
- outbox / `_pushOne` / `_buildRemoteRow` — بلا تغيير.
