import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'categories_table.dart';
import 'credit_cards_table.dart';
import 'users_table.dart';

@DataClassName('FinanceTransaction')
class FinancialTransactions extends Table {
  @override
  String get tableName => 'transactions';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get accountId => integer().references(
        Accounts,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get creditCardId => integer()
      .references(
        CreditCards,
        #id,
        onDelete: KeyAction.setNull,
      )
      .nullable()();
  IntColumn get categoryId => integer().references(
        Categories,
        #id,
        onDelete: KeyAction.restrict,
      )();
  TextColumn get type => text().withLength(min: 1, max: 30)();
  TextColumn get description => text().withLength(min: 1, max: 160)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get paymentMethod => text().withLength(min: 1, max: 40)();
  IntColumn get installmentNumber => integer().nullable()();
  IntColumn get totalInstallments => integer().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
