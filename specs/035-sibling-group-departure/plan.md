# Implementation Plan: تعديل مجموعة الإخوة عند خروج عضو

**Branch**: `035-sibling-group-departure` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/035-sibling-group-departure/spec.md`

## Summary

المشكلة: `siblingsTotal` (المبلغ المشترك) ثابت، لكن القاسم (`siblingGroupSize`) بيتغيّر تلقائي مع أي أرشفة/حذف — فلما عضو يخرج من مجموعة ٣، الباقيين يتفاجؤوا بمديونية أعلى بلا قرار. الحل: تخزين "العدد اللي المبلغ المشترك اتحسب عليه وقت آخر قرار واعي" كحقل جديد على الطالب، ومقارنته بالعدد الفعلي الحالي وقت العرض — أي فرق (نقص) يعرض تنبيه قرار (تأكيد/تعديل) بدل ما يتفعّل الحساب الجديد صامتًا. الحقل بيتزامن زي أي حقل عادي (بلا أي تعقيد إضافي في طبقة المزامنة).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1 — بلا تغيير.

**Primary Dependencies**: بلا تبعيات جديدة — تعديل داخل `database_service.dart`/`pricing_helper.dart`/`student_model.dart` الحاليين + widget حوار جديد.

**Storage**: عمود محلي جديد على `students` (`sibling_group_committed_count INTEGER`) — DB v32→v33. يتزامن كحقل عادي (بلا ترجمة remote_id، زي `siblings_total`).

**Testing**: `flutter test` لمنطق `pricing_helper.dart` الصرف (الدالة الجديدة لاكتشاف "قرار معلّق") — يُفضَّل بس مش إلزامي حسب توجيه المشروع الحالي (specs السابقة معظمها بلا اختبارات آلية للواجهة).

**Target Platform**: Android (بلا تغيير).

**Project Type**: تطبيق موبايل واحد — بلا تغيير في البنية.

**Performance Goals**: التحقق من "قرار معلّق" بيحصل بمقارنة رقمين محليين (بلا استعلام شبكة) — تكلفة صفر تقريبًا.

**Constraints**: يجب عدم كسر السلوك الحالي لحالة "عضوين وواحد يخرج" (خارج النطاق — FR-009). يجب عدم إعادة حساب أي مديونية/مدفوعة تاريخية بأثر رجعي (FR-005/FR-006).

**Scale/Scope**: تعديل محدود في 3-4 ملفات + widget حوار واحد جديد — لا تغيير في بنية المزامنة أو الجداول الأخرى.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا يوجد `constitution.md` مُفعّل في المشروع (لسه على شكل القالب الافتراضي). الاعتبارات العملية المكافئة (من نمط المشروع الفعلي):
- ✅ لا تغيير في نظام المزامنة نفسه (الحقل الجديد يتزامن بنفس آلية `siblings_total` الموجودة أصلاً — بلا كود مزامنة إضافي).
- ✅ لا حذف/إعادة حساب بيانات تاريخية — الميزة كلها منطق عرض/تنبيه وقت القراءة، مش تعديل بأثر رجعي.
- ✅ لا تغيير في حد الأعضاء الأقصى (٣) ولا في حالة "عضوين وواحد يخرج" الحالية.

## Project Structure

### Documentation (this feature)

```text
specs/035-sibling-group-departure/
├── plan.md              # هذا الملف
├── research.md          # Phase 0 — قرارات تقنية
├── data-model.md         # Phase 1 — الحقل الجديد + الحالات
├── contracts/            # Phase 1 — عقد حوار القرار
│   └── departure-decision-dialog.md
├── quickstart.md         # Phase 1 — سيناريوهات تحقق
└── tasks.md              # Phase 2 (/speckit-tasks — لسه مش منشأ)
```

### Source Code (repository root)

```text
active_class/
├── lib/
│   ├── config/constants.dart              # عمود جديد: COL_STUDENT_SIBLING_GROUP_COMMITTED_COUNT
│   ├── models/student_model.dart          # حقل جديد + toMap/fromMap/copyWith
│   ├── services/database_service.dart     # schema + migration (v32→v33)
│   │                                       # linkSiblingGroup: يحفظ committed_count = العدد الحالي
│   │                                       # archiveStudent/deleteStudent: بلا تغيير في المنطق
│   │                                       # (التنبيه بيتحسب وقت القراءة، مش وقت الحذف)
│   ├── utils/pricing_helper.dart          # دالة جديدة: siblingGroupDepartureAlert(student, allStudents)
│   │                                       # → معلومات التنبيه (مين خرج، العدد القديم/الجديد) أو null
│   ├── widgets/
│   │   └── sibling_departure_dialog.dart  # [جديد] حوار التأكيد/التعديل
│   └── views/
│       ├── groups/group_details_page.dart # يستدعي التنبيه عند فتح المجموعة
│       └── students/student_details_page.dart # يستدعي التنبيه عند فتح طالب متأثر
└── supabase/
    └── migration_sibling_group_committed_count.sql
```

**Structure Decision**: تعديل داخل نفس بنية التطبيق الحالية — بلا مشروع/طبقة جديدة. الحقل الجديد يتبع نفس نمط `siblings_total` بالضبط (عمود عادي على `students`، يتزامن بلا أي منطق خاص في `sync_engine.dart`).

## Complexity Tracking

> لا توجد انتهاكات دستورية تحتاج تبرير.
