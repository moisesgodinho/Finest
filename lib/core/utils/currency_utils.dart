import 'package:intl/intl.dart';

class CurrencyUtils {
  const CurrencyUtils._();

  static final NumberFormat _brlFormatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  static String formatCents(int cents) {
    return _brlFormatter.format(cents / 100);
  }

  static int parseToCents(String value) {
    final normalized = value
        .replaceAll(r'R$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    final amount = double.tryParse(normalized) ?? 0;
    return (amount * 100).round();
  }
}
