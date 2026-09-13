# عقد: Sync Rules (قواعد المزامنة — جانب التحميل/القراءة)

هذا العقد بيوصف **الشكل المنطقي** لقواعد المزامنة المطلوبة على خدمة PowerSync، بمعزل عن صياغة YAML الحرفية النهائية (تُحسم في تنفيذ Phase 2 تحت `/speckit-tasks`).

## المبدأ العام

كل جدول مُتزامن (راجع [data-model.md](../data-model.md)) بيتصنّف تحت "bucket" واحد بارامتره `team_id` — مطابق تمامًا لمنطق سياسات RLS الحالية (`is_team_member(team_id) AND is_team_license_active(team_id)`). العضو (مدرس أو مساعد) بيستلم فقط بيانات الفريق/الفرق اللي هو عضو فيها — بلا أي تغيير في نطاق الرؤية الحالي.

## البارامتر المشترك: `team_id` من التوكن

- الـbucket بيتحدد بمعامل واحد: `team_id` (أو أكتر من فريق واحد لو المستخدم ينتمي لأكتر من فريق — نادر حاليًا لكن ممكن نظريًا مستقبلًا).
- قيمة `team_id` بتُستخرج وقت الاتصال من جدول `team_members` (نفس الاستعلام المنطقي اللي بيعمله `is_team_member` حاليًا) — مش بتتبعت من العميل مباشرة (تفاديًا لانتحال فريق تاني).

## Buckets المطلوبة (واحد لكل جدول متزامن)

| الجدول | فلتر المزامنة (منطقي) | ملاحظة |
|---|---|---|
| `groups` | `team_id = :team_id` | — |
| `students` | `team_id = :team_id` | — |
| `attendance` | `team_id = :team_id` | أكبر حجمًا — أولوية اختبار الأداء |
| `payments` | `team_id = :team_id` | — |
| `homework` | `team_id = :team_id` | — |
| `session_overrides` | `team_id = :team_id` | spec 032 |
| `exams`, `exam_questions`, `bank_questions`, `exam_groups`, `exam_grades`, `exam_submissions` | `team_id = :team_id` | نفس النمط لكل جداول الامتحانات |

## الحذف المنطقي (Soft Delete)

الجداول الحالية بتستخدم `deleted_at` (soft delete) بدل الحذف الفعلي — sync rules لازم تشمل الصفوف المحذوفة منطقيًا (`deleted_at IS NOT NULL`) في تدفق المزامنة (مش تستبعدها)، عشان العميل يقدر يمسحها محليًا لما توصله (نفس سلوك `catchUpPull(includeDeleted: true)` الحالي) — الفرق إن PowerSync بيدي الفرق (delta) تلقائيًا بدل ما نجيب الجدول كله من الأول كل مرة.

## معيار القبول

- عضو مش موجود في `team_members` لفريق معيّن **ميستلمش أي صف** من بياناته (نفس ضمان RLS الحالي — FR-004 في spec.md).
- تعطيل ترخيص الفريق (`owner_license_active = false`) بيوقف استلام بيانات جديدة لهذا الفريق فورًا (نفس منطق `is_team_license_active` الحالي).
