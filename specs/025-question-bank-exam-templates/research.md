# Phase 0 Research: بنك الأسئلة + قوالب الامتحان 025

## R1 — `BankQuestion`: صنف مستقل أم امتداد لـ`ExamQuestion`؟

**السياق**: `ExamQuestion` عنده `examId` و`position` **required**، و`toCloudMap()`/`toMap()` مربوطين بأعمدة `exam_questions`. البنك ملوش examId/position، وله `subject`/`tags`.

**القرار**: **صنف مستقل `BankQuestion`** في `lib/models/bank_question_model.dart`:
- حقول: `id`, `type` (`ExamQuestionType` — يُعاد استخدامه)، `text`, `options`, `correctIndex`, `points`, `imageUrl`, `explanation`, `subject`, `tags` (`List<String>`), `createdAt`.
- `bool get isValid` — نفس منطق `ExamQuestion.isValid` (خيارات ≥2 وغير فارغة، correctIndex في المدى، points > 0). المادة **مش** شرط صلاحية (تُطلب وقت الحفظ من المحرّر فقط، FR-014).
- `toMap()`/`fromMap()` لأعمدة `bank_questions`. `tags` عبر `jsonEncode`/`jsonDecode` (زي `options`).
- `ExamQuestion toExamQuestion({required int examId, required int position})` — للنسخ إلى امتحان.
- `factory BankQuestion.fromExamQuestion(ExamQuestion q, {String subject = '', List<String> tags = const []})` — لزر "احفظ في البنك".
- `copyWith` بنمط `_unset` sentinel (زي `ExamQuestion`).

**البديل المرفوض**: `extends ExamQuestion` — يورّث examId/position اللي ملهومش معنى، ويكسر `toCloudMap`.

## R2 — استخراج `QuestionEditor` widget مشترك؟

**السياق**: تحرير السؤال في `online_exam_editor_page.dart` = صنف `_QDraft` (controllers) + `_questionCard(i)` (~150 سطر UI: نص، صورة، اختيارات + راديو، درجة، شرح). شاشة البنك محتاجة نفس المكوّن.

**القرار**: **استخراج `QuestionEditor` StatefulWidget** في `lib/views/exams/question_editor.dart`:
- يملك controllers السؤال داخليًا (نص/اختيارات/شرح) + حالة (type/correctIndex/points/imageUrl).
- يبني عبر `QuestionEditorController` أو `ValueNotifier<QuestionDraft>` — أو أبسط: `QuestionEditor({QuestionDraft? initial, required void Function(QuestionDraft) onChanged, ...})` مع `QuestionDraft` نموذج قيمة عادي (بلا controllers، القيم النهائية بس).
- **قرار مبسّط**: `QuestionEditor` يحتفظ بـ`_QDraft` داخليًا (يُنقل الصنف لملف مشترك `question_draft.dart`)، ويعرض دالة `QuestionDraft toValue()` أو callback `onChanged`. `online_exam_editor_page` و`question_bank_page` الاتنين يستخدموه. زر رفع الصورة (`_pickQuestionImage`) يُنقل جواه.
- المخاطرة: `online_exam_editor_page` كبير ومترابط — الاستخراج تدريجي، مع `flutter analyze` بعد كل خطوة.

**البديل المرفوض**: تكرار كارت السؤال في شاشة البنك — ~150 سطر مكرر، وأي تعديل مستقبلي (زي حقل الشرح في spec 023) لازم يتعمل مرتين.

**احتياط**: لو الاستخراج طلع أخطر من المتوقّع أثناء التنفيذ، البديل الآمن = `QuestionEditor` جديد نظيف (مش استخراج) + `online_exam_editor_page` يفضل بكارته الحالي مؤقتًا؛ يُوحَّدوا لاحقًا. تُسجَّل كانحراف في tasks.md.

## R3 — تخزين وفلترة `tags`

**القرار**:
- عمود `tags TEXT` — JSON list (`["جبر","معادلات"]`). فارغ/`[]` = بلا وسوم.
- الفلترة بوسم: تُجلب كل الأسئلة (عشرات–مئات، رخيص) ويُفلتر في Dart بـ`q.tags.contains(tag)` — أبسط من `LIKE '%"tag"%'` وأدق.
- قائمة الوسوم للفلتر = اتحاد كل `tags` من كل الأسئلة (محسوب في الكنترولر).
- البحث النصّي: `WHERE text LIKE ?` (`%query%`) في DB، أو فلتر Dart — كلاهما مقبول؛ نختار Dart للاتساق مع فلتر الوسم (كله في الذاكرة).

## R4 — المادة (`subject`)

**القرار**: حقل نصّي حر، عمود `subject TEXT NOT NULL DEFAULT ''`. المحرّر يعرض `Autocomplete`/اقتراحات من `SELECT DISTINCT subject FROM bank_questions WHERE subject != ''` (عبر `DatabaseService.distinctSubjects()`). حدّ 60 حرفًا. الفلتر = قائمة من نفس `distinctSubjects`.

