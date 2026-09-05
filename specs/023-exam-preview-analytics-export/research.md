# Phase 0 Research: تطويرات الامتحانات 023

## R1 — نقطة تصدير درجات الامتحان الورقي (كل المجموعات)

**السياق**: `ExamGradesPage(exam, groupId, groupName)` تُفتح لكل مجموعة على حدة من `exams_page.dart` (`_ExamCard.onOpenGrades(gId, gName)`). فيها بالفعل `_exportPdf()` (per-group) و`_shareText()` (per-group واتساب). `Exam.groupIds: List<int>` فيه كل المجموعات المرتبطة.

**القرار**: زر "تصدير" في `ExamGradesPage` يفتح قائمة بخيارين:
- "هذه المجموعة فقط" → يصدّر `_grades` الحالية.
- "كل مجموعات الامتحان" → `ExportService.exportExamGradesSheet(exam)` يجمع عبر `exam.groupIds` باستخدام استعلام DB جديد `getExamGradesForExport(examId)` (JOIN grades+students+groups، مرتّب بالمجموعة ثم الاسم).

**البديل المرفوض**: زر منفصل على `_ExamCard` — يزحم كارت الامتحان، وأغلب الامتحانات مجموعة واحدة.

**الأثر**: استعلام DB واحد جديد (قراءة فقط)؛ لا شاشة جديدة.

## R2 — صيغة التصدير: Excel أم PDF أم الاثنان؟

**السياق**: `pdf`/`printing` مستخدمان بكثرة في `ExportService` و`exam_grades_page._exportPdf`. `excel: ^4.0.6` مستخدم في `excel_import_service.dart` فقط (كتابة `.xlsx`). طلب المستخدم: "Excel .xlsx و/أو PDF".

**القرار**: **الاثنان، عبر قائمة اختيار عند الضغط على "تصدير"**:
- **Excel (.xlsx)** — الأساسي للنتائج الجدولية (المدرس يرفعه للإدارة/يعدّل عليه). صف ترويسة + صف لكل طالب.
- **PDF** — للطباعة/المشاركة السريعة؛ يعيد استخدام نمط جدول `pw.Table` من `_exportPdf` الحالي.
- كلاهما → `Share.shareXFiles([XFile(path)])` (نمط `ExportService` سطر 363).

**البديل المرفوض**: Excel فقط — المدرسون بيطبعوا كتير، وPDF شبه مجاني (النمط موجود).

**الأثر**: طريقتان في `ExportService` لكل هدف، أو طريقة واحدة بمعامل `format`. القرار في العقد: معامل `ExportFormat { xlsx, pdf }`.

## R3 — عرض "تحليل الأسئلة": bottom sheet أم صفحة؟

**السياق**: `OnlineExamResultsPage` فيها بالفعل `_summaryHeader`، قوائم صفوف، وقسم "مُبطَلة". التحليل قائمة قد تطول (سؤال × توزيع اختيارات).

**القرار**: **صفحة كاملة `ExamAnalyticsPage`** (`Get.to`)، تُفتح من زر/أيقونة `Icons.insights_rounded` في AppBar لـ`OnlineExamResultsPage`. قائمة قابلة للتمرير، كارت لكل سؤال: نص، شريط نسبة الصح، صفوف الاختيارات مع أعداد + تمييز الصحيح + تمييز أبرز distractor، سطر "لم يجب: N".

**البديل المرفوض**: bottom sheet — المحتوى أطول من نصف الشاشة عادة؛ التمرير داخل sheet سيّئ على قوائم طويلة.

**الأثر**: ملف شاشة واحد جديد + خدمة حساب نقية.

## R4 — حدّ طول الشرح وعرضه على الموقع

**القرار**:
- حدّ الإدخال: **500 حرف** (`maxLength: 500` على `TextField`). كافٍ لجملة–جملتين، يمنع إساءة الاستخدام.
- التخزين: `explanation TEXT` (nullable) — فارغ/NULL = لا شرح.
- العرض على `booking_site/exam/index.html` في `renderReview`: بعد صفوف الاختيارات وقبل `rfoot`، `<div class="rexpl">💡 <span>${escapeHtml(q.explanation)}</span></div>` — يظهر فقط `if (q.explanation)`. CSS: خلفية خفيفة، حدّ يمين ملوّن (RTL)، خط 12.5px.

