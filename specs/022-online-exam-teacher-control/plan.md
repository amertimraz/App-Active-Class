# Implementation Plan: تحكّم أوسع للمدرس في الامتحان الإلكتروني

**Branch**: `022-online-exam-teacher-control` | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

## Summary

3 إجراءات جديدة فوق البنية الموجودة بالفعل لسبيك 016/018/021 — صفر آلية جديدة تُخترع:
- **إلغاء الاعتماد / الإبطال**: إعادة استخدام نفس مسار حذف الدرجة + `pushStudentSummary` + حذف مستند `results/{attemptKey}` (نفس اللي بنى عليه سبيك "مراجعة الإجابات" بالأمس). الإبطال زيادة عليه حذف `submissions/{attemptKey}` من Firestore.
- **تعديل سؤال بعد النشر**: `DatabaseService.updateQuestion` المحلي موجود بالفعل — الإضافة الوحيدة فعليًا هي إعادة نشر مصفوفة `questions` (بنفس `toCloudMap()`، بدون مفتاح إجابة) من غير ما نلمس بقية مستند الامتحان.

## Technical Context

- **Language**: Dart 3.5.4 / Flutter 3.38.1، GetX.
- **Deps**: صفر حزم جديدة.
- **DB**: عمود/جدول جديد؟ **لا** — `exam_submissions.status` عمود `TEXT` بلا `CHECK` constraint، فإضافة قيمة `'voided'` لـ`SubmissionStatus` enum صفر migration. `exam_grades` تحذف صف بدل ما تتحدّث (دالة جديدة `deleteGrade`).
- **Firestore rules**: **صفر تعديل** — `submissions/{docId}` عندها `allow delete: if _oeOwner(slug)` بالفعل، `results/{docId}` عندها `allow write: if _oeOwner(slug)` (بيغطّي الحذف) من أمس، و`exams/{examId}` عندها `allow write: if _oeOwner(slug)` بغضّ النظر عن `status` — كل الكتابات/الحذف المطلوبة هنا مسموحة أصلاً.
- **مزامنة الفريق**: `exam_questions` محلي بالكامل (مش من ضمن `SyncEngine._tables`، زي ما هو من سبيك 016) — تعديل سؤال بعد النشر برضو محلي بحت، الجزء الوحيد اللي بيروح للسحابة هو إعادة نشر `questions` array (مش عن طريق SyncEngine، عن طريق `OnlineExamService` مباشرة زي `publish()`).
- **Testing**: `flutter analyze` صفر تحذيرات + تحقّق يدوي (quickstart.md). منطق عدّ التسليمات المتأثرة (FR-011) قابل لاختبار وحدة بسيط.

## Constitution Check

PASS — الثلاث قدرات إعادة استخدام مباشر لمسارات موجودة (حذف درجة + `pushStudentSummary`، حذف مستند Firestore، إعادة نشر مصفوفة أسئلة). القيد الوحيد الجديد هو enum value جديدة (`voided`) وميثود حذف بسيطة (`deleteGrade`) — صفر تعقيد معماري إضافي.

## Source Changes

