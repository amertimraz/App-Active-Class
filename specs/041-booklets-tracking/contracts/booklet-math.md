# Contract: `lib/utils/booklet_math.dart` (دوال صرفة)

بلا DB ولا GetX — قابلة للاختبار المباشر (`test/booklet_math_test.dart`).

```dart
enum BookletPaymentStatus { none, partial, full }

double bookletPaid(Iterable<BookletPayment> payments);
double bookletRemaining(double price, double paid);   // max(0, price - paid)
double bookletOverpaid(double price, double paid);    // max(0, paid - price)
BookletPaymentStatus bookletPaymentStatus(double price, double paid);
// price == 0 → full؛ paid >= price → full؛ paid > 0 → partial؛ else none

/// طلاب مؤهَّلون لملزمة: من [groupStudents] (طلاب كل مجموعات الملزمة)،
/// بلا المؤرشفين، وبلا من عندهم record.excluded == true.
List<Student> eligibleStudents({
  required List<Student> groupStudents,
  required Map<int, BookletRecord> recordsByStudent,
});

/// عرض "السجل التاريخي": نفس القائمة + أي طالب (مؤرشف/مستثنى/منقول)
/// عنده تسليم أو دفعة مسجَّلة لهذه الملزمة.
List<Student> historicalStudents({
  required List<Student> allCandidateStudents,
  required Map<int, BookletRecord> recordsByStudent,
  required Set<int> studentIdsWithPayments,
});

/// إجمالي "متبقي ملازم" لطالب: Σ المتبقي على الملازم اللي هو مؤهَّل لها.
double studentBookletsRemaining(Iterable<BookletRemainingLine> lines);
```

**سلوك مطلوب**: كل الدوال لا تُعدّل مدخلاتها؛ الأرقام العشرية تُقارَن بتسامح 0.005 عند اللزوم (قص القيم السالبة الصغيرة الناتجة عن الفاصلة العائمة إلى صفر).
