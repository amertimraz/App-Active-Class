# Data Model: الحضور بالحصة

> لا جداول/أعمدة جديدة ولا تغيير في المزامنة. الكيانات التالية **في الذاكرة فقط** (مشتقة).

## SessionRef
| الحقل | النوع | ملاحظات |
|---|---|---|
| group | `Group` | المجموعة |
| day | `DateTime` (منتصف الليل محلي) | تاريخ الحصة |
| timeLabel | `String?` | "HH:mm - HH:mm" من `sessionTimeForGroupOnDay` |
| overrideType | `SessionOverrideType?` | cancelled / makeup / extra / null |

- `isCancelled = overrideType == cancelled` → لا ملخص ولا تسجيل.
- `isFuture = day > اليوم` → بدل الملخص رسالة "لسه ما بدأتش"، والشاشة للقراءة فقط (بدون تسجيل).

## SessionRow (عنصر roster)
| الحقل | النوع |
|---|---|
| student | `Student` |
| status | `String?` — قيمة موحّدة `ATTENDANCE_PRESENT/LATE/ABSENT` أو `null` = لم يُسجَّل |
| record | `Attendance?` (للقراءة، التعديل عبر الـcontroller) |

## SessionSummary
| الحقل | النوع |
|---|---|
| present | `int` |
| late | `int` |
| absent | `int` |
| unrecorded | `int` |
| total | `int` = مجموع الأربعة |

قاعدة: `present + late + absent + unrecorded == total`، و`attended = present + late` (المتأخر يُحتسب حضورًا زي بقية التطبيق).

## SessionFilter
`all | present | late | absent | unrecorded`

## قواعد الاشتقاق (دوال صرفة في `lib/utils/session_attendance.dart`)
- `buildSessionRows({students, records, day})`:
  - يستبعد `isArchived` إلا لو للطالب سجل في `day`.
  - يستبعد من `attendanceStart != null && attendanceStart > day`.
  - يربط كل طالب بسجل يومه (أول سجل في اليوم، الفهرس الفريد يضمن واحد).
  - `status = normalizeAttendanceStatus(record.status)` أو `null`.
  - ترتيب: الاسم تصاعديًا.
- `summarize(rows)` → `SessionSummary`.
- `filterRows(rows, filter, query)` → بحث بالاسم/الكود (غير حساس لحالة الأحرف، تطبيع عربي موجود في `arabic_normalize.dart`).

## جدول الحصص (schedule_week.dart)
- `weekStartSaturday(DateTime anchor)` → سبت الأسبوع الذي يحتوي `anchor`.
- `dateForDayIndex(DateTime anchor, int weekOffset, int dayIndex)` → `weekStart + weekOffset*7 + dayIndex` (السبت=0).
- `dayIndexOf(DateTime d)` و`weekOffsetFor(DateTime anchor, DateTime target)` للقفز لتاريخ مختار.

## رسالة الغياب (absence_message.dart)
`buildAbsenceMessage({name, code, groupName, date, teacherName, teacherSpecialization})` و`buildLateMessage` — نفس النص الحالي حرفيًا مع `date` معامل (بدل `DateTime.now()`).
