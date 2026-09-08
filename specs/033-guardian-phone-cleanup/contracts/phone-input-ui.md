# Contract: حقل رقم ولي الأمر + المعاينة

## `CustomTextField` — بارامترات جديدة (توافق تام للخلف)

```dart
const CustomTextField({
  // ... القائم بلا تغيير ...
  this.textDirection,                 // TextDirection?  → TextFormField.textDirection
  this.textAlign = TextAlign.start,   // TextAlign       → TextFormField.textAlign
  this.inputFormatters,               // List<TextInputFormatter>? → TextFormField.inputFormatters
});
```
- كل القيَم الافتراضية = السلوك الحالي بالضبط. ممنوع تغيير أي سلوك لأي مستدعٍ قائم.

## `PhoneSanitizerFormatter`

```dart
class PhoneSanitizerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = PhoneHelper.cleanForStorage(newValue.text);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}
```
- لصق `"+20 100 123 4567"` → الحقل يعرض `"+201001234567"` فورًا.
- كتابة رقم رقمًا رقمًا → تجربة طبيعية (`cleanForStorage` لا يغيّر أرقامًا لاتينية نظيفة).

## `PhoneField` widget

```dart
PhoneField({
  required TextEditingController controller,
  required String dialCode,
  VoidCallback? onContactPick,
})
```

**التركيب**:
```
Column(
  Row(
    Expanded(CustomTextField(
      controller, label: '01xxxxxxxxx',
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      inputFormatters: [PhoneSanitizerFormatter()],
    )),
    if (onContactPick != null) IconButton(contacts) → onContactPick,
  ),
  ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (_, v, __) {
      if (v.text.trim().isEmpty) return SizedBox.shrink();
      return Column(
        Text('هيتبعت على: ${PhoneHelper.displayIntl(v.text, dialCode)}'),  // رمادي صغير
        if (!PhoneHelper.isLikelyValid(v.text, dialCode))
          Text('الرقم يبدو غير مكتمل')  // برتقالي صغير — غير معطِّل
      );
    },
  ),
)
```

**عقود السلوك**:
- FR-005: الحقل LTR + محاذاة يسار مهما كان اتجاه الواجهة.
- FR-006: التنظيف لحظة الكتابة/اللصق عبر الـformatter (لا عند الحفظ).
- FR-008: المعاينة تتحدّث مع كل ضغطة (ValueListenableBuilder على controller).
- FR-009: التحذير غير معطِّل — لا يمنع `_submit`.
- FR-010: حقل فارغ → لا معاينة ولا تحذير.
- `onContactPick` = `ContactPickerService.pickPhoneNumber` (مخرجه أصلًا محلي؛ يمرّ عبر الـformatter
  عند `controller.text = ...`).

## نقاط التعديل

| ملف | تغيير |
|---|---|
| `lib/widgets/add_student_sheet.dart` | استبدل `Row(CustomTextField + IconButton)` لحقل الرقم بـ`PhoneField(controller: _phoneCtrl, dialCode: settings.countryDial.value, onContactPick: ...)` |
| `lib/widgets/edit_student_sheet.dart` | نفس الاستبدال لحقل `_phoneCtrl` |
| `lib/services/contact_picker_service.dart` | `_normalize` → يستدعي `PhoneHelper.cleanForStorage` (يزيل التكرار الرابع) |

## عدم انحدار
- كل حقول `CustomTextField` الأخرى: صفر تغيير بصري/سلوكي.
- `_submit` في الشيتين: يخزّن `_phoneCtrl.text.trim()` كما هو (بقى نظيفًا بفعل الـformatter) — لا
  تحقّق مانع جديد.