## R5 — "أضف N عشوائي"

**القرار**: منطق نقي `List<BankQuestion> pickRandom(List<BankQuestion> pool, int n, {Random? rng})`:
- `pool` = أسئلة البنك ضمن النطاق (كل البنك / `subject == x` / `tags.contains(y)`) — يُجلب من الكنترولر.
- `n >= pool.length` → ترجّع نسخة مخلوطة من `pool` كله.
- وإلا → `pool.shuffled(rng).take(n)` — بلا تكرار داخل الطلب.
- `pool` فارغ → قائمة فارغة (الواجهة تعرض "لا توجد أسئلة في هذا النطاق").
- قابل للاختبار مباشرة (`rng` محقون).

## R6 — "نسخة جديدة": إلكتروني فقط أم يشمل الورقي؟

**السياق**: الورقي ملوش أسئلة مخزّنة سؤال-سؤال — نسخه = نسخ الاسم + الدرجات بس، قيمة محدودة، وممكن يلخبط المدرس (يفتكر إن فيه أسئلة).

**القرار**: **الإلكتروني فقط في v1**. زر "نسخة جديدة" يظهر في `online_exams_tab._actions` لكل الحالات (draft/published/stopped/removed). الورقي مؤجّل (خارج نطاق فعلي — يُذكر في spec Out of Scope لاحقًا لو طُلب). يبسّط FR-016..FR-021 على مسار واحد.

## R7 — قسم "قوالب" منفصل أم "تكرار" فقط؟

**القرار**: **"تكرار" فقط في v1** — لا علامة `is_template`، لا قسم منفصل، لا عمود DB جديد على `exams`. أي امتحان يتكرر بزر واحد. لو المدرس عايز "قالب"، يعمل امتحان مسمّى "قالب X" ويكرّره. أبسط، صفر DB على `exams`. (توسّع مستقبلي ممكن لو التبنّي عالي.)

## R8 — مزامنة `bank_questions`

**القرار**: نمط spec 024 لـ`exam_questions` بالحرف:
- `SyncEngine._tables`: `TABLE_BANK_QUESTIONS` (أي مكان — ملهوش أب، لكن نحطه بعد `exams` للاتساق). `_extendedTables`: يُضاف.
- `_pkCol`: `TABLE_BANK_QUESTIONS => COL_BQ_ID`.
- `_buildRemoteRow`: كل الحقول من `payload[COL_BQ_*]` + `base`. **ملهوش `*_remote_id` لأب** — بسيط.
- `_toLocalMap`: كل الحقول + `COL_SYNC_UPDATED_AT`/`COL_SYNC_REMOTE_ID`. بلا `return null` (ملوش أب).
- `_refreshUiForTable`: `case TABLE_BANK_QUESTIONS:` → `if (Get.isRegistered<QuestionBankController>()) Get.find<QuestionBankController>().refresh()`.
- **بلا dedup خاص** — البنك ملوش UNIQUE constraint غير الـPK؛ التعرّف بـ`remote_id` (تحديث) أو insert.
- `DatabaseService`: `insertBankQuestion`/`updateBankQuestion`/`deleteBankQuestion` → `_queueRowUpsert(TABLE_BANK_QUESTIONS, COL_BQ_ID, id)` / `_queueDelete`. نفس helpers spec 024.
- Supabase: `migration_question_bank.sql` — جدول واحد، RLS، trigger (`check_delete_exams` موجودة)، publication. يُطبَّق عبر SSH.

## R9 — ترقية DB

**القرار**: `DATABASE_VERSION` 27 → **28**. `_onCreate` + بلوك `if (oldVersion < 28)` يشغّل `_bankQuestionsTableSql` (جدول جديد بأعمدة المزامنة من الأول — لا ALTER). نمط spec 021 (`student_follow_ups`) بالحرف.

## ملخص القرارات

| # | القرار |
|---|---|
| R1 | `BankQuestion` صنف مستقل + `toExamQuestion` / `fromExamQuestion` |
| R2 | استخراج `QuestionEditor` widget مشترك (مع احتياط: نسخة نظيفة لو الاستخراج خطر) |
| R3 | `tags` JSON list، فلترة في Dart |
| R4 | `subject` حقل حر + autocomplete من DISTINCT، حدّ 60 حرف |
| R5 | `pickRandom(pool, n, {rng})` منطق نقي قابل للاختبار |
| R6 | "نسخة جديدة" للإلكتروني فقط في v1 |
| R7 | "تكرار" فقط — لا قسم قوالب، لا عمود على `exams` |
| R8 | مزامنة `bank_questions` نمط `exam_questions` (spec 024) + القناة الممتدة |
| R9 | DB v27→v28، جدول جديد، نمط spec 021 |
