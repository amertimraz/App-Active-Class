# Contract: `lib/utils/performance.dart` (دوال صرفة)

```dart
const double kTrendSteadyBand = 3.0;
const int kPerfMonths = 6;

DateTime monthStart(DateTime d);
List<DateTime> monthsBack(DateTime month, {int count = kPerfMonths}); // الأقدم أولًا، آخرها = month

double? examsPercent(Iterable<StudentExamRecord> r, DateTime month);
double? attendancePercent(Iterable<Attendance> a, DateTime month);
double? homeworkPercent(Iterable<Homework> h, DateTime month);
double? recitationPercent(Iterable<Attendance> a, DateTime month);
// + عدّادات العينات لكل مؤشر في الشهر

PerfTrend trendOf(double? cur, double? prev, {double band = kTrendSteadyBand});
String levelOf(double? pct); // ممتاز/جيد جدًا/جيد/مقبول/يحتاج دعمًا أو ''

StudentPerformance buildPerformance({
  required Student student, required String groupName, required DateTime month,
  required List<Attendance> attendance, required List<Homework> homework,
  required List<StudentExamRecord> exams,
  Set<PerfKind> enabled = const {...PerfKind.values},
});

/// ترتيب تنازلي بالمستوى العام؛ بلا بيانات في الآخر. onlyDeclining يفلتر المتراجعين.
List<StudentPerformance> rankPerformances(List<StudentPerformance> l,
    {bool onlyDeclining = false});

String performanceMessage(StudentPerformance p,
    {String teacherName = '', String teacherSpecialization = ''});
Map<String, dynamic>? performancePortalFields(StudentPerformance p); // null لو لا بيانات
String trendArrow(PerfTrend t); // ↑ ➖ ↓ ''
```

# Contract: خدمات/واجهات
- `PerformanceService.forStudent(studentId, month)` / `forGroup(groupId, month)` (جلب جماعي).
- `PerformanceCard` (ودجت الكارت، عرض ثابت 360)، `capturePerformanceCardPng(GlobalKey)`.
- `ExportService.exportStudentPerformancePDF(StudentPerformance)`.

# Contract: حقل بوابة الأهالي (Firestore، داخل مستند الطالب)
```json
"performance": {
  "month": "2026-10-01",
  "indicators": [{"kind":"exams","label":"الامتحانات","percent":70.0,"prev":60.0,"trend":"up","level":"جيد"}],
  "series": {"exams":[null,55.0,60.0,70.0,null,null]}
}
```
مفتاح `performance` يغيب لو لا بيانات أو المؤشرات كلها مخفية.
