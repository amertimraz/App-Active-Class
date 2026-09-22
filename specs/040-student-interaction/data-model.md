# Phase 1 Data Model: تفاعل الطالب في حضور اليوم

## `Attendance` (تعديل — عمود جديد فقط)

| الحقل | النوع | ملاحظة |
|---|---|---|
| `id`, `studentId`, `date`, `status`, `notes`, `createdAt` | (موجودين) | بدون تغيير |
| `interaction` | `String?` (جديد) | واحدة من 3 قيم ثابتة بالضبط: `'نشيط'` / `'عادي'` / `'غير متفاعل'`، أو `null` (بدون تقييم). قيمة مخزَّنة كنص عربي مباشر، بنفس نمط `status` (راجع research.md #1). |

### الثوابت الجديدة (`lib/config/constants.dart`)

```dart
const String STUDENT_INTERACTION_ACTIVE = 'نشيط';
const String STUDENT_INTERACTION_NEUTRAL = 'عادي';
const String STUDENT_INTERACTION_DISENGAGED = 'غير متفاعل';
const String COL_ATTENDANCE_INTERACTION = 'interaction';
```

### دوال عرض جديدة (`lib/models/attendance_model.dart`، بنفس نمط `attendanceStatusLabel`/`attendanceStatusColor`)

```dart
String? normalizeInteraction(String? raw); // يطبّع لواحدة من الثلاث أو null
bool canRecordInteraction(String? attendanceStatus); // حاضر/متأخر فقط (راجع research.md #2)
String interactionEmoji(String? raw); // 😃 / 😐 / 😴 / '' لو null
String interactionLabel(String? raw); // "نشيط" / "عادي" / "غير متفاعل" / '' لو null
```

### قواعد الصلاحية (Validation)

- `interaction` لا يُقبَل إلا إذا كان `canRecordInteraction(status) == true` لنفس السجل وقت الكتابة — أي محاولة تسجيل تفاعل لسجل "غائب" تُرفَض على مستوى الـcontroller (دفاع إضافي، رغم إن الواجهة أصلاً مش هتعرض الخيار).
- تغيير `status` إلى `ATTENDANCE_ABSENT` أو حذف السجل بالكامل (status = null) يمسح `interaction` تلقائيًا كجزء من نفس العملية (FR-006) — يتم داخل `AttendanceController.setAttendanceStatus` (راجع research.md #2).

### لا كيانات جديدة أو جداول جديدة

التفاعل حقل إضافي على `Attendance` الموجود بالفعل — لا `StudentInteraction` أو أي كيان مستقل.

## تعديل بنية بيانات داخلية في `export_service.dart`

`attMap` في `exportAttendancePDF`/`_attendanceTable`/`_attendanceSummary` يتغيّر من `Map<int, Map<DateTime, String>>` (status فقط) إلى `Map<int, Map<DateTime, Attendance>>` (السجل الكامل) عشان يوصل لعمود `interaction` كمان (راجع research.md #4). **تصحيح تنفيذ**: خانة اليوم في جدول PDF بترسم نقطة ملوَّنة (7×7px) بدون نص — خط Cairo المحمَّل ومكتبة `pdf` لا يدعمان رسم إيموجي ملوّن، فالتمثيل الفعلي هو تغيير لون النقطة (بنفسجي/أزرق/رمادي) بدل رسم الإيموجي نفسه، مع مفتاح ألوان نصي أسفل الجدول.
