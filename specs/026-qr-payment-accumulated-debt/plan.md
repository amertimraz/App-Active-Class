# Implementation Plan: تحصيل المديونية المتراكمة من شاشة الدفع بماسح QR

**Branch**: `026-qr-payment-accumulated-debt` | **Date**: 2026-09-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/026-qr-payment-accumulated-debt/spec.md`

## Summary

الباج الجذري: مسار "بالحصة" في `QRController` يثبّت `selectedMonths` على الشهر الحالي فقط (`_preparePayment`: `start = nowMonth` للـper-session)، فكل الـgetters المبنية عليه (`selectedSessionsCount` / `_paidSessionsInSelectedMonths` / `unpaidSessionsCount` / `unpaidSessionDates` / `fullyPaidUp`) تحسب الشهر الحالي فقط — بينما `QRController.scannedStudentDebt` (المعروض بالفعل للمجموعات الشهرية عبر `PricingHelper.accumulatedDebt`) يحسب كل الشهور. النتيجة تعارض في الأرقام ومنع تحصيل المتأخر القديم من الماسح.

1. **US1 (P1)** — عرض `scannedStudentDebt` في شاشة الدفع بالماسح **للمجموعات بالحصة أيضًا** (حاليًا `if (!controller.isPerSessionGroup ...)` يخفيه)، مع سطر تحويل "= N حصة" = `floor(debt / effectivePrice)`.
2. **US2 (P1)** — في `_preparePayment` للـper-session: بناء `upcomingMonths` واختيار `selectedMonths` من **شهر انضمام الطالب حتى الشهر الحالي** بدل الشهر الحالي فقط. كل الـgetters القائمة تتصحّح تلقائيًا (المجموع، التواريخ، عدد الحصص، "دفع كل المستحق"، الـstepper). لا month chips للـper-session في الواجهة → صفر أثر بصري غير المقصود. رفع سقف `_buildUpcomingMonths` (12 شهرًا) للمسار per-session.
3. **US3 (P2)** — حقل مبلغ حرّ في شاشة الدفع بالماسح للـper-session: `QRController.applyDebtAmountPayment(double amount)` يتحقق `0 < amount ≤ scannedStudentDebt` ويضبط `overrideAmount` + عدد الحصص المغطّاة الصريح (`floor(amount / effectivePrice)`)؛ getters معاينة لحظية `sessionsCoveredBy(amount)` و`debtRemainingAfter(amount)`؛ الملاحظة تُسجَّل `sessions=X` بنفس نمط `payAllUnpaidSessions`.

**تبعية DB**: **لا شيء**. لا ترقية `DATABASE_VERSION`، لا سكيمة جديدة.
**تبعية مزامنة**: **لا شيء**. الدفعة تُدرَج عبر `DatabaseService.insertPayment` القائم (يصف outbox للـ`payments` كالمعتاد).
**تبعية Firestore/Supabase**: **لا شيء**.

## Technical Context

**Language/Version**: Dart 3.5.4 / Flutter 3.38.1

**Primary Dependencies**: GetX، sqflite، `intl`. صفر تبعيات جديدة.

**Storage**: SQLite فقط — قراءة `attendance` + `payments` (موجود في `_preparePayment`). جدول `payments`: صف دفعة عادي، ملاحظة `note` بصيغة `months=<keys>;...;sessions=X` القائمة. لا أعمدة جديدة.

**Testing**: `flutter test` — وحدات لمنطق نقي مستخرج/قائم:
- `PricingHelper.accumulatedDebt` عبر شهرين per-session (موجود، نضيف تغطية).
- تحويل مديونية ← عدد حصص (`floor`, سعر = 0، مديونية سالبة).
- `sessionsCoveredBy` / `debtRemainingAfter` (منع الزيادة، صفر، غير رقمي).
- عدّ الحصص غير المدفوعة عبر شهرين (FIFO، دفعة سابقة `sessions=3`).
تحقّق يدوي عبر [quickstart.md](quickstart.md).

**Target Platform**: Android (تطبيق المدرس + المساعد).

**Project Type**: Mobile single-project (`lib/`).

**Performance Goals**: فتح شاشة الدفع < 1s (نفس المسار الحالي — قراءتان محليتان). المعاينة اللحظية للمبلغ الحر: إعادة بناء `Obx` واحدة لكل حرف، حساب O(عدد الدفعات).

**Constraints**:
- **مصدر واحد للمديونية**: كل رقم مديونية/عدد حصص يمرّ عبر `PricingHelper` — صفر منطق حساب مديونية جديد في `QRController` أو الواجهة.
- التوافق: دفعات `note` بلا `sessions=` = حصة واحدة (سلوك `_paidSessionsInSelectedMonths` القائم — يُحافَظ عليه).
- منع الزيادة عن المديونية سلوك v1 (لا رصيد مقدّم من هذه الشاشة).
- الإخوة/الإعفاء: عبر `siblingGroupMembers` المُمرَّرة لـ`PricingHelper` (نمط `_allStudents` القائم) — لا خصم مكرَّر.
- لا تعديل على `PricingHelper`، شاشة تفاصيل الطالب، شاشة المدفوعات، `SessionLogController`، `SyncEngine`.

**Scale/Scope**: طالب واحد لكل مسح؛ عشرات الحصص/الدفعات كحد أقصى للطالب. ملفان معدَّلان (`qr_controller.dart`، `qr_scanner_payment_page.dart`) + ملف اختبار جديد.

## Constitution Check

`.specify/memory/constitution.md` قالب فارغ — تُطبَّق أعراف المشروع:

| العُرف | الالتزام |
|---|---|
| مصدر حساب مديونية واحد (`PricingHelper`) في كل الشاشات | ✅ إعادة استخدام `scannedStudentDebt` القائم |
| صفر ترقية DB / صفر ALTER | ✅ لا سكيمة |
| صفر تغيير في مسار المزامنة (الدفعة صف `payments` عادي) | ✅ `insertPayment` القائم |
| صيغة ملاحظة `sessions=N` القائمة يقرأها منطق "المدفوع" | ✅ نفس النمط |
| مفاتيح التصحيح/Firestore | ✅ غير معنية |
| صفر تبعيات جديدة | ✅ |
| التغيير محصور في شاشة الماسح + منطقها (FR-016) | ✅ ملفان فقط |

**النتيجة**: PASS. `Complexity Tracking` غير مطلوب.

## Project Structure

### Documentation (this feature)

```text
specs/026-qr-payment-accumulated-debt/
├── plan.md              # هذا الملف
├── research.md          # Phase 0
├── data-model.md        # Phase 1 — كيانات محسوبة (لا سكيمة)
├── quickstart.md        # Phase 1 — سيناريوهات تحقّق
├── contracts/           # Phase 1
│   ├── qr-controller-per-session-scope.md
│   ├── debt-display.md
│   └── debt-amount-payment.md
├── checklists/
│   └── requirements.md  # موجود
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── controllers/
│   └── qr_controller.dart              # [M] المحور:
│       # - _preparePayment: للـper-session، start = شهر انضمام الطالب (attendanceStart ?? createdAt)
│       #   بدل nowMonth؛ autoSelect لكل الشهور من start حتى الشهر الحالي
│       # - _buildUpcomingMonths: سقف 12 → أعلى (أو غير محدود) للمسار per-session
│       # - عدّاد حصص صريح موحّد: Rxn<int> _explicitSessionsForPayment يُضبط من
│       #   payAllUnpaidSessions و applyDebtAmountPayment؛ confirmPayment يستخدمه إن != null
│       # - [NEW] applyDebtAmountPayment(double amount) — تحقّق + setOverride + عدّاد صريح
│       # - [NEW] getters: int sessionsCoveredBy(double), double debtRemainingAfter(double),
│       #   int scannedStudentDebtSessions (debt ÷ effectivePrice، floor)
│       # - scannedStudentDebt: بلا تغيير (مصدر موحّد)
├── views/
│   └── qr_scanner/
│       └── qr_scanner_payment_page.dart # [M]
│           # - سطر "المديونية المتراكمة" يظهر للـper-session أيضًا (رفع شرط !isPerSessionGroup)
│           #   + "= N حصة" للـper-session
│           # - [NEW] حقل مبلغ حرّ (per-session): TextField رقمي + معاينة
│           #   "يغطي X حصة" و"المتبقي بعد الدفع: Y" + زر تطبيق → applyDebtAmountPayment
│           # - "دفع كل المستحق": النص/المبلغ يعكسان unpaid الكلي (تلقائي عبر getters)

