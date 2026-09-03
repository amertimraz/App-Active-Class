# Contract — قوالب الشهادات + CertificateService

## `CertificateData` (lib/models/certificate_model.dart)

```dart
enum CertTemplate { classic, modern, simple }

enum CertKind { examExcellence, rank1, rank2, rank3, appreciation }

class CertificateData {
  final String studentName;
  final CertKind kind;
  final String achievementText;   // "تقديرًا لتفوّقه في امتحان الوحدة 3" / "لحصوله على المركز الأول"
  final String? gradeText;        // "الدرجة: 92 من 100 (92%)" — null لو مش مناسب
  final String dateText;          // "الأحد 3 سبتمبر 2026"
  final String? teacherName;      // null/فاضي → السطر يتحذف
  final String? teacherSpecialization;
  final String teacherTitle;      // "مستر" / "مس"
  final String congratsText;      // ثابت: "نبارك لك هذا التميّز، ونتمنّى لك دوام التفوّق والنجاح."
}
```

## `CertificateService` (lib/services/certificate_service.dart)

```dart
class CertificateService {
  factory CertificateService() => _i;   // singleton زي ExportService
  Future<void> _loadFonts();            // Cairo-Regular/Bold من assets/fonts (نسخة من ExportService)

  /// يبني PDF فيه صفحة A4 رأسية لكل CertificateData بالقالب المحدّد.
  Future<Uint8List> buildCertificatesPdf(
      List<CertificateData> items, CertTemplate template);

  // دوال القوالب الداخلية — كل واحدة pw.Widget (محتوى صفحة كاملة):
  pw.Widget _classic(CertificateData d);
  pw.Widget _modern(CertificateData d);
  pw.Widget _simple(CertificateData d);
}
```

المشاركة: المستدعي يعمل `Printing.sharePdf(bytes: pdf, filename: 'شهادات_<اسم الامتحان>.pdf')`.

## تخطيط القوالب (كلها RTL، A4 portrait، هوامش ~2سم)

### كلاسيكي (`_classic`)
- إطار مزدوج (خارجي سميك ذهبي `0xFFB8860B`، داخلي رفيع كحلي `0xFF1E3A5F`).
- أعلى: زخرفة/رمز 🏅 + "شهادة تقدير" (خط كبير، bold، كحلي).
- منتصف: "تُمنح هذه الشهادة إلى" → **اسم الطالب** (أكبر خط، ذهبي داكن) → `achievementText` → `gradeText` (لو موجود).
- أسفل: `dateText` (يسار) · توقيع "المعلّم: {teacherTitle} {teacherName}" + "{teacherSpecialization}" (يمين) — السطور الفارغة تُحذف.
- `congratsText` سطر صغير فوق التذييل.

### حديث (`_modern`)
- شريط متدرّج علوي (إنديجو `0xFF4F46E5` → بنفسجي `0xFF7C3AED`) بارتفاع ~120، فيه "شهادة تقدير" أبيض + رمز.
- خلفية بيضاء، بلوك نص مركزي: اسم الطالب (إنديجو، bold كبير) → achievement → grade في كبسولة ملوّنة.
- شريط متدرّج سفلي رفيع + التذييل (تاريخ + معلّم).
- زاوية مزخرفة خفيفة (دوائر شبه شفافة).

### بسيط (`_simple`)
- إطار رفيع رمادي `0xFF9CA3AF` واحد.
- "شهادة تقدير" أعلى، رفيع.
- نص مركزي نظيف: اسم الطالب (أسود، bold) → achievement → grade.
- تذييل سطر واحد: "{teacherTitle} {teacherName} — {teacherSpecialization} · {dateText}" (الأجزاء الفارغة تُحذف مع فواصلها).

## قواعد المحتوى

| CertKind | achievementText |
|---|---|
| `examExcellence` | "تقديرًا لتفوّقه في امتحان «{اسم الامتحان}»" |
| `rank1` | "لحصوله على **المركز الأول** {نطاق الفلتر}" |
| `rank2` | "لحصوله على **المركز الثاني** {نطاق الفلتر}" |
| `rank3` | "لحصوله على **المركز الثالث** {نطاق الفلتر}" |
| `appreciation` | "تقديرًا لتميّزه والتزامه" (يدوي عام) |

- `{نطاق الفلتر}`: "" (الكل) · "في مجموعة {اسم}" · "في امتحان «{اسم}»" · "خلال {شهر}".
- `gradeText`: للـ`examExcellence` و`rank*` (لو من امتحان واحد) → "الدرجة: {g} من {m} ({pct}%)". للترتيب الإجمالي → "بمعدّل {pct}% عبر {n} امتحان".
- تقليم `studentName` لو > ~28 حرف: نقلّل حجم الخط تلقائيًا (auto-fit) بدل القص.
