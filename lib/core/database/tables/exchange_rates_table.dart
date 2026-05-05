import 'package:drift/drift.dart';

class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get baseCurrency =>
      text().withLength(min: 3, max: 3).named('base_currency')();
  TextColumn get quoteCurrency =>
      text().withLength(min: 3, max: 3).named('quote_currency')();
  RealColumn get rate => real()();
  TextColumn get source => text()
      .withLength(min: 1, max: 80)
      .withDefault(const Constant('awesomeapi'))();
  DateTimeColumn get fetchedAt => dateTime().named('fetched_at')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
