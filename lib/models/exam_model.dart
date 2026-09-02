// lib/models/exam_model.dart

class Exam {
  final int? id;
  final String name;
  final DateTime date;
  final double maxGrade;
  final double passingGrade;
  /// spec 013 — الشهر اللي يُحسب له الامتحان في التقارير الشهرية،
  /// نص "YYYY-M" (مثلاً "2026-8"). null → بديله شهر [date].
  final String? reportMonth;
  final DateTime? createdAt;

  // بيانات إضافية محسوبة (مش محفوظة في DB)
  final List<int> groupIds;   // المجموعات المرتبطة بالامتحان

  const Exam({
    this.id,
    required this.name,
    required this.date,
    this.maxGrade = 100,
    this.passingGrade = 50,
    this.reportMonth,
    this.createdAt,
    this.groupIds = const [],
  });

  /// الشهر الفعلي للفلترة الشهرية — reportMonth لو موجود وصالح، وإلا شهر التاريخ.
  DateTime get effectiveReportMonth {
    final rm = reportMonth;
    if (rm != null) {
      final p = rm.split('-');
      if (p.length == 2) {
        final y = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        if (y != null && m != null && m >= 1 && m <= 12) {
          return DateTime(y, m, 1);
        }
      }
    }
    return DateTime(date.year, date.month, 1);
  }

  Map<String, dynamic> toMap() => {
    'id':            id,
    'name':          name,
    'date':          date.toIso8601String(),
    'max_grade':     maxGrade,
    'passing_grade': passingGrade,
    'report_month':  reportMonth,
    'created_at':    createdAt?.toIso8601String(),
  };

  factory Exam.fromMap(Map<String, dynamic> m) => Exam(
    id:           m['id'] as int?,
    name:         m['name'] as String,
    date:         DateTime.parse(m['date'] as String),
    maxGrade:     (m['max_grade'] as num).toDouble(),
    passingGrade: (m['passing_grade'] as num).toDouble(),
    reportMonth:  m['report_month'] as String?,
    createdAt:    m['created_at'] != null
        ? DateTime.parse(m['created_at'] as String)
        : null,
  );

  static const Object _unset = Object();

  Exam copyWith({
    int? id,
    String? name,
    DateTime? date,
    double? maxGrade,
    double? passingGrade,
    // sentinel عشان نفرّق بين "مش متغيّر" و"صفّره لـnull" (يتبع التاريخ)
    Object? reportMonth = _unset,
    List<int>? groupIds,
  }) => Exam(
    id:           id           ?? this.id,
    name:         name         ?? this.name,
    date:         date         ?? this.date,
    maxGrade:     maxGrade     ?? this.maxGrade,
    passingGrade: passingGrade ?? this.passingGrade,
    reportMonth:  identical(reportMonth, _unset)
        ? this.reportMonth
        : reportMonth as String?,
    createdAt:    createdAt,
    groupIds:     groupIds     ?? this.groupIds,
  );
}
