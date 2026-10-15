# Implementation Plan: صحة البيانات — اكتشاف ودمج المكرّر

**Branch**: `052-data-health-merge` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/052-data-health-merge/spec.md`

## Summary

نواة صرفة قابلة للاختبار تكتشف التكرار وتبني "خطة دمج" (منقول/محذوف/متعارض) من بيانات محمّلة، وخدمة تنفّذ الخطة **ذرّيًا في transaction واحدة** على قاعدة SQLite المحلية ثم تطابر تغييرات المزامنة بالترتيب الصحيح (تحديثات النقل أولًا ثم حذف المكرّر)، فتوصل للمساعد بالمزامنة العادية بلا أي شغل على السيرفر. الواجهة: شاشة "صحة البيانات" (فحص ← حالات ← معاينة ← تأكيد) تحت فئة البيانات للمالك فقط، بنسخة احتياطية إجبارية قبل التنفيذ (نفس آلية حذف السجلات). القواعد مطابقة لسكربت تنظيف Grade 2 اللي اتجرّب (24 طالب، 288 حضور، 64 واجب، 30 درجة، 1 دفعة).

## Technical Context

**Language/Version**: Flutter 3.38 / Dart 3.5، GetX، sqflite (DATABASE_VERSION = 39، **لا تغيير**)

**Primary Dependencies**: لا إضافات. موجود: `BackupService`، `DatabaseService` (`_queueSync/_queueDelete/_queueRowUpsert`)، `TeamModeService`.

**Storage**: SQLite محلي (جداول موجودة). سجل العمليات يتخزّن كـJSON في جدول الإعدادات (`settings` key/value، غير متزامن) — **صفر migration، صفر تغيير سيرفر**.

**Testing**: اختبارات وحدة للنواة (الاكتشاف + خطة الدمج) + اختبارات على قاعدة in-memory للتنفيذ لو متاح sqflite_common_ffi، وإلا تحقق يدوي. تحقق يدوي على الجهاز (quickstart).

**Target Platform**: Android (APK direct + AAB play)

**Project Type**: mobile-app (Flutter)

**Performance Goals**: فحص ومعاينة 1000 طالب و50 ألف حضور < 30 ثانية بلا تعليق للـUI.

**Constraints**: لا حذف نهائي بلا نسخة؛ كله أو ولا حاجة (transaction)؛ المالك فقط؛ يشتغل بدون وضع الفريق؛ لا تغيير في مفاتيح الإعدادات؛ المساعدون على v1.2.74+ (حماية 049) لمنع رجوع المكرّر.

**Scale/Scope**: ~8 ملفات جديدة (نواة 2 + خدمة 1 + كنترولر 1 + صفحة 1 + اختبارات 2 + تعديل 3 ملفات صغيرة).

## Constitution Check

`.specify/memory/constitution.md` قالب غير مُعبَّأ → لا بوابات. ملتزم بأنماط المشروع: دوال صرفة + اختبارات، نسخة احتياطية قبل أي حذف جماعي، احترام وضع الفريق والصلاحيات.

## Project Structure

### Documentation (this feature)

```text
specs/052-data-health-merge/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── merge-rules.md        # قواعد الدمج لكل جدول + ترتيب طابور المزامنة
├── checklists/requirements.md
└── tasks.md                  # /speckit-tasks
```

### Source Code (repository root)

```text
lib/utils/duplicate_detection.dart          (جديد، صرف) تطبيع الاسم + اكتشاف المجموعات/الطلاب المكرّرين + اختيار الأساسي
lib/utils/merge_plan.dart                   (جديد، صرف) خطة الدمج: منقول/محذوف/متعارض من مدخلات بسيطة + الملخص
lib/services/data_health_service.dart       (جديد) الفحص (استعلامات GROUP BY) + التنفيذ الذرّي + سجل العمليات
lib/controllers/data_health_controller.dart (جديد) حالة الشاشة: فحص/اختيار/معاينة/تنفيذ/نتيجة
lib/views/settings/data_health_page.dart    (جديد) شاشة صحة البيانات
lib/views/settings/categories/data_category.dart  (تعديل) سطر تنقّل "صحة البيانات" (مخفي للمساعد)
lib/views/settings/settings_registry.dart   (تعديل) عنصر data.data_health + تحديث اختبار الجرد (nav 9 → 10)
lib/services/database_service.dart          (تعديل صغير) دوال استعلام عدّادات مجمّعة + عدّاد الـoutbox
lib/main.dart / routes                      (تعديل صغير لو لزم route)
test/duplicate_detection_test.dart          (جديد)
test/merge_plan_test.dart                   (جديد)
```

**Structure Decision**: مشروع Flutter موجود؛ منطق الاكتشاف والخطة في `lib/utils` (صرف، بلا GetX/DB) والتنفيذ في خدمة تحت `lib/services`، بنفس نمط `deleteRecordsInRange`/`DeleteRecordsController`.

## Design notes

- **الاكتشاف والتنفيذ مفصولين**: الفحص بيبني `DuplicateCase`s (قراءة فقط) ثم `MergePlan` بالمعاينة؛ التنفيذ بياخد الخطة الجاهزة (مش بيعيد الاكتشاف) فالمعاينة = ما بيتنفّذ بالظبط (SC-002).
- **التنفيذ**: (1) collect: لكل صف هيتحذف (جدول، pk، remote_id) قبل التعديل، وكل صف هيتنقل؛ (2) transaction واحدة: نقل الصفوف (UPDATE student_id)، حذف الصفوف المكرّرة، حذف الطالب/المجموعة المكرّرة، نقل الطلاب/الامتحانات للمجموعة الأساسية؛ (3) بعد الـcommit: طابور المزامنة بالترتيب **تحديثات النقل ← حذف الصفوف المكرّرة ← حذف الطلاب ← حذف المجموعة**.
- **سبب الترتيب**: المساعد لو استقبل حذف الطالب (cascade محلي) قبل تحديثات أطفاله، الأطفال المنقولة بترجع كـinsert بنفس الـremote id وتتحوّل للطالب الأساسي — يتقارب في الحالتين، لكن الترتيب أنظف وبيقلّل الرجوع للسيرفر.
- **شرط سلامة في وضع الفريق**: الطالب/المجموعة الأساسية لازم تكون متزامنة (`remote_id` موجود) قبل ما نطابر تحديثات النقل (الـpush بيتخطّى الصف لو remote id الطالب مش موجود) — فحص مسبق مع رسالة "استنّى المزامنة".
- **التعارض**: الأساسي يكسب؛ العدد بيظهر في المعاينة (حضور بحالة مختلفة). الدفعات المرشّحة للإزالة بتتعرض قائمة مفصّلة وقابلة للاستبعاد.
- **الأمان**: `BackupService().createBackup()` إجباري؛ فشله يمنع التنفيذ؛ أي استثناء داخل الـtransaction يلغيها بالكامل (sqflite rollback)؛ الاسترجاع المضمون من النسخة (نفس شاشة الاستعادة الموجودة).
- **المساعد**: الشاشة والتنفيذ مقفولين عليه (`isAssistant`)؛ التنفيذ بيستخدم `requireTeamOwnerIfTeamMode` زي الحذف الجماعي.
- **الإخوة**: لو المكرّر في مجموعة إخوة، نستدعي نفس منطق `_unlinkOrphanedSiblingSurvivor` بعد حذفه (زي `deleteStudent`)، والأساسي بيحتفظ بربطه.
