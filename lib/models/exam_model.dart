// lib/models/exam_model.dart

class Exam {
  final int? id;
  final String name;
  final DateTime date;
  final double maxGrade;
  final double passingGrade;
  final DateTime? createdAt;

  // بيانات إضافية محسوبة (مش محفوظة في DB)
  final List<int> groupIds;   // المجموعات المرتبطة بالامتحان

  const Exam({
    this.id,
    required this.name,
    required this.date,
    this.maxGrade = 100,
    this.passingGrade = 50,
    this.createdAt,
    this.groupIds = const [],
  });

  Map<String, dynamic> toMap() => {
    'id':            id,
    'name':          name,
    'date':          date.toIso8601String(),
    'max_grade':     maxGrade,
    'passing_grade': passingGrade,
    'created_at':    createdAt?.toIso8601String(),
  };

  factory Exam.fromMap(Map<String, dynamic> m) => Exam(
    id:           m['id'] as int?,
    name:         m['name'] as String,
    date:         DateTime.parse(m['date'] as String),
    maxGrade:     (m['max_grade'] as num).toDouble(),
    passingGrade: (m['passing_grade'] as num).toDouble(),
    createdAt:    m['created_at'] != null
        ? DateTime.parse(m['created_at'] as String)
        : null,
  );

  Exam copyWith({
    int? id,
    String? name,
    DateTime? date,
    double? maxGrade,
    double? passingGrade,
    List<int>? groupIds,
  }) => Exam(
    id:           id           ?? this.id,
    name:         name         ?? this.name,
    date:         date         ?? this.date,
    maxGrade:     maxGrade     ?? this.maxGrade,
    passingGrade: passingGrade ?? this.passingGrade,
    createdAt:    createdAt,
    groupIds:     groupIds     ?? this.groupIds,
  );
}
