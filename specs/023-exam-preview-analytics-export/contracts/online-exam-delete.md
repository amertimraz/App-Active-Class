# Contract: حذف الامتحان الإلكتروني نهائيًا

## Controller — `lib/controllers/exam_controller.dart`

```
/// حذف نهائي لامتحان إلكتروني: السحابة (best-effort) ثم المحلي (كاسكيد + مزامنة).
/// يرجّع null عند النجاح الكامل، أو رسالة تحذير لو تنظيف السحابة لم يكتمل.
Future<String?> deleteOnlineExam(int examId) async {
  String? warn;
  try {
    await _online.deleteRemote(examId);
  } catch (_) {
    warn = 'تم الحذف من التطبيق — لكن تنظيف السحابة قد لا يكون اكتمل';
  }
  await _db.deleteExam(examId);
  await loadExams();
  return warn;
}
```

- `_db.deleteExam` موجودة — تحذف `exams` وتترك FK cascade يمسح `exam_questions`/`exam_submissions`/`exam_grades`/`exam_groups`، ثم `_queueDelete` لـ`exam_grades`/`exam_groups`/`exams` (تبليغ الفريق).
- لا استدعاء `deleteExam` مكرّرًا؛ idempotent (لو الصف غير موجود، `db.delete` = 0 صفوف، `_queueDelete` بلا ضرر).

## Service — `lib/services/online_exam_service.dart` `deleteRemote`

تغيير سطر واحد:
```
for (final sub in ['submissions', 'attempts', 'results']) {   // + 'results'
```
- الباقي كما هو: batch (حد 400)، ثم `examRef.delete()`، كله داخل try/catch مع `debugPrint`.
- best-effort: فشل الشبكة/عدم وجود الوثيقة (مسودّة) لا يرمي للأعلى.

## UI — `lib/views/exams/online_exams_tab.dart` `_actions(status)`

يُضاف في **كل** فروع `switch`:
```
_btn('حذف نهائي', Icons.delete_forever_outlined, () {
  _confirm(context,
    title: 'حذف الامتحان نهائيًا',
    color: const Color(0xFFDC2626),
    icon: Icons.delete_forever_rounded,
    body: 'مفيش رجوع. هيتمسح الامتحان وكل أسئلته، وكل التسليمات '
          'والدرجات المعتمَدة، وصفحات مراجعة الطلاب على الويب.',
    onYes: () => _run(() => _ec.deleteOnlineExam(exam.id!), 'اتحذف الامتحان'));
}),
```
- لفرع `draft`: نفس الزر، النص يظل صحيحًا (لا تسليمات → لا شيء يُمسح سحابيًا فعليًا).
- `_btn('حذف من الويب', ...)` الحالي **يبقى** في فرعي published/stopped بلا تغيير.
- `_run` يعرض التحذير المُرجَع من `deleteOnlineExam` لو غير null (نمط موجود).

## Firestore rules

**صفر تعديل.** `online_exams/{slug}/exams/{examId}` ومجموعاته الفرعية `submissions`/`attempts`/`results` كلها `allow write/delete: if _oeOwner(slug)` (المدرس المالك). القواعد الحالية تغطّي الحذف الكامل.

## معايير القبول

- مسودّة → حذف نهائي → تختفي من القائمة، لا خطأ سحابة.
- منشور + تسليمات + درجة معتمَدة → حذف نهائي → يختفي محليًا؛ `exam` + `submissions` + `attempts` + `results` كلها غير موجودة على الخادم؛ صفحة مراجعة الطالب لا تفتح.
- "محذوف من الويب" → حذف نهائي → يختفي السجل المحلي.
- فشل شبكة أثناء الحذف → الحذف المحلي يتم + تحذير للمدرس.
- ضغط مزدوج سريع → حذف واحد فعّال، بلا استثناء.
- FR-030..FR-036، SC-008، SC-009.
