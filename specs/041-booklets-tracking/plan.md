# Implementation Plan: الملازم والكتب — إدارة التسعير والتسليم والتحصيل

**Branch**: `041-booklets-tracking` | **Date**: 2026-09-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/041-booklets-tracking/spec.md`

## Summary

أول ميزة "منتجات مادية" في المشروع. أربع جداول جديدة متزامنة في وضع الفريق: `booklets` (الاسم والسعر)، `booklet_groups` (ربط ملزمة بمجموعات — نفس نمط `exam_groups`)، `booklet_records` (حالة تسليم + استثناء لكل طالب × ملزمة، **صفوف كسولة** تُنشأ عند أول تفاعل فقط)، و`booklet_payments` (دفعات بمبلغ دقيق وتاريخ). قرار جوهري: دفعات الملازم **جدول مستقل** وليست صفوف `Payment` بملاحظة (عكس نهج spec 038)، فيتحقق FR-008/FR-009 (فصل تام عن مديونية الاشتراك وإجماليات المحصَّل) بدون أي تعديل على ملفات الحسابات القائمة. قائمة مؤهَّلي الملزمة = طلاب مجموعاتها (غير المؤرشفين) مطروحًا منهم المستثنون، محسوبة بدالة صرفة قابلة للاختبار؛ المدفوع/المتبقي/حالة الدفع مشتقة دائمًا من الدفعات مقابل السعر (لا تُخزَّن). واجهة: شاشة "الملازم" (قائمة + ملخص لكل ملزمة)، شاشة تفاصيل ملزمة (قائمة الطلاب بتسليم/دفع)، وقسم "الملازم" داخل تاب المدفوعات في تفاصيل الطالب. يتطلب DB v35 + migration على السيرفر.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX، sqflite، Supabase self-hosted (مزامنة وضع الفريق). لا تبعيات جديدة.

**Storage**: 4 جداول SQLite جديدة (DB v34→35) + 4 جداول Postgres مقابلة على Supabase (migration مُطبَّقة عبر SSH).

**Testing**: `flutter test` لدوال صرفة جديدة (حساب المدفوع/المتبقي/الحالة، تحديد المؤهَّلين) + تحقق يدوي على جهاز حقيقي (اتساقًا مع specs 038–040) + تحقق مزامنة على جهازين.

**Target Platform**: Android.

**Project Type**: mobile-app (مشروع Flutter واحد).

**Performance Goals**: ملزمة على 10–50 طالب تُحمَّل فورًا (استعلامات محلية بسيطة، حساب Dart في الذاكرة).

**Constraints**: صفر تأثير على `PricingHelper.accumulatedDebt` وإجماليات المحصَّل الحالية (SC-004)؛ ترتيب المزامنة يحترم الآباء (booklets قبل أبنائها، students قبل records/payments)؛ الجداول الجديدة على القناة الممتدة (`_extendedTables`) لتفادي حادثة CHANNEL_ERROR (spec 024).

**Scale/Scope**: ~4 جداول، controller واحد، 3 شاشات/أقسام واجهة، ~7 ملفات قائمة تتعدّل، migration واحدة.

## Constitution Check

لا دستور مُفعَّل — تُطبَّق ممارسات المشروع: نمط جدول متزامن جديد مطابق لـ spec 032 وspec 025 وexam_groups، دوال صرفة قابلة للاختبار (specs 038/040)، إعادة استخدام صلاحيات الفريق القائمة بدل صلاحيات جديدة. **لا مخالفات.**

## Project Structure

### Documentation (this feature)

```text
specs/041-booklets-tracking/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── booklet-controller.md
│   └── booklet-math.md
└── tasks.md            # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── config/
│   └── constants.dart                    # [MODIFY] DATABASE_VERSION 35، TABLE_/COL_ للجداول الأربعة، ROUTE_BOOKLETS/ROUTE_BOOKLET_DETAILS
├── models/
│   └── booklet_model.dart                # [NEW] Booklet, BookletRecord, BookletPayment
├── utils/
│   └── booklet_math.dart                 # [NEW] دوال صرفة: paid/remaining/status/eligible (راجع contracts/booklet-math.md)
├── services/
│   ├── database_service.dart             # [MODIFY] CREATE + _onUpgrade(<35) + CRUD + _queueSync/_queueDelete + تجميع ملزمة (deleteBooklet بنمط deleteExam) + cascade عند حذف طالب/مجموعة
│   └── sync_engine.dart                  # [MODIFY] _tables/_extendedTables/_pkCol + push/pull mapping + reload switch + reconcile duplicates
├── controllers/
│   └── booklet_controller.dart           # [NEW] GetX — راجع contracts/booklet-controller.md
├── views/
│   ├── booklets/
│   │   ├── booklets_page.dart            # [NEW] قائمة الملازم + ملخص لكل ملزمة (FR-010) + إضافة/تعديل/حذف
│   │   └── booklet_details_page.dart     # [NEW] قائمة المؤهَّلين: تسليم + دفع + فلترة (FR-005/006/011/013) + استثناء
│   ├── students/student_details_page.dart # [MODIFY] قسم "الملازم" في تاب المدفوعات + "متبقي ملازم" (FR-012)
│   └── home_page.dart                    # [MODIFY] نقطة دخول لشاشة الملازم (بنفس نمط مدخل بنك الأسئلة)
└── main.dart                             # [MODIFY] تسجيل GetPage للمسارين

supabase/
└── migration_booklets.sql                # [NEW] 4 جداول + RLS + triggers (نمط migration_session_overrides.sql)

test/
└── booklet_math_test.dart                # [NEW]
```

**Structure Decision**: مشروع Flutter واحد؛ مجلد `views/booklets/` جديد بنفس تنظيم `views/exams/`. لا تعديل على `pricing_helper.dart`/`payment_controller.dart`/تقارير المدفوعات إطلاقًا (ده اختبار قبول FR-008/009).

## Complexity Tracking

*لا مخالفات تستدعي تبرير.*
