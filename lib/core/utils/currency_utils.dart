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
    final cleaned = value.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
    if (cleaned.isEmpty) {
      return 0;
    }

    final isNegative = cleaned.contains('-');
    final number = cleaned.replaceAll('-', '');
    final commaIndex = number.lastIndexOf(',');
    final dotIndex = number.lastIndexOf('.');
    final normalized = switch ((commaIndex, dotIndex)) {
      (>= 0, >= 0) => _normalizeMixedSeparators(
          number: number,
          decimalSeparator: commaIndex > dotIndex ? ',' : '.',
        ),
      (>= 0, _) => _normalizeSingleSeparator(number, ','),
      (_, >= 0) => _normalizeSingleSeparator(number, '.'),
      _ => number,
    };
    final amount = double.tryParse(normalized) ?? 0;
    final cents = (amount * 100).round();
    return isNegative ? -cents : cents;
  }

  static String _normalizeMixedSeparators({
    required String number,
    required String decimalSeparator,
  }) {
    final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
    return number
        .replaceAll(thousandsSeparator, '')
        .replaceAll(decimalSeparator, '.');
  }

  static String _normalizeSingleSeparator(String number, String separator) {
    final lastSeparatorIndex = number.lastIndexOf(separator);
    final decimalDigits = number.length - lastSeparatorIndex - 1;
    final hasDecimalDigits = decimalDigits > 0 && decimalDigits <= 2;
    if (!hasDecimalDigits) {
      return number.replaceAll(separator, '');
    }

    final wholePart =
        number.substring(0, lastSeparatorIndex).replaceAll(separator, '');
    final decimalPart = number.substring(lastSeparatorIndex + 1);
    return '$wholePart.$decimalPart';
  }
}
