// lib/models/certificate_model.dart
//
// spec 018 — شهادات تقدير. مخرَج PDF فقط، مفيش تخزين. البيانات كلها
// تُبنى وقت التوليد من درجة الطالب + الامتحان + إعدادات المدرس.

/// قوالب التصميم — كل واحد صورة خلفية جاهزة في assets/images والتطبيق
/// يركّب النص فوقها (FR-005).
enum CertTemplate { blueGold, blueWhite, goldWhite }

extension CertTemplateX on CertTemplate {
  String get label => switch (this) {
        CertTemplate.blueGold => 'أزرق وذهبي',
        CertTemplate.blueWhite => 'أزرق وأبيض',
        CertTemplate.goldWhite => 'ذهبي وأبيض',
      };

  String get bgAsset => switch (this) {
        CertTemplate.blueGold => 'cert_bg_1.png',
        CertTemplate.blueWhite => 'cert_bg_2.png',
        CertTemplate.goldWhite => 'cert_bg_3.png',
      };

  /// المفتاح المخزَّن في app_settings.
  String get storageKey => name;

  static CertTemplate fromStorage(String? v) => CertTemplate.values.firstWhere(
        (t) => t.name == v,
        orElse: () => CertTemplate.blueWhite,
      );
}

/// نوع الإنجاز — يحدّد نص السبب في الشهادة.
enum CertKind { examExcellence, rank1, rank2, rank3, appreciation }

class CertificateData {
  final String studentName;
  final CertKind kind;

  /// نص السبب: "تقديرًا لتفوّقه في امتحان «الوحدة 3»" / "لحصوله على المركز الأول".
  final String achievementText;

  /// "الدرجة: 92 من 100 (92%)" — null لو مش مناسب.
  final String? gradeText;

  /// "الأحد 3 سبتمبر 2026".
  final String dateText;

  /// من الإعدادات — null/فاضي → السطر يتحذف من الشهادة (FR-006).
  final String? teacherName;
  final String? teacherSpecialization;

  /// "مستر" / "مس".
  final String teacherTitle;

  /// نص تهنئة ثابت.
  final String congratsText;

  const CertificateData({
    required this.studentName,
    required this.kind,
    required this.achievementText,
    this.gradeText,
    required this.dateText,
    this.teacherName,
    this.teacherSpecialization,
    this.teacherTitle = 'مستر',
    this.congratsText =
        'نبارك لك هذا التميّز، ونتمنّى لك دوام التفوّق والنجاح.',
  });

  /// سطر توقيع المعلّم كامل، أو null لو مفيش اسم.
  String? get teacherLine {
    final n = teacherName?.trim() ?? '';
    if (n.isEmpty) return null;
    final t = teacherTitle.trim();
    return t.isEmpty ? n : '$t $n';
  }
}
