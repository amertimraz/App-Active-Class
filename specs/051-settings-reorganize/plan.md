# Implementation Plan: إعادة تنظيم شاشة الإعدادات

**Branch**: `051-settings-reorganize` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/051-settings-reorganize/spec.md`

## Summary

نقل كل عناصر `settings_page.dart` (3482 سطر، 12 قسم) إلى **شاشة رئيسية بفئات (drill-down)** + **8 صفحات فئات**، بنقل الكود حرفيًا (بلا تغيير منطق أو مفاتيح تخزين). أي إعداد بيتنقل للفئة اللي يتوقعها المدرس، والإجراءات المدمّرة في "منطقة خطر" منفصلة. سجل بيانات صرف (`settings_registry.dart`) بيغذّي البحث ويحرس بالاختبار إن ولا إعداد ضاع. التنفيذ على مراحل آمنة: أولًا استخراج مشترَكات (ودجتس + أفعال + حوارات) والتطبيق لسه بيشتغل بالصفحة القديمة، وبعدين صفحات الفئات، وبعدين تبديل الشاشة الرئيسية، ثم البحث.

## Technical Context

**Language/Version**: Flutter 3.38 / Dart 3.5، GetX (لا تغيير في الإصدارات)

**Primary Dependencies**: لا إضافات جديدة (الودجتس الحالية + `get` للتنقّل)

**Storage**: لا تغيير — كل الإعدادات بتفضل في `SettingsController`/`_dbGet/_dbSet` بنفس المفاتيح والقيم الافتراضية. صفر DB/sync/migration.

**Testing**: `flutter test` — اختبارات وحدة لسجل الإعدادات والبحث (دوال صرفة) + جرد يحرس عدد/معرّفات العناصر؛ تحقق يدوي على الجهاز (quickstart).

**Target Platform**: Android (APK direct + AAB play)

**Project Type**: mobile-app (Flutter)

**Performance Goals**: فتح الإعدادات ≤ الحالي؛ كل صفحة فئة أخف من الصفحة الواحدة (عدد عناصر أقل لكل Obx).

**Constraints**: لا تغيير سلوكي أو بصري للعناصر نفسها؛ وضع المساعد/الفريق/الترخيص بنفس القواعد؛ RTL + وضع ليلي؛ `sendMonthlyReportsViaWhatsAppAuto` (بيتنادى من `main.dart:107` عند ضغط إشعار) لازم يفضل شغّال.

**Scale/Scope**: 20 سويتش + 13 قائمة اختيار/إدخال + 9 تنقّل = 42 عنصر، 8 فئات، ~10 ملفات جديدة، ملف واحد كبير يتحوّل لـ~150 سطر.

## Constitution Check

`.specify/memory/constitution.md` قالب غير مُعبَّأ → لا بوابات. ملتزم بأنماط المشروع: دوال صرفة + اختبارات، لا تغيير مخزّن، احترام الصلاحيات.

## Project Structure

### Documentation (this feature)

```text
specs/051-settings-reorganize/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── settings-registry.md      # الجرد الكامل: عنصر ← فئة ← قسم ← مفتاح ← شرط ظهور
├── checklists/requirements.md
└── tasks.md                      # /speckit-tasks
```

### Source Code (repository root)

```text
lib/views/settings/
├── settings_page.dart                    # (يتقلّص) الشاشة الرئيسية: كارت الترخيص + بحث + قائمة الفئات
├── settings_registry.dart                # (جديد، صرف) SettingsCategory/SettingsItem + البحث
├── widgets/
│   ├── settings_widgets.dart             # (جديد) SettingsSectionCard / SwitchTile / NavTile / DropdownTile / InfoTile / TextField / Divider (كانت private methods)
│   ├── settings_category_scaffold.dart   # (جديد) هيكل صفحة الفئة (AppBar + ListView + خلفية) + تمييز نتيجة البحث
│   └── settings_category_tile.dart       # (جديد) صف الفئة في الرئيسية
├── categories/
│   ├── account_team_category.dart        # بيانات المعلم + المساعدين والحسابات + متابعة أولياء الأمور
│   ├── attendance_category.dart          # ورقة الحضور + ماسح QR
│   ├── billing_category.dart             # العملة + الفوترة + تأخّر الدفع
│   ├── followup_category.dart            # طلاب محتاجين متابعة + مركز الإشعارات
│   ├── whatsapp_category.dart            # رمز الدولة + التقارير + زر المجموعات + بعد الحضور
│   ├── appearance_category.dart          # الوضع الليلي + نظام الساعة
│   ├── data_category.dart                # النسخ الاحتياطي + منطقة الخطر
│   └── about_category.dart               # الإصدار + التحديث + الدعم + الخصوصية + المجتمع
├── actions/
│   ├── backup_actions.dart               # (نقل حرفي) _handleEnhancedBackup/_handleRestoreBackup/_handleManageBackups/_handleCloudBackup/_handleDeleteAll/_reloadAllControllers
│   └── whatsapp_batch_send.dart          # (نقل حرفي) _startWhatsappBatchSend + sendMonthlyReportsViaWhatsAppAuto + _waitUntilResumed
└── dialogs/
    ├── backup_dialogs.dart               # _BackupListDialog / _ManageBackupsDialog / _DataSummaryList / _ChoiceButton / _InfoRow
    └── parent_portal_tile.dart           # _ParentPortalTile (+ _IconBtn/_GenderChip حسب الاستخدام)
