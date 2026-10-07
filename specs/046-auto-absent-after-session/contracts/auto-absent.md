# Contract: دوال صرفة — `lib/utils/auto_absent.dart`

```dart
const String kAutoAbsentNote = 'غياب تلقائي';
const int kAutoAbsentLookbackDays = 3;
const int kAutoAbsentMaxGrace = 180;

/// "HH:mm - HH:mm" → نهاية الحصة كاملة بتاريخ [day]؛ null لو غير صالحة/بلا نهاية.
/// نهاية ≤ بداية → +1 يوم.
DateTime? sessionEndFor(DateTime day, String? sessionTime);

/// هل الحصة "مقفولة" للغياب: now >= end + grace.
bool isSessionClosed({required DateTime end, required DateTime now, required int graceMinutes});

/// الأيام المرشّحة للفحص: من (now - 3 أيام) لحد now (بالتاريخ فقط)، الأقدم أولًا.
List<DateTime> lookbackDays(DateTime now);

/// الحصة مؤهَّلة للمعالجة: مقفولة + closeTime > enabledAt + مفتاحها ('gid|yyyy-MM-dd') مش في processed.
bool sessionEligible({required DateTime end, required DateTime now, required int graceMinutes,
  required DateTime enabledAt, required String key, required Set<String> processed});

/// طلاب يتسجّل لهم غياب: نشطين، في المجموعة، attendanceStart ≤ اليوم، بلا سجل في [existingIds].
List<Student> studentsToMarkAbsent({required List<Student> groupStudents, required DateTime day, required Set<int> studentIdsWithRecord});

/// الغياب تلقائي؟ (غائب + الملاحظة)
bool isAutoAbsent(Attendance a);

/// يقلّم processed للنافذة.
Set<String> pruneProcessed(Set<String> keys, DateTime now);
```

# Contract: `AutoAbsentService`
- `Future<int> runOnce({DateTime? now})` → عدد السجلات المضافة؛ idempotent، بيرجع 0 بصمت لو الإعداد مطفي أو الـcontrollers غير مسجّلة، وبيحمي نفسه من التشغيل المتزامن (`_running`).
- `start()` (Timer كل دقيقة) / `stop()`؛ ويُستدعى `runOnce` عند resumed.
