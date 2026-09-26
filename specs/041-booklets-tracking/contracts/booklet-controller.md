# Contract: `BookletController` (GetX)

واجهة داخلية بين الشاشات وطبقة البيانات (`DatabaseService`).

## الحالة
```dart
final RxList<Booklet> booklets;
final RxList<BookletGroupLink> links;          // booklet_groups
final RxList<BookletRecord> records;
final RxList<BookletPayment> payments;
Future<void> load();                            // يحمّل الأربعة + يُستدعى من reload switch في sync_engine
```

## عمليات الملزمة (FR-001..004)
```dart
Future<int?> createBooklet({required String name, required double price, required List<int> groupIds});
Future<void> updateBooklet(Booklet b, {List<int>? groupIds});   // تغيير السعر لا يمسّ الدفعات (المشتقات تتحدّث)
Future<void> deleteBooklet(int bookletId);       // deleteExam-style cascade + طابور المزامنة؛ الواجهة تعرض تأكيدًا برقم التسليمات/المحصَّل
```

## التسليم والاستثناء (FR-003/005)
```dart
Future<void> setDelivered(int bookletId, int studentId, bool delivered); // upsert كسول على booklet_records؛ لا يلمس الدفع
Future<void> setExcluded(int bookletId, int studentId, bool excluded);   // لا يمسح دفعات
```

## الدفعات (FR-006/013)
```dart
/// يرجّع null عند النجاح، أو رسالة خطأ عربية (مبلغ ≤ 0، أو > المتبقي).
Future<String?> addPayment(int bookletId, int studentId, double amount, {DateTime? date});
Future<void> deletePayment(int paymentId);       // الواجهة تحرسها canDeletePaymentsNow
```

## استعلامات العرض
```dart
List<BookletStudentRow> rowsFor(int bookletId, {BookletFilter filter});   // مؤهَّلون + حالة تسليم + مدفوع/متبقي/حالة
BookletSummary summaryFor(int bookletId);       // FR-010: مسلَّم/غير مسلَّم، كامل/جزئي/بلا، إجمالي المحصَّل، إجمالي المتبقي
List<BookletStudentLine> linesForStudent(int studentId);   // FR-012: ملازم الطالب + "متبقي ملازم"
```
`BookletFilter`: حسب التسليم (الكل/لم يستلم/استلم) وحسب الدفع (الكل/لم يدفع/جزئي/كامل).

## قواعد
- كل الحسابات تمر بـ`booklet_math.dart`؛ الـcontroller لا يكرّر منطق المدفوع/المتبقي.
- كل كتابة = `DatabaseService` CRUD مع `_notifyChanged` + `_queueSync`/`_queueDelete` (نمط `insertPayment`/`deleteExam`).
- لا استدعاء لـ`PaymentController`/`PricingHelper` (فصل تام — FR-008).
