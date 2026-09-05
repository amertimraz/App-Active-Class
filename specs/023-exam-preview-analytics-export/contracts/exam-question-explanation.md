# Contract: شرح الإجابة الصحيحة (explanation)

## Model — `ExamQuestion`

```
final String? explanation;   // ≤ 500 chars, nullable
```

- `toMap()` → يشمل `COL_EQ_EXPLANATION`
- `fromMap()` → `explanation` = القيمة إن غير فارغة، وإلا `null`
- `copyWith({Object? explanation = _unset})` → نمط sentinel
- `isValid` → **دون تغيير**
- `toCloudMap()` → **دون تغيير** — يجب ألا يحتوي `explanation` (ولا `correctIndex`/`points`). اختبار يفرض ذلك.

## DB

| البند | القيمة |
|---|---|
| `DATABASE_VERSION` | `26` |
| ثابت العمود | `COL_EQ_EXPLANATION = 'explanation'` |
| DDL (قواعد جديدة) | `explanation TEXT` في `_examQuestionsTableSql` |
| Migration | `if (oldVersion < 26) → ALTER TABLE exam_questions ADD COLUMN explanation TEXT` (داخل try/catch) |
| مزامنة الفريق | لا شيء (`exam_questions` محلي) |

## المحرّر — `online_exam_editor_page.dart`

- في `_questionCard(i)`: `TextField` جديد "شرح الإجابة (اختياري)"، `maxLength: 500`, `maxLines: 2..3`, يربط بـ`q.explanation`.
- يُحفظ ضمن نفس مسار حفظ السؤال (مسودّة/نشر/حفظ مباشر spec 022) — `toModel()` يمرّر `explanation`.
- إرشاد صغير: "يظهر للطالب في مراجعة إجاباته بعد اعتماد الدرجة".

## مسار الاعتماد — `exam_controller.dart`

- `questionResults(sub)`: كل `QuestionResult` يُبنى بـ`explanation: q.explanation`.
- لا تغيير في `approveOnlineGrade` عدا انتقال الحقل ضمن `results`.

## النشر — `online_exam_service.dart` `publishReview`

داخل `questions.map`:
```
if (r.explanation != null && r.explanation!.isNotEmpty) 'explanation': r.explanation,
```

## الموقع — `booking_site/exam/index.html` `renderReview`

- بعد صفوف `opts` وقبل `<div class="rfoot">`:
  ```
  ${q.explanation ? `<div class="rexpl"><span class="rexpl-i">💡</span><span>${escapeHtml(q.explanation)}</span></div>` : ''}
  ```
- CSS `.rexpl`: خلفية `rgba(...,.06)`, `border-right: 3px solid var(--accent)` (RTL), padding، خط 12.5px، `border-radius`.
- يُنشر إلى VPS: `scp -i ~/.ssh/ovh_key booking_site/exam/index.html root@active-class.online:/var/www/active-class.online/exam/index.html` ثم تحقّق `curl`.

## معايير القبول

- سؤال بشرح → بعد الاعتماد يظهر الشرح في صفحة المراجعة، تحت/بعد الاختيارات.
- سؤال بلا شرح → لا عنصر `.rexpl` في DOM.
- فحص `online_exams/{slug}/exams/{id}` (المستند العام) → لا `explanation`، لا `correctIndex`.
- ترقية من v25: قاعدة موجودة تُفتح، عمود يُضاف، أسئلة قديمة `explanation = NULL`.
