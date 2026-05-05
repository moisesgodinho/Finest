import 'package:intl/intl.dart';

import '../currency/app_currency.dart';

class CurrencyUtils {
  const CurrencyUtils._();

  static String formatCents(
    int cents, {
    String currencyCode = AppCurrencies.defaultCode,
  }) {
    final currency = AppCurrencies.byCode(currencyCode);
    final formatter = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 2,
    );
    return formatter.format(cents / 100);
  }

  static int parseToCents(String value) {
    final normalized = value
        .replaceAll(r'R$', '')
        .replaceAll(r'CA$', '')
        .replaceAll(r'A$', '')
        .replaceAll(r'MX$', '')
        .replaceAll(r'AR$', '')
        .replaceAll(r'CLP$', '')
        .replaceAll(r'$', '')
        .replaceAll('€', '')
        .replaceAll('£', '')
        .replaceAll('¥', '')
        .replaceAll('CHF', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    final amount = double.tryParse(normalized) ?? 0;
    return (amount * 100).round();
  }
}
