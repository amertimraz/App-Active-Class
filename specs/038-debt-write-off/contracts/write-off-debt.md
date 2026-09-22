# Internal Contract: writeOffDebt

التطبيق موبايل offline-first بدون واجهة برمجية خارجية عامة — "العقد" هنا هو الواجهة الداخلية بين شاشة تفاصيل الطالب (UI) و`PaymentController` (منطق الأعمال)، لضمان اختبار الدالة بمعزل عن الواجهة.

## الدالة

```dart
/// يسجّل عملية "إسقاط مديونية" للطالب المُعطى — دفعة بمبلغ يساوي
/// accumulatedDebt الحالية لحظة الاستدعاء، موسومة بـ kDebtWriteOffNote.
/// يرجّع null لو نجحت العملية، أو رسالة خطأ بالعربي لو اتلغت
/// (مثلاً المديونية بقت صفر أو أقل لحظة التنفيذ).
Future<String?> writeOffDebt({
  required Student student,
  required Group? group,
  required List<Attendance> allAttendance,
  required List<Payment> payments,
  required double graceDays,
  List<Student>? siblingGroupMembers,
});
```

## المدخلات

| المعامل | المصدر | ملاحظة |
|---|---|---|
| `student` | الطالب المعروض في الشاشة | لازم يكون نفس الطالب المعروضة بياناته |
| `group` | مجموعة الطالب الحالية | تُمرَّر زي ما بيتم بالفعل عند حساب `accumulatedDebt` في الشاشة |
| `allAttendance` | `AttendanceController` الحيّة | نفس البيانات المستخدمة لعرض كارت "مديونية متراكمة" |
| `payments` | `PaymentController.payments` (مفلترة لنفس الطالب) | نفس المصدر المستخدم لعرض المديونية الحالية |
| `graceDays` | `SettingsController` | لضمان نفس منطق حساب `accumulatedDebt` المعروض |
| `siblingGroupMembers` | لو الطالب ضمن مجموعة إخوة | اختياري — نفس ما هو مُستخدَم في حساب الكارت |

## السلوك

1. تُعاد حساب `PricingHelper.accumulatedDebt(...)` بنفس المدخلات فورًا داخل الدالة (وليس بقيمة مُمرَّرة جاهزة من الشاشة) — لضمان "القيمة الحالية وقت التنفيذ الفعلي" (research.md #2).
2. لو الناتج `<= 0`: **لا** يُنشأ أي `Payment`، وتُرجع الدالة رسالة توضّح أن المديونية لم تعد موجودة (FR-010).
3. لو الناتج `> 0`: يُستدعى `DatabaseService.insertPayment(Payment(studentId: student.id, date: DateTime.now(), amount: <الناتج>, note: kDebtWriteOffNote))`، وتُرجع الدالة `null` (نجاح).
4. أثناء التنفيذ (بين الاستدعاء وانتهاء `insertPayment`)، الزرار/الدالة المستدعية في الواجهة تمنع أي استدعاء متكرر (FR-009 — عبر `busy` flag في الـcontroller، راجع research.md #4).

## المخرجات المرصودة على الشاشة (بعد النجاح)

- `PaymentController.payments` تتحدّث تلقائيًا (نفس آلية أي `insertPayment` موجودة) → `accumulatedDebt` المعاد حسابها في `build()` التالي = صفر → كارت "مديونية متراكمة" وزرار الإسقاط يختفوا (FR-005، بدون أي كود UI إضافي غير إعادة البناء العادية لأن الشرط `accumulatedDebt > 0` موجود بالفعل).

## أخطاء متوقعة

| الحالة | الاستجابة |
|---|---|
| المديونية `<= 0` لحظة التنفيذ | رسالة عربية واضحة، لا تغيير في البيانات |
| فشل الكتابة في SQLite (نادر — امتلاء تخزين إلخ) | تُمرَّر الاستثناء لأعلى زي أي `insertPayment` فاشلة أخرى في التطبيق (لا معالجة خاصة إضافية) |
