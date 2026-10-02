import 'package:aptechka/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = _textTheme(isDark);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      brightness: brightness,
      surface: isDark ? const Color(0xFF121B18) : AppColors.canvas,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? const Color(0xFF1A2521) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isDark ? const Color(0xFF2D3A35) : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A2521) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF34443E) : AppColors.line,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sage, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121B18) : Colors.white,
        indicatorColor: isDark ? const Color(0xFF315D50) : AppColors.mint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(
          color: isDark ? const Color(0xFF34443E) : AppColors.line,
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: colorScheme.secondaryContainer,
        backgroundColor: colorScheme.surface,
        checkmarkColor: colorScheme.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF2D3A35) : AppColors.line,
      ),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final textColor = isDark ? const Color(0xFFF0F5F2) : AppColors.ink;
    final mutedColor = isDark ? const Color(0xFFB7C5BF) : AppColors.muted;
    return TextTheme(
      displaySmall: TextStyle(
        color: textColor,
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        color: textColor,
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: textColor, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: mutedColor, fontSize: 14, height: 1.45),
      labelLarge: TextStyle(
        color: textColor,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
