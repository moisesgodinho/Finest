import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'users_table.dart';

class CreditCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get bankName => text().nullable()();
  TextColumn get lastDigits => text().withLength(min: 4, max: 4)();
  TextColumn get brand => text().withDefault(const Constant('other'))();
  IntColumn get limit => integer().withDefault(const Constant(0))();
  IntColumn get currentInvoice => integer().withDefault(const Constant(0))();
  IntColumn get defaultPaymentAccountId => integer()
      .references(
        Accounts,
        #id,
        onDelete: KeyAction.setNull,
      )
      .nullable()();
  IntColumn get closingDay => integer()();
  IntColumn get dueDay => integer()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().withDefault(const Constant('#006B4F'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
