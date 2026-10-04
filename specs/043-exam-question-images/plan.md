# Implementation Plan: صور أسئلة الامتحان الإلكتروني — قص + صورة للشرح + صورة لكل اختيار

**Branch**: `043-exam-question-images` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

## Summary

إضافة خطوة قص إجبارية قبل رفع أي صورة سؤال (موجودة بالفعل)، وحقلين جديدين على السؤال: صورة شرح (محلية فقط، تظهر بعد الاعتماد زي النص) وصور اختيارات (جزء من `toCloudMap`، تظهر وقت أداء الامتحان). يمتد التغيير لأربع طبقات: الموديل/DB/المزامنة، محرّري الامتحان وبنك الأسئلة (Flutter)، شاشة المعاينة ومسار المراجعة بعد الاعتماد، وصفحة أداء الامتحان على الويب (`booking_site/exam/index.html`، داخل نفس الريبو).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1 (موبايل) + JS ثابت بلا بناء (`booking_site/exam/index.html`)
**Primary Dependencies**: `image_picker` (موجود) + **جديد**: `image_cropper` (قص تفاعلي)، `dio` (رفع، موجود عبر `BookingService`)، GetX، Firestore (الويب فقط، عبر SDK مضمّن في الصفحة)
**Storage**: SQLite محلي (DB v35→**v36**) + Supabase (أعمدة جديدة على `exam_questions`/`bank_questions`) + رفع صور على نفس نقطة الـVPS الحالية (`BookingService.uploadExamImage`)
**Testing**: `flutter test` لمنطق صرف (تسلسل صور الاختيارات مع حذف/إضافة اختيار، فلترة null) + تحقق يدوي على جهاز (محرّر + أداء امتحان فعلي من متصفح)
**Target Platform**: Android (تطبيق المدرّس) + أي متصفح (صفحة أداء الامتحان للطالب)
**Project Type**: mobile app + صفحة ويب ثابتة ضمن نفس الريبو
**Constraints**: صورة الشرح لا تدخل `toCloudMap` العام (تسريب قبل الاعتماد)؛ صور الاختيارات لازم تدخله؛ فشل تحميل صورة فردية عند الطالب لا يوقف الامتحان؛ القص إجباري لكل صورة جديدة (لا رفع مباشر من المعرض)
**Scale/Scope**: حتى 6 اختيارات بالسؤال (الحد الحالي) × صورة اختيارية لكل واحد + صورة شرح واحدة + صورة السؤال القديمة

## Constitution Check

لا مبادئ مُفعَّلة في `.specify/memory/constitution.md` (قالب فقط). ملتزم بأعراف المشروع: DB migration بنمط `_onUpgrade` + try/catch لكل عمود، تحديث `sync_engine.dart` (push/pull + القناة الممتدة لأن `exam_questions`/`bank_questions` فيها أصلًا)، migration Supabase idempotent عبر SSH، فصل الحقول "المحلية فقط" (زي `explanation`) عن حقول `toCloudMap`.

## Project Structure

### Documentation
```text
specs/043-exam-question-images/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/question-images.md
└── checklists/requirements.md
```

### Source Code
```text
pubspec.yaml                                   # + image_cropper
lib/widgets/image_crop_picker.dart             # جديد: اختيار من المعرض + قص (مشترك)
lib/models/exam_question_model.dart            # + explanationImageUrl, optionImageUrls
lib/models/bank_question_model.dart            # + نفس الحقلين
lib/models/exam_submission_model.dart          # QuestionResult + نفس الحقلين
lib/config/constants.dart                      # + أعمدة جديدة + DATABASE_VERSION=36
lib/services/database_service.dart             # ALTER TABLE exam_questions/bank_questions
lib/services/sync_engine.dart                  # push/pull mapping للحقلين الجديدين (القناة الممتدة)
lib/controllers/exam_controller.dart           # questionResults() يمرّر الحقلين
lib/services/online_exam_service.dart          # publishReview يضيف optionImageUrls/explanationImageUrl
lib/views/exams/online_exam_editor_page.dart   # صورة شرح + صور اختيارات + استخدام image_crop_picker
lib/views/question_bank/question_editor_sheet.dart  # نفس الإضافات
lib/views/exams/online_exam_preview_page.dart  # عرض صورة الشرح وصور الاختيارات
booking_site/exam/index.html                   # عرض صورة كل اختيار (أداء) + صورة الشرح (مراجعة)
supabase/migration_exam_question_images.sql    # أعمدة جديدة على exam_questions + bank_questions
test/exam_question_images_test.dart            # منطق صرف (مواءمة الصور مع الاختيارات)
```

**Structure Decision**: ودجت قص مشتركة واحدة (`image_crop_picker.dart`) تستخدمها الشاشتان (محرّر الامتحان + محرّر بنك الأسئلة) لأي صورة (سؤال/شرح/اختيار) — بدل تكرار منطق `ImagePicker` + القص 3 مرات في كل شاشة. منطق مواءمة قائمة صور الاختيارات مع تغييرات الاختيارات (إضافة/حذف/إعادة ترتيب) صرف وقابل للاختبار في `test/`.
