import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'app_currency.dart';

class ExchangeRateQuote {
  const ExchangeRateQuote({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.fetchedAt,
  });

  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime fetchedAt;

  int convertCents(int amountCents) {
    return (amountCents * rate).round();
  }
}

class ExchangeRateService {
  ExchangeRateService(this._database);

  final AppDatabase _database;

  static const _quoteCurrency = AppCurrencies.defaultCode;
  static const _cacheDuration = Duration(hours: 1);

  Future<void> refreshIfStale() async {
    final now = DateTime.now();
    final staleCodes = <String>[];

    for (final currency in AppCurrencies.supported) {
      if (currency.code == _quoteCurrency) {
        continue;
      }

      final latest = await _database.exchangeRatesDao.latestRate(
        baseCurrency: currency.code,
        quoteCurrency: _quoteCurrency,
      );
      if (latest == null ||
          now.difference(latest.fetchedAt) >= _cacheDuration) {
        staleCodes.add(currency.code);
      }
    }

    if (staleCodes.isEmpty) {
      return;
    }

    await _fetchAndStoreRates(staleCodes);
  }

  Future<ExchangeRateQuote> quote({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();

    if (from == to) {
      return ExchangeRateQuote(
        fromCurrency: from,
        toCurrency: to,
        rate: 1,
        fetchedAt: DateTime.now(),
      );
    }

    await refreshIfStale();

    final fromToBrl = from == _quoteCurrency ? 1.0 : await _rateToBrl(from);
    final toToBrl = to == _quoteCurrency ? 1.0 : await _rateToBrl(to);
    final rate = fromToBrl / toToBrl;

    return ExchangeRateQuote(
      fromCurrency: from,
      toCurrency: to,
      rate: rate,
      fetchedAt: DateTime.now(),
    );
  }

  Future<Map<String, double>> ratesToBrlSnapshot() async {
    try {
      await refreshIfStale();
    } catch (_) {
      // The UI can keep using the last local rates when the device is offline.
    }

    final rates = <String, double>{
      _quoteCurrency: 1,
    };
    final storedRates =
        await _database.exchangeRatesDao.latestRatesToQuote(_quoteCurrency);
    for (final rate in storedRates) {
      rates.putIfAbsent(rate.baseCurrency, () => rate.rate);
    }
    return rates;
  }

  int convertCentsWithRates({
    required int amountCents,
    required String fromCurrency,
    required String toCurrency,
    required Map<String, double> ratesToBrl,
  }) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) {
      return amountCents;
    }

    final fromToBrl = ratesToBrl[from];
    final toToBrl = ratesToBrl[to];
    if (fromToBrl == null || toToBrl == null || toToBrl == 0) {
      return amountCents;
    }

    return (amountCents * (fromToBrl / toToBrl)).round();
  }

  Future<double> _rateToBrl(String currencyCode) async {
    final latest = await _database.exchangeRatesDao.latestRate(
      baseCurrency: currencyCode,
      quoteCurrency: _quoteCurrency,
    );
    if (latest == null) {
      throw StateError('Cotacao indisponivel para $currencyCode.');
    }
    return latest.rate;
  }

  Future<void> _fetchAndStoreRates(List<String> currencyCodes) async {
    final pairs = [
      for (final code in currencyCodes) '$code-$_quoteCurrency',
    ];
    if (pairs.isEmpty) {
      return;
    }

    final uri = Uri.https(
      'economia.awesomeapi.com.br',
      '/json/last/${pairs.join(',')}',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
            'Erro ao buscar cotacoes: HTTP ${response.statusCode}.');
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Resposta de cotacao invalida.');
      }

      final now = DateTime.now();
      for (final code in currencyCodes) {
        final key = '$code$_quoteCurrency';
        final payload = decoded[key];
        if (payload is! Map<String, dynamic>) {
          continue;
        }

        final bid = double.tryParse(payload['bid']?.toString() ?? '');
        if (bid == null || bid <= 0) {
          continue;
        }

        await _database.exchangeRatesDao.insertRate(
          ExchangeRatesCompanion.insert(
            baseCurrency: code,
            quoteCurrency: _quoteCurrency,
            rate: bid,
            source: const Value('awesomeapi'),
            fetchedAt: now,
          ),
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService(ref.watch(appDatabaseProvider));
});

final exchangeRatesBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(exchangeRateServiceProvider).refreshIfStale();
});
