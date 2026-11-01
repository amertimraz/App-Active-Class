// lib/config/theme.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:active_class/utils/responsive.dart';

class AppTheme {
  // Colors - Premium & Modern
  static const Color primaryColor = Color(0xFF4F46E5); // Indigo 600
  static const Color accentColor = Color(0xFF6366F1);  // Indigo 500
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color errorColor = Color(0xFFEF4444); // Red 500
  static const Color successColor = Color(0xFF10B981); // Emerald 500
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFE2E8F0); // Slate 200

  // Light Theme - Minimal & Professional
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    extensions: const [AppTokens.light],
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      error: errorColor,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Cairo',
        color: textSecondary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: dividerColor),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceColor,
      elevation: 0,
      height: 65,
      indicatorColor: primaryColor.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor);
        }
        return const IconThemeData(color: textSecondary);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          );
        }
        return const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: textSecondary,
        );
      }),
    ),
    // spec 055: على الويب القوائم السفلية بعرض مريح متوسّط بدل عرض الشاشة كلها.
    bottomSheetTheme: BottomSheetThemeData(
      constraints:
          kIsWeb ? const BoxConstraints(maxWidth: kSheetMaxWidth) : null,
    ),
    iconTheme: const IconThemeData(
      color: textPrimary,
      size: 24,
    ),
    dividerTheme: const DividerThemeData(
      color: dividerColor,
      thickness: 1,
    ),
  );

  // Dark Theme - Premium & Modern
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: const [AppTokens.dark],
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
    appBarTheme: const AppBarTheme(
      backgroundColor: const Color(0xFF1E293B), // Slate 800
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: const Color(0xFF1E293B), // Slate 800
      error: errorColor,
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B), // Slate 800
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)), // Slate 700
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Cairo',
        color: Colors.grey,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E293B), // Slate 800
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)), // Slate 700
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1E293B), // Slate 800
      elevation: 0,
      height: 65,
      indicatorColor: primaryColor.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor);
        }
        return const IconThemeData(color: Colors.grey);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          );
        }
        return const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: Colors.grey,
        );
      }),
    ),
    // spec 055: على الويب القوائم السفلية بعرض مريح متوسّط بدل عرض الشاشة كلها.
    bottomSheetTheme: BottomSheetThemeData(
      constraints:
          kIsWeb ? const BoxConstraints(maxWidth: kSheetMaxWidth) : null,
    ),
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: 24,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF334155), // Slate 700
      thickness: 1,
    ),
  );
}

/// نظام التصميم: مسافات بمضاعفات 4.
class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// استدارة الحواف حسب مستوى العنصر: شريحة، زرار، لوحة، السبورة.
class AppRadius {
  static const double chip = 8;
  static const double control = 12;
  static const double panel = 16;
  static const double board = 24;
}

/// مقاسات الخط. Cairo متضمَّن بوزنين بس (400 و700)، فأي وزن تاني بيترسم
/// كأقرب واحد منهم. أقل مقاس 12 عشان الوضوح.
class AppType {
  static const TextStyle greeting = TextStyle(
      fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);
  static const TextStyle figure = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const TextStyle title = TextStyle(
      fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, height: 1.35);
  static const TextStyle label = TextStyle(
      fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, height: 1.35);
  static const TextStyle body = TextStyle(
      fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);
  static const TextStyle caption = TextStyle(
      fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w400, height: 1.35);
}

