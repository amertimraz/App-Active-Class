# Phase 1 Data Model: تقسيم شاشات إضافة/تعديل الطالب والمجموعة

لا يوجد كيان بيانات جديد ولا تعديل على أي نموذج بيانات موجود (`Student`, `Group`) في هذا الـrefactor — التقسيم تنظيمي بحت على مستوى واجهة المستخدم (Widgets)، بدون أي تأثير على `lib/models/` أو مخطط قاعدة البيانات (FR-009).

## الكيانات التنظيمية الجديدة (Widgets/Functions مشتركة — ليست بيانات)

هذه ليست "كيانات بيانات" بالمعنى التقليدي، لكنها الوحدات الجديدة القابلة لإعادة الاستخدام الناتجة عن التقسيم، موثَّقة هنا لوضوح البنية:

| الوحدة الجديدة | تحل محل | نوعها | ملاحظة |
|---|---|---|---|
| `StudentCodeField` | القسم المكرَّر في add/edit_student_sheet | StatefulWidget | يقبل `onReset` اختياري (راجع research.md #1) |
| `StudentDateButton` | `_DatePickerBtn` + `_DateBtn` | StatelessWidget | فرق بصري ضئيل (padding) موحَّد لصالح نسخة edit |
| `SiblingPicker` | `_pickSibling`/`_addSiblingCandidate` المكرَّرين | Function/StatefulWidget مساعد | يقبل `excludeStudentId` اختياري |
| `StudentGroupPicker` (add) و(edit) | — (يبقيان منفصلين عمدًا) | — | لا توحيد — راجع research.md #1 |
| `GroupFormSheet` | `_GroupFormSheet` + `_GroupEditSheet` | StatefulWidget | يقبل `Group?` (nullable = إضافة، غير null = تعديل)، نسخة `_GroupFormSheet` الأكمل |
| `GroupScheduleEditor` | `_ScheduleEditor` + `_GDScheduleEditor` | StatefulWidget | صفر فرق سلوكي — دمج مباشر |
| `parseDaySlots` / `findConflictingGroup` / `hasScheduleOverlap` | `_findConflictingGroup`/`_findConflictingGroupGD` وما حولها | دوال صرفة (Pure functions) | أول تغطية اختبارية آلية لهذا المنطق |

## قواعد الصلاحية (Validation)

لا تغيير في أي قاعدة تحقق (validation rule) قائمة بالفعل — كل رسائل الخطأ ونصوصها وتوقيتها تبقى كما هي بالحرف، إلا في حالة واحدة موثَّقة صراحة: شيت تعديل المجموعة من "تفاصيل المجموعة" سيكتسب رسائل الخطأ inline الأكثر وضوحًا من `_GroupFormSheet` (بدل التوست البسيط)، ويكتسب تحقق تكرار الاسم/الكود (`nameTaken`/`codeTaken`) غير الموجود فيه حاليًا — هذا تحسين مقصود ضمن استثناء التوحيد الموافق عليه (راجع research.md #2).

## لا حالات انتقالية (State Transitions)

هذا refactor لا يغيّر أي دورة حياة بيانات — فقط إعادة تنظيم كود العرض (presentation layer).
