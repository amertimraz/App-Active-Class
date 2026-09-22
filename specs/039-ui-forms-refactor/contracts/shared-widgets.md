# Internal Contracts: الويدجتس والدوال المشتركة الجديدة

التطبيق موبايل داخلي بدون API خارجي — "العقود" هنا هي الواجهات الداخلية (constructor parameters / function signatures) للوحدات المشتركة الجديدة، لضمان استخدام متسق من كل نقاط الاستدعاء (add/edit الطالب، groups_page/group_details_page).

## `StudentCodeField` (`lib/widgets/student_form/student_code_field.dart`)

```dart
/// StatelessWidget عرض بحت — كل منطق تحديد الحالة (فارغ/يدوي/تلقائي في
/// add، تغيّر/بدون تغيير في edit) يبقى في الشاشة المستدعية كما هو
/// بالضبط؛ الويدجت بس بيرسم الحاوية/الأيقونة/الحقل/السويتش/الأزرار
/// بالألوان والنصوص الجاهزة المُمرَّرة له (راجع research.md #1 —
/// تصحيح وقت التنفيذ لتفادي فرض state machine واحدة على منطقين مختلفين).
class StudentCodeField extends StatelessWidget {
  final TextEditingController codeController; // نفس _codeCtrl الموجود بالفعل في كل شاشة (لا يُنشأ داخل الويدجت لتفادي فقدان الـcursor/الفوكس عند كل rebuild)
  final bool isManual;                 // وضع الإدخال اليدوي مفعّل؟
  final Color boxColor;                 // محسوب من الشاشة المستدعية بمنطقها الخاص
  final IconData icon;                  // محسوب من الشاشة المستدعية بمنطقها الخاص
  final String displayText;             // النص المعروض لما isManual == false
  final String manualHint;              // hint النص لما isManual == true
  final ValueChanged<bool> onManualChanged;
  final ValueChanged<String> onCodeChanged; // بيتنادى وقت الكتابة اليدوية فقط
  final VoidCallback onScanQr;
  final VoidCallback? onReset;          // null في add_student_sheet، مُمرَّر في edit
}
```

**السلوك المتوقَّع**: نفس شكل/تفاعل القسم الحالي في add_student_sheet.dart وedit_student_sheet.dart بالحرف — كل شاشة تحسب `boxColor`/`icon`/`displayText` بنفس منطقها الحالي بدون تغيير، والفرق الوحيد المسموح في الويدجت نفسه هو ظهور زرار "رجوع للكود الأصلي" فقط لو `onReset != null`. (ملاحظة دقيقة: حدود الحاوية في add كانت بشفافية 0.3 لحالة "فارغ" و0.25 لباقي الحالات — الويدجت الموحَّد يستخدم 0.25 ثابتة، فرق غير ملحوظ.)

## `StudentDateButton` (`lib/widgets/student_form/student_date_button.dart`)

```dart
class StudentDateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final Color color;
  final VoidCallback onTap;
}
```

**السلوك المتوقَّع**: يحل محل `_DatePickerBtn` (add) و`_DateBtn` (edit) بنفس الـpadding/الأحجام المستخدَمة حاليًا في `edit_student_sheet.dart` (الفرق البصري عن نسخة add أقل من 2px — غير ملحوظ، راجع research.md #1).

## `SiblingPicker` (`lib/widgets/student_form/sibling_picker.dart`)

```dart
/// يفتح حوار اختيار طالب أخ/أخت، ويرجّع القائمة المدموجة الجديدة بعد
/// الإضافة (تشمل باقي أعضاء مجموعة إخوة الطالب المختار لو كان عضوًا
/// في مجموعة موجودة بالفعل)، أو null لو اتلغى/اتجاوز الحد الأقصى.
Future<List<Student>?> showSiblingPicker(
  BuildContext context, {
  required List<Student> currentSiblings,
  int? excludeStudentId, // null في add، معرّف الطالب الحالي في edit
  required Color accentColor,
});
```

**السلوك المتوقَّع**: نفس حوار البحث/الاختيار الحالي بالحرف، ونفس حد أقصى 3 أعضاء، ونفس رسالة الخطأ عند التجاوز.

## `GroupFormSheet` (`lib/views/groups/group_form/group_form_sheet.dart`)

```dart
class GroupFormSheet extends StatefulWidget {
  final Group? group;                 // null = إضافة، غير null = تعديل
  final List<Group> existingGroups;
  final Future<bool> Function(Group) onSave;
  final void Function(String groupName, double newPrice)? onSaved; // اختياري — groups_page بيستخدمه، group_details_page ممكن يسيبه null
}
```

**السلوك المتوقَّع**: طبق الأصل من `_GroupFormSheet` الحالي في `groups_page.dart` (اختيار أيقونة/لون/نوع تسعير + تحقق تكرار الاسم/الكود + رسائل خطأ inline)، يُستخدَم من كل من `groups_page.dart` و`group_details_page.dart` (استبدال `_GroupEditSheet` بالكامل — راجع research.md #2).

## `GroupScheduleEditor` (`lib/views/groups/group_form/group_schedule_editor.dart`)

```dart
class GroupScheduleEditor extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
}
```

**السلوك المتوقَّع**: طبق الأصل من `_ScheduleEditor` الحالي (صفر فرق سلوكي متعمَّد — راجع research.md #3).

## دوال تعارض المواعيد (`lib/views/groups/group_form/group_schedule_conflict.dart`)

```dart
Map<String, List<(int, int)>> parseDaySlots(String raw);
bool hasScheduleOverlap(String raw);
Group? findConflictingGroup(String raw, List<Group> others);
```

**السلوك المتوقَّع**: طبق الأصل من `_findConflictingGroup`/`_parseDaySlots` (النسختين متطابقتين منطقيًا — راجع research.md #4). أول دالة من الأربعة الأصلية تحصل على اختبار وحدة آلي مباشر.
