# Implementation Plan: إرسال نتيجة الامتحان لولي الأمر عبر واتساب

**Branch**: `008-exam-whatsapp-results` | **Date**: 2026-08-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/008-exam-whatsapp-results/spec.md`

## Summary

إضافة زرار إرسال واتساب فردي جنب كل صف طالب في شاشة رصد درجات الامتحان (`exam_grades_page.dart`)، وزرار "إرسال للكل" في الـAppBar، بنفس نمط إرسال تقرير الحضور الموجود بالفعل في `attendance_page.dart` (روابط `wa.me` تُفتح واحدة ورا التانية، بعد انتظار رجوع التطبيق من الخلفية). الرسالة بتتولّد وقت الإرسال من بيانات `ExamGrade` + `Exam` + رقم ولي أمر الطالب — مفيش تخزين جديد.

## Technical Context

**Language/Version**: Dart / Flutter (نفس إصدار المشروع الحالي)

**Primary Dependencies**: GetX (`ExamController`)، `url_launcher` (موجود بالفعل، مُستخدَم في `attendance_page.dart`)، `sqflite` عبر `DatabaseService`

**Storage**: `sqflite` — لا حاجة لجدول/عمود جديد؛ الرسالة تُبنى وقت الإرسال من `exam_grades` + `exams` + `students.guardian_phone` الموجودين بالفعل

**Testing**: يدوي/على الجهاز فقط، اتساقًا مع بقية المشروع (لا اختبارات آلية)

**Target Platform**: Android (Flutter mobile app)

**Project Type**: تطبيق موبايل واحد موحّد (لا فصل frontend/backend)

**Performance Goals**: غير منطبق — عملية يدوية بضغطة زرار، لا حِمل أداء يُذكر

**Constraints**: لازم تعيد استخدام نفس منطق تطبيع رقم الهاتف (`normalizePhone`) وآلية `wa.me` + انتظار رجوع التطبيق (`_atWaitForResume` أو ما يعادلها) المستخدمة بالفعل في `attendance_page.dart`، بدل تكرار منطق جديد منفصل

**Scale/Scope**: شاشة واحدة (`exam_grades_page.dart`) + إضافات صغيرة على `ExamController`/`ExamGrade` — لا تغييرات على شاشات أخرى

## Constitution Check

لا يوجد ملف دستور مملوء فعليًا للمشروع (لسه على القالب الافتراضي) — لا بوابات (gates) واجبة التطبيق هنا.

## Project Structure

### Documentation (this feature)

```text
specs/008-exam-whatsapp-results/
├── plan.md              # هذا الملف
├── research.md          # Phase 0
├── data-model.md         # Phase 1
├── quickstart.md        # Phase 1
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

مشروع Flutter موحّد واحد — لا خيارات هيكلية بديلة. الملفات المتأثرة:

```text
lib/
├── models/
│   └── exam_grade_model.dart        # لا تغييرات بنيوية؛ استخدام الحقول الموجودة
├── controllers/
│   └── exam_controller.dart         # دالة جديدة: buildGuardianExamResultMessage(...)
├── views/exams/
│   └── exam_grades_page.dart        # زرار فردي في _GradeRow + زرار "إرسال للكل" بالـAppBar
│                                     # + تحميل خرائط guardianPhone للطلاب (Map<int, Student>)
```

**Structure Decision**: لا هيكل جديد — إضافات محدودة داخل نفس الملفات الثلاثة أعلاه، معتمدة على النمط الموجود بالفعل في `attendance_page.dart` (نُقل منطق بناء رقم الهاتف وفتح `wa.me` بنفس الشكل، بدون تكرار كامل الكود — دالة مساعدة مشتركة صغيرة أو نسخ مباشر حسب حجم الكود الفعلي وقت التنفيذ).

## Complexity Tracking

لا يوجد انتهاكات تستدعي تبريرًا — الميزة صغيرة ومحصورة في نمط موجود بالفعل.
