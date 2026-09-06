# Phase 1 — Data Model: تحصيل المديونية المتراكمة من شاشة الدفع بماسح QR

**لا سكيمة جديدة، لا ترقية `DATABASE_VERSION`، لا أعمدة جديدة.** الميزة تستهلك بيانات قائمة وتضيف قيمًا **محسوبة** (غير مخزَّنة).

## كيانات قائمة مُستهلَكة (قراءة فقط)

### Student (`students`)
| حقل | الاستخدام في الميزة |
|---|---|
| `id` | مفتاح جلب الحضور/الدفعات |
| `price` / `effectivePrice` | سعر الحصة للـper-session؛ مقام تحويل المديونية ← عدد حصص |
| `attendanceStart` ?? `createdAt` | **جديد الاستخدام هنا**: بداية نطاق الشهور للـper-session (بدل الشهر الحالي) |
| `exemptPercent` / `isFullyExempt` | يراعيها `PricingHelper` — لا حساب مكرَّر |
| `siblingGroupId` / `siblingsTotal` | يراعيها `PricingHelper` عبر `siblingGroupMembers` |

### Attendance (`attendance`)
- مُحمَّلة بالفعل في `_preparePayment` للـper-session (`getAttendanceByStudent`).
- تُصفّى بـ`attendanceCountsAsPresent(status)` (حاضر/متأخر) — نفس المنطق القائم.

### Payment (`payments`)
| حقل | الاستخدام |
|---|---|
| `amount` | مجموعها = إجمالي المدفوع (رصيد FIFO واحد) |
| `date` | مطابقة الشهر في `_paidSessionsInSelectedMonths` |
| `note` | يحوي `sessions=X` (per-session)؛ regex `sessions=(\d+)` قائم؛ غياب العدّاد = 1 |

**كتابة**: صف `payments` واحد جديد لكل تأكيد دفعة، عبر `DatabaseService.insertPayment` القائم (يصف outbox المزامنة تلقائيًا). لا تغيير في شكل الصف.

## قيم محسوبة (getters جديدة/معدَّلة في `QRController`)

| قيمة | تعريف | مصدر |
|---|---|---|
| `scannedStudentDebt` | **قائم، بلا تغيير** | `PricingHelper.accumulatedDebt(student, group, _scannedAttendance, _scannedPayments, _allStudents)` |
| `scannedStudentDebtSessions` | `effectivePrice > 0 ? (scannedStudentDebt / effectivePrice).floor() : 0` | مشتق |
| `unpaidSessionsCount` | **قائم، يتصحّح** عبر توسيع `selectedMonths` (join→now) | `selectedSessionsCount - _paidSessionsInSelectedMonths` |
| `unpaidSessionDates` | **قائم، يتصحّح** تلقائيًا | حضور كل الشهور مرتّب، بحذف أقدم `_paidSessionsInSelectedMonths` |
| `sessionsCoveredBy(amount)` | `effectivePrice > 0 ? (amount / effectivePrice).floor() : 0` | مشتق — معاينة لحظية |
| `debtRemainingAfter(amount)` | `(scannedStudentDebt - amount).clamp(0, ∞)` | مشتق — معاينة لحظية |
| `_explicitSessionsForPayment` (`Rxn<int>`) | عدد الحصص المسجَّل في `note` — يُضبط من `payAllUnpaidSessions` و`applyDebtAmountPayment` | حالة داخلية |

## حالات (state) في `_preparePayment` — before/after

| العنصر | قبل (per-session) | بعد (per-session) |
|---|---|---|
| `start` | `nowMonth` | `DateTime(attendanceStart ?? createdAt)` مقصوصًا للشهر |
| `upcomingMonths` | شهر واحد (الحالي) غالبًا | كل الشهور من `start` حتى الشهر الحالي (سقف مرفوع) |
| `selectedMonths` (autoSelect) | `[الشهر الحالي]` | كل `upcomingMonths` |
| المجموعات الشهرية | **بلا تغيير** | **بلا تغيير** |

## ثوابت التحقّق (US3)

| قاعدة | قيمة |
|---|---|
| حد أدنى للمبلغ الحر | `> 0` |
| حد أقصى للمبلغ الحر | `≤ scannedStudentDebt + 0.01` |
| مدخل غير رقمي / فارغ | مرفوض (زر التطبيق معطّل) |
| `effectivePrice <= 0` | حقل المبلغ الحر معطّل كليًا |
| `scannedStudentDebt <= 0.01` | حقل المبلغ الحر + "دفع كل المستحق" معطّلان |
