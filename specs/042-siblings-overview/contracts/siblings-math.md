# Contract: `lib/utils/siblings_overview.dart` (منطق صرف)

بلا GetX ولا DB — قابل للاختبار المباشر (`test/siblings_overview_test.dart`).

```dart
class SiblingMember { student, group, totalDue, paid, remaining, monthPresent, monthAbsent, double? monthRate }
class SiblingFamily { key, members, sharedTotal, totalPaid, totalRemaining, phones, hasBalance }

/// يبني العيلات من الطلاب النشطين. يتجاهل أي طالب بلا siblingGroupId أو
/// مؤرشف، وأي عيلة أقل من عضوين. مرتّبة: عليها متبقي أولًا ثم الاسم.
List<SiblingFamily> buildSiblingFamilies({
  required List<Student> activeStudents,
  required List<Group> groups,
  required List<Attendance> attendance,
  required List<Payment> payments,
  required DateTime now,
});

/// بحث بالاسم/الكود + فلتر "عليها متبقي".
List<SiblingFamily> filterFamilies(List<SiblingFamily> f, {String query = '', bool owingOnly = false});

/// رسالة واتساب واحدة للعيلة. لو withFinance=false لا تحتوي أرقامًا مالية.
/// بدون توقيع المعلم (launchGuardianWhatsapp بيضيفه).
String buildFamilyMessage(SiblingFamily f, {required bool withFinance, required DateTime month});
```

**سلوك مطلوب**: لا تعدّل المدخلات؛ أرقام المستحق/المتبقي تطابق `PricingHelper` حرفيًا؛ المدفوع يستبعد `kDebtWriteOffNote`؛ `phones` بدون تكرار بعد `PhoneHelper.normalize`.
