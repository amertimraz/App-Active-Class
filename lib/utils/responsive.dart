// lib/utils/responsive.dart
//
// spec 055 (T055) — دوال صرفة لتجاوب الشاشات العريضة (ويب/تابلت). على
// الموبايل (< 600) كل القيم بترجع بالظبط للأرقام الأصلية.

/// أقل عرض نعتبره شاشة عريضة.
const double kWideBreakpoint = 600;

/// من هنا نطبّق إطار المحتوى المتوسّط والتكبير.
const double kDesktopBreakpoint = 900;

/// أقصى عرض لمحتوى التطبيق على الكمبيوتر.
const double kDesktopContentMaxWidth = 1100;

/// أقصى عرض لقوائم الاختيار السفلية (bottom sheets) على الكمبيوتر.
const double kSheetMaxWidth = 640;

/// عدد أعمدة شبكة: [phone] على الموبايل، وعلى العريض بيزيد حسب
/// أقل عرض للخلية [minTileWidth] وبحد أقصى [max].
int adaptiveColumns(
  double width, {
  required int phone,
  double minTileWidth = 180,
  int max = 6,
}) {
  if (width < kWideBreakpoint) return phone;
  final n = (width / minTileWidth).floor();
  return n.clamp(phone, max < phone ? phone : max);
}

/// معامل تكبير الخط على الكمبيوتر (1.0 = بلا تغيير).
double desktopTextScale(double viewportWidth) =>
    viewportWidth >= kDesktopBreakpoint ? 1.12 : 1.0;

/// عرض المحتوى الفعلي بعد الإطار المتوسّط.
double framedWidth(double viewportWidth) => viewportWidth >= kDesktopBreakpoint
    ? (viewportWidth < kDesktopContentMaxWidth
        ? viewportWidth
        : kDesktopContentMaxWidth)
    : viewportWidth;
