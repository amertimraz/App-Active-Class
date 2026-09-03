# Implementation Plan: شهادات تقدير + تطوير صفحة المراكز

**Branch**: `018-certificates-leaderboard` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/018-certificates-leaderboard/spec.md`

## Summary

3 أجزاء، كلها فوق بنية قائمة:
1. **شهادات تقدير** — خدمة جديدة `CertificateService` تبني PDF بـ`pdf`/`printing` (نفس نمط `ExportService`)، 2–3 قوالب `pw.Widget`. زر في `ExamGradesPage` + شاشة نتائج الامتحان الإلكتروني + صفحة الطالب + صفحة المراكز. شاشة اختيار الطلاب + القالب.
2. **صفحة المراكز** — إعادة تصميم `LeaderboardPage` (كروت + ترويسة متدرّجة + ميداليات)، فلاتر (الكل/مجموعة/امتحان/شهر)، توسيع `getLeaderboard` (استبعاد المؤرشفين، فلتر الشهر، tie-break ثابت)، زر مشاركة نص.
3. **زر مشاركة نتائج واتساب** في `OnlineExamResultsPage` — يعيد استخدام `ExamController.buildGuardianExamResultMessage` + مسار الإرسال في `exam_grades_page`.

**صفر تغييرات قاعدة بيانات** — الدرجات في `exam_grades`، تفضيل القالب في `app_settings` (key/value).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: `pdf` + `printing: ^5.11.0` (مستخدمين في `ExportService`، `exam_grades_page`, `group_details_page`)، GetX، `url_launcher` (واتساب)، `share_plus`. لا حزم جديدة. خطوط Cairo-Regular/Bold من `assets/fonts/` (محمّلة في `ExportService._loadFonts`).

**Storage**: لا شيء جديد. `exam_grades` (الدرجات)، `app_settings` (`SETTING_CERT_TEMPLATE` مفتاح جديد لتذكّر آخر قالب). `DATABASE_VERSION` يفضل 23.

**Testing**: يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات (نهج specs 009–017).

**Target Platform**: Android (arm64 + v7a).

**Project Type**: تطبيق موبايل single-project.

**Performance Goals**: توليد PDF لـ~15 شهادة < 5 ثوانٍ؛ صفحة المراكز تفتح فوري؛ إعادة الفلترة فورية.

**Constraints**:
- صفر تغيير سلوك لأي شاشة غير `LeaderboardPage` (بتتطوّر عمدًا) + إضافة أزرار.
- الشهادة عربي RTL، A4 رأسي، Cairo font.
- ترتيب الأوائل ثابت (tie-break بالاسم، مش عشوائي) — SC-005.
- المؤرشفون مستبعدون من المراكز — FR-016.
- كل مشاركة/إرسال بضغطة صريحة.

**Scale/Scope**: ~5 ملفات lib جديدة/معدّلة + توسيع `getLeaderboard`. لا migration.

## Constitution Check

`.specify/memory/constitution.md` = placeholders، مفيش مبادئ ملزمة. المشروع يتبع نمط specs 013/016/017: إعادة استخدام `ExportService` pattern + `buildGuardianExamResultMessage`، تحقّق يدوي، صفر تغيير سلوك للمخرجات القائمة.

**النتيجة**: PASS (قبل وبعد التصميم).

## Project Structure

### Documentation (this feature)

```text
specs/018-certificates-leaderboard/
├── plan.md · research.md · quickstart.md
├── contracts/
│   ├── certificate-templates.md    # محتوى/تخطيط كل قالب + مصادر البيانات
│   └── leaderboard-filters.md       # عقد الفلاتر + توسيع getLeaderboard
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                    # + const SETTING_CERT_TEMPLATE = 'cert_template';
├── models/
│   └── certificate_model.dart            # جديد — CertificateData (studentName, achievementText,
│                                         #   gradeText, dateText, teacherLine) + CertKind enum
│                                         #   (examExcellence / rank1 / rank2 / rank3 / appreciation)
├── services/
│   ├── certificate_service.dart          # جديد — buildCertificatesPdf(List<CertificateData>, template)
│   │                                     #   → Uint8List؛ 2–3 دوال قالب _templateClassic/_templateModern/_templateSimple
│   │                                     #   (نمط ExportService: _loadFonts, pw.Document, PdfColor)
│   └── database_service.dart             # getLeaderboard: + استبعاد is_archived=0،
│                                         #   + دعم monthKey (فلتر بـ effectiveReportMonth)،
│                                         #   + ORDER BY pct DESC, student_name ASC (tie-break ثابت)
├── controllers/
│   └── exam_controller.dart              # + certifiableStudents(examId) (grade > passingGrade && !absent)؛
│                                         #   getLeaderboard wrapper بالفلتر الجديد
└── views/
    ├── exams/
    │   ├── exam_grades_page.dart         # + زر "شهادات تقدير" في actions (US1)
    │   ├── online_exam_results_page.dart # + زر "إرسال النتائج واتساب" (US3) + زر "شهادات تقدير"
    │   ├── leaderboard_page.dart         # إعادة تصميم كامل + فلاتر + ميداليات + مشاركة (US2)
    │   └── certificates_sheet.dart       # جديد — شاشة/شيت: قائمة طلاب checkable + منتقي قالب + "توليد"
    └── students/
        └── student_details_page.dart     # + زر "شهادة تقدير" (تبويب الامتحانات أو الأكشنز) (US1/FR-008)

lib/utils/
└── leaderboard_share.dart               # جديد — buildLeaderboardShareText(entries, teacher, filterLabel)
```

**Structure Decision**: single-project. أكبر جزء: `certificate_service.dart` + القوالب + `leaderboard_page.dart` redesign. الباقي أزرار + توسيع query. لا migration.

## Complexity Tracking

> لا انتهاكات — القسم فاضي.
