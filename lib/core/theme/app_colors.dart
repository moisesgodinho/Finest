import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF006B4F);
  static const primaryDark = Color(0xFF003D32);
  static const primaryLight = Color(0xFF19A974);
  static const mint = Color(0xFFE8F6EF);
  static const background = Color(0xFFF6F8F7);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF121A22);
  static const textSecondary = Color(0xFF65727E);
  static const border = Color(0xFFE0E6E4);
  static const success = Color(0xFF0A8F4D);
  static const danger = Color(0xFFD93025);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF2F80ED);
  static const purple = Color(0xFF7C3AED);

  static const light = AppPalette(
    brightness: Brightness.light,
    primary: primary,
    primaryDark: primaryDark,
    primaryLight: primaryLight,
    accentSoft: mint,
    background: background,
    surface: surface,
    surfaceElevated: surface,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    border: border,
    success: success,
    danger: danger,
    warning: warning,
    info: info,
    purple: purple,
    onPrimary: Colors.white,
    shadow: Color(0x1A000000),
    inverseSurface: Color(0xFF101715),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF00A878),
    primaryDark: Color(0xFF001F1A),
    primaryLight: Color(0xFF34D399),
    accentSoft: Color(0xFF0B241D),
    background: Color(0xFF000000),
    surface: Color(0xFF070A09),
    surfaceElevated: Color(0xFF0D1210),
    textPrimary: Color(0xFFF3FBF7),
    textSecondary: Color(0xFFA6B6AF),
    border: Color(0xFF1D2A25),
    success: Color(0xFF34D399),
    danger: Color(0xFFFF6B61),
    warning: Color(0xFFFBBF24),
    info: Color(0xFF60A5FA),
    purple: Color(0xFFA78BFA),
    onPrimary: Colors.white,
    shadow: Color(0x99000000),
    inverseSurface: Color(0xFFF6F8F7),
  );
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accentSoft,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.danger,
    required this.warning,
    required this.info,
    required this.purple,
    required this.onPrimary,
    required this.shadow,
    required this.inverseSurface,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accentSoft;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color danger;
  final Color warning;
  final Color info;
  final Color purple;
  final Color onPrimary;
  final Color shadow;
  final Color inverseSurface;

  bool get isDark => brightness == Brightness.dark;

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accentSoft,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? danger,
    Color? warning,
    Color? info,
    Color? purple,
    Color? onPrimary,
    Color? shadow,
    Color? inverseSurface,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accentSoft: accentSoft ?? this.accentSoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      purple: purple ?? this.purple,
      onPrimary: onPrimary ?? this.onPrimary,
      shadow: shadow ?? this.shadow,
      inverseSurface: inverseSurface ?? this.inverseSurface,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
    );
  }
}

extension AppThemeColors on BuildContext {
  AppPalette get colors {
    return Theme.of(this).extension<AppPalette>() ?? AppColors.light;
  }
}
