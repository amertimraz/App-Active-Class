# Phase 0 — Research: تحصيل المديونية المتراكمة من شاشة الدفع بماسح QR

## R1 — تصحيح نطاق حساب الحصص للـper-session

**القرار**: توسيع `selectedMonths` في `_preparePayment` ليشمل من شهر انضمام الطالب (`student.attendanceStart ?? student.createdAt`) حتى الشهر الحالي، بدل `start = nowMonth` الحالي.

**السبب**:
- كل الـgetters المعنية (`selectedSessionsCount`, `_paidSessionsInSelectedMonths`, `unpaidSessionsCount`, `unpaidSessionDates`, `fullyPaidUp`, `effectiveSessionsSelected`, `_recalculateTotal` للـper-session) مبنية على `selectedMonths`. توسيعه يصحّحها كلها دفعة واحدة بلا تكرار منطق.
- الواجهة **لا تعرض month chips للمسار per-session** (`qr_scanner_payment_page.dart` سطر ~1114: `isPerSessionGroup ? <بلا chips> : <chips>`) — فتوسيع القائمة صفر أثر بصري.
- الخاصية المقصودة في تعليق `_preparePayment` (سطور 162-170: حصة سادسة تُحضَر في نفس شهر دفعة سابقة تظل مستحقة) **محفوظة** — الشهر الحالي ضمن النطاق الموسّع.
- `_paidSessionsInSelectedMonths` يطابق `p.date` بشهور `selectedMonths`؛ مع النطاق الموسّع (join→now) كل دفعات عضوية الطالب داخل النطاق → تُحتسب كلها.

**البدائل المرفوضة**:
- getters جديدة "كل الشهور" (`totalUnpaidSessionsCount`, `allUnpaidSessionDates`) تتجاهل `selectedMonths`: تضاعف المنطق، تترك الـgetters القديمة كفخّ، وتحتاج تعديل الواجهة لتبديل المصدر.
- حساب من `PricingHelper.accumulatedDebt ÷ price` مباشرة: يفقد قائمة التواريخ (`unpaidSessionDates`) التي يحتاجها المدرس، ويكسر منطق `sessions=N` FIFO.

**نقطة انتباه**: `_buildUpcomingMonths` يحدّ القائمة بـ12 شهرًا — طالب متأخر > سنة سيفقد أقدم الشهور. يُرفع السقف (أو يُلغى) في المسار per-session فقط.

## R2 — عدّاد الحصص المسجَّل في `note` عند `confirmPayment`

**القرار**: إدخال `Rxn<int> _explicitSessionsForPayment` يُضبط من **كل** مسار دفع بالحصة (`payAllUnpaidSessions` و`applyDebtAmountPayment` الجديد)، ويُصفَّر في `setOverride` العام و`_clearPaymentState`. `confirmPayment` يستخدمه مباشرة عندما `!= null` بدل تقدير `round(overrideAmount / effectivePrice)`.

**السبب**: مبلغ حرّ لا يقبل القسمة (45 ج، سعر 20) → `round(2.25) = 2` صحيح صدفة، لكن (30 ج، سعر 20) → `round(1.5) = 2` بينما "يغطي حصة واحدة كاملة" هو المقصود (`floor`). العدّاد الصريح يزيل الغموض ويطابق تمامًا ما عُرض للمدرس في المعاينة.

**البدائل المرفوضة**: الاعتماد على `_sessionsCoveredByQuickPay` الحالي — اسمه وتعليقه مقيّدان بـ"quick pay"، و`setOverride` يصفّره عمدًا؛ توسيع دلالته يربك. الأنظف اسم/حقل جديد صريح يشمل المسارين.

## R3 — `floor` مقابل `round` لتحويل المبلغ ← عدد حصص

**القرار**: `floor(amount / effectivePrice)` في كل من المعاينة (`sessionsCoveredBy`) والعدّاد المسجَّل.

**السبب**: مطلب المستخدم الحرفي: "هذا المبلغ يغطّي X حصة" — حصص **كاملة** مغطّاة. 39 ج بسعر 20 = حصة واحدة مغطّاة + 19 ج تحت حساب الثانية. المبلغ الفعلي المسجَّل يبقى 39 (لا يُقرَّب)، فقط عدّاد الحصص يُبتر لأسفل.

