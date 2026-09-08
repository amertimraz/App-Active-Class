# Research: اتساق تعارضات مزامنة الفريق

## قرار 1 — وقت الخادم: trigger لا تغيير في الـclient

**القرار**: migration Supabase يضيف دالة `set_updated_at()` وtrigger `BEFORE INSERT OR UPDATE` على كل جدول متزامن يضبط `NEW.updated_at = now()`. الـclient يبقى يرسل `updated_at` في الـupsert (لا نغيّر `_buildRemoteRow`) — الـtrigger يدوس عليه بوقت الخادم. عند السحب، `_toLocalMap` يخزّن `remote['updated_at']` (= وقت الخادم) في `sync_updated_at` — يفعل بالفعل.

**السبب**: أبسط نقطة تدخّل، تغطّي كل الكتابات (كل الأجهزة) بلا تنسيق client. لا عمود جديد، لا تغيير schema محلي. الـtrigger idempotent وغير مؤذٍ (`updated_at` يُستخدَم فقط للمقارنة النسبية).

**الجداول (11)**: `groups, students, attendance, payments, homework, exams, exam_groups, exam_grades, exam_questions, exam_submissions, bank_questions`.

**البدائل المرفوضة**:
- مزامنة ساعة في الـclient (NTP) — تعقيد + نقطة فشل.
- `DEFAULT now()` فقط — الـclient يدوس عليه في الـupsert (بيرسل قيمة صريحة).
- عمود `server_updated_at` منفصل — يحتاج تغيير `_toLocalMap`/`_applyRemoteRow` والمقارنة، وأصعب في الترحيل.

**التطبيق**: عبر SSH (نمط specs 021/024/025): `ssh ... 'docker exec -i active-class-auth-db-1 psql -U postgres -d postgres -v ON_ERROR_STOP=1' < supabase/migration_server_updated_at.sql`.

---

## قرار 2 — التوفيق: LWW على البيانات، لا تغيير `remote_id`

**القرار**: عند اكتشاف dup في `_applyRemoteRow` (صف وارد يطابق منطقيًا صفًا محليًا بمعرّف مختلف):
1. اقرأ الصف المحلي المكرّر بحقوله (`pk`, `sync_updated_at`).
2. `syncConflictIncomingWins(localUpdatedAt, remoteUpdatedAt, localRemoteId, remoteRemoteId)`:
   - `remoteUpdatedAt` بعد `localUpdatedAt` → true
   - قبل → false
   - تساوٍ → `remoteRemoteId.compareTo(localRemoteId) < 0` (الأصغر معجميًا يفوز)
3. لو `incomingWins` → `db.update(table, localMapWithoutRemoteId, where: pk = dupPk)` — نحدّث حقول البيانات فقط، **نحتفظ بـ`remote_id` المحلي**.
4. غير ذلك → لا شيء (نبقي المحلي).

**السبب**:
- عدم تغيير `remote_id` يتفادى إرباك دفعات الـoutbox اللاحقة (`_pushOne` يستخدم `origin_device_id + local_id` كـconflict key، وتغيير `remote_id` تحت الصف كان يخلق تناقضًا).
- الجهازان يتّفقان على **البيانات** (الأحدث بوقت الخادم يفوز) رغم اختلاف `remote_id` داخليًا — وده اللي يهمّ المستخدم.
- الصفّان على الخادم يبقيان ويعيدان البثّ؛ كل بثّة تُعيد LWW فتبقى النتيجة ثابتة (اتساق نهائي).

**البدائل المرفوضة**:
- اختيار `remote_id` فائز وتغيير المحلي إليه — إرباك outbox + سباقات.
- soft-delete "الخاسر" على الخادم — قد يفشل لعضو بلا صلاحية حذف + خارج النطاق.
- field-level merge — تعقيد بلا داعٍ لـ v1.

---

## قرار 3 — استخراج المنطق النقي

**القرار**: `lib/utils/sync_conflict.dart`:
```dart
/// هل الصف الوارد (من جهاز آخر) يفوز على الصف المحلي المكرّر؟
bool syncConflictIncomingWins({
  DateTime? localUpdatedAt,
  DateTime? remoteUpdatedAt,
  required String localRemoteId,
  required String remoteRemoteId,
}) {
  if (remoteUpdatedAt == null) return false;      // لا وقت وارد → لا نلمس
  if (localUpdatedAt == null) return true;         // محلي بلا وقت → الوارد أولى
  final cmp = remoteUpdatedAt.compareTo(localUpdatedAt);
  if (cmp > 0) return true;
  if (cmp < 0) return false;
  return remoteRemoteId.compareTo(localRemoteId) < 0; // تعادل → الأصغر معجميًا
}
```

**السبب**: `sync_engine.dart` يصعب اختباره (يحتاج `SupabaseClient`/DB حيّين). العتبة/التعادل منطق نقي.

---

## قرار 4 — نطاق الـdup: الجداول ذات الفهرس المنطقي فقط

**القرار**: التوفيق يُطبَّق على الكتل الخمس القائمة فقط: `attendance` (طالب+يوم)، `homework` (طالب+يوم)، `exam_groups` (امتحان+مجموعة)، `exam_grades` (امتحان+طالب)، `exam_submissions` (امتحان+طالب). `groups`/`students`/`payments`/`exams` بلا فهرس منطقي → غير متأثّرة (تستفيد فقط من trigger الخادم).

**السبب**: لا مفتاح منطقي = كل صف كيان مستقل، مفيش "تكرار" يُوفَّق.

---

## قرار 5 — التوافق الرجعي

**القرار**: البيانات الحالية على الخادم طوابعها (المحلية القديمة) تبقى كما هي؛ أول تعديل جديد يمرّ يأخذ وقت الخادم عبر الـtrigger. لا re-stamp رجعي.

**السبب**: مقارنة نسبية — بمجرد أن الطرفين يمرّان تعديلًا واحدًا عبر الخادم، المقارنات تصير موحّدة. re-stamp رجعي كان هيغيّر "الأحدثية" لصفوف قديمة بلا داعٍ.

**أثر انتقالي**: خلال أول أيام بعد الـmigration، قد تظل بعض المقارنات تخلط وقت خادم بوقت جهاز قديم لصفوف لم تُعدَّل — نادر ومؤقت.

---

## ملخّص الحسم

| # | الموضوع | القرار |
|---|---|---|
| 1 | وقت الخادم | trigger `BEFORE INS/UPD` على 11 جدول، لا تغيير client |
| 2 | التوفيق | LWW على البيانات، `remote_id` المحلي ثابت، الخاسر يبقى يعيد البثّ |
| 3 | الاختبار | `sync_conflict.dart` دالة نقية |
| 4 | النطاق | 5 كتل dup القائمة فقط |
| 5 | التوافق | لا re-stamp؛ يتوحّد بعد أول تعديل يمرّ |