/// ألوان دلالية للوضعين الفاتح والداكن. الشاشات تقرا منها بدل كتابة ألوان
/// مباشرة. درجات positive/caution/danger أغمق من ألوان AppTheme القديمة
/// عشان تعدّي تباين 4.5:1 كنص على الأبيض.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.page,
    required this.surface,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.brand,
    required this.board,
    required this.boardInk,
    required this.boardInkSoft,
    required this.boardLine,
    required this.chalk,
    required this.onChalk,
    required this.positive,
    required this.positiveSoft,
    required this.caution,
    required this.cautionSoft,
    required this.cautionBar,
    required this.rosterTint,
    required this.rosterInk,
    required this.moneyTint,
    required this.moneyLine,
    required this.moneyInk,
    required this.danger,
    required this.dangerSoft,
  });

  final Color page, surface, line, ink, inkSoft, inkFaint, brand;
  // السبورة: رأس الشاشة الرئيسية، والطباشير للإجراء الأساسي عليها.
  final Color board, boardInk, boardInkSoft, boardLine, chalk, onChalk;
  final Color positive, positiveSoft, caution, cautionSoft, danger, dangerSoft;
  // تعبئة الشرائط: أزهى من caution اللي متظبطة كلون نص.
  final Color cautionBar;
  // لون صينية كل قسم: البنفسجي لملخص الأعداد والحضور، والأخضر للدفعات.
  final Color rosterTint, rosterInk;
  final Color moneyTint, moneyLine, moneyInk;

  static const AppTokens light = AppTokens(
    page: Color(0xFFF4F5FA),
    surface: Color(0xFFFFFFFF),
    line: Color(0xFFE2E5F0),
    ink: Color(0xFF14172B),
    inkSoft: Color(0xFF4A5068),
    inkFaint: Color(0xFF6B7189),
    brand: Color(0xFF4F46E5),
    board: Color(0xFF2B2785),
    boardInk: Color(0xFFFFFFFF),
    boardInkSoft: Color(0xFFCDCFF4),
    boardLine: Color(0x33FFFFFF),
    chalk: Color(0xFFFFD15C),
    onChalk: Color(0xFF2A2200),
    positive: Color(0xFF0B7A55),
    positiveSoft: Color(0xFFE3F5EE),
    caution: Color(0xFF9A5200),
    cautionSoft: Color(0xFFFCF0DD),
    cautionBar: Color(0xFFD98200),
    rosterTint: Color(0xFFECECFB),
    rosterInk: Color(0xFF2B2785),
    moneyTint: Color(0xFFE4F4EC),
    moneyLine: Color(0xFFC3E5D3),
    moneyInk: Color(0xFF0B5D42),
    danger: Color(0xFFC9252D),
    dangerSoft: Color(0xFFFCE9E9),
  );

  static const AppTokens dark = AppTokens(
    page: Color(0xFF0D1020),
    surface: Color(0xFF171B2F),
    line: Color(0xFF2A3048),
    ink: Color(0xFFF2F4FB),
    inkSoft: Color(0xFFB4BBD0),
    inkFaint: Color(0xFF8C93AB),
    brand: Color(0xFFA5A8FF),
    board: Color(0xFF1F1C5C),
    boardInk: Color(0xFFFFFFFF),
    boardInkSoft: Color(0xFFC3C6EC),
    boardLine: Color(0x33FFFFFF),
    chalk: Color(0xFFFFD15C),
    onChalk: Color(0xFF2A2200),
    positive: Color(0xFF4AD6A3),
    positiveSoft: Color(0xFF12332B),
    caution: Color(0xFFF5B14C),
    cautionSoft: Color(0xFF3A2C12),
    cautionBar: Color(0xFFF5B14C),
    rosterTint: Color(0xFF1E2048),
    rosterInk: Color(0xFFC9CBFF),
    moneyTint: Color(0xFF10291F),
    moneyLine: Color(0xFF1F4535),
    moneyInk: Color(0xFF7FE3BC),
    danger: Color(0xFFFF8A8A),
    dangerSoft: Color(0xFF3D1C22),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      t < 0.5 || other is! AppTokens ? this : other;
}

extension AppTokensX on BuildContext {
  /// بيرجع لقيمة حسب السطوع لو الثيم الحالي مفيهوش الامتداد (اختبارات مثلًا).
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark
            ? AppTokens.dark
            : AppTokens.light);
  }
}
