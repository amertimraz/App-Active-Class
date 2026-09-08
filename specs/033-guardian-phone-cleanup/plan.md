# Implementation Plan: تنظيف وتوحيد رقم هاتف ولي الأمر + دعم اسم مستخدم/رابط واتساب

**Branch**: `033-guardian-phone-cleanup` | **Date**: 2026-09-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/033-guardian-phone-cleanup/spec.md`

## Summary

`lib/utils/phone_helper.dart` جديد = **نقطة تطبيع واحدة**: تحويل الأرقام العربية/الفارسية → لاتيني،
إزالة علامات الاتجاه والمسافات والأقواس والحروف، توحيد `+`/`00`/صفر البادئة، وإخراج (أ) صيغة تخزين
«بشرية نظيفة» (`01001234567` أو `+201001234567` لو دولي صريح) و(ب) صيغة `wa.me` (`201001234567`
بلا `+` ولا صفر). كل الملفات الـ6 اللي فيها نسخة مكرّرة معطوبة تستدعي `PhoneHelper` بدلها.

حقل رقم ولي الأمر (في `add_student_sheet` + `edit_student_sheet`) يبقى LTR + محاذاة يسار +
`inputFormatter` ينظّف وقت الكتابة + سطر معاينة تحت الحقل «هيتبعت على: ‎+20 …» + تحذير غير معطِّل.

US3 (P2): عمود جديد `guardian_whatsapp` على `students` (DB v29 → **v30**، مُزامَن زي `guardian_phone`،
`alter table students add column` على Supabase). عند الإرسال: رابط `wa.me` صالح في الحقل → يُفتح
مباشرة؛ رقم → السلوك القديم عبر `PhoneHelper`؛ username → فتح واتساب + نسخ الرسالة + تنبيه.

**التطبيع للأرقام القديمة = لحظة الإرسال فقط** — صفر ترحيل مجمّع، صفر موجة مزامنة.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1؛ SQL بسيط للـmigration (US3 فقط).

**Primary Dependencies**: GetX، sqflite، `url_launcher` (قائم)، `flutter/services` (`Clipboard`,
`FilteringTextInputFormatter`/`TextInputFormatter`). لا مكتبات جديدة. **لا** مكتبة تنسيق أرقام دولية
(`libphonenumber` وغيرها) — تطبيع يدوي خفيف كافٍ للنطاق.

**Storage**: بدون تغيير لـ`guardian_phone` (نصّه يُنظَّف عند الإدخال، ويُطبَّع للـwa.me لحظة الإرسال).
US3: عمود `guardian_whatsapp TEXT` جديد على `students` — SQLite **v29 → v30** (`ALTER TABLE ADD
COLUMN`) + Supabase `alter table public.students add column if not exists guardian_whatsapp text`
(نمط `migration_student_archiving.sql`). مُزامَن عبر الفريق زي `guardian_phone`.

**Testing**: `flutter test` — وحدة لـ`PhoneHelper` (كل صيغ المدخلات الملوّثة → مخرج ثابت،
`waMe`/`display`/`isLikelyValid`، تحليل رابط/username لـUS3). ملف اختبار واحد.

**Target Platform**: Android (+ بوابة الأهل على السحابة تقرأ الرقم).

**Project Type**: تطبيق موبايل Flutter + خادم.

**Performance Goals**: `PhoneHelper` نقي متزامن O(طول الرقم). `inputFormatter` على كل ضغطة —
تكلفة تافهة. صفر أثر على المسار الساخن.

**Constraints**: صفر انحدار لأي طالب له رقم صالح اليوم. صفر تعديل مجمّع للبيانات المخزّنة. صفر
تغيير في `PricingHelper`. حقل الواتساب اختياري بالكامل — غيابه = السلوك القديم بالحرف.

**Scale/Scope**: 1 ملف util جديد + 1 ملف اختبار + تعديل `CustomTextField` (بارامترات اختيارية:
`textDirection`/`textAlign`/`inputFormatters`) + widget معاينة صغير + تعديل حقلَي الرقم في
`add_student_sheet`/`edit_student_sheet` + استبدال ~6 نسخ normalizer باستدعاء `PhoneHelper` + US3:
عمود + model field + 2 نقطة في `sync_engine` + migration محلي + migration Supabase + منطق أولوية
الإرسال في نقطة مساعدة واحدة تستدعيها كل أزرار الواتساب.

## Constitution Check

الدستور قالب فارغ. أعراف المشروع:

| عرف | الحالة |
|---|---|
| توحيد المنطق المكرّر في نقطة واحدة | ✅ الهدف الأساسي — `PhoneHelper` |
| ترقية DB بنسخة صريحة + migration (US3 فقط) | ✅ v29→v30، عمود جديد فقط |
| migration Supabase عبر SSH (نمط 021/024/025/032) | ✅ نفس النمط، `alter table ... add column if not exists` |
| مزامنة العمود الجديد زي أعمدة الطالب الأخرى | ✅ `guardian_phone` هو النموذج بالضبط |
| لا تغيير تسعير | ✅ |
| إعادة استخدام: `SettingsController.countryDial`، `ContactPickerService`، `url_launcher` | ✅ |
| اختبارات + `analyze` نظيف | ✅ مخطّط |
| git push بإذن؛ commit على `main` | ✅ ملحوظ |

**النتيجة: PASS** — لا انتهاكات.

## Project Structure

### Documentation (this feature)

```text
specs/033-guardian-phone-cleanup/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — 6 قرارات
├── data-model.md        # Phase 1 — PhoneHelper API + عمود guardian_whatsapp
├── quickstart.md        # Phase 1 — سيناريوهات لصق/إرسال
├── contracts/
│   ├── phone-helper.md          # عقد PhoneHelper (النقي)
│   ├── phone-input-ui.md        # عقد حقل الرقم + المعاينة + CustomTextField
│   └── whatsapp-send.md         # عقد أولوية الإرسال (رابط/رقم/username) + عمود US3
└── tasks.md             # Phase 2 — /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── utils/
│   ├── phone_helper.dart            # جديد — نقطة التطبيع الوحيدة
│   └── phone_format.dart            # يصير re-export/wrapper رفيع فوق PhoneHelper (توافق)
├── widgets/
│   ├── custom_widgets.dart          # CustomTextField: + textDirection/textAlign/inputFormatters اختيارية
│   ├── phone_field.dart             # جديد — حقل الرقم + معاينة «هيتبعت على..» + تحذير
│   ├── add_student_sheet.dart       # يستخدم PhoneField
│   └── edit_student_sheet.dart      # يستخدم PhoneField
├── models/student_model.dart        # + guardianWhatsapp (US3)
├── config/constants.dart            # + COL_STUDENT_GUARDIAN_WHATSAPP + DATABASE_VERSION=30 (US3)
├── services/
│   ├── database_service.dart        # migration v30 + عمود في _createTables (US3)
│   ├── sync_engine.dart             # guardian_whatsapp في _buildRemoteRow + _toLocalMap (US3)
│   ├── contact_picker_service.dart  # _normalize → PhoneHelper.cleanForStorage
│   └── parent_portal_service.dart   # الرقم المرفوع عبر PhoneHelper
├── utils/whatsapp_launcher.dart     # جديد — دالة launchGuardianWhatsapp(student, message) بأولوية رابط/رقم/username
└── views/…                          # كل نقاط wa.me تستدعي whatsapp_launcher / PhoneHelper بدل النسخ المحلية:
    ├── attendance/attendance_page.dart (×2)
    ├── exams/exam_grades_page.dart
    ├── exams/online_exam_results_page.dart
    ├── exams/student_exam_history_page.dart
    ├── reports/reports_page.dart
    ├── reports/payments_report_page.dart
    ├── groups/group_details_page.dart (×2)
    ├── students/student_details_page.dart
    └── students/at_risk_students_page.dart

test/
└── phone_helper_test.dart           # جديد
```

**Structure Decision**: `PhoneHelper` نقي في `utils/` (قابل للاختبار المباشر). `phone_format.dart`
القائم يتحوّل لغلاف رفيع يستدعي `PhoneHelper` حتى ما نكسرش المستدعين فورًا، ثم تُهاجَر النداءات.
`PhoneField` widget يجمع الحقل + المعاينة + التحذير في مكان واحد يُعاد استخدامه في شيتَي الطالب.
`whatsapp_launcher.dart` يجمع منطق أولوية الإرسال (رابط `wa.me` → رقم → username) في دالة واحدة
تستبدل كل بلوكات `Uri.parse('https://wa.me/...')` المكرّرة.

## Complexity Tracking

> لا انتهاكات — لا شيء يُبرَّر.

US3 (عمود + migration + مزامنة) قابل للفصل تمامًا: لو اتأجّل، US1/US2/US4 يشحنوا لوحدهم بصفر
تغيير schema.
