# Implementation Plan: مدة تفعيل بوابة متابعة أولياء الأمور

**Branch**: `003-parent-portal-expiry` | **Date**: 2026-08-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-parent-portal-expiry/spec.md`

## Summary

بوابة متابعة أولياء الأمور دلوقتي مفعّلة/معطّلة بحقل `parentPortalEnabled` (bool) بس على مستند ترخيص المدرس في Firestore — بدون أي مفهوم مدة مستقلة. المطلوب: حقل تاريخ انتهاء مستقل (`parentPortalExpiresAt`) يتحكم فيه المطور يدويًا، ويقفل تلقائيًا (أ) قسم الإعدادات ونشر البيانات في تطبيق الموبايل، و(ب) الصفحة العامة `active-class.online/track/{slug}` المستضافة خارج هذا المستودع — بنفس نمط فحص انتهاء الترخيص الأساسي الموجود بالفعل، من غير أي بنية سيرفر جديدة.

## Technical Context

**Language/Version**: Dart/Flutter (تطبيق الموبايل) + JavaScript ES modules خام (الصفحة العامة، بدون build step)

**Primary Dependencies**: GetX (state)، `cloud_firestore` (Flutter + Firebase JS SDK v10.12.0 على الصفحة العامة عبر CDN مباشر)

**Storage**: Firestore — مستند `licenses/{code}` (مصدر الحقيقة، بيتعدّل يدويًا من المطور) + مستند عام `parent_portal/{slug}` (بيتنشر تلقائيًا من التطبيق، والصفحة العامة بتقرأه من غير مصادقة)

**Testing**: لا يوجد test suite آلي في المشروع — `flutter analyze` + تحقق يدوي عبر quickstart.md (نفس نمط الميزات السابقة هذه الجلسة)

**Target Platform**: Android (تطبيق الموبايل) + صفحة ويب ثابتة مستضافة على VPS خارجي (`root@192.99.145.122:/var/www/active-class.online/track/index.html`, خلف Caddy)

**Project Type**: mobile-app + إضافة تعديل صغير على صفحة ويب ثابتة موجودة (مش مشروع جديد، الاتنين موجودين بالفعل)

**Performance Goals**: غير منطبق (فحص تاريخ محلي بسيط، مفيش عمليات ثقيلة)

**Constraints**: بدون Cloud Functions أو أي بنية سيرفر جديدة — الفحص كله client-side (تطبيق + صفحة الويب) بمقارنة `DateTime.now()`/`Date.now()` مع تاريخ محفوظ في Firestore، بنفس نمط `LicenseController._validateLicense`/`_watchLicense` الحالي بالظبط

**Scale/Scope**: تعديل على ملفين في تطبيق Flutter (`license_controller.dart`, `parent_portal_service.dart`) + شاشة إعدادات واحدة (فحص شرط إضافي) + ملف HTML واحد خارج هذا المستودع (`track/index.html` على VPS منفصل)

## Constitution Check

*لا توجد بوابات رسمية مطبَّقة — `.specify/memory/constitution.md` قالب فارغ لم يُثبَّت بعد. الالتزام غير الرسمي بأعراف الكود القائمة (نفس نمط `LicenseController` الحالي لفحص الانتهاء، ونفس نمط الجلسات السابقة هذه الجلسة) هو المرجع.*

## Project Structure

### Documentation (this feature)

```text
specs/003-parent-portal-expiry/
├── plan.md              # هذا الملف
├── research.md          # Phase 0
├── data-model.md         # Phase 1
├── quickstart.md         # Phase 1
└── tasks.md              # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── controllers/
│   └── license_controller.dart      # + parentPortalExpiresAt (Rxn<DateTime>) + getter parentPortalActiveNow
├── services/
│   └── parent_portal_service.dart   # الفحوصات الأربعة تستخدم parentPortalActiveNow بدل parentPortalEnabled الخام
│                                     # + نشر parentPortalExpiresAt جوه مستند parent_portal/{slug} العام
└── views/
    └── settings/
        └── settings_page.dart       # شرط ظهور قسم "متابعة أولياء الأمور" يستخدم parentPortalActiveNow

# خارج هذا المستودع — على VPS منفصل (نفس أسلوب migration/website updates السابقة هذه الجلسة)
/var/www/active-class.online/track/index.html   # + فحص parentPortalExpiresAt المنشور، وشاشة "غير متاحة" بدلاً من الفورم لو انتهت
```

**Structure Decision**: تعديل على ملفات Flutter الموجودة بالفعل (لا ملفات/طبقات جديدة) + تعديل مباشر على ملف HTML واحد على السيرفر الخارجي عبر SSH (بنفس أسلوب migration files السابقة هذه الجلسة) — لا حاجة لمشروع/مستودع منفصل لصفحة الويب لأنها ملف ثابت واحد بالفعل.

## Complexity Tracking

*لا توجد مخالفات تستدعي تبرير — التغيير كله في حدود الأنماط المعمول بها بالفعل.*
