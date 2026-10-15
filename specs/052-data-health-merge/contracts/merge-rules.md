# Contract: قواعد الدمج وترتيب المزامنة

مصدر القواعد: سكربت تنظيف Grade 2 (`cleanup_team.sql`) اللي اتجرّب كـdry-run على بيانات حقيقية.

## 1) جداول الطالب (عند دمج طالب مكرّر → أساسي)

| الجدول | عمود الطالب | المفتاح الطبيعي (لو الأساسي عنده نفسه ← يتشال المكرّر) | عند عدم التعارض |
|---|---|---|---|
| `attendance` | `student_id` | اليوم (`date` أول 10 حروف) | يتنقل |
| `homework` | `student_id` | اليوم | يتنقل |
| `payments` | `student_id` | `date` + `amount` | يتنقل |
| `exam_grades` | `student_id` | `exam_id` | يتنقل |
| `exam_submissions` | `student_id` | `exam_id` (UNIQUE) | يتنقل |
| `booklet_records` | `student_id` | `booklet_id` | يتنقل |
| `booklet_payments` | `student_id` | `booklet_id` + `date` + `amount` | يتنقل |
| `student_follow_ups` | `student_id` | — | يتنقل كله |
| `student_archive_events` | `student_id` | `type` + `event_at` (UNIQUE) | يتنقل |
| `report_logs` | `student_id` | — (غير متزامن) | يتنقل |

- لو أكتر من صف مكرّر على نفس المفتاح عند المكرّر نفسه ← يفضل واحد (الأحدث `updated_at`) والباقي يتشال (زي `rn > 1` في السكربت).
- التعارض بحالة مختلفة (حضور): الأساسي يكسب ويُعدّ في `conflicts`.

## 2) جداول المجموعة (عند دمج مجموعة مكرّرة → أساسية)

| الجدول | الإجراء |
|---|---|
| `students` | المطابق (اسم مطبّع) ← يتدمج بقواعد (1)؛ غير المطابق ← `group_id` = الأساسية |
| `exam_groups` | لو الامتحان مربوط بالأساسية فعلًا ← حذف الربط المكرّر؛ غير كده ← `group_id` = الأساسية |
| `booklet_groups` | نفس منطق `exam_groups` (مفتاح UNIQUE: booklet+group) |
| `session_overrides` | `group_id` = الأساسية (نقل) |
| `groups` | المجموعة المكرّرة تتحذف في الآخر |

## 3) ترتيب التنفيذ (كلها داخل transaction واحدة محليًا)
1. نقل صفوف الأطفال غير المتعارضة (UPDATE `student_id`).
2. حذف الصفوف المكرّرة (بعد جمع `remote_id`).
3. حذف الطالب المكرّر (CASCADE بيشيل الباقي محليًا).
4. نقل الطلاب غير المطابقين وروابط المجموعة.
5. حذف المجموعة المكرّرة.
6. `_unlinkOrphanedSiblingSurvivor` للإخوة لو لزم.

## 4) ترتيب طابور المزامنة (بعد الـcommit)
1. `update` لكل صف منقول (`_queueRowUpsert`).
2. `delete` للصفوف المكرّرة (مع `remote_id`).
3. `delete` للطلاب المكرّرين.
4. `update` للطلاب/الروابط المنقولة لمجموعة أساسية.
5. `delete` للمجموعة المكرّرة.

## 5) الشروط المسبقة
- وضع الفريق: كل أساسي (طالب/مجموعة) له `remote_id`.
- `sync_outbox` المعلّقة: عدّاد يظهر في الواجهة (> 0 = تحذير).
- صلاحية: `!isAssistant` + `requireTeamOwnerIfTeamMode`.
- نسخة احتياطية ناجحة.

## 6) الواجهة الداخلية (Dart)

```dart
// lib/utils/duplicate_detection.dart
String normalizeName(String s);
String codeStem(String code);                       // يشيل -N
List<DuplicateCase> detectGroupDuplicates(List<Group> groups, ...);
List<DuplicateCase> detectStudentDuplicates(List<Student> students, ..., {Set<int>? dupGroupIds});
int pickCanonical(List<CandidateCopy> copies);

// lib/utils/merge_plan.dart
MergePlan buildMergePlan(List<DuplicateCase> selected, MergeInputs inputs);

// lib/services/data_health_service.dart
Future<ScanResult> scan();
Future<MergeOutcome> execute(MergePlan plan);       // backup → txn → queue → log
Future<List<MergeLogEntry>> history();
```
