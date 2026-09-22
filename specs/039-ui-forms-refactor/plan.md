# Implementation Plan: تقسيم شاشات إضافة/تعديل الطالب والمجموعة الضخمة

**Branch**: `039-ui-forms-refactor` | **Date**: 2026-09-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/039-ui-forms-refactor/spec.md`

## Summary

تقسيم أربع ملفات Flutter ضخمة (add_student_sheet.dart، edit_student_sheet.dart، groups_page.dart، group_details_page.dart) لوحدات أصغر منظّمة حسب القسم الوظيفي، مع توحيد أربع ازدواجيات حقيقية مكتشَفة أثناء المراجعة: (1) شيت تعديل المجموعة (`_GroupFormSheet` مقابل `_GroupEditSheet`)، (2) محرر المواعيد الأسبوعية (`_ScheduleEditor` مقابل `_GDScheduleEditor`)، (3) منتقي الإخوة (`_pickSibling`/`_addSiblingCandidate` مكرَّرين بين add/edit الطالب)، (4) زر اختيار التاريخ (`_DatePickerBtn` مقابل `_DateBtn`، نفس الويدجت بالحرف تقريبًا). التوحيد يتم دائمًا نحو النسخة الأكمل فعليًا (مش الأحدث زمنيًا) — قرار محسوم مع المستخدم لكل حالة ازدواجية بمراجعة الكود الفعلي، موثَّق في research.md. الاستثناء الوحيد المقصود من "صفر تغيير سلوك": شاشة "تفاصيل المجموعة" ستكتسب تعديل أيقونة/لون/نوع تسعير (موافقة صريحة من المستخدم، راجع Assumptions في spec.md).

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX (لـcontrollers خارج نطاق الملفات الأربعة — الشاشات نفسها StatefulWidget عادي)، لا تبعيات جديدة

**Storage**: N/A — لا تغيير في قاعدة البيانات أو نموذج البيانات إطلاقًا (FR-009)

**Testing**: `flutter analyze` + `flutter test` (الأساس المرجعي الحالي، بدون كسر أي اختبار موجود) + اختبار يدوي شامل على جهاز حقيقي بعد كل خطوة تقسيم (لا widget tests آلية لهذه الشاشات — FR-008)

**Target Platform**: Android (تطبيق موبايل للمدرّسين)

**Project Type**: mobile-app (Flutter، مشروع واحد `lib/`)

**Performance Goals**: لا هدف أداء جديد — الهدف قابلية الصيانة فقط. يجب عدم إدخال أي rebuild إضافي ملحوظ (مثلاً بتفكيك widget لقطعة بحالة داخلية منفصلة بلا داعٍ يزيد عدد `setState` calls).

**Constraints**: عدم تغيير أي سلوك ظاهر (FR-001)؛ احترام نمط StatefulWidget + GetX الحالي بدل فرض معمارية جديدة (FR-007)؛ لا نقل ملفات بين مجلدات تكسر استيرادات أخرى بدون تحديثها بالكامل.

**Scale/Scope**: 4 ملفات مصدر (1076 + 848 + 1467 + 2704 = 6095 سطر إجمالي) تتحول لنحو 15-20 ملف/كلاس أصغر منظَّم، بدون أي تغيير في عدد الشاشات أو نقاط الدخول (`showAddStudentSheet`, `showEditStudentSheet`, `GroupsPage`, `GroupDetailsPage` تفضل بنفس التوقيع العام).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

لا دستور مُفعَّل (`.specify/memory/constitution.md` placeholder). تُطبَّق ممارسات المشروع القائمة بدلًا منه: صفر تغيير في مخطط قاعدة البيانات، إعادة استخدام الكود الموجود بدل تكراره (نفس روح specs 030/031)، والتحقق اليدوي على جهاز حقيقي حيث لا توجد اختبارات آلية. **لا مخالفات.**

الخطر الوحيد المميَّز: هذا refactor "أعمى" جزئيًا من ناحية التحقق الآلي (بدون widget tests) — يُخفَّف بتنفيذه على خطوات صغيرة متتالية (ملف واحد أو ازدواجية واحدة في كل مرة)، مع `flutter analyze`/`flutter test` بعد كل خطوة، واختبار يدوي شامل على جهاز حقيقي قبل الانتقال للخطوة التالية — بدل تقسيم الأربع ملفات دفعة واحدة ثم اكتشاف كسر بعد فوات الأوان.

## Project Structure

### Documentation (this feature)

```text
specs/039-ui-forms-refactor/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command) — لا تغيير فعلي، توثيقي فقط
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── widgets/
│   ├── add_student_sheet.dart              # [MODIFY] يفضل نقطة الدخول (showAddStudentSheet) + تجميع الأقسام
│   ├── edit_student_sheet.dart             # [MODIFY] يفضل نقطة الدخول (showEditStudentSheet) + تجميع الأقسام
│   └── student_form/                        # [NEW] مجلد مشترك بين add/edit
│       ├── student_code_field.dart          # [NEW] قسم الكود التلقائي/اليدوي + مسح QR (موحَّد بين add/edit)
│       ├── student_date_button.dart         # [NEW] استبدال _DatePickerBtn و_DateBtn المكرَّرين بويدجت واحد
│       ├── sibling_picker.dart              # [NEW] استبدال منطق _pickSibling/_addSiblingCandidate المكرَّر
│       ├── student_basic_fields_section.dart # [NEW] اسم/سعر/تليفون/واتساب (add_student_sheet فقط بصيغتها الحالية — راجع research.md لو فيه فرص إعادة استخدام حقيقية مع edit)
│       └── student_group_picker.dart        # [NEW] اختيار/تغيير مجموعة الطالب
├── views/groups/
│   ├── groups_page.dart                     # [MODIFY] يفضل GroupsPage + _GroupCard وما شابه، الشيت والمحرر ينتقلوا لمجلد مشترك
│   ├── group_details_page.dart              # [MODIFY] يفضل GroupDetailsPage + أقسامها الخاصة، تستورد الشيت والمحرر من المجلد المشترك بدل نسختها الخاصة
│   └── group_form/                           # [NEW] مجلد مشترك بين groups_page وgroup_details_page
│       ├── group_form_sheet.dart             # [NEW] الشيت الموحَّد (من _GroupFormSheet — النسخة الأكمل)، يقبل group nullable لدعم إضافة+تعديل من المكانين
│       ├── group_schedule_editor.dart        # [NEW] محرر المواعيد الموحَّد (من _ScheduleEditor — النسخة الأكمل)
│       ├── group_icon_color_pickers.dart     # [NEW] منتقي الأيقونة/اللون (كانا already داخل _GroupFormSheet، يتفصلوا كويدجتس مستقلة)
│       └── group_schedule_conflict.dart      # [NEW] دالة صرفة موحَّدة لفحص تعارض المواعيد (كانت مكرَّرة بمنطق شبه مطابق: _findConflictingGroup وnظيرتها _findConflictingGroupGD)

test/
└── group_schedule_conflict_test.dart          # [NEW] اختبار وحدة للدالة الصرفة الموحَّدة (كانت غير مُختبَرة في الحالتين قبل كده)
```

**Structure Decision**: مشروع Flutter واحد موجود بالفعل — التقسيم يضيف مجلدين فرعيين جديدين (`lib/widgets/student_form/`, `lib/views/groups/group_form/`) بدل ملفين ضخمين لكل مجال، مع إبقاء نقاط الدخول العامة (`showAddStudentSheet`, `showEditStudentSheet`, `GroupsPage`, `GroupDetailsPage`) في نفس أماكنها ونفس تواقيعها العامة حتى لا ينكسر أي استيراد خارجي. لا حاجة لـ`contracts/` بمعنى API خارجي (تطبيق موبايل داخلي)، لكن يُوثَّق "عقد" الويدجتس المشتركة الجديدة (المدخلات/المخرجات المتوقَّعة) في `contracts/` لضمان استخدام متسق من المكانين في كل حالة توحيد.

## Complexity Tracking

*لا مخالفات على الممارسات القائمة تستدعي تبرير — القسم ده فاضي بالتصميم.*
