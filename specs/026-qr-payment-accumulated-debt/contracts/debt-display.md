# Contract: عرض المديونية المتراكمة في شاشة الدفع بالماسح

## المصدر
`QRController.scannedStudentDebt` — **قائم، بلا تعديل**:
```
PricingHelper.accumulatedDebt(
  student: s, group: _scannedGroup.value,
  allAttendance: _scannedAttendance, payments: _scannedPayments,
  siblingGroupMembers: _allStudents)
```
نفس الاستدعاء تمامًا الذي تستخدمه شاشة تفاصيل الطالب → تطابق مضمون (SC-001).

## getter جديد
```
double get _effPrice => scannedStudent.value?.effectivePrice ?? 0;
int get scannedStudentDebtSessions =>
    _effPrice > 0 ? (scannedStudentDebt / _effPrice).floor() : 0;
```

## الواجهة (`qr_scanner_payment_page.dart`)

### قبل
سطر المديونية داخل `if (!controller.isPerSessionGroup && !student.isFullyExempt)` (سطر ~1054) — **مخفي للـper-session**.

### بعد
- الشرط يصبح `if (!student.isFullyExempt)` — يظهر للمسارين.
- محتوى `Obx`:
  - `isPreparingPayment` → `SizedBox.shrink()` (كما هو).
  - `debt <= 0.01` → أخضر: «الطالب سديد الحساب — لا مديونية».
  - `debt > 0.01` → برتقالي: «متبقّي عليه: {formatCurrency(debt)}»
    - **إضافة للـper-session فقط** وعندما `scannedStudentDebtSessions >= 1`: سطر ثانٍ أصغر «= {n} حصة».

### حالات
| حالة | العرض |
|---|---|
| شهري، مديونية > 0 | «متبقّي عليه: X ج» (كما اليوم) |
| per-session، مديونية > 0، سعر > 0 | «متبقّي عليه: X ج» + «= N حصة» |
| per-session، مديونية > 0، `effectivePrice == 0` | «متبقّي عليه: X ج» فقط (بلا سطر حصص) |
| أي، مديونية ≤ 0 | «سديد الحساب» (أخضر) |
| `isFullyExempt` | لا يظهر السطر إطلاقًا (كما اليوم) |

## اختبار القبول
- طالب per-session مديونيته 140 ج وسعر حصته 20 → الشاشة تعرض «متبقّي عليه: 140.00 ج» و«= 7 حصة»، مطابقًا لكارت تفاصيل الطالب.
- طالب دفع كل المستحق → «سديد الحساب» في الشاشتين.
