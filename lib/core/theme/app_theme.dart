import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PANDA AI STUDIO design system — strictly monochrome.
/// Only #000000 and #FFFFFF are used. "Gray" surfaces are opacity
/// variations of black (light theme) or white (dark theme).
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  static Color onBlack(double opacity) => white.withOpacity(opacity);
  static Color onWhite(double opacity) => black.withOpacity(opacity);
}

/// Semantic colors resolved from the current [Brightness].
class AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color inverseBackground;
  final Color inverseText;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.inverseBackground,
    required this.inverseText,
  });

  factory AppPalette.of(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const AppPalette(
        background: AppColors.black,
        surface: Color(0x14FFFFFF), // white @ 8%
        surfaceElevated: Color(0x24FFFFFF), // white @ 14%
        textPrimary: AppColors.white,
        textSecondary: Color(0xB3FFFFFF), // white @ 70%
        textTertiary: Color(0x80FFFFFF), // white @ 50%
        border: Color(0x33FFFFFF), // white @ 20%
        inverseBackground: AppColors.white,
        inverseText: AppColors.black,
      );
    }
    return const AppPalette(
      background: AppColors.white,
      surface: Color(0x0D000000), // black @ 5%
      surfaceElevated: Color(0x14000000), // black @ 8%
      border: Color(0x26000000), // black @ 15%
      textPrimary: AppColors.black,
      textSecondary: Color(0xB3000000), // black @ 70%
      textTertiary: Color(0x80000000), // black @ 50%
      inverseBackground: AppColors.black,
      inverseText: AppColors.white,
    );
  }
}

/// Extension so any widget can read the palette via `context.palette`.
extension PaletteContext on BuildContext {
  AppPalette get palette =>
      AppPalette.of(Theme.of(this).brightness);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final AppPalette p = AppPalette.of(brightness);
    final TextTheme baseText = GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.textPrimary,
        onPrimary: p.inverseText,
        secondary: p.textSecondary,
        onSecondary: p.background,
        surface: p.background,
        onSurface: p.textPrimary,
        error: p.textPrimary,
        onError: p.inverseText,
      ),
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: p.textPrimary,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: p.textPrimary,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.45,
          color: p.textPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.45,
          color: p.textSecondary,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12.5,
          color: p.textTertiary,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
          letterSpacing: 0.4,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.background,
        selectedItemColor: p.textPrimary,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.textTertiary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.textPrimary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.inverseBackground,
          foregroundColor: p.inverseText,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.textPrimary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.inverseBackground,
        secondarySelectedColor: p.inverseBackground,
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: p.inverseText, fontSize: 13),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.textPrimary,
        inactiveTrackColor: p.border,
        thumbColor: p.textPrimary,
        overlayColor: p.surfaceElevated,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.inverseBackground,
        contentTextStyle: TextStyle(color: p.inverseText, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textPrimary,
        textColor: p.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.textPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(p.textPrimary),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return p.textPrimary;
          return p.border;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(p.textPrimary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
