# Data Model: ملخص تفصيلي لكارت دفعات الشهر (تفصيل حسب المجموعة)

## كيان محسوب جديد: `GroupPaymentSummaryEntry`

مش جدول DB — كلاس بيانات بسيط (زي `UnpaidStudentEntry` الموجود بالفعل) يمثّل صف مجموعة واحدة في الملخص:

- **`groupId`** (`int?`): مفتاح المجموعة المحلي. `null` = تصنيف "بلا مجموعة" (FR-007).
- **`groupName`** (`String`): اسم المجموعة للعرض ("بلا مجموعة" لو `groupId == null`).
- **`expected`** (`double`): مجموع `monthlyDue` لكل طلاب المجموعة النشطين غير المعفيين للشهر المختار — نفس تعريف `expected` الإجمالي في `_computePaymentCardBody`، لكن مجمَّع بـ`groupId` بدل المدرسة كلها.
- **`collected`** (`double`): مجموع `paidThisMonth` (نفس منطق FIFO الموجود) لطلاب المجموعة.
- **`remaining`** (`double`, مشتق): `expected - collected` (لا يقل عن صفر).
- **`unpaidStudentsCount`** (`int`): عدد الطلاب في المجموعة اللي ظهروا في `unpaidEntries` (شورتفول > 0.5) لنفس الشهر.

مجموعات مستحقها `expected <= 0` (كل الأعضاء معفيين أو لسه ما انضموش) **لا تُضاف** للقائمة أصلاً (FR-006) — يعني القائمة نفسها هي فلتر "عليها مستحق" ضمنيًا.

## العلاقة بالبيانات الموجودة

القيم دي **مش مصدر حقيقة مستقل** — كل صف `GroupPaymentSummaryEntry` هو تجميع فرعي لنفس الحلقة اللي بتبني `expected`/`collected`/`unpaidEntries` الإجمالية في `_computePaymentCardBody` (راجع research.md #1). يعني رياضيًا:

```
paymentCardExpected  == Σ entry.expected  لكل entry في paymentCardGroupBreakdown
paymentCardCollected == Σ entry.collected لكل entry في paymentCardGroupBreakdown
paymentCardUnpaid    == Σ entry.unpaidStudentsCount لكل entry في paymentCardGroupBreakdown
```

الشرط ده هو بالظبط SC-002 في السبيك، وبيتأكد منه اختبار الوحدة الجديد.

## حالات الترتيب والعرض

1. **الترتيب**: تنازليًا حسب `remaining` (الأكبر أولاً) — FR-005.
2. **مجموعة `remaining == 0`** (دفعت بالكامل): تظهر آخر الترتيب، بشارة/لون مختلف (مكتملة) بدل الاختفاء.
3. **تصنيف "بلا مجموعة"** (`groupId == null`, لو فيه طلاب من غير مجموعة أصلاً عندهم مستحق): بياخد مكانه الطبيعي في نفس الترتيب حسب `remaining` — مش دايمًا في الآخر.

## بلا تغيير

- `UnpaidStudentEntry` (الموجود بالفعل) — القائمة المسطحة القديمة تفضل زي ما هي، ونفس القائمة بتتفلتر بـ`groupId` للـdrill-down (US3) بدل ما تتبنى قائمة تانية.
- سكيما الـDB بالكامل — صفر تغيير.
