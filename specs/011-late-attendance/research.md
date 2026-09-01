# Research: حالة حضور "متأخر"

**Feature**: 011-late-attendance | **Date**: 2026-09-01

## جرد الوضع الحالي

### الثوابت — `lib/config/constants.dart`
- `ATTENDANCE_PRESENT = 'حاضر'` · `ATTENDANCE_ABSENT = 'غائب'` (سطر 158-159)

### القاعدة — `lib/services/database_service.dart`
- `_onCreate` سطر 121: `CHECK($COL_ATTENDANCE_STATUS IN ('حاضر', 'غائب'))` — **مصدر وحيد** (مفيش CREATE تاني في migration، عكس الواجب).
- `DATABASE_VERSION = 20` حاليًا (بعد spec 010).
- `_attendanceDayUniqueIndexSql` فهرس فريد (student, day).

### الكنترولر — `lib/controllers/attendance_controller.dart`
- `toggleAttendance(id, day)` (187) — دوّار: غير مسجّل→حاضر→غائب→حذف.
- **`setAttendanceStatus(id, day, String status)` (220)** — موجود بالفعل! upsert بحالة محددة، بيرمي الخطأ للمتصل. **مفيش دعم status=null (حذف)** — محتاج يتضاف.
- `markGroupAllPresent(ids, day)` (251) — بيسجّل `ATTENDANCE_PRESENT` أو يلغي لو الكل حاضر.

### نقاط `== ATTENDANCE_PRESENT` / `== ATTENDANCE_ABSENT` (~66 موضع، 13 ملف)
| ملف | الطبيعة |
|-----|---------|
| `attendance_page.dart` (19) | تسجيل + ملخّص المجموعة + تبويب "غياب اليوم" + تقرير الحصة + `_StudentAttendanceChip` |
| `attendance_controller.dart` | `toggleAttendance`, `markGroupAllPresent`, `getStudentMonthAttendance`, `buildGuardianReportMessage`, `isAttendanceCompleteForGroupToday` |
| `pricing_helper.dart` | `sessionsAttended` — بيعدّ `a.status == ATTENDANCE_PRESENT` للفوترة بالحصة |
| `dashboard_controller.dart` | إحصائيات لوحة التحكم |
| `report_controller.dart` (غير ظاهر في grep الأولي لكن بيستخدم presentByStudent) | تجميعات التقرير الشهري + PDF |
| `parent_portal_service.dart` | `present`/`absent` counts + `attendanceHistory[].status` |
| `export_service.dart` | تقرير حضور PDF (خانات اليوم + عدّادات) |
| `student_details_page.dart` | تبويب الحضور في تفاصيل الطالب + التقرير الشهري |
| `settings_page.dart` | التقرير الشهري |
| `qr_scanner_attendance_page.dart` + `qr_controller.dart` | مسح QR (بيسجّل `ATTENDANCE_PRESENT`) |
| `group_details_page.dart` | نسبة الحضور في بطاقات المجموعات |
| `student_sort_helper.dart` | فرز الطلاب بنسبة الحضور |

### الواجهة العامة — `booking_site/track/index.html`
- بيعرض `present`/`absent` counts + `attendanceHistory[].status` (زي الواجب).

## القرارات

### قرار 1: ثابت + طبقة تطبيع/تسمية مشتركة (مصدر حقيقة واحد)

- `ATTENDANCE_LATE = 'متأخر'` في `constants.dart`.
- في `lib/models/attendance_model.dart` (أو helpers): دوال نقية:
  - `bool attendanceCountsAsPresent(String? s)` → `s == ATTENDANCE_PRESENT || s == ATTENDANCE_LATE`
  - `String? normalizeAttendanceStatus(String? raw)` → حاضر/غائب/متأخر/null
  - `String attendanceStatusLabel(String? raw)` → `'✅ حاضر'` / `'⏰ متأخر'` / `'❌ غائب'` / `'لم يُسجَّل'`
  - `Color attendanceStatusColor(...)` (للـUI/PDF) — أخضر/كهرماني/أحمر

  نفس نمط `homework_model.dart` من spec 010.

**السبب**: الواجب في spec 010 عمل نفس الشيء ونجح؛ helper واحد يمنع نسيان موضع.

### قرار 2: التعامل مع الـ66 موضع

- **`== ATTENDANCE_PRESENT` اللي معناها "حضر"** (نسبة الحضور، عدّ الحاضرين، `sessionsAttended`،
  اكتمال التسجيل) → تتحوّل لـ`attendanceCountsAsPresent(status)`.
- **`== ATTENDANCE_ABSENT`** → تفضل زي ما هي غالبًا (متأخر ≠ غائب). تبويب "غياب اليوم" وتقرير
  الغياب: يفضلوا يفلتروا `== ATTENDANCE_ABSENT` (فالمتأخر يخرج تلقائيًا من قائمة الغياب).
- **أماكن محتاجة عدّاد "متأخر" منفصل**: ملخّص موديل المجموعة، تبويب الإحصائيات، الداشبورد،
  التقرير الشهري (عدّاد + سطور)، تقرير PDF (خانة + عدّاد)، البوابة (count + history label)،
  تبويب "غياب اليوم" (قسم "متأخرين").

**البديل المرفوض**: إبقاء "متأخر" كـalias لـ"حاضر" في التخزين — بيضيّع المعلومة، ومينفعش يظهر مميّز.

### قرار 3: تسجيل الحضور — segmented ثلاثي بدل التبديل الدوّار

- `_StudentAttendanceChip` (في `attendance_page.dart`) يتحوّل لعرض 3 أزرار مجزّأة متصلة
  (حاضر أخضر / متأخر كهرماني / غائب أحمر) — نفس نمط `_HomeworkStatusSegmented` من spec 010
  (يمكن تعميم الودجت أو توأمة).