```text
lib/models/exam_submission_model.dart
  + SubmissionStatus.voided (dbValue: 'voided', label: 'مُبطَل')
  + fromDb: 'voided' → SubmissionStatus.voided

lib/services/database_service.dart
  + Future<void> deleteGrade(int examId, int studentId)
      — يحذف صف exam_grades المطابق (WHERE exam_id=? AND student_id=?)، _notifyChanged()
  + Future<void> voidSubmissionLocally(int examId, int studentId)
      — db.update(TABLE_EXAM_SUBMISSIONS, {status: 'voided'}, WHERE exam_id=? AND student_id=?)
  (updateQuestion(ExamQuestion) موجودة بالفعل — تُستخدم كما هي)

lib/services/online_exam_service.dart
  + Future<void> deleteSubmission(int examId, String attemptKey)
      — _examDoc(slug, examId).collection('submissions').doc(attemptKey).delete()
      (best-effort try/catch زي publishReview)
  + Future<void> deleteReview(int examId, String attemptKey)
      — نفس الشكل لـ collection('results')
  + Future<void> republishQuestions(int examId, List<ExamQuestion> questions)
      — _examDoc(slug, examId).update({
          'questions': questions.map((q) => q.toCloudMap()).toList(),
          'questionCount': questions.length,
          'totalPoints': questions.fold(0.0, (s,q)=>s+q.points),
          'updatedAt': FieldValue.serverTimestamp(),
        })  — update() جزئي، مش set() كامل — بيسيب status/opensAt/closesAt/allowedCodes زي ما هم

lib/controllers/exam_controller.dart
  + Future<void> unapproveOnlineGrade(int examId, int studentId)
      — updateSubmissionApproval(examId, studentId, 0, SubmissionStatus.pending)
        + _db.deleteGrade(examId, studentId) + pushStudentSummary(studentId)
        + attemptKeyFor(student) → _online.deleteReview(examId, attemptKey) (best-effort)
  + Future<void> voidSubmission(int examId, int studentId)
      — نفس unapproveOnlineGrade (حذف الدرجة + المراجعة) + _db.voidSubmissionLocally
        + attemptKeyFor(student) → _online.deleteSubmission(examId, attemptKey) (best-effort)
  + Future<({int affectedCount})> updateQuestionAfterPublish(ExamQuestion updated)
      — _db.updateQuestion(updated)
        → affectedCount = (submissions لنفس examId اللي answers تحتوي updated.id).length
        → questions = _db.getQuestionsForExam(examId) (بعد التحديث)
        → _online.republishQuestions(examId, questions) (best-effort — فشل الشبكة ميرجّعش خطأ يمنع الحفظ المحلي)
        → يرجّع العدد المتأثر عشان الـUI يقرر يعرض تحذير أو لأ

lib/views/exams/online_exam_results_page.dart
  + _row(s): زر "إلغاء الاعتماد" (لو approved) بجانب/بدل زر "اعتماد" — تأكيد ثم unapproveOnlineGrade
  + _row(s): زر "إبطال التسليم" (لو approved أو pending، مش notSubmitted) — تأكيد (نص يوضّح مسح الدرجة+التسليم) ثم voidSubmission
  + قسم/فلتر منفصل لعرض التسليمات status==voided (مش مندمجة مع القائمة العادية)
  + استبعاد voided من حساب _summaryHeader (متوسط الدرجات، عدد المعتمَد/الكل)

lib/views/exams/online_exam_editor_page.dart
  + _questionCard(i): أيقونة قلم "تعديل سريع" — مفعّلة حتى لو _isPublished (بعكس باقي الشاشة)
      → showDialog بنفس حقول السؤال (نص/اختيارات/صح/درجة/صورة) لكن سؤال واحد بس
      → عند الحفظ: _ec.updateQuestionAfterPublish(...) → لو affectedCount > 0 وامتحان منشور،
        AlertDialog تحذير "فيه N تسليم اتصحّح بالإجابة القديمة — اضغط 'تحديث النتائج' من شاشة
        النتائج عشان تتحدّث" (زر "فهمت" بس، مفيش أكشن تلقائي)
```

**نقطة إدراج زر "تعديل سريع"**: جوّه `_questionCard` الموجودة، شرط `_isPublished` (بدل ما يمنع التعديل بيفتح دايلوج مصغّر).
**نقطة إدراج أزرار الإبطال/الإلغاء**: جوّه `_row(ExamSubmission s)` في `online_exam_results_page.dart`، بجانب زر "اعتماد"/"تعديل الدرجة" الموجودين.

## Complexity Tracking

> لا انتهاكات — صفر جداول جديدة، صفر تعديل Firestore rules، صفر حزم جديدة. القيمة الجديدة الوحيدة في enum موجود (`voided`) لا تحتاج migration لغياب CHECK constraint على العمود.
