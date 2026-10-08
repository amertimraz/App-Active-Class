# Contract: `lib/utils/recitation.dart` (دوال صرفة)

```dart
const int kRecitationMin = 1;
const int kRecitationMax = 10;

/// 1..10 → نفسها، غير كده/null → null.
int? normalizeRecitation(int? raw);

/// حاضر/متأخر فقط.
bool canRecordRecitation(String? attendanceStatus);

/// متوسط الدرجات الصالحة لسجلات الحضور (اختياريًا لشهر معيّن)، مقرّب لعشري واحد؛ null لو لا درجات.
double? recitationAverage(Iterable<Attendance> records, {DateTime? month});

/// عدد الأيام ذات الدرجة.
int recitationCount(Iterable<Attendance> records, {DateTime? month});

/// "8.3" / "—".
String recitationAverageLabel(double? avg);
```

# Contract: `AttendanceController.setRecitation(int studentId, DateTime day, int? value)`
- يتجاهل بصمت لو: لا سجل لليوم، أو الحالة غير مؤهلة، أو value خارج 1..10 (إلا null = مسح).
- يحدّث السجل (`updateAttendance`) ويستبدل محليًا (`_replaceLocal`) بلا إعادة تحميل كاملة.
