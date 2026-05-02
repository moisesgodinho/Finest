import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system,
  light,
  dark,
}

extension AppThemePreferenceLabel on AppThemePreference {
  String get label {
    return switch (this) {
      AppThemePreference.system => 'Sistema',
      AppThemePreference.light => 'Claro',
      AppThemePreference.dark => 'Escuro AMOLED',
    };
  }

  String get description {
    return switch (this) {
      AppThemePreference.system => 'Segue o tema do aparelho',
      AppThemePreference.light => 'Visual claro para uso geral',
      AppThemePreference.dark => 'Fundo preto para telas AMOLED',
    };
  }

  IconData get icon {
    return switch (this) {
      AppThemePreference.system => Icons.brightness_auto_rounded,
      AppThemePreference.light => Icons.light_mode_rounded,
      AppThemePreference.dark => Icons.dark_mode_rounded,
    };
  }

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }
}

class ThemeController extends StateNotifier<AppThemePreference> {
  ThemeController() : super(AppThemePreference.system) {
    _loadPreference();
  }

  static const _storageKey = 'app_theme_preference';

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, preference.name);
  }

  Future<void> _loadPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = preferences.getString(_storageKey);
    AppThemePreference? storedPreference;
    for (final preference in AppThemePreference.values) {
      if (preference.name == storedValue) {
        storedPreference = preference;
        break;
      }
    }

    if (mounted && storedPreference != null) {
      state = storedPreference;
    }
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, AppThemePreference>((ref) {
  return ThemeController();
});
