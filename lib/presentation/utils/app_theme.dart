import 'package:flutter/material.dart';

/// Semantic palette supporting both Dark Mode (default) and Light Mode.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.surfaceBase,
    required this.surfaceCard,
    required this.surfaceSubtle,
    required this.surfaceDark,
    required this.surfaceDarkCard,
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnDark,
    required this.textOnDarkMuted,
    required this.brandPrimary,
    required this.brandAccent,
    required this.brandAccentBg,
    required this.assetPositive,
    required this.assetPositiveBg,
    required this.assetPositiveBorder,
    required this.liabilityNegative,
    required this.liabilityNegativeBg,
    required this.liabilityNegativeBorder,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
  });

  final Brightness brightness;
  final Color surfaceBase;
  final Color surfaceCard;
  final Color surfaceSubtle;
  final Color surfaceDark;
  final Color surfaceDarkCard;
  final Color borderSubtle;
  final Color borderStrong;
  final Color borderFocus;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnDark;
  final Color textOnDarkMuted;
  final Color brandPrimary;
  final Color brandAccent;
  final Color brandAccentBg;
  final Color assetPositive;
  final Color assetPositiveBg;
  final Color assetPositiveBorder;
  final Color liabilityNegative;
  final Color liabilityNegativeBg;
  final Color liabilityNegativeBorder;
  final Color warning;
  final Color warningBg;
  final Color warningBorder;

  bool get isDark => brightness == Brightness.dark;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    surfaceBase: Color(0xFF0B0F19), // Deep midnight slate
    surfaceCard: Color(0xFF161F30), // Slate 900 container
    surfaceSubtle: Color(0xFF1E293B), // Slate 800 item container
    surfaceDark: Color(0xFF070B14),
    surfaceDarkCard: Color(0xFF0F172A),
    borderSubtle: Color(0xFF26334D), // Sleek subtle border
    borderStrong: Color(0xFF3B4D6E),
    borderFocus: Color(0xFF3B82F6),
    textPrimary: Color(0xFFF8FAFC), // High contrast white
    textSecondary: Color(0xFF94A3B8), // Slate 400
    textMuted: Color(0xFF64748B),
    textOnDark: Color(0xFFF8FAFC),
    textOnDarkMuted: Color(0xFF94A3B8),
    brandPrimary: Color(0xFF60A5FA),
    brandAccent: Color(0xFF3B82F6),
    brandAccentBg: Color(0xFF1E3A8A),
    assetPositive: Color(0xFF34D399), // Emerald 400 luminous
    assetPositiveBg: Color(0x33064E3B),
    assetPositiveBorder: Color(0xFF065F46),
    liabilityNegative: Color(0xFFF87171), // Red 400 luminous
    liabilityNegativeBg: Color(0x337F1D1D),
    liabilityNegativeBorder: Color(0xFF991B1B),
    warning: Color(0xFFFBBF24),
    warningBg: Color(0x3378350F),
    warningBorder: Color(0xFF92400E),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    surfaceBase: Color(0xFFF8FAFC), // Slate 50
    surfaceCard: Color(0xFFFFFFFF), // Pure white
    surfaceSubtle: Color(0xFFF1F5F9), // Slate 100
    surfaceDark: Color(0xFF0F172A), // Slate 900
    surfaceDarkCard: Color(0xFF1E293B),
    borderSubtle: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    borderFocus: Color(0xFF2563EB),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    textOnDark: Color(0xFFF8FAFC),
    textOnDarkMuted: Color(0xFF94A3B8),
    brandPrimary: Color(0xFF1E3A8A),
    brandAccent: Color(0xFF2563EB),
    brandAccentBg: Color(0xFFEFF6FF),
    assetPositive: Color(0xFF059669), // Emerald 600
    assetPositiveBg: Color(0xFFECFDF5),
    assetPositiveBorder: Color(0xFFA7F3D0),
    liabilityNegative: Color(0xFFDC2626), // Red 600
    liabilityNegativeBg: Color(0xFFFEF2F2),
    liabilityNegativeBorder: Color(0xFFFECACA),
    warning: Color(0xFFD97706),
    warningBg: Color(0xFFFFFBEB),
    warningBorder: Color(0xFFFDE68A),
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  BoxDecoration cardDecoration({
    double borderRadius = 16,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderSubtle, width: 1),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}

