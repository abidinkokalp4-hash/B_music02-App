import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Eski ekranların kullandığı isimler korunuyor; ana kimlik plak temasını kullanır.
  static const gold = Color(0xFFFF9A3C);
  static const burgundy = Color(0xFFFF9A3C);
  static const accentSoft = Color(0xFFF6B778);
  static const cyan = Color(0xFFD8AF88);

  static const neonPurple = Color(0xFFFF9A3C);
  static const neonPink = Color(0xFFDC8054);
  static const neonBlue = Color(0xFFBF936D);
  static const neonCyan = Color(0xFFD8AF88);

  static const background = Color(0xFF14100D);
  static const surface = Color(0xFF1F1812);
  static const surfaceAlt = Color(0xFF2A211A);
  static const border = Color(0xFF493C31);

  static const textPrimary = Color(0xFFF2E6D0);
  static const textSecondary = Color(0xFFA89A86);

  static const darkBackground = background;
  static const darkSurface = surface;
  static const darkSurfaceAlt = surfaceAlt;

  static const lightBackground = Color(0xFFF6EFE3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEFE5D3);
}

class AppTheme {
  /// Dark navigation bar with light buttons on every screen (both themes).
  static const systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarDividerColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );
  static final lightSystemBars = systemBars.copyWith(
      statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.neonPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.neonPurple,
      secondary: AppColors.neonPink,
      surface: AppColors.surface,
      onPrimary: const Color(0xFF1A100A),
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceAlt,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DM Sans',
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const ['Roboto', 'Arial'],
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: systemBars,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: 'Fraunces',
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          height: 1.0,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonPurple, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonPurple,
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.neonPurple,
          foregroundColor: const Color(0xFFFFFFFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.burgundy,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'DM Sans'),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        showCheckmark: false,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(44, 44))),
      dividerColor: AppColors.border,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.neonPurple,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFFD9741A),
      secondary: const Color(0xFFA95D26),
      surface: AppColors.lightSurface,
      surfaceContainer: AppColors.lightSurface,
      surfaceContainerHigh: AppColors.lightSurfaceAlt,
      onSurface: const Color(0xFF1F1610),
      onSurfaceVariant: const Color(0xFF6F6253),
      outline: const Color(0xFFDFD4C6),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DM Sans',
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: lightSystemBars,
        titleTextStyle: const TextStyle(fontFamily: 'Fraunces', fontSize: 24,
            color: Color(0xff1f1610), fontWeight: FontWeight.w700),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: const Color(0xFF1F1610),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDFD4C6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonPurple, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD9741A),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE6DBCD)),
        ),
      ),
      dividerColor: const Color(0xFFE6DBCD),
    );
  }
}
