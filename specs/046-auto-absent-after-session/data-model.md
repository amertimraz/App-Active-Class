# Data Model: الغياب التلقائي

لا تغيير في schema ولا migration ولا مزامنة جديدة.

## إعدادات محلية (جدول settings الموجود، مفاتيح جديدة)
| المفتاح | النوع | الافتراضي | ملاحظة |
|---|---|---|---|
| `auto_absent_enabled` | bool ('1'/'0') | 0 | المفتاح |
| `auto_absent_grace_minutes` | int | 15 | 0..180 |
| `auto_absent_enabled_at` | ISO datetime | — | يُكتب عند التفعيل (لا أثر رجعي قبله) |
| `auto_absent_processed` | نص، عناصر `groupId|yyyy-MM-dd` مفصولة بفاصلة | فاضي | تُقلَّم لنافذة 3 أيام |

## سجل الحضور (موجود)
غياب تلقائي = `Attendance(status: ATTENDANCE_ABSENT, notes: 'غياب تلقائي', date: يوم الحصة + ساعة الإغلاق)`. ثابت `kAutoAbsentNote`.

## قواعد
- تاريخ السجل = يوم الحصة (مش يوم الفحص)، فاليوم الصحيح في الفهرس الفريد.
- طلاب مؤهَّلون: `!isArchived`، `attendanceStart ?? createdAt` ≤ يوم الحصة (يوم كامل)، groupId = المجموعة، بلا أي سجل حضور في اليوم.
