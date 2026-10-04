# Implementation Plan: المساعد ينشئ ويدير الامتحانات الإلكترونية

**Branch**: `044-assistant-online-exams` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

## Summary

تفويض إدارة الامتحانات الإلكترونية للمساعد بثلاث طبقات: (1) **صلاحية جديدة** `can_manage_online_exams` لكل مساعد (Supabase `team_members`، افتراضي false) بواجهة تفعيل في شاشة إدارة الأعضاء؛ (2) **مرآة حالة البوابة** على صف الفريق (`teams.portal_slug/portal_enabled/portal_expires_at`) يدفعها جهاز المدرس ويقرأها المساعد، فتتحكم توافر الميزة للفريق كله بدل ترخيص جهاز المساعد؛ (3) **تفويض Firestore**: المدرس يكتب قائمة `coOwnerUids` على مستند `online_exams/{slug}` من هويات Firebase المجهولة للمساعدين المسموح لهم، وقواعد الأمان تعتبرهم "مالك" للكتابة تحت `exams/**` فقط (لا على المستند الجذر). النشر من المساعد يطلع على slug المدرس نفسه.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1
**Primary Dependencies**: GetX، `supabase_flutter` (فريق)، `cloud_firestore` + `firebase_auth` (نشر الامتحانات)، `TeamModeService`، `SyncEngine`، `OnlineExamService`
**Storage**: Supabase (أعمدة جديدة على `team_members`/`teams` + RPCs) + Firestore rules (تعديل `_oeOwner`) + SQLite محلي: **لا تغيير** (الحالة في الذاكرة + `app_settings` لاستعادة أوفلاين)
**Testing**: `flutter test` لمنطق صرف (قرار التوافر/الصلاحية) + تحقق يدوي بجهازين (مدرس + مساعد) + اختبار قواعد Firestore يدويًا
**Target Platform**: Android
**Constraints**: لا كشف جديد لكود الترخيص؛ المدرس المرجع الوحيد للتفويض؛ لا تغيير في سلوك المدرس/المستخدم العادي (خارج الفريق) إطلاقًا؛ نشر الامتحان محتاج إنترنت أصلاً
**Scale/Scope**: فريق = مدرس + مساعد (حد افتراضي 1، قابل للزيادة)؛ عدد قليل من القيم المتزامنة

## Constitution Check

لا مبادئ مُفعَّلة (`.specify/memory/constitution.md` قالب). ملتزم بأعراف المشروع: migration Supabase idempotent عبر SSH، صلاحيات الواجهة بنمط `canXxxNow` في `TeamModeService`، دوال صرفة + اختبار وحدة، تغيير قواعد Firestore موثّق ومنفّذ بموافقة صريحة (إنتاج).

## Project Structure

### Documentation
```text
specs/044-assistant-online-exams/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/team-portal-contract.md
└── checklists/requirements.md
```

### Source Code
```text
supabase/migration_assistant_online_exams.sql   # أعمدة + RPCs
firestore.rules                                  # _oeOwner يقبل coOwnerUids
lib/utils/online_exam_access.dart                # منطق صرف: قرار التوافر/الصلاحية/وضع القراءة
lib/services/team_mode_service.dart              # canManageOnlineExams + حالة بوابة الفريق + مزامنة (مالك/مساعد)
lib/services/online_exam_service.dart            # _slug فريق، publish للمساعد بلا كتابة جذر، setCoOwners
lib/controllers/exam_controller.dart             # publishOnlineExam + uploadQuestionImage يستخدمان الحارس الجديد
lib/views/exams/exams_page.dart                  # زر الإنشاء حسب الحارس الجديد
lib/views/exams/online_exams_tab.dart            # قفل/قراءة فقط حسب الحارس + الأزرار
lib/views/exams/online_exam_results_page.dart    # وضع القراءة فقط (يخفي الاعتماد/الإبطال)
lib/views/team/manage_members_screen.dart        # مفتاح "إدارة الامتحانات الإلكترونية"
test/online_exam_access_test.dart
```

**Structure Decision**: منطق القرار كله (هل الميزة متاحة؟ هل يقدر يكتب؟ هل قراءة فقط؟) دالة صرفة واحدة تستهلكها كل الشاشات والخدمات، فمفيش شروط متفرقة. الحالة المعروضة للمساعد تتحمّل من Supabase كل 30 ثانية (نفس إيقاع الفحص الحالي) وتتخزن محليًا للأوفلاين.
