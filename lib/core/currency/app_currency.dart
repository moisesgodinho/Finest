class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.locale,
  });

  final String code;
  final String name;
  final String symbol;
  final String locale;

  String get label => '$name ($symbol)';
}

class AppCurrencies {
  const AppCurrencies._();

  static const defaultCode = 'BRL';

  static const supported = [
    AppCurrency(
      code: 'BRL',
      name: 'Real brasileiro',
      symbol: r'R$',
      locale: 'pt_BR',
    ),
    AppCurrency(
      code: 'USD',
      name: 'Dolar americano',
      symbol: r'$',
      locale: 'en_US',
    ),
    AppCurrency(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      locale: 'de_DE',
    ),
    AppCurrency(
      code: 'GBP',
      name: 'Libra esterlina',
      symbol: '£',
      locale: 'en_GB',
    ),
    AppCurrency(
      code: 'JPY',
      name: 'Iene japones',
      symbol: '¥',
      locale: 'ja_JP',
    ),
    AppCurrency(
      code: 'CHF',
      name: 'Franco suico',
      symbol: 'CHF',
      locale: 'de_CH',
    ),
    AppCurrency(
      code: 'CAD',
      name: 'Dolar canadense',
      symbol: r'CA$',
      locale: 'en_CA',
    ),
    AppCurrency(
      code: 'AUD',
      name: 'Dolar australiano',
      symbol: r'A$',
      locale: 'en_AU',
    ),
    AppCurrency(
      code: 'CNY',
      name: 'Yuan chines',
      symbol: '¥',
      locale: 'zh_CN',
    ),
    AppCurrency(
      code: 'MXN',
      name: 'Peso mexicano',
      symbol: r'MX$',
      locale: 'es_MX',
    ),
    AppCurrency(
      code: 'ARS',
      name: 'Peso argentino',
      symbol: r'AR$',
      locale: 'es_AR',
    ),
    AppCurrency(
      code: 'CLP',
      name: 'Peso chileno',
      symbol: r'CLP$',
      locale: 'es_CL',
    ),
  ];

  static AppCurrency byCode(String? code) {
    final normalized = (code ?? defaultCode).toUpperCase();
    for (final currency in supported) {
      if (currency.code == normalized) {
        return currency;
      }
    }
    return supported.first;
  }

  static bool isSupported(String code) {
    final normalized = code.toUpperCase();
    return supported.any((currency) => currency.code == normalized);
  }
}
