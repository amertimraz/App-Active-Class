# Data Model: حالة حضور "متأخر"

**Feature**: 011-late-attendance | **Date**: 2026-09-01

## 1. جدول `attendance` (تعديل قيد فقط — لا أعمدة جديدة)

| العمود | النوع | ملاحظة |
|--------|------|--------|
| `id` | INTEGER PK | كما هو |
| `student_id` | INTEGER FK | كما هو |
| `day` / `date` | TEXT | كما هو |
| `status` | TEXT | **يتغيّر القيد**: `CHECK(status IN ('حاضر','غائب','متأخر'))` |

- فهرس فريد `(student_id, day)` — كما هو (`_attendanceDayUniqueIndexSql`).
- **القيم المسموحة**: `'حاضر'` (ATTENDANCE_PRESENT) · `'غائب'` (ATTENDANCE_ABSENT) · `'متأخر'` (ATTENDANCE_LATE، جديد) · غياب السجل = "غير مسجّل".

### دلالات القيم

| القيمة | نسبة الحضور | فوترة بالحصة | تبويب "غياب اليوم" | أزرار الواجب |
|--------|-------------|-------------|-------------------|--------------|
| حاضر | تُحتسب حضور | حصة كاملة | لا يظهر | تظهر |
| **متأخر** | **تُحتسب حضور** | **حصة كاملة** | **قسم "متأخرين" منفصل** | **تظهر** |
| غائب | لا | لا | قائمة الغياب | تختفي (spec 010) |
| غير مسجّل | لا | لا | لا يظهر | تظهر |

## 2. Migration: نسخة القاعدة 20 → 21

`DATABASE_VERSION`: `20` → `21` في `constants.dart`.

في `_onUpgrade` (داخل transaction الـsqflite أصلاً — **`db.execute` مباشرة، بلا `db.transaction`**):

```
if (oldVersion < 21) {
  try {
    CREATE TABLE attendance_new ( ...نفس الأعمدة... CHECK(status IN ('حاضر','غائب','متأخر')) );
    INSERT INTO attendance_new (...) SELECT ... FROM attendance;
    DROP TABLE attendance;
    ALTER TABLE attendance_new RENAME TO attendance;
    <إعادة إنشاء الفهرس الفريد _attendanceDayUniqueIndexSql>
  } catch (_) {}
}
```

- `_onCreate` (سطر 121): تحديث الـCHECK للقيمة الموسّعة (للتثبيتات الجديدة).
- guard `< 21` يغطّي أي جهاز علق على نسخة وسيطة (نفس درس spec 010).
- البيانات التاريخية: كلها `'حاضر'`/`'غائب'` → تعدّي القيد الجديد بلا تعديل، لا فقدان.

## 3. إعدادان جديدان

في `app_settings` (مفتاح/قيمة نصّية، نفس نمط `payment_grace_days`):

| المفتاح | النوع المنطقي | افتراضي | حدود | الاستخدام |
|---------|--------------|---------|------|-----------|
| `late_grace_minutes` | int (كنص) | `15` | `clamp(0, 120)` | حساب "متأخر" وقت مسح QR |
| `qr_auto_late_enabled` | bool (`'1'`/`'0'`) | `true` | — | لو `false` → مسح QR يسجّل "حاضر" دائمًا (السلوك القديم) |

في `SettingsController`:
- `_keyLateGraceMinutes = 'late_grace_minutes'` · `final RxInt lateGraceMinutes = 15.obs`
  - `_loadLateGraceMinutes()` → `_migrateInt(_keyLateGraceMinutes) ?? 15` (يُضاف لـ`Future.wait` في `loadSettings`)
  - `setLateGraceMinutes(int m)` → `clamp(0,120)` + `_dbSet`
- `_keyQrAutoLateEnabled = 'qr_auto_late_enabled'` · `final RxBool qrAutoLateEnabled = true.obs`
  - `_loadQrAutoLate()` → القيمة المخزّنة أو `true` لو غياب المفتاح
  - `setQrAutoLateEnabled(bool v)` + `_dbSet`

## 4. طبقة التطبيع/التسمية — `lib/models/attendance_model.dart` (جديد)

دوال نقية top-level (نفس نمط `homework_model.dart` من spec 010):

| الدالة | التوقيع | السلوك |
|--------|---------|--------|
| `normalizeAttendanceStatus` | `String? Function(String? raw)` | trim؛ فارغ/null → null؛ يطابق حاضر/غائب/متأخر (+ أي مرادفات) → القيمة القياسية؛ غير كده → null |
| `attendanceCountsAsPresent` | `bool Function(String? s)` | `normalize(s) == ATTENDANCE_PRESENT \|\| normalize(s) == ATTENDANCE_LATE` |
| `attendanceStatusLabel` | `String Function(String? raw)` | `'✅ حاضر'` / `'⏰ متأخر'` / `'❌ غائب'` / `'لم يُسجَّل'` |
| `attendanceStatusColor` | `Color Function(String? raw)` | أخضر `0xFF10B981` / كهرماني `0xFFF59E0B` / أحمر `0xFFEF4444` / رمادي |

## 5. منطق حساب "متأخر" عبر QR (في `qr_controller`)

عند تسجيل حضور طالب عبر مسح:

```
var status = ATTENDANCE_PRESENT;
if (settings.qrAutoLateEnabled.value) {
  // وقت البداية من جدول المجموعة لليوم الحالي — نفس تحليل remainingSessionTime (سطر ~582)
  final startText = attendanceCtrl.sessionTimeForGroupOnDay(group, now);   // "14:00" أو "14:00-16:00" أو null
  final startTod  = _parseStart(startText);                                // TimeOfDay?
  if (startTod != null) {
    final start = DateTime(now.year, now.month, now.day, startTod.hour, startTod.minute);
    final threshold = start.add(Duration(minutes: settings.lateGraceMinutes.value));
    if (now.isAfter(threshold)) status = ATTENDANCE_LATE;
  }
}
attendanceCtrl.setAttendanceStatus(studentId, now, status);
```

- منطق تحليل وقت البداية موجود أصلاً جوّه `remainingSessionTime` (`attendance_controller.dart:582`)؛
  يُستخرج helper مشترك أو يُعاد استخدامه.
- QR بيشيك أصلاً `groupHasSessionOnDay` قبل التسجيل (`qr_controller.dart:90`) — لو مفيش حصة اليوم
  المسح بيترفض، فحالة "مفيش جدول" بتوصل بس للمجموعات اللي ملهاش schedule نصّي.
- `markGroupAllPresent` / "تحضير الكل": يسجّل `ATTENDANCE_PRESENT` للطلاب غير المسجّلين/الغايبين،
  و**يتخطّى** الطلاب المسجّلين `ATTENDANCE_LATE` (ما يكتبش فوقهم) — FR-004.
  شرط "الكل حاضر بالفعل → امسح" (سطر 262) يفضل مربوط بـ`== ATTENDANCE_PRESENT` فقط (وجود متأخر
  يمنع مسح-التبديل، وده مقبول — المدرس يمسح المتأخر يدويًا).

## 6. التزامات المزامنة / البوابة

- قيمة `'متأخر'` تُزامَن زي أي قيمة حالة (نفس مسار جدول الحضور — لا تغيير في آلية المزامنة).
- `parent_portal_service`: يُضاف عدّاد `attendanceLate` + `attendanceHistory[].status` يمرّ عبر
  `normalizeAttendanceStatus` + `statusLabel` من `attendanceStatusLabel`.
- `booking_site/track/index.html`: عدّاد + label ثالث (`attLabel()`/`attClass()` JS helpers) — **نشر VPS يدوي**.