**البديل المرفوض**: بلا حدّ — نصوص عملاقة تكسر تخطيط الموقع ومستند Firestore.

## R5 — أين يُحقن `explanation` في مسار الاعتماد

**السياق**: `ExamController.approveOnlineGrade` (لغير الغائب) → `questionResults(sub)` يبني `List<QuestionResult>` → `_online.publishReview(examId, attemptKey, grade, maxGrade, results)`. `questionResults` بيقرأ `_db.getQuestionsForExam(examId)` ويعمل map لكل سؤال (بيمرّر `imageUrl: q.imageUrl` بالفعل).

**القرار**:
- `QuestionResult` يكسب `final String? explanation;`.
- في `questionResults`: `explanation: q.explanation`.
- في `publishReview` questions map: `if (r.explanation != null && r.explanation!.isNotEmpty) 'explanation': r.explanation`.
- **لا تغيير** في `toCloudMap` (لا يضيف explanation — مضمون بعدم لمسه). `republishQuestions` (spec 022) يستدعي `toCloudMap` فيبقى المستند العام نظيفًا تلقائيًا.

**الأثر**: ٣ أسطر عبر ٣ ملفات، صفر مخاطرة تسريب.

## R6 — المعاينة: إعادة استخدام عرض السؤال

**السياق**: `booking_site/exam/index.html` هو مرجع "شكل الطالب" لكن HTML. داخل التطبيق لا يوجد عرض سؤال بأسلوب الطالب (المحرّر عرضه تحرير).

**القرار**: `OnlineExamPreviewPage(exam, questions)` تبني عرضًا بسيطًا خاصًّا بها: ترويسة (اسم/عدد أسئلة/درجة كلية = `questions.fold(points)`/مدة `exam.durationMin`) ثم `ListView` كروت — لكل سؤال: رقم، نص، `Image.network(imageUrl)` إن وُجد (مع `errorBuilder`/`loadingBuilder`)، ثم الاختيارات كصفوف محايدة (بلا راديو، بلا تمييز صحيح). لافتة أعلى: "معاينة — الطلاب قد يرون الأسئلة/الاختيارات بترتيب مخلوط إن كان الخلط مفعّلًا".

**البديل المرفوض**: تشغيل webview لصفحة الطالب — يتطلب نشر الامتحان أولًا؛ يناقض الغرض.

**الأثر**: شاشة عرض واحدة مكتفية ذاتيًا، ~120 سطر.

## R7 — التحليل: تجميع بهوية السؤال مع الخلط

**السياق**: `ExamSubmission.answers` هي `Map<int, int>` = `{questionId: chosenOptionIndex}` (مفاتيح = `COL_EQ_ID` المحلي، مخزّنة كـ JSON). الخلط (إن وُجد) على جهة العرض للطالب لكن الإجابة تُحفظ بـ`questionId` الأصلي وفهرس الخيار الأصلي (التصحيح المحلي يعتمد على ذلك أصلًا).

**القرار**: `ExamAnalyticsService.compute` يدور على `questions`، ولكل سؤال يجمع من `submissions.where(status != voided)`: `answers[q.id]` → لو null = "لم يجب"؛ غير ذلك عدّاد لكل فهرس خيار. الصحيح = `q.correctIndex`. أبرز distractor = أعلى عدّاد ضمن الفهارس ≠ correctIndex (وعدده > 0).

**الأثر**: خدمة نقية، مدخلاتها `List<ExamQuestion>` + `List<ExamSubmission>` فقط — قابلة للاختبار تمامًا.

## R8 — DB migration

