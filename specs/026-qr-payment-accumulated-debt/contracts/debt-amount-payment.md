# Contract: دفع مبلغ حرّ من المديونية (per-session)

## getters معاينة لحظية (`QRController`)
```
int sessionsCoveredBy(double amount) =>
    _effPrice > 0 ? (amount / _effPrice).floor() : 0;

double debtRemainingAfter(double amount) =>
    (scannedStudentDebt - amount).clamp(0.0, double.infinity).toDouble();
```
نقية، بلا آثار جانبية — تُستدعى من `Obx` أثناء الكتابة في الحقل.

## الأمر
```
/// يضبط دفعة بمبلغ حرّ على حساب المديونية المتراكمة (per-session فقط).
/// يرجّع true لو قُبِل المبلغ وضُبط الـoverride.
bool applyDebtAmountPayment(double amount) {
  if (!isPerSessionGroup) return false;
  final s = scannedStudent.value;
  if (s == null) return false;
  if (amount <= 0) { ToastHelper.error('أدخل مبلغًا صحيحًا'); return false; }
  final debt = scannedStudentDebt;
  if (debt <= 0.01) { ToastHelper.error('الطالب سديد الحساب'); return false; }
  if (amount > debt + 0.01) {
    ToastHelper.error('المبلغ أكبر من المديونية المتراكمة (${FormatHelper.formatCurrency(debt)})');
    return false;
  }
  final sessions = sessionsCoveredBy(amount);
  setOverride(amount: amount, note: 'دفعة من المديونية');
  _explicitSessionsForPayment.value = sessions; // بعد setOverride (يصفّره)
  return true;
}
```

## `_explicitSessionsForPayment` (`Rxn<int>`)
- يُضبط في: `payAllUnpaidSessions` (= `count`) و`applyDebtAmountPayment` (= `sessionsCoveredBy`).
- يُصفَّر (`= null`) في: `setOverride` (المسار العام)، `_clearPaymentState`، `_preparePayment`.
- يُقرأ في `confirmPayment`:
```
final sessionsBeingPaid = !isPerSessionGroup
    ? 0
    : (_explicitSessionsForPayment.value
        ?? (overrideAmount.value != null && s.effectivePrice > 0
            ? (overrideAmount.value! / s.effectivePrice).round().clamp(1, 999)
            : unpaidSessionsCount));
```
يحل محل الاعتماد على `_sessionsCoveredByQuickPay` وحده (الذي يبقى كتفصيل داخلي لـ`payAllUnpaidSessions` أو يُدمج في الحقل الجديد).

## شكل `note` الناتج
نفس مسار `confirmPayment` العام:
```
months=<keys.join(',')>;custom=1;note=دفعة من المديونية;sessions=<X>
```
- `<keys>` = `selectedMonths` المشفّرة (النطاق الموسّع join→now) — لا يؤثر على قراءة `sessions=` لاحقًا.
- `X` = `floor(amount / effectivePrice)` (قد يكون 0 لو `amount < سعر حصة` — regex يقرأ 0، ويُعامَل كصفر حصص مدفوعة؛ المبلغ نفسه يقلّل `scannedStudentDebt` فعليًا فلا يضيع).

## الواجهة (`qr_scanner_payment_page.dart`, per-session فقط)
عنصر جديد أسفل زر «دفع كل المستحق» (يظهر فقط عندما `scannedStudentDebt > 0.01` و`effectivePrice > 0` و`!fullyPaidUp`):
- `TextField` رقمي (`keyboardType: number`, يقبل عشري)، عنوان «ادفع مبلغًا من المديونية».
- تحت الحقل، `Obx` معاينة أثناء الكتابة:
  - `amount` صالح → «يغطّي {sessionsCoveredBy(amount)} حصة • المتبقّي بعد الدفع: {formatCurrency(debtRemainingAfter(amount))}».
  - `amount > debt` → تحذير أحمر «المبلغ أكبر من المديونية» + زر التطبيق معطّل.
  - فارغ/غير رقمي/0 → لا معاينة، زر معطّل.
- زر «تطبيق» → `controller.applyDebtAmountPayment(parsed)`؛ عند النجاح يظهر شريط الـoverride القائم («المبلغ المعدّل: …») ويكمل المدرس بزر «تأكيد الدفع».

## التوافق مع المسارات القائمة
- `payAllUnpaidSessions` + الـstepper: بلا تغيير سلوكي (يستفيدان من `unpaidSessionsCount` الكلي الآن).
- زر «تعديل» اليدوي القائم (`setOverride` من الحوار): يصفّر `_explicitSessionsForPayment` → `confirmPayment` يقدّر بالـ`round` كما اليوم.
- `SessionLogController` / سجل «دفعوا اليوم»: يقرأ `lastConfirmedPaymentId` — بلا تغيير؛ الدفعة الجزئية تظهر بمبلغها.
- المزامنة: `insertPayment` القائم يصف outbox — صفر تغيير.

## اختبار القبول
- سعر 20، مديونية 140: إدخال «50» → معاينة «يغطّي 2 حصة • المتبقّي: 90.00 ج»؛ تأكيد → صف `payments` amount=50، `note` به `sessions=2`؛ إعادة فتح → مديونية 90.
- إدخال «200» (> 140) → زر التطبيق معطّل + تحذير.
- إدخال «0» أو «abc» → لا معاينة، لا تطبيق.
- إدخال «45» → «يغطّي 2 حصة»؛ الدفعة تُسجَّل 45 فعليًا، `sessions=2`.
