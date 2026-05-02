import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(AppColors.light);

  static ThemeData get dark => _build(AppColors.dark);

  static ThemeData _build(AppPalette colors) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: colors.brightness,
      primary: colors.primary,
      surface: colors.surface,
      error: colors.danger,
    ).copyWith(
      onPrimary: colors.onPrimary,
      onSurface: colors.textPrimary,
      secondary: colors.primaryLight,
      outline: colors.border,
      surfaceContainerHighest: colors.surfaceElevated,
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: colors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      fontFamily: 'Inter',
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        centerTitle: false,
      ),
      textTheme: AppTextStyles.textTheme(colors),
      iconTheme: IconThemeData(color: colors.textSecondary),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(color: colors.textSecondary),
        labelStyle: TextStyle(color: colors.textSecondary),
        prefixIconColor: colors.primary,
        suffixIconColor: colors.textSecondary,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        modalBackgroundColor: colors.surface,
        modalBarrierColor: Colors.black.withValues(
          alpha: colors.isDark ? 0.72 : 0.42,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.isDark ? AppColors.textPrimary : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: const CircleBorder(),
      ),
    );
  }
}