- `onSelect(status)` → `controller.setAttendanceStatus(id, day, status)`؛ `onSelect(null)` (لمس
  المختار) → حذف السجل.
- `setAttendanceStatus` يتوسّع ليقبل `String?` (null = حذف، زي `setHomeworkStatus`).
- التبديل الدوّار (`toggleAttendance`) يفضل موجود لو مستخدم في أماكن تانية (تبويب "السجل"?) —
  يُتحقق ويُترك أو يُشال.
- `markGroupAllPresent`: يسجّل "حاضر" للغايبين/غير المسجّلين، **يتخطّى** المسجّلين "متأخر" (قرار 7).
- مسح QR: **يحسب "متأخر" تلقائيًا** لو المفتاح مفعّل — انظر قرار 7.

### قرار 4: migration نسخة القاعدة 20 → 21

- إعادة بناء جدول `attendance` بنفس الأعمدة + `CHECK IN ('حاضر','غائب','متأخر')`.
- نفس نمط migration الواجب (v19/v20) — **`db.execute` مباشرة، بلا `db.transaction` متداخلة**
  (onUpgrade أصلاً جوه transaction — الغلط ده حصل في spec 010 واتصلح).
- `_onCreate` (سطر 121) يتحدّث للـCHECK الموسّع كمان (للتثبيتات الجديدة).

### قرار 5: تبويب "غياب اليوم" — قسم "متأخرين" منفصل

- التبويب (`_AbsentTodayTab` أو ما يعادله في `attendance_page.dart`) يعرض:
  قائمة الغايبين (زي دلوقتي) + تحتها `Divider` + قسم "متأخرين" (لو فيه) بنفس نمط الصفوف.
- القسم يختفي/يهدأ لو مفيش متأخرين.

### قرار 6: الربط مع الواجب (spec 010)

- تبويب الواجب (`_HomeworkTabBody`) بيستثني `statusMap[id] == ATTENDANCE_ABSENT` من عرض الأزرار.
  "متأخر" **مش** غياب → أزرار الواجب تظهر للطالب المتأخر عادي. **مفيش تغيير مطلوب** —
  الشرط `== ATTENDANCE_ABSENT` صح كما هو.
- `clearHomework` عند تسجيل الغياب: يفضل يتنفّذ عند `ATTENDANCE_ABSENT` فقط (مش "متأخر").
  الكود الحالي `if (ns == ATTENDANCE_ABSENT)` — صح كما هو.

### قرار 7: مسح QR → "متأخر" تلقائيًا + مهلة قابلة للضبط + مفتاح تشغيل (قرار المستخدم)

- إعدادان جديدان في `SettingsController` + `app_settings` (نفس نمط `payment_grace_days`):
  - `late_grace_minutes` (افتراضي 15) — حقل رقمي "مهلة التأخير (دقائق)".
  - `qr_auto_late_enabled` (افتراضي `true`) — مفتاح "تسجيل المتأخر تلقائيًا عبر QR". لو مُوقَف →
    QR يسجّل "حاضر" دائمًا (السلوك القديم). بيدّي المدرس تحكم كامل لو الكشف بالوقت مش مناسب لطريقته.
- عند مسح QR لطالب:
  1. لو مجموعته ليها حصة مجدولة اليوم (`AttendanceController.sessionTimeForGroupOnDay`
     أو ما يعادله يرجّع وقت البداية) →
     احسب `lateThreshold = classStart + late_grace_minutes`.
     - `DateTime.now().isAfter(lateThreshold)` → سجّل `ATTENDANCE_LATE`.
     - غير كده → `ATTENDANCE_PRESENT`.
  2. لو ملهاش جدول/حصة اليوم → `ATTENDANCE_PRESENT` (مفيش أساس للحساب).
- الحساب يتم في `qr_controller` وقت التسجيل (لو المفتاح مفعّل)؛ المدرس يعدّلها يدويًا بعدين.
- **caveat**: مسح كل الكشف مرة واحدة بعد المهلة = الكل "متأخر". التخفيف: المفتاح، أو المسح وقت الدخول.
- `markGroupAllPresent` / "تحضير الكل": يسجّل "حاضر" للغايبين/غير المسجّلين، **يتخطّى** المسجّلين "متأخر".

**السبب**: المستخدم طلب "أوتوماتيك + المهلة قابلة للضبط من الإعدادات". المهلة إعداد
عشان المدرسين يختلفوا في تعريف التأخير.

**البديل المرفوض**: QR = "حاضر" دايمًا مع تعديل يدوي — المستخدم رفضه صراحةً.

## المخاطر

- **سطح تغيير كبير (~66 موضع)**: التخفيف — helper واحد + `rg` منهجي + مهمة تحقّق تعدّ كل موضع.
- **`sessionsAttended` في `pricing_helper`**: لو اتنسي، الطالب المتأخر في مجموعة بالحصة ميتحسبش
  عليه الحصة → مديونية غلط. **حرج** — لازم يتحوّل لـ`attendanceCountsAsPresent`.
- **البيانات التاريخية**: القيم القديمة حاضر/غائب — التطبيع بيرجّعها زي ما هي، مفيش فقدان.
- **الواجهة العامة على VPS**: محتاجة تحديث + نشر (زي spec 010 اللي لسه معلّق نشره).
- **migration**: نفس درس spec 010 — بلا `db.transaction`، وبعد ما نسخة القاعدة تتبمب لازم
  guard يغطّي الأجهزة اللي علقت (استخدام `< 21`).
