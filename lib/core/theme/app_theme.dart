import 'package:aptechka/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final text = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkMuted : AppColors.muted;
    final canvas = isDark ? AppColors.darkCanvas : AppColors.canvas;
    final card = isDark ? AppColors.darkCard : AppColors.card;
    final line = isDark ? AppColors.darkLine : AppColors.line;
    final primary = isDark ? const Color(0xFF70AEFF) : AppColors.primary;
    final textTheme = _textTheme(text, muted);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: isDark ? AppColors.darkCanvas : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF1D365A)
              : AppColors.primarySoft,
          onPrimaryContainer: primary,
          secondary: text,
          onSecondary: card,
          secondaryContainer: text,
          onSecondaryContainer: card,
          tertiary: isDark ? AppColors.warning : AppColors.warningText,
          tertiaryContainer: isDark
              ? const Color(0xFF442E18)
              : AppColors.warningSoft,
          onTertiaryContainer: isDark
              ? const Color(0xFFFFBE65)
              : AppColors.warningText,
          error: isDark ? const Color(0xFFFF8C90) : AppColors.danger,
          errorContainer: isDark
              ? const Color(0xFF49252F)
              : AppColors.dangerSoft,
          onErrorContainer: isDark ? const Color(0xFFFFAEB1) : AppColors.danger,
          surface: canvas,
          onSurface: text,
          onSurfaceVariant: muted,
          surfaceContainerLowest: card,
          surfaceContainerLow: card,
          surfaceContainer: card,
          surfaceContainerHigh: isDark ? AppColors.darkPlate : AppColors.canvas,
          surfaceContainerHighest: isDark
              ? AppColors.darkPlate
              : AppColors.canvas,
          outline: muted,
          outlineVariant: line,
          surfaceTint: Colors.transparent,
        );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
    );
    OutlineInputBorder fieldBorder([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: side,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Manrope',
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: muted, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        border: fieldBorder(),
        enabledBorder: fieldBorder(),
        focusedBorder: fieldBorder(BorderSide(color: primary, width: 1.5)),
        errorBorder: fieldBorder(BorderSide(color: scheme.error, width: 1.5)),
        focusedErrorBorder: fieldBorder(
          BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: pill,
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          foregroundColor: primary,
          side: BorderSide(color: line),
          shape: pill,
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: pill,
        extendedTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: card.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? AppColors.darkPlate : const Color(0xFFE5E7ED),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : text,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? primary : text,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: canvas,
        indicatorColor: isDark
            ? const Color(0xFF1D365A)
            : AppColors.primarySoft,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: muted,
          fontSize: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: BorderSide(color: line),
        labelStyle: TextStyle(
          color: text,
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: card,
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        selectedColor: text,
        backgroundColor: canvas,
        checkmarkColor: card,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 0.5, space: 1),
    );
  }

  static TextTheme _textTheme(Color text, Color muted) => TextTheme(
    displaySmall: TextStyle(
      color: text,
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: TextStyle(
      color: text,
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: TextStyle(
      color: text,
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      color: text,
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      color: text,
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: TextStyle(
      color: text,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(color: text, fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(color: muted, fontSize: 14, height: 1.4),
    bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
    labelLarge: TextStyle(
      color: text,
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      color: muted,
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      color: muted,
      fontSize: 10,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
  ).apply(fontFamily: 'Manrope');
}
