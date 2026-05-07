import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(AppColors.light);

  static ThemeData get dark => _build(AppColors.dark);

  static SystemUiOverlayStyle systemOverlayStyle(AppPalette colors) {
    final isLight = colors.brightness == Brightness.light;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.surface,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
    );
  }

  static SystemUiOverlayStyle systemOverlayStyleFor(BuildContext context) {
    final colors = Theme.of(context).extension<AppPalette>() ?? AppColors.light;
    return systemOverlayStyle(colors);
  }

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
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: colors.border),
    );
    final menuTextStyle = AppTextStyles.bodyMedium.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w800,
    );
    final floatingMenuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colors.surfaceElevated),
      shadowColor: WidgetStatePropertyAll(
        colors.shadow.withValues(alpha: colors.isDark ? 0.72 : 0.18),
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: WidgetStatePropertyAll(colors.isDark ? 14 : 10),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: 8),
      ),
      shape: WidgetStatePropertyAll(menuShape),
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
        systemOverlayStyle: systemOverlayStyle(colors),
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
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: colors.shadow.withValues(
          alpha: colors.isDark ? 0.72 : 0.18,
        ),
        elevation: colors.isDark ? 14 : 10,
        shape: menuShape,
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
        iconColor: colors.textSecondary,
        iconSize: 24,
        textStyle: menuTextStyle,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return menuTextStyle.copyWith(
              color: colors.textSecondary.withValues(alpha: 0.55),
            );
          }
          return menuTextStyle;
        }),
      ),
      menuTheme: MenuThemeData(style: floatingMenuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: menuTextStyle,
        menuStyle: floatingMenuStyle,
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
