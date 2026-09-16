# Implementation Plan: نسخ احتياطي سحابي (Google Drive شخصي لكل مدرّس)

**Branch**: `037-cloud-backup` | **Date**: 2026-09-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/037-cloud-backup/spec.md`

## Summary

رفع نفس ملف النسخة الاحتياطية (.zip) الموجود بالفعل (spec محلي: db + shared_prefs + صورة المعلم) لحساب **Google Drive الشخصي للمدرّس نفسه** — تلقائيًا بعد كل نسخة محلية دورية (لأي مستخدم ربط حسابه، بغض النظر عن وضع الفريق)، مع رفع/استرجاع/حذف يدوي وحد أقصى 5 نسخ. الوصول لدرايف المدرّس عبر `google_sign_in` (OAuth قياسي) بنطاق صلاحية محصور على ملفات التطبيق نفسها بس (`drive.file`)، والرفع/التحميل/الحذف عبر استدعاءات REST مباشرة لـ Google Drive API v3 (بلا مكتبة `googleapis` الثقيلة) باستخدام `dio` الموجود بالفعل كتبعية.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1 — بلا تغيير.

**Primary Dependencies**:
- **[جديد]** `google_sign_in` (مكتبة Google الرسمية لـFlutter) — تسجيل دخول/اختيار حساب Google + الحصول على access token بنطاق `drive.file`.
- **بلا مكتبة جديدة للـHTTP** — استدعاءات Google Drive API v3 (`files.create` multipart للرفع، `files.list`/`files.get` للقائمة والتحميل، `files.delete` للحذف) عبر `dio` الموجود بالفعل في المشروع، بدل إضافة `googleapis`/`googleapis_auth` (تبعية تقيلة لعملية بسيطة نسبيًا: رفع/قائمة/تحميل/حذف ملفات في مجلد واحد).
- بلا تغيير في `supabase_flutter` أو أي تبعية سيرفر موجودة — الميزة مستقلة تمامًا عن Supabase.

**Storage**: **مفيش تخزين سيرفر خاص بالمشروع** — البيانات بتتخزن في Google Drive الشخصي للمدرّس نفسه (خارج بنية Supabase/VPS الحالية بالكامل). المعلومات المحلية المطلوبة (حالة الربط، إيميل الحساب المربوط) بتتخزن كإعداد عادي في `DatabaseService.setSetting` (نفس نمط أي إعداد تاني في التطبيق).

**Testing**: `flutter test` لمنطق قرار إعادة المحاولة الصرف (بلا شبكة فعلية) — بنفس نمط `sync_retry_policy_test.dart` الموجود. اختبار تكامل حقيقي مع Google Drive API خارج نطاق `flutter test` الآلي (يحتاج حساب Google حقيقي — تحقّق يدوي عبر quickstart.md).

**Target Platform**: Android (تطبيق) — Google Drive API خدمة سحابية عامة، بلا أي تغيير على أي سيرفر يملكه المشروع.

**Project Type**: تطبيق موبايل واحد — خدمة/كونترولر جديدان داخل نفس البنية، بلا مشروع/سيرفر جديد.

**Performance Goals**: رفع نسخة احتياطية واحدة (متوقَّع بضع ميجابايت لمدرسة متوسطة) في الخلفية بلا تجميد الواجهة؛ لا حاجة لأداء لحظي (العملية دورية/يدوية).

**Constraints**:
- **إعداد Google Cloud Console مطلوب قبل أي كود** (OAuth consent screen + Android OAuth client ID مربوط بتوقيع التطبيق `5f74fe10af2da396cbf0a98895af02bb5ffbdc01cdf68a55bea25a841f02ec7b` + SHA-1 المقابل) — خطوة تشغيلية خارج الكود، لازم تتعمل الأول (راجع research.md #3). بلا الإعداد ده، `google_sign_in` هيفشل بالكامل.
- نطاق `drive.file` **غير حسّاس** (non-sensitive) حسب تصنيف Google الحالي — مايحتاجش مراجعة أمان (security assessment) طويلة من Google، بعكس نطاق `drive` الكامل أو `drive.appdata` (يحتاجوا تحقّق إضافي في بعض الحالات) — قرار مباشر لتفادي عملية اعتماد Google الطويلة (راجع research.md #1).
- إعادة المحاولة عند فشل الرفع لازم تكون محدودة (مش لا نهائية) — نفس مبدأ `sync_retry_policy.dart` الموجود (spec 030)، لكن بمنطق مستقل (الميزة دي بلا علاقة بـ`sync_engine.dart`).
- access token من Google بينتهي بعد فترة قصيرة (ساعة عادة) — لازم `google_sign_in` يجدّده تلقائيًا (`silentSignIn`) قبل كل عملية، وليس الاعتماد على توكن مخزَّن قديم.

**Scale/Scope**: خدمة وكونترولر جديدان + تعديل شاشة إعدادات موجودة + تعديل بسيط في `auto_backup_service.dart` — بلا أي تغيير في `sync_engine.dart` أو بنية Supabase.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد `constitution.md` مُفعّل في المشروع (لسه على شكل القالب الافتراضي). الاعتبارات العملية المكافئة (من نمط المشروع الفعلي):
- ✅ إعادة استخدام نفس ملف النسخة الاحتياطية (.zip) وآليته الحالية بالكامل — الميزة دي "وجهة رفع/استرجاع" إضافية، مش نظام نسخ احتياطي موازٍ.
- ✅ صفر تأثير على مستخدم ماربطش حساب Google (FR-005) — التوسعة اختيارية بالكامل.
- ✅ صفر تغيير في بنية Supabase/وضع الفريق الحالية — الميزة مستقلة بالكامل (استثناء ملحوظ عن نمط كل الـspecs السابقة اللي كانت كلها migration.sql على نفس الـVPS؛ هنا الوجهة برّه المشروع تمامًا، والمبرر موثّق في research.md #1).
- ⚠️ **تبعية جديدة على خدمة خارجية (Google)** لأول مرة في المشروع — مقبولة لأن المستخدم صراحة طلب "درايف خاص بكل مدرّس"، وهي بديل واعي عن الوجهة الأصلية المقترَحة (Supabase VPS المشترك) اللي كانت هتحتاج نشر خدمة Storage جديدة على السيرفر.

## Project Structure

### Documentation (this feature)

```text
specs/037-cloud-backup/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — قرارات النطاق (scope)، إعداد Google Cloud، استراتيجية الرفع
├── data-model.md        # Phase 1 — بيانات الربط المحلية + بنية ملف النسخة على Drive
├── contracts/            # Phase 1 — عقود عمليات الربط/الرفع/القائمة/الاستعادة/الحذف
│   └── cloud-backup-operations.md
├── quickstart.md         # Phase 1 — سيناريوهات تحقق (تحتاج حساب Google حقيقي)
└── tasks.md              # Phase 2 (/speckit-tasks — لسه مش منشأ)
```

### Source Code (repository root)

```text
active_class/
├── android/app/
│   └── build.gradle(.kts)                  # بلا تغيير كود — لازم فقط التأكد إن SHA-1 توقيع
│                                             #   الـrelease مسجّل في Google Cloud Console
│                                             #   (خطوة تشغيلية، راجع research.md #3)
├── lib/
│   ├── services/
│   │   ├── google_drive_backup_service.dart # [جديد] signIn/signOut/isLinked/uploadBackup/
│   │   │                                     #   listCloudBackups/downloadBackup/
│   │   │                                     #   deleteCloudBackup — يغلّف google_sign_in +
│   │   │                                     #   استدعاءات Drive API v3 عبر dio
│   │   ├── auto_backup_service.dart         # تعديل: بعد نجاح createBackup() محلي، لو
│   │   │                                     #   الحساب مربوط → رفع سحابي (fire-and-forget +
│   │   │                                     #   طابور إعادة محاولة بسيط، منفصل عن SyncEngine)
│   │   └── backup_service.dart              # بلا تغيير — يفضل هو مصدر بناء ملف .zip الوحيد
│   ├── controllers/
│   │   └── google_drive_backup_controller.dart # [جديد] GetX — حالة الربط (مربوط/لأ + إيميل
│   │                                             #   الحساب) + قائمة النسخ + حالة الرفع/الاستعادة
│   └── views/settings/settings_page.dart    # تعديل: قسم "النسخ السحابية (Google Drive)" في
│                                             #   شاشة إدارة النسخ الاحتياطي الموجودة (ربط/
│                                             #   إلغاء ربط + قائمة + رفع الآن + استعادة + حذف)
└── test/
    └── cloud_backup_retry_policy_test.dart  # [جديد] منطق قرار إعادة المحاولة الصرف