lib/main.dart                             # import لـsendMonthlyReportsViaWhatsAppAuto من مكانه الجديد
test/settings_registry_test.dart          # (جديد)
```

**Structure Decision**: مشروع Flutter موجود؛ الإضافات تحت `lib/views/settings/` بتقسيم فرعي (widgets/categories/actions/dialogs). الصفحة الرئيسية بتحتفظ باسم `SettingsPage` والـroute `ROUTE_SETTINGS` فمفيش مستدعي بيتأثر. صفحات الفئات تُفتح بـ`Get.to`.

## Design notes

- **نقل حرفي أولًا**: الودجتس بتتحوّل من instance methods (`_buildSwitchTile` …) لـtop-level widgets بنفس الـparameters والشكل (بلا تغيير بصري)، والأفعال (النسخ/الحذف/الإرسال الجماعي) بتتنقل كما هي لدوال top-level تاخد `BuildContext` + `SettingsController`.
- **السجل الصرف**: `kSettingsCategories` (id، اسم، وصف، أيقونة، لون، ترتيب) و`kSettingsItems` (id، العنوان، كلمات بحث، فئة، قسم، شرط ظهور رمزي: `always | hiddenForAssistant | ownerOnly | portalAddonOnly`). الشاشة الرئيسية والبحث بيستهلكوه؛ الصفحات الفعلية بتبنى ودجتس حقيقية (السجل لا يبني UI).
- **البحث**: `searchSettings(query, {isAssistant, portalEnabled})` → قائمة نتايج مرتّبة، يطابق العنوان والكلمات المفتاحية بعد تطبيع عربي (حذف التشكيل/توحيد ألف/ياء/تاء مربوطة). الضغط على نتيجة = فتح الفئة مع `highlightId` يعمل scroll + تمييز لثانيتين.
- **"تأخّر الدفع"**: سويتشه ينتقل لفئة الفلوس (بقرار الـspec) ويفضل بيكتب في `setAtRiskPaymentEnabled` زي ما هو؛ وفي فئة المتابعة سطر تنقّل "تأخّر الدفع بيتظبط من الفلوس والتحصيل" عشان الإعدادات المتّصلة (مدة التهدئة) مايتقطّعوش. نص "بنفس مهلة السماح في قسم الفوترة فوق" يتغيّر لـ"بنفس مهلة السماح فوق" داخل نفس الفئة.
- **قواعد المساعد**: كل شرط ظهور/قفل (`isAssistant`، `requireTeamOwnerIfTeamMode`، `parentPortalEnabled`، تعطيل يوم النزول في وضع الفريق) بيتنقل مع عنصره كما هو؛ البحث بيطبّق نفس الشروط عشان ما يكشفش مخفي.
- **الأمان**: كل مرحلة ترجّع التطبيق لحالة شغّالة (analyze نضيف + الشاشة القديمة لسه شغّالة لحد مرحلة التبديل)، فمفيش مرحلة وسط بتكسر.
