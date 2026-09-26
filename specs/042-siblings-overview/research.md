# Phase 0 Research: شاشة الإخوة

## 1. مفتاح تجميع العيلة
- **Decision**: `Student.siblingGroupId` (نفس ما يستخدمه `PricingHelper.siblingGroupSize`). العيلة تظهر فقط لو فيها ≥ 2 طالب **نشط**.
- **Rationale**: `StudentController.students` أصلًا بدون المؤرشفين (`loadAllStudents` بيفلتر `!isArchived`)، والأرشفة بتفك الربط. الـUUID للمزامنة بس؛ الـid المحلي بيتبنّى عند الاستقبال (sync_engine).
- **Alternatives**: التجميع بـ`siblingGroupUuid` — رُفض: قد يكون null لبيانات قديمة.

## 2. مصدر الأرقام (تطابق SC-002)
- **المستحق**: `PricingHelper.totalDueThrough(month: now)` لكل أخ (بنفس `group`, `allAttendance` للطالب, `siblingGroupMembers: students`).
- **المتبقي**: `PricingHelper.accumulatedDebt(...)` بكل دفعات الطالب (شاملة الإسقاط عشان يصفّر) — نفس تفاصيل الطالب بالظبط.
- **المدفوع**: مجموع دفعات الطالب **بدون** `kDebtWriteOffNote` (spec 038).
- **Alternatives**: حساب مبسّط `due - paid` — رُفض: بيفرق مع الإعفاء/الأشهر المؤجلة/وضع الحصة.

## 3. الحضور الشهري
- **Decision**: عدد حاضر (`attendanceCountsAsPresent`) وغائب (`ATTENDANCE_ABSENT`) داخل الشهر الجاري، النسبة = حاضر ÷ (حاضر + غائب) — نفس تعريف التقرير الشهري على واتساب. لو المجموع 0 → "لا توجد سجلات".

## 4. الأرقام والواتساب
- أرقام الإخوة تُجمَّع بعد `PhoneHelper` (تطبيع) ويُزال التكرار؛ الإرسال عبر `launchGuardianWhatsapp` الذي يضيف توقيع المعلم تلقائيًا (لا نضيفه يدويًا).
- لو أكتر من رقم مختلف: bottom sheet يختار منه المدرّس؛ لو صفر: التنبيه المدمج في الـlauncher.
- الرسالة تخلو من أي رقم مالي إن لم يكن `canSeeFinancials` (FR-010).

## 5. التحديث التلقائي
- الشاشة داخل `Obx` تقرأ `students`, `payments`, `attendance` (RxLists) فتتحدّث مع أي تغيير، ومنها تغييرات المزامنة (SyncEngine بيحمّل نفس الكنترولرز).

## 6. الأداء
- الحساب عند كل rebuild لـ ~100 عيلة مقبول (خرائط مبنية مرة: دفعات/حضور حسب studentId)، والفلترة/البحث in-memory.

## 7. الصلاحيات
- `TeamModeService().canSeeFinancials` يُقرأ مرة؛ لو false تُحذف كل الأعمدة/الأرقام المالية وشريحة "عليها متبقي" وأسطر الرسالة المالية.