```

**Structure Decision**: تعديل داخل نفس بنية التطبيق الحالية — خدمة وكونترولر جديدان يتبعان نفس نمط `BackupService`/`AuthService` الموجودين. **الاختلاف الجوهري عن كل الـspecs السابقة**: مفيش migration.sql ولا تغيير على VPS المدرّس — الوجهة كاملة برّه بنية Supabase (حساب Google شخصي لكل مستخدم تطبيق على حدة).

## Complexity Tracking

> **انتهاك واحد يستاهل تبرير صريح** (الجدول تحت) — كل حاجة تانية مطابقة لنمط المشروع الحالي.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| تبعية جديدة على خدمة خارجية (Google Drive API) لأول مرة في المشروع | المستخدم طلب صراحة "درايف خاص بكل مدرّس" — حماية لا تعتمد على سيرفر المدرسة نفسه (فايدة إضافية: مفيدة حتى لمدرّس بلا وضع فريق) | البديل الأصلي (تخزين على VPS Supabase المشترك) كان بيحتاج نشر خدمة Storage جديدة على السيرفر (بند مرفوض هو نفسه في مسودة سابقة من الخطة)، وبرضو كان بيربط الحماية بوضع الفريق فقط — يفوّت أكبر شريحة مستفيدة (المدرّسين الأفراد) |
