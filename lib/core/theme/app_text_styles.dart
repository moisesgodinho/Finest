import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextTheme textTheme(AppPalette colors) {
    return TextTheme(
      headlineLarge: headlineLarge.copyWith(color: colors.textPrimary),
      headlineMedium: headlineMedium.copyWith(color: colors.textPrimary),
      titleLarge: titleLarge.copyWith(color: colors.textPrimary),
      titleMedium: titleMedium.copyWith(color: colors.textPrimary),
      bodyLarge: bodyLarge.copyWith(color: colors.textPrimary),
      bodyMedium: bodyMedium.copyWith(color: colors.textSecondary),
      labelLarge: labelLarge.copyWith(color: colors.textPrimary),
    );
  }

  static const headlineLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const headlineMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}
