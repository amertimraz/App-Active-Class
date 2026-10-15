# Data Model: صحة البيانات

**لا تغيير في قاعدة البيانات ولا الخادم.** النماذج دي في الذاكرة (نواة صرفة) + سجل JSON محلي.

## DuplicateKind
`group` | `student`

## MatchReason
| القيمة | معناها | محدّد تلقائيًا للدمج؟ |
|---|---|---|
| `sameCode` | نفس الكود (بعد تشيل لاحقة `-N` للمقارنة) | نعم |
| `sameNameInGroup` | نفس الاسم المطبّع داخل نفس المجموعة / مجموعتين مكرّرتين | **لا** (قرار صريح) |
| `sameGroupName` | مجموعتين بنفس الاسم المطبّع وغير مؤرشفتين | نعم |

## CandidateCopy
| الحقل | ملاحظة |
|---|---|
| `id` / `remoteId` | المعرّف المحلي + البعيد (للتحقق من التزامن) |
| `name`, `code`, `groupId`, `guardianPhone`, `createdAt` | للعرض والترتيب |
| `isArchived` | يؤثر على اختيار الأساسي |
| `counts` | `attendance`, `payments`, `homework`, `grades`, `others` (follow-ups/booklets/submissions/archive events) |
| `suffixed` | الكود بلاحقة `-N` |

## DuplicateCase
| الحقل | ملاحظة |
|---|---|
| `kind`, `reason` | |
| `copies` | قائمة `CandidateCopy` (≥ 2) |
| `canonicalId` | المقترح تلقائيًا (الأكتر بيانات ← الأقدم ← بلا لاحقة) |
| `selected` | تحديد المدرس (افتراضي حسب `reason`) |
| `linkedGroupCase` | معرّف حالة مجموعة مرتبطة (طالب داخل مجموعة مكرّرة) |

## MergeRule (لكل جدول؛ راجع contracts/merge-rules.md)
`{table, studentCol, naturalKey[], onKeyConflict: dropDuplicate | keepBoth}`

## MergePlan
| الحقل | ملاحظة |
|---|---|
| `moves` | `Map<table, List<rowId>>` الصفوف اللي بتتنقل للأساسي |
| `drops` | `Map<table, List<(rowId, remoteId?)>>` صفوف مكرّرة بتتحذف |
| `conflicts` | حضور بحالة مختلفة (id، يوم، حالة المكرّر ↔ حالة الأساسي) |
| `studentsToRemove`, `groupsToRemove` | معرّفات (مع remote ids) |
| `groupReassignments` | طلاب/روابط امتحانات بتتنقل لمجموعة أساسية |
| `summary` | أعداد للمعاينة والتقرير (نفس مصدر التنفيذ) |

## MergeLogEntry (محلي، JSON)
`{at, kind, caseCount, studentsMerged, groupsMerged, moved:{...}, dropped:{...}, backupPath, items:[{canonicalName, mergedNames[]}]}` — آخر 20 عملية في `settings['data_health_log']`.

## قيود الاتساق
- الأساسي ≠ أي مكرّر؛ لا دمج دائري.
- النسخة الأساسية تفضل بمعرّفها (id/remote_id) — بس المكرّر هو اللي بيتشال.
- مفيش تعديل في بيانات الأساسي الشخصية (الاسم/الرقم/السعر) تلقائيًا.
- طلاب مجموعة مكرّرة بيتطابقوا بالاسم المطبّع مع طلاب الأساسية؛ غير المطابق بيتنقل كما هو.
