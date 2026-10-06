import 'package:flutter/material.dart';

class AppColors {
  // Eski ekranların kullandığı isimler korunuyor; ana kimlik neon mor.
  static const gold = Color(0xFFB65CFF);
  static const burgundy = Color(0xFF6C2BFF);
  static const accentSoft = Color(0xFFC96BFF);
  static const cyan = Color(0xFF4EDCFF);

  static const neonPurple = Color(0xFFB65CFF);
  static const neonPink = Color(0xFFFF4BB8);
  static const neonBlue = Color(0xFF347BFF);
  static const neonCyan = Color(0xFF24C9DF);

  static const background = Color(0xFF030305);
  static const surface = Color(0xFF101116);
  static const surfaceAlt = Color(0xFF1B1C25);
  static const border = Color(0xFF30253F);

  static const textPrimary = Color(0xFFF7F5FF);
  static const textSecondary = Color(0xFFA1A4B5);

  static const darkBackground = background;
  static const darkSurface = surface;
  static const darkSurfaceAlt = surfaceAlt;

  static const lightBackground = Color(0xFFF7F5FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF0ECF8);
}

class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.neonPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.neonPurple,
      secondary: AppColors.neonPink,
      surface: AppColors.surface,
      onPrimary: const Color(0xFFFFFFFF),
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceAlt,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const ['Roboto', 'Arial'],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          height: 1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
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
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'Roboto'),
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
      primary: const Color(0xFF7A28E8),
      secondary: const Color(0xFFD12E91),
      surface: AppColors.lightSurface,
      surfaceContainer: AppColors.lightSurface,
      surfaceContainerHigh: AppColors.lightSurfaceAlt,
      onSurface: const Color(0xFF17151D),
      onSurfaceVariant: const Color(0xFF6E6978),
      outline: const Color(0xFFE0DCE9),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF17151D),
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
          borderSide: const BorderSide(color: Color(0xFFE0DCE9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonPurple, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7A28E8),
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
          side: const BorderSide(color: Color(0xFFE5E1EC)),
        ),
      ),
      dividerColor: const Color(0xFFE5E1EC),
    );
  }
}
