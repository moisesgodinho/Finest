import 'package:finest/core/utils/currency_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyUtils.parseToCents', () {
    test('parseia valores no formato brasileiro', () {
      expect(CurrencyUtils.parseToCents('R\$ 8.420,75'), 842075);
      expect(CurrencyUtils.parseToCents('1.234,56'), 123456);
    });

    test('parseia valores com ponto decimal', () {
      expect(CurrencyUtils.parseToCents('\$8,420.75'), 842075);
      expect(CurrencyUtils.parseToCents('2000.00'), 200000);
    });
  });
}
