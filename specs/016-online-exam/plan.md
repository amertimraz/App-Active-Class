# Implementation Plan: امتحان إلكتروني (اختبار أونلاين)

**Branch**: `016-online-exam` | **Date**: 2026-09-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/016-online-exam/spec.md`

## Summary

تبويب جديد "امتحان إلكتروني" جوه شاشة الامتحانات. المدرس يؤلّف أسئلة موضوعية (صح/خطأ + اختيار من متعدد)، يحدّد نافذة فتح/قفل + مدة لكل طالب + المجموعات، وينشر. النشر يرفع الامتحان **بدون الإجابات الصحيحة** لـ Firestore تحت نفس `{slug}` المشتق من كود الترخيص (المستخدم حاليًا في بوابة الأهالي والحجوزات). صفحة ثابتة جديدة `booking_site/exam/` على `active-class.online/exam/{slug}` — الطالب يدخل بكوده + آخر 4 أرقام من تليفون ولي الأمر (هوية بوابة الأهالي)، يحلّ بمؤقّت، أسئلة/اختيارات مخلوطة، يسلّم **مرة واحدة** (مستند create-only). التطبيق يسحب التسليمات، يصحّح موضعيًا (الإجابات الصحيحة ما تغادرش الجهاز)، يعرض النتائج بحالة "بانتظار الاعتماد"؛ عند الاعتماد تُكتب الدرجة في `exam_grades` — ومن هناك خط أنابيب النتائج الحالي (بوابة الأهالي + واتساب سبيك 008) يشتغل بدون تغيير.

**النهج المعماري**: إعادة استخدام نمط بوابة الأهالي بالكامل — `{slug}` حتمي، مصادقة Firestore مجهولة، الحماية في معرّف المستند `{code}_{last4}` مش في قواعد معقّدة. جدولان محليان جديدان (`exam_questions`, `exam_submissions`) + أعمدة حالة على `exams`. DB v22 → v23. خدمة جديدة `OnlineExamService` على غرار `ParentPortalService`.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter

**Primary Dependencies**: GetX، sqflite، cloud_firestore + firebase_auth (مصادقة مجهولة، موجودة)، url_launcher. لا حزم جديدة. صفحة الطالب: Firebase JS SDK 10.12.0 عبر CDN (نفس `booking_site/track` و`booking_site/book` بالظبط).

**Storage**:
- محلي (sqflite): جدولان جديدان `exam_questions`، `exam_submissions`؛ أعمدة جديدة على `exams` (`is_online`, `online_status`, `opens_at`, `closes_at`, `duration_minutes`). لا تغيير على `exam_grades`.
- سحابي (Firestore): شجرة جديدة `online_exams/{slug}/exams/{examId}` + `/attempts/{code}_{last4}` + `/submissions/{code}_{last4}`. قراءة هوية الطالب من `parent_portal/{slug}/students/{code}_{last4}` الموجود.

**Testing**: يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات (نهج specs 009–015).

**Target Platform**: Android (arm64 + v7a، split-per-abi) للتطبيق؛ أي متصفح موبايل حديث لصفحة الطالب.

**Project Type**: تطبيق موبايل single-project + موقع ثابت (`booking_site/`).

**Performance Goals**: فتح الامتحان على صفحة الطالب < 5 ثوانٍ على 3G مصري (SC-002)؛ سحب وتصحيح 50 تسليمًا < 10 ثوانٍ؛ التأليف/التصحيح/الاعتماد فوري.

**Constraints**:
- الإجابات الصحيحة **لا تُرفع أبدًا** للسحابة (SC-004، FR-034).
- الطالب لا يرى درجة/إجابات قبل اعتماد المدرس (FR-019).
- تسليم واحد لكل طالب — مضمون بقاعدة `create` فقط لو المستند غير موجود (FR-016).
- التوقيت بوقت مطلق UTC (نمط `parentPortalExpiresAt`)، مش وقت جهاز الطالب (FR-015).
- migration صاعد فقط، `CREATE TABLE IF NOT EXISTS` + `ALTER TABLE ... ADD COLUMN` داخل `try/catch` (نمط v9–v22).
- توافق خلفي: صفر أثر على المدرسين بلا بوابة أهالي أو اللي ما يستخدموش التبويب (SC-006).
- الميزة مقفولة خلف `LicenseController.to.parentPortalActiveNow` (FR-002).

**Scale/Scope**: ~8 ملفات lib جديدة/معدّلة + migration واحدة + صفحة ثابتة واحدة + بلوك قواعد Firestore واحد. لا تغيير على `sync_engine` (الأسئلة/التسليمات محلية للمدرس في v1).

## Constitution Check

`.specify/memory/constitution.md` = placeholders، مفيش مبادئ ملزمة. المشروع يتبع نمط specs 003/008/012:
- مصدر حقيقة واحد للنتيجة (`exam_grades`) — الامتحان الإلكتروني يغذّيه، لا يوازيه.
- إعادة استخدام البنية القائمة (`{slug}`، مصادقة مجهولة، هوية `{code}_{last4}`) بدل اختراع نظام.
- migration محافظة بـguard؛ تحقّق يدوي؛ توافق خلفي كامل.
- أمان: أقل امتياز على قواعد Firestore؛ لا بيانات حسّاسة في المستند العام.

**النتيجة**: PASS (قبل وبعد التصميم).

## Project Structure

### Documentation (this feature)

```text
specs/016-online-exam/
├── plan.md · research.md · data-model.md · quickstart.md
├── contracts/
│   ├── firestore-online-exams.md      # شكل المستندات + قواعد الأمان
│   └── student-exam-page.md            # عقد صفحة الطالب (مدخلات/حالات/سلوك)
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                      # DATABASE_VERSION 22→23؛
│                                           # TABLE_EXAM_QUESTIONS/TABLE_EXAM_SUBMISSIONS + أعمدتها؛
│                                           # أعمدة exams: is_online/online_status/opens_at/closes_at/duration_minutes
├── models/
│   ├── exam_model.dart                     # + isOnline, onlineStatus (enum), opensAt, closesAt,
│   │                                       #   durationMinutes + toMap/fromMap/copyWith
│   ├── exam_question_model.dart            # جديد — ExamQuestion (type enum: trueFalse/mcq)
│   └── exam_submission_model.dart          # جديد — ExamSubmission + SubmissionStatus enum
├── services/
│   ├── database_service.dart               # _createTables: جدولان + أعمدة؛ _onUpgrade v23؛
│   │                                       #   CRUD أسئلة؛ upsert/get تسليمات؛ setExamOnlineStatus؛
│   │                                       #   allowedStudentCodesForGroups(groupIds)
│   ├── online_exam_service.dart            # جديد — publish/unpublish/stopNow/deleteRemote،
│   │                                       #   fetchSubmissions(examId)، يعيد استخدام slug من ParentPortalService
│   └── parent_portal_service.dart          # كشف ensureSlug()/deterministic slug للاستخدام المشترك (public)
├── controllers/
│   └── exam_controller.dart                # authoring الأسئلة؛ publishOnlineExam؛ pullAndGrade؛
│                                           #   approveGrade(single/all)؛ markNotSubmittedAbsent
└── views/
    └── exams/
        ├── exams_page.dart                 # DefaultTabController: تبويب "ورقي" (الحالي) + "إلكتروني"
        ├── online_exam_editor_page.dart    # جديد — تأليف الأسئلة + إعدادات النافذة/المدة/المجموعات + نشر
        └── online_exam_results_page.dart   # جديد — تحديث النتائج، مراجعة، تعديل يدوي، اعتماد

booking_site/
└── exam/
    └── index.html                          # جديد — صفحة الطالب (نمط track/index.html)

firestore.rules                             # + بلوك online_exams/{slug}
```

**Structure Decision**: single-project + موقع ثابت. أكبر جزء: `online_exam_service.dart` + صفحة الطالب + قواعد Firestore (الجزء السحابي)، يليه UI التأليف/النتائج. الجزء المحلي (migration + models + DB CRUD) مباشر على نمط سبيك 013 US6.

## Complexity Tracking

> لا انتهاكات — القسم فاضي.