test/
└── qr_payment_debt_test.dart           # [NEW] وحدات المنطق النقي (انظر Testing)
```

**Structure Decision**: Mobile single-project قائم. لا ملفات/مجلدات جديدة عدا ملف اختبار. كل التغيير حقن في `QRController` (توسيع نطاق الشهور + مسار المبلغ الحر) وواجهة `qr_scanner_payment_page.dart` (عرض + حقل إدخال). `PricingHelper` وكل مسار المزامنة/DB بلا لمس.

## Phase 0 — Research

انظر [research.md](research.md). أسئلة محسومة:
- **تصحيح نطاق per-session**: توسيع `selectedMonths` (join→now) مقابل getters "كل الشهور" منفصلة → **توسيع** (أقل تدخّلًا، يصحّح كل الـgetters تلقائيًا، الخاصية المقصودة في تعليق `_preparePayment` سطر 162-170 محفوظة).
- **عدّاد الحصص في `confirmPayment`**: `round(amount/price)` الحالي مقابل عدّاد صريح → **`Rxn<int>` صريح** يُضبط من كل مسارات الدفع بالحصة (quick-pay + debt-amount) لتفادي تقدير خاطئ عند مبلغ لا يقبل القسمة.
- **`floor` مقابل `round`** لتحويل المبلغ ← حصص → **`floor`** ("يغطي X حصة كاملة").
- **سقف `_buildUpcomingMonths`** (12) → رفعه/إلغاؤه للـper-session (طالب متأخر > سنة).
- **المبلغ الحر للمجموعات الشهرية** → **خارج v1** (يبقى اختيار شهور كاملة)؛ يُعرض رقم المديونية فقط.
- **منع الزيادة عن المديونية** → **يُمنع في v1**؛ لا رصيد مقدّم من هذه الشاشة.
- **سعر الحصة = 0 / مديونية سالبة** → عرض بالجنيه بلا تحويل حصص، حقل المبلغ الحر معطّل.
- **مصدر رقم المديونية** → `scannedStudentDebt` القائم (بلا تغيير) — مضمون التطابق مع كارت الطالب.

## Phase 1 — Design & Contracts

- [data-model.md](data-model.md) — الكيانات المحسوبة (المديونية المتراكمة، الحصة غير المدفوعة، عدّاد `sessions=X`)، مصادرها، ولا سكيمة/ترقية.
- [contracts/](contracts/) — ٣ عقود:
  - `qr-controller-per-session-scope.md` — سلوك `_preparePayment` الجديد + الـgetters المتأثرة + جدول before/after.
  - `debt-display.md` — عقد عرض سطر المديериة + "= N حصة" (per-session + شهري، حالات صفر/سالب/سعر 0).
  - `debt-amount-payment.md` — توقيع `applyDebtAmountPayment` + getters المعاينة + قواعد التحقّق + شكل `note` + التفاعل مع `_explicitSessionsForPayment`.
- [quickstart.md](quickstart.md) — سيناريوهات تحقّق يدوي (طالب شهرين متأخر، دفع كل المستحق، مبلغ جزئي، تطابق مع كارت الطالب، سجل "دفعوا اليوم"، مزامنة بجهازين).

## Complexity Tracking

لا انتهاكات.
