# Implementation Plan: تطوير واجهة الإعدادات + قناة المجتمع

**Branch**: `017-settings-ui-refresh` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/017-settings-ui-refresh/spec.md`

## Summary

إعادة ترتيب أقسام شاشة الإعدادات حسب الأهمية، مع تنسيق موحّد (الـhelper `_buildSection` موجود بالفعل بترويسة أيقونة-في-مربّع + كارت radius 22)، وفصل إعدادات الفوترة من داخل قسم "الواتساب" لقسم مستقل "الفوترة والتحصيل"، وتجميع بوابة الأهالي + اختصار الحجوزات في قسم "الإضافات المدفوعة"، وإضافة قسم جديد "المجتمع والدعم" فيه زر يفتح قناة واتساب (رابط ثابت، `launchUrl` بنفس نمط `_openSupportWhatsApp`).

**كل الشغل في ملف واحد**: `lib/views/settings/settings_page.dart`. **صفر تغيير** على `settings_controller`، قاعدة البيانات، أو أي منطق. إعادة ترتيب استدعاءات `_buildSection(...)` + نقل children بين قسمين + دالة `_openCommunityChannel` + قسم جديد.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX (`Get.find<SettingsController>`, `Obx`)، `url_launcher` (`launchUrl` + `LaunchMode.externalApplication` — مستخدم بالفعل في `_openSupportWhatsApp`/`_openPrivacyPolicy`)، `ToastHelper`.

**Storage**: لا شيء. رابط القناة نصّي ثابت في الكود.

**Testing**: يدوي عبر [quickstart.md](quickstart.md) + `flutter analyze` صفر تحذيرات (نهج specs 009–016).

**Target Platform**: Android (arm64 + v7a).

**Project Type**: تطبيق موبايل single-project.

**Performance Goals**: فتح الإعدادات فوري زي دلوقتي؛ لا استعلامات جديدة.

**Constraints**:
- صفر تراجع وظيفي — كل إعداد يفضل موجود وشغّال (SC-002/SC-006).
- بصري بحت + بند واحد جديد.
- دعم ليلي/فاتح كامل (الـ`_buildSection` بياخد `isDark` بالفعل).
- الـ`_buildSection` الحالي هو مصدر التنسيق الموحّد — نعيد استخدامه، مش نخترع نمط تاني.

**Scale/Scope**: ملف واحد (~2500 سطر) — إعادة ترتيب ~12 بلوك قسم + بلوك جديد + دالة helper واحدة.

## Constitution Check

`.specify/memory/constitution.md` = placeholders، مفيش مبادئ ملزمة. المشروع يتبع نمط specs 013/016: إعادة استخدام الـhelpers الموجودة، تحقّق يدوي، صفر تغيير سلوك للمخرجات القائمة.

**النتيجة**: PASS (قبل وبعد التصميم).

## Project Structure

### Documentation (this feature)

```text
specs/017-settings-ui-refresh/
├── plan.md · research.md · quickstart.md
├── contracts/settings-layout.md      # ترتيب الأقسام + عقد زر القناة
└── checklists/requirements.md
```

### Source Code (repository root)

```text
lib/views/settings/settings_page.dart
├── build() → ListView children             # إعادة ترتيب بلوكات _buildSection حسب FR-001
├── قسم "الواتساب" الحالي                   # نشيل منه: تحصيل مؤخّر، حساب نسبي، (يوم التحصيل لو موجود)
├── قسم جديد "الفوترة والتحصيل"             # ياخد إعدادات الفوترة المنقولة (نفس الـtiles بالظبط)
├── قسم جديد/موسّع "الإضافات المدفوعة"       # بوابة الأهالي (Obx الموجود) + nav tile "إعدادات الحجوزات"
│                                            #   (يظهر لو LicenseController.to ... canBooking) → BookingSettingsPage
├── قسم جديد "المجتمع والدعم"               # كارت + زر → _openCommunityChannel()
│   (فوق قسم "عن التطبيق" مباشرة)
└── _openCommunityChannel()                 # جديد — نسخة من _openSupportWhatsApp بلا رسالة،
                                             #   رابط ثابت kCommunityChannelUrl، ToastHelper.error عند الفشل
```

**Structure Decision**: single-file refactor. المخاطرة الرئيسية: نقل children إعدادات الفوترة بدون فقد أي `Obx`/شرط إظهار. المرجع: [contracts/settings-layout.md](contracts/settings-layout.md).

## Complexity Tracking

> لا انتهاكات — القسم فاضي.
