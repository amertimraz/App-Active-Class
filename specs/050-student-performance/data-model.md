# Data Model: تقرير الأداء

لا جداول ولا أعمدة جديدة، ولا migration. كل شيء مشتق وقت العرض.

```dart
enum PerfKind { exams, attendance, homework, recitation }
enum PerfTrend { up, steady, down, none }

class PerfIndicator {
  final PerfKind kind;
  final double? current;      // % الشهر
  final double? previous;     // % الشهر السابق
  final int currentSamples;   // عدد الامتحانات/الأيام/المرات
  final double? delta;        // current - previous
  final PerfTrend trend;
  final String level;         // تقييم لفظي ('' لو لا بيانات)
  final List<double?> series; // آخر 6 شهور (الأقدم أولًا)
}

class StudentPerformance {
  final int studentId; final String name; final String groupName;
  final DateTime month;             // أول الشهر
  final List<DateTime> months;      // الـ6 شهور
  final List<PerfIndicator> indicators; // المفعّلة فقط
  final double? overall;            // للترتيب فقط
  final double? overallDelta;
  final PerfTrend overallTrend;
  bool get hasData;
}
```
- يعتمد على `Attendance`, `Homework`, `StudentExamRecord` الموجودة.
- حقل `performance` الاختياري في ملخص بوابة أولياء الأمور (Firestore) — انظر `contracts/performance.md`.
