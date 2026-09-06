# Contract: تكامل البنك مع محرّر الامتحان + الشاشات

## استخراج `QuestionEditor` — `lib/views/exams/question_editor.dart` (جديد)

- يُنقل صنف `_QDraft` (من `online_exam_editor_page.dart`) إلى ملف مشترك `lib/views/exams/question_draft.dart` (اسم عام `QuestionDraft`).
- `QuestionEditor` StatefulWidget: يعرض كارت تحرير سؤال واحد — نص، رفع صورة + مصغّرة، اختيارات + راديو الإجابة الصحيحة (+ إضافة/حذف اختيار للـmcq)، درجة، شرح (spec 023). يدير controllers السؤال داخليًا.
- المدخلات: `QuestionEditor({QuestionDraft draft, VoidCallback onChanged, VoidCallback? onDelete, Widget? trailing})`.
  - `trailing` — لزر "احفظ في البنك" (محرّر الامتحان) أو "حفظ هذا السؤال" (spec 022).
- `online_exam_editor_page._questionCard(i)` يُعاد كتابته ليستخدم `QuestionEditor`.
- **احتياط R2**: لو الاستخراج طلع خطر، `QuestionEditor` يُكتب من الصفر (نظيف)، ومحرّر الامتحان يفضل بكارته الحالي — يُوحَّدوا لاحقًا. انحراف يُسجَّل في tasks.md.

## "أضف من البنك" — `question_bank_picker_page.dart` (جديد)

- `QuestionBankPickerPage` تُفتح بـ`Get.to<List<BankQuestion>>(...)` وترجّع الأسئلة المختارة (أو null إن أُلغيت).
- تبويبان/وضعان:
  1. **اختيار فردي**: قائمة أسئلة البنك (بفلاتر مادة/وسم/بحث زي الشاشة الرئيسية) + `Checkbox` لكل سؤال + عدّاد "مختار: N" + زر "أضف".
  2. **أضف N عشوائي**: اختيار نطاق (الكل / مادة / وسم) + حقل رقم N + معاينة "متاح: M" → عند التأكيد `pickRandom(pool, n)`.
- بنك فارغ → رسالة "أضف أسئلة للبنك أولًا" + زر يفتح `QuestionBankPage`.

### منطق `pickRandom` — `lib/services/question_bank_picker.dart` (جديد، Dart نقي)
```
List<BankQuestion> pickRandom(List<BankQuestion> pool, int n, {Random? rng}) {
  if (pool.isEmpty || n <= 0) return [];
  final shuffled = [...pool]..shuffle(rng ?? Random());
  return shuffled.take(n).toList();
}
```

## `online_exam_editor_page.dart` — تعديلات

- زر "أضف من البنك" (`Icons.library_add_rounded`) في `AppBar.actions` أو أسفل قائمة الأسئلة → `QuestionBankPickerPage` → لكل `BankQuestion` مرتجع: `_questions.add(_QDraft.fromBankQuestion(bq))` (نسخة قيمة، id = null).
- في كل `QuestionEditor.trailing`: زر "احفظ في البنك" (`Icons.bookmark_add_outlined`):
  - لو السؤال غير صالح → `_blockingMsg`.
  - `BankQuestion.fromExamQuestion(draft.toModel(0, 0))` → لو `subject` فارغ، `showDialog` يطلب المادة (حقل + autocomplete من `distinctSubjects`) — إلغاء = لا حفظ.
  - `_bankController.add(bq)` → `ToastHelper.success('اتحفظ في البنك')`.
- زر "احفظ كل الأسئلة في البنك" في overflow menu: يطبّق على كل الأسئلة الصالحة (يطلب مادة واحدة لكلهم، أو لكل واحد بلا مادة).
- **لا رابط دائم** — النسخ قيمة كاملة (FR-012).

## `question_bank_page.dart` (جديد)

- `Scaffold` + `AppBar('بنك الأسئلة')` + `Directionality(rtl)`.
- شريط علوي: بحث نصّي + `DropdownButton`/chips للمادة والوسم (من `controller.subjects`/`controller.tags`).
- `Obx` → `ListView` كروت مختصرة (نص السؤال + نوعه + مادته + عدد اختياراته + الدرجة). ضغط الكارت → `QuestionEditor` sheet للتعديل. زر `+` عائم → sheet سؤال جديد.
- حذف بـ`Dismissible` أو زر في الكارت + تأكيد.
- بنك فارغ → رسالة + دعوة لإضافة أول سؤال.

## نقاط الدخول

- `home_page._buildDrawer`: `_DrawerItem(icon: Icons.quiz_rounded, title: 'بنك الأسئلة', onTap: () { Navigator.pop(context); Get.toNamed(ROUTE_QUESTION_BANK); })` — بعد "الحجوزات".
- `main.dart`: `GetPage(name: ROUTE_QUESTION_BANK, page: () => const QuestionBankPage())`.
- (اختياري) أيقونة "بنك الأسئلة" في `online_exams_tab` header.

## معايير القبول

- FR-009..FR-015، SC-001، SC-002، SC-004.
- بناء امتحان من ١٠ أسئلة بنك < دقيقتين، صفر إعادة كتابة.
- تعديل نسخة في الامتحان لا يلمس الأصل في البنك (والعكس).
- "أضف N عشوائي" — بلا تكرار، N > المتاح → كل المتاح + رسالة.
- امتحان منشور بأسئلة من البنك → المستند العام بلا `correctIndex`/`points`/`explanation`.
