import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'categories_table.dart';
import 'credit_cards_table.dart';
import 'subcategories_table.dart';
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
  IntColumn get subcategoryId => integer()
      .references(
        Subcategories,
        #id,
        onDelete: KeyAction.setNull,
      )
      .nullable()();
  TextColumn get type => text().withLength(min: 1, max: 30)();
  TextColumn get description => text().withLength(min: 1, max: 160)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get paymentMethod => text().withLength(min: 1, max: 40)();
  IntColumn get invoiceMonth => integer().nullable()();
  IntColumn get invoiceYear => integer().nullable()();
  TextColumn get expenseKind => text().nullable()();
  IntColumn get installmentNumber => integer().nullable()();
  IntColumn get totalInstallments => integer().nullable()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(true))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
