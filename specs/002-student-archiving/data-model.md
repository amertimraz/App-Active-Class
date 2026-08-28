# Phase 1 Data Model: أرشفة الطلاب

## الكيان: الطالب (Student)

توسعة للكيان الموجود بالفعل (`lib/models/student_model.dart` + جدول `students` في `database_service.dart`) — لا كيان جديد.

### حقول جديدة

| الحقل (Dart) | العمود (SQLite) | النوع | الافتراضي | الوصف |
|---|---|---|---|---|
| `isArchived` | `is_archived` | `INTEGER` (0/1) | `0` (غير مؤرشف) | حالة الأرشفة الحالية للطالب |
| `archivedAt` | `archived_at` | `TEXT` (ISO 8601) nullable | `NULL` | تاريخ/وقت آخر عملية أرشفة؛ يُصفَّر (`NULL`) عند الاستعادة |

### قواعد الحالة (State Transitions)

```
[نشط] --(أرشفة)--> [مؤرشف]
[مؤرشف] --(استعادة)--> [نشط]
[مؤرشف] --(حذف نهائي)--> [محذوف نهائيًا — الصف وكل بياناته المرتبطة تُحذف بالكامل]
[نشط] --(حذف نهائي)--> غير متاح؛ يجب المرور بحالة "مؤرشف" أولاً (FR-008)
```

### تأثير على كيانات مرتبطة (بدون تعديل سكيمتها)

- **الحضور (Attendance)**, **المدفوعات (Payment)**, **درجات الامتحانات (ExamGrade)**, **الواجب (Homework)**: لا تعديل. تبقى مرتبطة بـ `studentId` كما هي (FK + `ON DELETE CASCADE` الحالي يبقى كما هو — يُفعَّل فقط عند الحذف النهائي الحقيقي، وليس عند الأرشفة).
- **الربط الأخوي (`siblingId` / `siblingsTotal`)**: عند الانتقال لحالة "مؤرشف"، يُصفَّر `siblingId`/`siblingsTotal` على **الطرفين** (الطالب المؤرشف والطالب النشط المرتبط به سابقًا) — راجع Research قرار 3.

### مصادر البيانات في الكود (بعد التعديل)

| المصدر | المحتوى | يشمل المؤرشفين؟ |
|---|---|---|
| `StudentController.students` / `.filteredStudents` | القائمة الافتراضية المستخدمة في كل الشاشات الحالية | ❌ لا (تغيير سلوك — راجع Research قرار 2) |
| `StudentController.archivedStudents` (جديد) | لشاشة الأرشيف فقط | ✅ المؤرشفين فقط |
| استعلام مباشر (`DatabaseService.getAllStudents()`) | يبقى بلا فلترة كما هو (يُستخدم داخليًا لبناء القائمتين أعلاه) | ✅ الكل |
| فحص حد الباقة (`LicenseController.checkCanAddStudent`) | يستمر بتمرير عدد **كل** الطلاب (نشط + مؤرشف) — قرار FR-013 | ✅ الكل |

## عقد التخزين المحلي (SQLite)

لا يوجد API خارجي لهذه الميزة (تطبيق موبايل بدون backend مخصص للطلاب) — "العقد" هنا هو دوال `DatabaseService` الجديدة/المعدَّلة:

```dart
// database_service.dart
Future<void> archiveStudent(int studentId);
  // يضبط is_archived=1, archived_at=now(); يفكّ أي ربط أخوي على الطرفين؛
  // يسجّل تغيير للمزامنة (queueSync) لو وضع الفريق مفعّل.

Future<void> unarchiveStudent(int studentId);
  // يضبط is_archived=0, archived_at=NULL؛ يسجّل تغيير للمزامنة.

Future<List<Student>> getArchivedStudents();
  // SELECT * FROM students WHERE is_archived = 1

Future<List<Student>> getActiveStudents();
  // SELECT * FROM students WHERE is_archived = 0
  // (getAllStudents() الحالية تبقى بلا تغيير: بلا فلترة، للاستخدام الداخلي
  //  وفحص حد الباقة فقط)
```

## عقد مزامنة وضع الفريق (Supabase)

توسعة لجدول `students` الموجود على Supabase (لا جدول جديد):

```sql
alter table public.students
  add column if not exists is_archived boolean not null default false,
  add column if not exists archived_at timestamptz;
```

حمولة الدفع/الاستقبال في `sync_engine.dart` (جدول `TABLE_STUDENTS` الموجود) تُضاف لها `is_archived`/`archived_at` بنفس نمط باقي أعمدة الطالب المُزامَنة حاليًا (`group_remote_id`, `sibling_remote_id`, ...).