/// Centralized Design System Tokens based on the frontend-design skill.
/// Provides consistent financial identity, clean typography, and rhythmic ergonomics.
class AppColors {
  const AppColors._();

  static AppPalette of(BuildContext context) => AppPalette.of(context);

  // Default values reflecting dark theme (predeterminado)
  static const Color surfaceBase = Color(0xFF0B0F19);
  static const Color surfaceCard = Color(0xFF161F30);
  static const Color surfaceSubtle = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color surfaceDark = Color(0xFF070B14);
  static const Color surfaceDarkCard = Color(0xFF0F172A);

  static const Color borderSubtle = Color(0xFF26334D);
  static const Color borderStrong = Color(0xFF3B4D6E);
  static const Color borderFocus = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnDarkMuted = Color(0xFF94A3B8);

  static const Color brandPrimary = Color(0xFF60A5FA);
  static const Color brandAccent = Color(0xFF3B82F6);
  static const Color brandAccentBg = Color(0xFF1E3A8A);

  static const Color assetPositive = Color(0xFF34D399);
  static const Color assetPositiveBg = Color(0x33064E3B);
  static const Color assetPositiveBorder = Color(0xFF065F46);

  static const Color liabilityNegative = Color(0xFFF87171);
  static const Color liabilityNegativeBg = Color(0x337F1D1D);
  static const Color liabilityNegativeBorder = Color(0xFF991B1B);

  static const Color warning = Color(0xFFFBBF24);
  static const Color warningBg = Color(0x3378350F);
  static const Color warningBorder = Color(0xFF92400E);
}

class AppTypography {
  const AppTypography._();

  static const TextStyle heroBalance = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle itemTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle amountEmphasized = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const TextStyle metaLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle badgeText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}

class AppDecorations {
  const AppDecorations._();

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration card({
    BuildContext? context,
    Color? backgroundColor,
    Color? borderColor,
    double borderRadius = 16,
    bool hasShadow = true,
  }) {
    final pal = context != null ? AppColors.of(context) : null;
    final bg = backgroundColor ?? pal?.surfaceCard ?? AppColors.surfaceCard;
    final border = borderColor ?? pal?.borderSubtle ?? AppColors.borderSubtle;
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1),
      boxShadow: hasShadow ? cardShadow : null,
    );
  }

  static BoxDecoration heroDarkCard() {
    return BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF334155), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration pillBadge({
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor, width: 1),
    );
  }
}

ThemeData buildAppTheme({Brightness brightness = Brightness.dark}) {
  final pal = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: pal.brandAccent,
      brightness: brightness,
      primary: pal.brandAccent,
      surface: pal.surfaceCard,
      error: pal.liabilityNegative,
    ),
    scaffoldBackgroundColor: pal.surfaceBase,
  );

  return base.copyWith(
    cardTheme: CardThemeData(
      color: pal.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pal.borderSubtle, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: pal.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: pal.textSecondary),
      titleTextStyle: TextStyle(
        color: pal.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.4,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pal.surfaceCard,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pal.borderSubtle, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pal.surfaceSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pal.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pal.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pal.borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pal.liabilityNegative),
      ),
      labelStyle: TextStyle(color: pal.textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: pal.textMuted, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pal.brandAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pal.textPrimary,
        side: BorderSide(color: pal.borderSubtle),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: pal.brandAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: pal.borderSubtle,
      thickness: 1,
      space: 1,
    ),
  );
}
