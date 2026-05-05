import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exchange_rates_table.dart';

part 'exchange_rates_dao.g.dart';

@DriftAccessor(tables: [ExchangeRates])
class ExchangeRatesDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeRatesDaoMixin {
  ExchangeRatesDao(super.db);

  Future<ExchangeRate?> latestRate({
    required String baseCurrency,
    required String quoteCurrency,
  }) {
    final query = select(exchangeRates)
      ..where(
        (rate) =>
            rate.baseCurrency.equals(baseCurrency.toUpperCase()) &
            rate.quoteCurrency.equals(quoteCurrency.toUpperCase()),
      )
      ..orderBy([
        (rate) => OrderingTerm.desc(rate.fetchedAt),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<List<ExchangeRate>> latestRatesToQuote(String quoteCurrency) {
    final query = select(exchangeRates)
      ..where((rate) => rate.quoteCurrency.equals(quoteCurrency.toUpperCase()))
      ..orderBy([
        (rate) => OrderingTerm.desc(rate.fetchedAt),
      ]);
    return query.get();
  }

  Future<int> insertRate(ExchangeRatesCompanion rate) {
    return into(exchangeRates).insert(rate);
  }
}
