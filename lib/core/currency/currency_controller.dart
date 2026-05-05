import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_currency.dart';

class CurrencyController extends StateNotifier<String> {
  CurrencyController() : super(AppCurrencies.defaultCode) {
    _loadPreference();
  }

  static const _storageKey = 'finest.default_currency_code';

  Future<void> setCurrency(String currencyCode) async {
    final normalized = currencyCode.toUpperCase();
    if (!AppCurrencies.isSupported(normalized)) {
      return;
    }

    state = normalized;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, normalized);
  }

  Future<void> _loadPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = preferences.getString(_storageKey);
    if (storedValue == null || !AppCurrencies.isSupported(storedValue)) {
      return;
    }
    if (mounted) {
      state = storedValue.toUpperCase();
    }
  }
}

final currencyControllerProvider =
    StateNotifierProvider<CurrencyController, String>((ref) {
  return CurrencyController();
});
