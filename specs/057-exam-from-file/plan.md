# Implementation Plan: إنشاء امتحان إلكتروني من ملف أو صورة

**Branch**: `057-exam-from-file` (بدون branch فعلي) | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/057-exam-from-file/spec.md`

## Summary

التطبيق يجهّز الصور (ضغط، وتحويل صفحات PDF لصور) ويرفعها لخدمة جديدة على الـ VPS (`ai-worker`). الخدمة تتحقق من هوية المدرس، تخصم من حصته، وتبعت الصور لمزوّد ذكاء اصطناعي **قابل للتبديل** (Groq الافتراضي، Claude احتياطي أو للحالات الصعبة) بتعليمات ثابتة تطلّع أسئلة JSON منظّمة. الخدمة تتحقق من شكل الأسئلة وتنضّفها، وترجّعها للتطبيق، فيحطها في محرر الامتحان الإلكتروني الحالي كمسودة بعلامات «محتاج مراجعة». المفاتيح على السيرفر فقط، والصور بتتحذف من الذاكرة بعد المعالجة.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.38 (التطبيق)؛ Node.js 20 (خدمة `ai-worker` — نفس نمط `wa-worker`)

**Primary Dependencies**: التطبيق: `image_picker` و`file_picker` و`printing` (موجودين؛ `Printing.raster` لتحويل PDF لصور) + `image` لضغط الصور. الخدمة: `pg` فقط، و`fetch` المدمج (بدون SDKs) لاستدعاء المزوّدين.

**Storage**: Supabase Postgres: `ai_jobs` و`ai_quota` و`ai_config`. التطبيق: عمود محلي واحد على `exam_questions` (DB v44) للعلامات. الصور لا تُخزَّن.

**Testing**: `flutter test` (تحضير الصور، تحويل JSON لمسودات، شاشة المصدر)؛ `node --test` للخدمة (التحقق من الأسئلة، تحويل أخطاء المزوّدين، الحصة) بمزوّد وهمي؛ تجربة يدوية بـ 3 صور حقيقية على Groq وClaude.

**Target Platform**: Android (تطبيق)، VPS Linux (docker). الويب (spec 055) خارج النطاق لأول إصدار.

**Project Type**: mobile-app + خدمة backend صغيرة

**Performance Goals**: 5 صفحات في أقل من دقيقة لـ 90% من الطلبات؛ طلبات متزامنة محدودة بقائمة انتظار

**Constraints**: مفاتيح سرية على السيرفر فقط؛ لا تخزين للملفات؛ حد أقصى 10 صور/15 ميجا للطلب؛ لا نشر تلقائي؛ خصم الحصة صافيه صفر عند الفشل

**Scale/Scope**: عشرات المدرسين، عمليات قليلة يوميًا لكل واحد؛ شاشتين جدد (مصدر + مراجعة/تقدّم) + زر في المحرر

## Constitution Check

ملف constitution قالب فاضي (بلا بوابات). قواعد المشروع المطبّقة:

- **المساعدة**: موضوع جديد في `kHelpTopics` + تغطية في `help_coverage.dart` + اختبارات help الثلاثة. ✅ (مرحلة 6)
- **تصميم السبورة والطباشير** (`AppTokens`/`AppPanel`)، RTL، Cairo. ✅
- **Migration على السيرفر والنشر** بموافقة صريحة، والأسرار خارج git. ✅
- **sqflite**: تعديل DB v44 بعمود واحد، من غير نداء `db` جوه transaction. ✅
- **الفلوس/الحصة**: الأرقام افتراضات يقررها صاحب النظام. ✅

*Post-design*: لا مخالفات.

## Project Structure

### Documentation (this feature)

```text
specs/057-exam-from-file/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── ai-api.md              # عقد التطبيق ↔ ai-worker
│   └── provider-and-prompts.md # عقد المزوّدين + التعليمات + مخطط JSON
├── checklists/requirements.md
└── tasks.md                   # /speckit-tasks (لم يُنشأ)
```

### Source Code (repository root)

```text
supabase/
├── migration_ai_exam.sql              # ai_jobs, ai_quota, ai_config + RLS + ai_reserve/ai_release
└── ai-worker/
    ├── Dockerfile, package.json
    ├── src/
    │   ├── index.js                   # http + auth + قائمة انتظار
    │   ├── auth.js                    # التحقق من JWT (HS256) → owner_id
    │   ├── providers/{index,groq,claude}.js  # واجهة موحدة + fallback
    │   ├── prompts.js                 # تعليمات التحويل والتوليد + مخطط JSON
    │   ├── validate.js                # تنضيف الأسئلة وحساب الثقة
    │   └── jobs.js                    # حالة الطلب والحصة وidempotency
    └── test/
lib/
├── models/ai_draft_question.dart
├── services/ai_exam_service.dart      # رفع + polling + قراءة الحصة
├── utils/ai_exam_prepare.dart         # ضغط الصور + rasterize PDF + حدود الحجم
├── utils/ai_exam_mapper.dart          # JSON → ExamQuestion مسودة
├── views/exams/ai_exam_source_sheet.dart   # اختيار الوضع والمصدر والعدد والصعوبة
├── views/exams/ai_exam_progress_page.dart  # تقدّم + نتيجة
├── views/exams/online_exam_editor_page.dart # زر «من ملف أو صورة» + شارات المراجعة + منع النشر
├── models/exam_question_model.dart + database_service.dart # عمود review_flags (v44)
└── help/help_content.dart, help_coverage.dart
test/ (ai_exam_prepare_test, ai_exam_mapper_test, ai_exam_source_sheet_test)
```

**Structure Decision**: خدمة منفصلة `ai-worker` على نفس نمط `wa-worker` (السيرفر مفيهوش runtime functions، والأسرار على السيرفر). المزوّدين وراء واجهة واحدة `provider.extract(mode, images, opts)`، والتطبيق مش بيعرف أي مزوّد اشتغل.

## Phases

1. **Spike (قبل أي بناء)**: تجربة 3 صور حقيقية (امتحان مطبوع، صفحة كتاب، خط يد) على Groq وClaude بالتعليمات الفعلية، ومقارنة الدقة والتكلفة والزمن. نتيجته تحدّد المزوّد الافتراضي وتحدّث `research.md`.
2. **السيرفر**: migration + `ai-worker` (auth، مزوّدين، validate، حصة، idempotency) + اختبارات، ثم نشر (بموافقة).
3. **التطبيق P1**: التحضير، الخدمة، شاشة المصدر والتقدّم، دمج المسودة في المحرر مع منع النشر.
4. **التطبيق P2**: عرض الحصة والتحذير، رسالة نفاد، سجل العمليات.
5. **P3**: إرفاق صورة سؤال فيه شكل (قص).
6. **المساعدة والأدمن**: موضوع help، ولوحة الأدمن (repo منفصل) لضبط الحصة والرصيد والإيقاف، وتجربة مغلقة.

## Complexity Tracking

| الإضافة | ليه لازمة | البديل المرفوض |
|---|---|---|
| خدمة `ai-worker` جديدة | المفاتيح السرية + قائمة انتظار + حصة + تبديل مزوّد | الاستدعاء من التطبيق: يكشف المفتاح ويكسر الحصة |
| مزوّدين وراء واجهة | قرار صاحب النظام: Groq الأرخص، Claude الأدق | مزوّد واحد: خطر الجودة/التسعير بدون بديل |
| تحويل PDF لصور في التطبيق | Groq بياخد صور بس (حد 5 لكل طلب)، ويوحّد المسار | رفع PDF للسيرفر: يحتاج مكتبة تحويل ويزوّد الحجم |