## R4 — عرض رقم المديونية (US1)

**القرار**: إعادة استخدام `QRController.scannedStudentDebt` كما هو (يستدعي `PricingHelper.accumulatedDebt` بنفس `siblingGroupMembers` = `_allStudents`). رفع شرط الإخفاء `!controller.isPerSessionGroup` في `qr_scanner_payment_page.dart` (سطر ~1054) ليظهر للمسارين. إضافة سطر "= N حصة" (`scannedStudentDebtSessions`) للـper-session فقط.

**السبب**: `_scannedAttendance` مُحمَّل بالكامل للـper-session في `_preparePayment` (سطر 153-156)، فـ`accumulatedDebt` دقيق أصلًا. المشكلة عرضية بحتة (الشرط يخفيه)، لا حسابية.

**التطابق مع كارت الطالب**: كارت تفاصيل الطالب يستدعي نفس `PricingHelper.accumulatedDebt` بنفس المدخلات → تطابق مضمون بلا اختبار تكامل معقّد (اختبار وحدة على `PricingHelper` يكفي).

## R5 — المبلغ الحرّ للمجموعات الشهرية

**القرار**: **خارج v1**. المجموعات الشهرية: يُعرض رقم المديونية المتراكمة الصريح فقط (موجود جزئيًا كـ"متبقي عليه")؛ التحصيل يبقى عبر اختيار شهور كاملة (month chips) كما هو.

**السبب**: تخصيص مبلغ جزئي على "نصف شهر" شهري يفتح أسئلة (أي شهر؟ كيف يظهر في `months=` بالملاحظة؟ تفاعل مع `prorateFirstMonth`) خارج نطاق شكوى المدرس (التي كانت per-session). FR-017 يسمح صراحة بتأجيله.

## R6 — منع الدفع الزائد عن المديونية

**القرار**: يُمنع في v1 — `applyDebtAmountPayment` يرفض `amount > scannedStudentDebt + 0.01`، والواجهة تعطّل زر التطبيق وتُظهر رسالة.

**السبب**: الرصيد المقدّم له مساراته القائمة (شاشة تسجيل الدفع العادية بمبلغ يدوي). إضافته هنا تعقّد المعاينة ("يغطي X حصة" + "رصيد مقدّم Y") بلا طلب صريح. المستخدم رجّح المنع: "الأفضل منع الزيادة في v1".

## R7 — الحالات الحديّة للتحويل لعدد حصص

**القرار**:
- `effectivePrice <= 0` (إعفاء 100% أو سعر غير محدد): عرض المديونية بالجنيه بلا سطر "= N حصة"؛ حقل المبلغ الحر معطّل.
- `scannedStudentDebt <= 0.01`: حالة "سديد الحساب"؛ حقل المبلغ الحر وزر "دفع كل المستحق" معطّلان.
- مديونية سالبة (رصيد لصالح الطالب): `accumulatedDebt` تُرجع 0 (مبنية على `_remainingThrough` التي تقصّ عند 0) — تُعامَل كـ"سديد الحساب".

**السبب**: `PricingHelper._remainingThrough` سطر: `return remaining > 0 ? remaining : 0;` — لا مديونية سالبة تصل للواجهة أصلًا. الحماية من القسمة على صفر شرط واجب.

## R8 — الاختبارات

**القرار**: ملف `test/qr_payment_debt_test.dart` لوحدات المنطق النقي:
- `PricingHelper.accumulatedDebt` لطالب per-session عبر شهرين (6 أغسطس + 1 سبتمبر، سعر 20، بلا دفعات → 140؛ بدفعة 60 → 80).
- دالة تحويل نقية `debtToSessions(debt, price)` = `price > 0 ? (debt / price).floor() : 0` (140/20=7, 45/20=2, سعر 0 → 0).
- `debtRemainingAfter` / منطق التحقّق (amount ≤ debt، amount > 0).
منطق `unpaidSessionsCount` عبر شهرين يُغطّى بـquickstart يدويًا (يحتاج `QRController` مع GetX + DB — تكلفة تهيئة عالية مقابل عائد اختبار وحدة).

**السبب**: المشروع بلا اختبارات QR/pricing حالية؛ إضافة وحدات نقية منخفضة التكلفة عالية القيمة (تثبّت مثال المستخدم الحرفي 140 ج = 7 حصص).
