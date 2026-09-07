# Data Model: تنبيه المتأخر في شاشة الحضور

لا كيانات قاعدة بيانات جديدة. DB version يبقى **28**. لا مزامنة. لا `toCloudMap`.

## 1. إعداد محلي: `attendanceOverdueWarning`

| الخاصية | القيمة |
|---|---|
| المكان | `SettingsController` (RxBool)، مخزَّن عبر `_dbSet` |
| المفتاح | `SETTING_ATTENDANCE_OVERDUE_WARNING` = `'attendance_overdue_warning'` في `constants.dart` |
| الافتراضي | `true` |
| التحميل | `await _migrateBool(SETTING_ATTENDANCE_OVERDUE_WARNING) ?? true` ضمن دالة تحميل إعدادات الحضور/المسح |
| الحفظ | `setAttendanceOverdueWarning(bool v)` → `.value = v; _dbSet(key, v ? '1' : '0')` |
| المزامنة | لا — محلي لكل جهاز |

## 2. قرار مشتقّ (غير مخزَّن): `showsAttendanceOverdueWarning`

دالة `PricingHelper` نقية. المدخلات كلها موجودة:

| المدخل | المصدر |
|---|---|
| `student` | `StudentController.students` |
| `group` | `GroupController.groups` بـ `student.groupId` |
| `allAttendance` | `AttendanceController.attendance` |
| `payments` | `PaymentController.payments` (كل الدفعات) — تُفلتَر لدفعات الطالب داخل الحساب القائم |
| `graceDays` | `SettingsController.paymentGraceDays` |
| `siblingGroupMembers` | `StudentController.students` (كامل — نفس نمط الاستدعاءات القائمة) |

**الإخراج**: `bool` (يظهر تنبيه / لا).

**قيمة العرض المرافقة**: `PricingHelper.accumulatedDebt(...)` بنفس المدخلات → رقم يُعرَض في الودجت (`.round()` جنيه).

## 3. مصفوفة القرار

| نوع الطالب | الشرط | النتيجة |
|---|---|---|
| معفى بالكامل (`isFullyExempt`) | — | لا تنبيه |
| مجموعة شهرية / بلا مجموعة | `isOverdue(graceDays)` == true و `accumulatedDebt > 0` | تنبيه |
| مجموعة شهرية / بلا مجموعة | ضمن مهلة السماح أو لا مديونية | لا تنبيه |
| مجموعة بالحصة | `accumulatedDebt − (حصص اليوم × effectivePrice) > 0.01` | تنبيه |
| مجموعة بالحصة | كل المديونية = حصص اليوم فقط (أو لا مديونية) | لا تنبيه |
| مجموعة بالحصة، `effectivePrice == 0` | `accumulatedDebt` = 0 | لا تنبيه |

## 4. حالة runtime في الشاشات

| الشيء | الوصف |
|---|---|
| `PaymentController` في `QRScannerAttendancePage` | يُكتسب في `initState`، `loadPayments()` في `postFrameCallback`. الـwidgets تقرأ عبر `Obx` |
| إعادة الحساب | يحدث تلقائيًا عند إعادة بناء الودجت (تغيّر `payments`/`attendance` عبر Rx، أو `setState` للمسح) — يحقّق FR-009 |
| بوابة العرض | `settings.attendanceOverdueWarning.value == true` — لو false الودجت يرجع `SizedBox.shrink()` والحساب لا يُنادى |
