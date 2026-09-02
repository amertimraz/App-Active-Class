# Contract — Firestore `online_exams/{slug}` + قواعد الأمان

## الشجرة

```
online_exams/{slug}
online_exams/{slug}/exams/{examId}
online_exams/{slug}/exams/{examId}/attempts/{code}_{last4}
online_exams/{slug}/exams/{examId}/submissions/{code}_{last4}
```

`{slug}` = `ParentPortalService.ensureSlug()` (مشتق حتميًا من كود الترخيص).
`{examId}` = id المحلي لجدول `exams` كنص.
`{code}_{last4}` = كود الطالب (uppercase) + `_` + آخر 4 أرقام من `guardianPhone` — نفس صيغة `parent_portal/{slug}/students`.

## أشكال المستندات

راجع [data-model.md](../data-model.md#نموذج-البيانات-السحابي-firestore) — لا تكرار هنا. النقاط الملزمة:

1. مستند `exams/{examId}` **يجب ألا يحتوي** أي مفتاح إجابة (`correct`, `correctIndex`, `answer`, …). المدقّق: قائمة مفاتيح `questions[*]` = `{id, type, text, options}` بالضبط.
2. `opensAt` / `closesAt` سلاسل ISO-8601 بنهاية `Z` (UTC).
3. `attempts` و`submissions` **create فقط** — لا تعديل، لا حذف من أي عميل (بما فيه المدرس؛ المدرس يحذف عبر حذف مستند `exams` الأب أو الشجرة كلها).

## قواعد الأمان (تُضاف إلى `firestore.rules` قبل قوس الإغلاق الأخير)

```
// ── الامتحانات الإلكترونية ───────────────────────────────────────
match /online_exams/{slug} {
  allow read: if true;
  allow create: if request.auth != null
                && request.resource.data.ownerUid == request.auth.uid;
  allow update: if request.auth != null
                && (resource.data.ownerUid == request.auth.uid
                    || request.resource.data.deviceId == resource.data.deviceId);
  allow delete: if false;

  match /exams/{examId} {
    // قراءة عامة — مقفولة فعليًا بمعرفة {slug} غير المتوقّع (نفس منطق
    // parent_portal/{slug}/students). لا مفتاح إجابة في المستند أصلًا.
    allow read: if true;
    allow write: if request.auth != null
                 && get(/databases/$(database)/documents/online_exams/$(slug)).data.ownerUid
                    == request.auth.uid;

    match /attempts/{docId} {
      allow read: if request.auth != null
                  && get(/databases/$(database)/documents/online_exams/$(slug)).data.ownerUid
                     == request.auth.uid;
      // إنشاء مرة واحدة فقط — الطالب المجهول يثبّت لحظة بدايته
      allow create: if request.resource.data.keys().hasOnly(['code','startedAt'])
                    && request.resource.data.code is string
                    && request.resource.data.code.size() > 0
                    && request.resource.data.code.size() < 20
                    && request.resource.data.startedAt == request.time;
      allow update, delete: if false;
    }

    match /submissions/{docId} {
      allow read: if request.auth != null
                  && get(/databases/$(database)/documents/online_exams/$(slug)).data.ownerUid
                     == request.auth.uid;
      // تسليم واحد فقط لكل طالب — القراءة السابقة على المستند غير الموجود
      // بترجع resource == null، فـ create بينجح مرة واحدة وبعدها أي محاولة
      // تانية بتفشل (المستند بقى موجود). مفيش داعي exists() صريح.
      allow create: if request.resource.data.code is string
                    && request.resource.data.code.size() > 0
                    && request.resource.data.code.size() < 20
                    && request.resource.data.answers is map
                    && request.resource.data.submittedAt == request.time
                    && request.resource.data.keys().hasOnly(
                         ['code','answers','submittedAt','autoSubmitted','startedAtClient']);
      allow update, delete: if false;
    }
  }
}
```

**ملاحظة على "تسليم واحد"**: Firestore `allow create` بيتقيّم على مستند غير موجود؛ بمجرد وجوده، `create` تالت بيتحوّل تقييمه ويفشل. ده نفس ضمان "مرة واحدة" اللي بتعتمد عليه صفحة الطالب (FR-016) — مؤكَّد بالقاعدة مش بس بالـUI.

**الحذف من جهة المدرس**: `exams/{examId}` عنده `allow write` لصاحب الرابط، وде يشمل `delete` للمستند الأب. حذف الشجرة الفرعية (`attempts`/`submissions`) يتم بحلقة حذف من التطبيق (batched)، والقاعدة `update, delete: if false` عليهم تمنع العملاء المجهولين فقط — **صاحب الرابط يقدر يحذفهم** لأن... لا. القاعدة `if false` تمنع الكل.

→ **قرار**: نضيف استثناء حذف لصاحب الرابط على `attempts`/`submissions`:
```
allow delete: if request.auth != null
              && get(/databases/$(database)/documents/online_exams/$(slug)).data.ownerUid
                 == request.auth.uid;
```
(بدل `if false` للحذف فقط؛ الـ`update` يفضل `if false` للكل — مفيش سيناريو تعديل مشروع).

## تسلسل النشر (`OnlineExamService.publish`)

1. `await ParentPortalService().ensureSlug()` → slug
2. `_ensureAuth()` (مصادقة مجهولة)
3. `await ParentPortalService().publishProfile()` — يضمن وجود `online_exams/{slug}` عبر كتابة `set(merge)` مماثلة، ووجود ملخصات الطلاب (لفحص الهوية على صفحة الطالب)
4. بناء `allowedCodes` = `DatabaseService.allowedStudentCodesForGroups(groupIds)` — يستبعد الطلاب بلا `last4` صالح
5. `set` على `online_exams/{slug}/exams/{examId}` بالمستند الكامل (بلا مفاتيح إجابة)
6. تحديث محلي: `online_status = 'published'`

## تسلسل السحب (`OnlineExamService.fetchSubmissions(examId)`)

1. slug + `_ensureAuth()`
2. `get` على `online_exams/{slug}/exams/{examId}/submissions` (collection) → كل التسليمات
3. لكل تسليم: مطابقة `code` بطالب محلي (عبر `students.code`)، فك `answers`
4. إرجاع `List<CloudSubmission>` للـ`ExamController` يصحّح ويـ upsert في `exam_submissions`

## تسلسل الإيقاف/الحذف

- **إيقاف الآن**: `update` على `exams/{examId}` بـ `status: 'stopped'` + `closesAt: now(UTC)`. صفحة الطالب تحترم `closesAt`.
- **حذف من الويب**: batched delete لكل `submissions` + `attempts`، ثم `delete` على `exams/{examId}`. محلي: `online_status = 'removed'`.
- **قفل بوابة الأهالي**: `ParentPortalService._watchLicenseChanges` موجود — نوسّعه ليكتب `active: false` على `online_exams/{slug}` كمان (أو صفحة الطالب تقرأ `parent_portal/{slug}.active` مباشرةً — الأبسط).

## أخطاء ومعالجة

| موقف | سلوك |
|---|---|
| نشر بلا إنترنت | `publish` يرمي؛ `ExamController` يعرض "تحقق من الاتصال"؛ الحالة تفضل `draft` |
| سحب بلا إنترنت | `fetchSubmissions` يرمي؛ رسالة toast؛ لا تغيير محلي |
| بوابة الأهالي غير نشطة وقت النشر | `publish` يرفض مبكرًا برسالة "الميزة ضمن إضافة بوابة الأهالي" |
| فشل حذف السحابة (best-effort) | يُسجَّل `debugPrint` فقط؛ الحالة المحلية تتحدّث بأي حال (نمط `removeStudentSummary`) |