**القرار**: نمط spec 019 (v24) بالحرف:
- `constants.dart`: `DATABASE_VERSION = 26`؛ `const String COL_EQ_EXPLANATION = 'explanation';`
- `_examQuestionsTableSql`: إضافة `$COL_EQ_EXPLANATION TEXT,` (لقواعد جديدة).
- `_onUpgrade`: `if (oldVersion < 26) { try { await db.execute('ALTER TABLE $TABLE_EXAM_QUESTIONS ADD COLUMN $COL_EQ_EXPLANATION TEXT'); } catch (_) {} }`
- أسئلة قديمة: NULL = لا شرح، صفر تأثير.
- `exam_questions` محلي بالكامل → صفر Supabase migration، صفر `_queueSync`.

## R9 — حذف الامتحان الإلكتروني نهائيًا (US5)

**السياق**: تبويب الامتحانات الإلكترونية (`online_exams_tab.dart`) `_actions(status)`:
- `draft` → "تعديل وإكمال" فقط — **لا حذف إطلاقًا** (مسودّات تتراكم).
- `published`/`stopped` → "حذف من الويب" (`removeOnlineExamFromWeb`) = `_online.deleteRemote` + `setExamOnlineStatus(removed)` — يُبقي السجل المحلي + الدرجات + الأسئلة.
- `removed` → "النتائج" فقط — السجل يبقى في القائمة للأبد.

`deleteExam` الورقي موجود ويتعامل مع `_queueDelete` للكاسكيد. `deleteRemote` ينظّف `submissions` + `attempts` فقط — **ثغرة**: مجموعة `results` (من ميزة المراجعة) تُترك.

**القرار**:
- `ExamController.deleteOnlineExam(int examId)` جديدة:
  ```
  try { await _online.deleteRemote(examId); } catch (_) { /* best-effort */ }
  await _db.deleteExam(examId);   // المسار الموجود — كاسكيد + _queueDelete
  await loadExams();
  ```
  ترجّع `String?` (رسالة تحذير لو تنظيف السحابة فشل) — نفس نمط `removeOnlineExamFromWeb`.
- `deleteRemote`: حلقة المجموعات الفرعية `['submissions', 'attempts']` → `['submissions', 'attempts', 'results']` (إصلاح ثغرة + يخدم الحذف النهائي).
- UI: `_btn('حذف نهائي', Icons.delete_forever_outlined, ...)` في **كل** الحالات (draft/published/stopped/removed) → `_confirm` أحمر، نص صريح: "لا رجعة — الامتحان وأسئلته وكل التسليمات والدرجات المعتمَدة وصفحات مراجعة الطلاب هتتمسح."
- للمسودّة: `deleteRemote` best-effort على وثيقة غير موجودة = بلا ضرر (try/catch يبتلع).

**البديل المرفوض**: جعل "حذف من الويب" يحذف كل شيء — يكسر توقّع المدرسين الحاليين (البعض يستخدمه لأرشفة الدرجات محليًا بعد انتهاء الامتحان). إضافة زر منفصل أوضح.

**الأثر**: دالة controller واحدة + سطر واحد في `deleteRemote` + زر/حوار في `online_exams_tab`. صفر DB، صفر Firestore rules.

## ملخص القرارات

| # | القرار |
|---|---|
| R1 | زر تصدير في `ExamGradesPage` بخيار "هذه المجموعة" / "كل المجموعات" + استعلام `getExamGradesForExport` |
| R2 | Excel + PDF، معامل `ExportFormat` |
| R3 | صفحة كاملة `ExamAnalyticsPage` من أيقونة في AppBar لشاشة النتائج |
| R4 | حدّ 500 حرف؛ عرض `.rexpl` على الموقع بعد الاختيارات، شرطي |
| R5 | `explanation` يُحقن في `questionResults` + `publishReview` فقط؛ `toCloudMap` بلا تغيير |
| R6 | `OnlineExamPreviewPage` عرض مكتفٍ ذاتيًا، متاح مسودّة/منشور |
| R7 | تجميع التحليل بـ`question.id`، استبعاد `voided` |
| R8 | DB v25→v26، `ALTER TABLE ADD COLUMN explanation TEXT`، نمط spec 019 |
| R9 | `deleteOnlineExam` = `deleteRemote` (best-effort، +`results`) ثم `deleteExam` الموجود؛ زر "حذف نهائي" لكل الحالات |
