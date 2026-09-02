// lib/models/exam_model.dart

/// spec 016 — حالة الامتحان الإلكتروني على السحابة.
/// null (أو للامتحان الورقي) = مش امتحان إلكتروني.
enum OnlineExamStatus { draft, published, stopped, removed }

extension OnlineExamStatusX on OnlineExamStatus {
  String get dbValue {
    switch (this) {
      case OnlineExamStatus.draft:
        return 'draft';
      case OnlineExamStatus.published:
        return 'published';
      case OnlineExamStatus.stopped:
        return 'stopped';
      case OnlineExamStatus.removed:
        return 'removed';
    }
  }

  static OnlineExamStatus? fromDb(String? raw) {
    switch (raw) {
      case 'draft':
        return OnlineExamStatus.draft;
      case 'published':
        return OnlineExamStatus.published;
      case 'stopped':
        return OnlineExamStatus.stopped;
      case 'removed':
        return OnlineExamStatus.removed;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case OnlineExamStatus.draft:
        return 'مسودّة';
      case OnlineExamStatus.published:
        return 'منشور';
      case OnlineExamStatus.stopped:
        return 'موقوف';
      case OnlineExamStatus.removed:
        return 'محذوف من الويب';
    }
  }
}

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

  // spec 016 — حقول الامتحان الإلكتروني. محلية فقط (خارج مزامنة الفريق):
  // مش موجودة في toMap عمدًا عشان payload المزامنة يفضل نظيف.
  final bool isOnline;
  final OnlineExamStatus? onlineStatus;
  final DateTime? opensAt;   // UTC
  final DateTime? closesAt;  // UTC
  final int? durationMinutes;

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
    this.isOnline = false,
    this.onlineStatus,
    this.opensAt,
    this.closesAt,
    this.durationMinutes,
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

  /// هل نافذة الامتحان الإلكتروني مفتوحة دلوقتي (للعرض في التطبيق فقط).
  bool get isWindowOpenNow {
    if (!isOnline || onlineStatus != OnlineExamStatus.published) return false;
    final now = DateTime.now().toUtc();
    return (opensAt == null || !now.isBefore(opensAt!)) &&
        (closesAt == null || now.isBefore(closesAt!));
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
    isOnline:     (m['is_online'] as int? ?? 0) == 1,
    onlineStatus: OnlineExamStatusX.fromDb(m['online_status'] as String?),
    opensAt:      _parseDt(m['opens_at']),
    closesAt:     _parseDt(m['closes_at']),
    durationMinutes: m['duration_minutes'] as int?,
  );

  static DateTime? _parseDt(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  static const Object _unset = Object();

  Exam copyWith({
    int? id,
    String? name,
    DateTime? date,
    double? maxGrade,
    double? passingGrade,
    // sentinel عشان نفرّق بين "مش متغيّر" و"صفّره لـnull" (يتبع التاريخ)
    Object? reportMonth = _unset,
    bool? isOnline,
    Object? onlineStatus = _unset,
    Object? opensAt = _unset,
    Object? closesAt = _unset,
    Object? durationMinutes = _unset,
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
    isOnline:     isOnline     ?? this.isOnline,
    onlineStatus: identical(onlineStatus, _unset)
        ? this.onlineStatus
        : onlineStatus as OnlineExamStatus?,
    opensAt:      identical(opensAt, _unset) ? this.opensAt : opensAt as DateTime?,
    closesAt:     identical(closesAt, _unset) ? this.closesAt : closesAt as DateTime?,
    durationMinutes: identical(durationMinutes, _unset)
        ? this.durationMinutes
        : durationMinutes as int?,
    groupIds:     groupIds     ?? this.groupIds,
  );
}
