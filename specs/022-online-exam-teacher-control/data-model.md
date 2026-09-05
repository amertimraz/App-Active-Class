# Data Model: تحكّم أوسع للمدرس في الامتحان الإلكتروني

مفيش جدول أو عمود DB جديد. التعديل الوحيد كيان-مستوى هو قيمة جديدة على enum موجود.

## `SubmissionStatus.voided` (قيمة جديدة)

| | |
|---|---|
| `dbValue` | `'voided'` |
| `label` | `'مُبطَل'` |
| العمود المخزَّن فيه | `exam_submissions.status` (TEXT، بلا CHECK constraint — صفر migration) |

**دلالتها**: تسليم كان موجود (بانتظار الاعتماد أو معتمَد) وقرّر المدرس إبطاله. الصف المحلي **يفضل موجود** (`status='voided'`) لغرض السجل/العرض في قسم منفصل بشاشة النتائج، لكن:
- درجته اتشالت من `exam_grades` (زي الإلغاء العادي).
- مستنداته على Firestore (`submissions/{attemptKey}`, `results/{attemptKey}`) اتمسحوا — عشان الطالب يقدر يبدأ من الصفر (قاعدة الأمان الحالية بترفض `create` لو المستند موجود بالفعل).

**استبعاد من الإحصائيات**: أي حساب لمتوسط الدرجات أو عدد "معتمَد"/"الكل" في `_summaryHeader` لازم يفلتر `status != voided` صراحة — نفس فلترة `notSubmitted` الموجودة بالفعل.

## عدّاد "التسليمات المتأثرة" (FR-011) — محسوب وقت العرض، مش مخزَّن

عند تعديل سؤال بعد النشر:
```
affectedCount = getSubmissionsForExam(examId)
  .where((s) => s.answers.containsKey(updatedQuestion.id))
  .length
```
بيشمل أي تسليم (بانتظار الاعتماد أو معتمَد) جاوب على السؤال ده — مش بس المعتمَدة، لأن حتى "بانتظار الاعتماد" عندها `autoScore` محسوب بالإجابة القديمة. `voided` مستبعدة (مفيش داعي تحذير عن تسليم مُلغى أصلاً).

## `unapproveOnlineGrade` / `voidSubmission` — نفس مسار الحذف

الاتنين بيستخدموا بالضبط نفس التسلسل اللي `approveOnlineGrade`/`saveGrade` بيستخدموه بالعكس:
1. `DatabaseService.deleteGrade(examId, studentId)` — حذف صف `exam_grades` (مش تحديثه بـ`null` — حذف فعلي، أبسط وأوضح من صف "درجة فاضية" معلّق).
2. `ParentPortalService().pushStudentSummary(studentId)` — نفس الآلية الموجودة، بتعيد بناء `examHistory` من غير الامتحان ده (لأن فلتر `e.grade != null || e.isAbsent` هيستبعده تلقائيًا).
3. `OnlineExamService.deleteReview(examId, attemptKey)` — حذف `results/{attemptKey}` (best-effort).

`voidSubmission` بس بيزود فوقها: `deleteSubmission(examId, attemptKey)` (Firestore) + `voidSubmissionLocally` (محلي، `status='voided'`).
