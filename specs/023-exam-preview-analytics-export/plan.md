# Implementation Plan: تطويرات الامتحانات — معاينة، تحليل، تصدير، شرح الإجابة، حذف

**Branch**: `023-exam-preview-analytics-export` | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/023-exam-preview-analytics-export/spec.md`

## Summary

٥ إضافات لجزء الامتحانات، كل واحدة مستقلة:

1. **معاينة الامتحان قبل النشر (US1, P1)** — شاشة عرض جديدة `OnlineExamPreviewPage` تُفتح من `OnlineExamEditorPage` عبر زر "معاينة"؛ تعرض الأسئلة كما يراها الطالب (نص/اختيارات/صورة/نقاط) + ترويسة (اسم/عدد/درجة/مدة)، للقراءة فقط، بلا إجابة صحيحة أو شرح. صفر DB، صفر شبكة.
2. **شرح الإجابة الصحيحة (US2, P2)** — عمود جديد `explanation TEXT` على `exam_questions` (ترقية DB v25→v26، نمط spec 019 بالظبط)؛ `ExamQuestion.explanation` (لا يظهر في `toCloudMap`)؛ حقل في محرّر السؤال؛ `QuestionResult.explanation` → `publishReview` questions array → `renderReview` في `booking_site/exam/index.html` (نشر VPS).
3. **إحصائيات الأسئلة (US3, P3)** — خدمة Dart نقية `ExamAnalyticsService.compute(questions, submissions)` تُرجع `List<QuestionAnalytics>`؛ عرض عبر صفحة كاملة `ExamAnalyticsPage`، تُفتح من أيقونة في AppBar لـ`OnlineExamResultsPage`. تستبعد `SubmissionStatus.voided`. صفر DB، صفر شبكة.
4. **تصدير نتائج الامتحان (US4, P3)** — طرق جديدة في `ExportService`: `exportOnlineExamResults(...)` و`exportExamGradesSheet(...)` (كل المجموعات). Excel (`excel` package) + PDF (`pdf`/`printing`) + `Share.shareXFiles`. زر "تصدير" في `OnlineExamResultsPage` و(شاشة على مستوى الامتحان) لدرجات الورقي.

5. **حذف الامتحان الإلكتروني نهائيًا (US5, P2)** — زر "حذف نهائي" + حوار تأكيد في `online_exams_tab.dart` لكل الحالات. `ExamController.deleteOnlineExam(examId)` = `_online.deleteRemote(examId)` (best-effort، يُوسَّع ليشمل `results`) ثم `_db.deleteExam(examId)` (المسار الموجود: كاسكيد محلي + `_queueDelete` للفريق) ثم `loadExams()`. صفر DB جديد، صفر تعديل Firestore rules.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX (state), sqflite (DB, rollback-journal), cloud_firestore + firebase_auth (anonymous — online exams), `pdf: ^3.10.0`, `printing: ^5.11.0`, `share_plus: ^10.0.0`, `excel: ^4.0.6`. كلها موجودة في `pubspec.yaml` — صفر تبعيات جديدة.

**Storage**: sqflite محلي. ترقية واحدة: `DATABASE_VERSION` 25 → 26، عمود `explanation TEXT` على `TABLE_EXAM_QUESTIONS`. `exam_questions` **محلي بالكامل** (خارج `SyncEngine._tables`) — صفر تعامل مع Supabase/الفريق. Firestore: مستند مراجعة الطالب `online_exams/{slug}/exams/{examId}/results/{attemptKey}` يتوسّع بحقل `explanation` لكل سؤال — **صفر تعديل Firestore rules** (`allow read: if true` + `_oeOwner` للكتابة موجودة من ميزة المراجعة).

**Testing**: `flutter test` — وحدات نقية لـ`ExamAnalyticsService` (نمط `test/at_risk_service_test.dart`). تحقّق يدوي عبر quickstart للبقية.

**Target Platform**: Android (تطبيق المدرس) + صفحة ويب ثابتة على VPS (`booking_site/exam/index.html`) لمراجعة الطالب.

**Project Type**: Mobile single-project (`lib/`) + ملف ويب ثابت واحد.

**Performance Goals**: كل الحسابات محلية على ≤ ~200 تسليم / ~50 سؤال — فورية. التصدير ≤ ~2 ثانية لتوليد الملف.

**Constraints**:
- **أمني (ثابت)**: `ExamQuestion.toCloudMap()` يجب أن يبقى **بلا** `correctIndex`/`points`/`explanation` (spec 016 FR-034 + FR-010 هنا). الشرح يخرج فقط في `results/{attemptKey}` بعد الاعتماد.
- المعاينة والتحليل offline-capable بالكامل.
- كل كتابات Firestore best-effort (try/catch + debugPrint) — فشل الشبكة لا يفشّل العملية المحلية.
- RTL/عربي في كل المخرجات (PDF/Excel/الشاشات).

**Scale/Scope**: ~4 ملفات جديدة، ~10 ملفات معدّلة، ملف ويب واحد. مدرّس واحد لكل جهاز.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` قالب فارغ (placeholders فقط) — لا مبادئ محدّدة تُفرض. تُطبَّق أعراف المشروع الفعلية المستخلصة من الأكواد:

| عُرف المشروع | الالتزام |
|---|---|
| صفر تبعيات جديدة إن أمكن | ✅ كل المكتبات موجودة |
| ترقية DB تدريجية غير مدمّرة (`ALTER TABLE ADD COLUMN`) | ✅ نمط v24 (spec 019) بالظبط |
| منطق قابل للاختبار في خدمات Dart نقية | ✅ `ExamAnalyticsService` نقية (نمط `AtRiskService`) |
| صفر تعديل Firestore rules ما لم يلزم | ✅ لا تعديل (القواعد الحالية تكفي) |
| الإجابة الصحيحة/الشرح لا يخرجان في المستند العام | ✅ مفروض في نقطة `toCloudMap` نفسها |
| إعادة استخدام أنماط موجودة (ExportService, sheets) | ✅ |

**النتيجة**: PASS — لا انتهاكات، `Complexity Tracking` غير مطلوب.

## Project Structure

### Documentation (this feature)

```text
specs/023-exam-preview-analytics-export/
├── plan.md              # هذا الملف
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/           # Phase 1
│   ├── exam-question-explanation.md
│   ├── exam-analytics-service.md
│   ├── exam-results-export.md
│   ├── student-review-doc.md
│   └── online-exam-delete.md
├── checklists/
│   └── requirements.md  # موجود من /speckit-specify
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                       # [M] DATABASE_VERSION 26، COL_EQ_EXPLANATION، (اختياري) ثابت route المعاينة
├── models/
│   ├── exam_question_model.dart             # [M] حقل explanation (لا في toCloudMap)، toMap/fromMap/copyWith/isValid دون تغيير
│   ├── exam_submission_model.dart           # [M] QuestionResult.explanation
│   └── exam_analytics_model.dart            # [NEW] QuestionAnalytics (كيان محسوب، غير مخزَّن)
├── services/
│   ├── database_service.dart                # [M] عمود explanation في _examQuestionsTableSql + migration v26؛ getExamsGradesForExport (كل المجموعات)
│   ├── exam_analytics_service.dart          # [NEW] compute(questions, submissions) → List<QuestionAnalytics> (Dart نقي)
│   ├── export_service.dart                  # [M] exportOnlineExamResults(...) + exportExamGradesSheet(...) — Excel + PDF
│   └── online_exam_service.dart             # [M] publishReview: +'explanation'؛ deleteRemote: +'results' في حلقة المجموعات الفرعية
├── controllers/
│   └── exam_controller.dart                 # [M] questionResults(): تمرير explanation؛ deleteOnlineExam(examId) جديدة؛ republishQuestions يظل بلا شرح (تلقائي)
└── views/exams/
    ├── online_exam_editor_page.dart         # [M] زر "معاينة" في AppBar؛ حقل "شرح (اختياري)" في _questionCard
    ├── online_exam_preview_page.dart        # [NEW] شاشة عرض للقراءة فقط
    ├── online_exam_results_page.dart        # [M] زر "تصدير" + أيقونة "تحليل الأسئلة"
    ├── exam_analytics_page.dart             # [NEW] عرض QuestionAnalytics (صفحة كاملة)
    ├── online_exams_tab.dart                # [M] زر "حذف نهائي" + حوار تأكيد لكل الحالات
    └── exam_grades_page.dart                # [M] زر تصدير (Excel/PDF) + نطاق (هذه المجموعة/كل المجموعات)

booking_site/exam/index.html                 # [M] renderReview: عرض q.explanation تحت الإجابة الصحيحة + CSS — نشر VPS

test/
└── exam_analytics_service_test.dart          # [NEW] وحدات: نسبة الصح، توزيع الاختيارات، غير المجيبين، استبعاد voided، تجميع بهوية السؤال
```

**Structure Decision**: Mobile single-project قائم. كل الإضافات على `lib/` + ملف ويب ثابت واحد. شاشتان جديدتان فقط (`online_exam_preview_page`, `exam_analytics_page`)؛ الباقي حقن في شاشات/خدمات موجودة (بما فيها زر الحذف في `online_exams_tab`). موديل/خدمة جديدة صغيرة (`exam_analytics_model`, `exam_analytics_service`).

## Phase 0 — Research

انظر [research.md](research.md). أسئلة محسومة:
- نقطة تصدير درجات الامتحان الورقي "كل المجموعات" (شاشة/زر).
- صيغة التصدير: Excel + PDF أم واحدة؟
- التحليل: bottom sheet أم صفحة كاملة؟
- حدّ طول الشرح وطريقة عرضه على الموقع.
- أين يُحقن `explanation` في مسار `pullAndGradeOnlineExam`/`questionResults`.
- حذف الامتحان الإلكتروني: إعادة استخدام `deleteExam` + توسيع `deleteRemote` بمجموعة `results`؛ زر لكل الحالات.

## Phase 1 — Design & Contracts

- [data-model.md](data-model.md) — `explanation` على ExamQuestion، `QuestionResult.explanation`، `QuestionAnalytics`، `ResultExportRow`، توسّع مستند `results/{attemptKey}`، ترقية DB v26، حذف الامتحان الإلكتروني (بلا كيان جديد).
- [contracts/](contracts/) — ٥ عقود: عمود/موديل الشرح، خدمة التحليل، تصدير النتائج، مستند مراجعة الطالب، حذف الامتحان الإلكتروني.
- [quickstart.md](quickstart.md) — سيناريوهات تحقّق يدوي + تشغيل الاختبارات.

## Complexity Tracking

لا انتهاكات. القسم غير مطلوب.
