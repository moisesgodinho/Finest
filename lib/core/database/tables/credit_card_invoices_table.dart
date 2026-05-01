import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'credit_cards_table.dart';
import 'users_table.dart';

@DataClassName('CreditCardInvoice')
class CreditCardInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get creditCardId => integer().references(
        CreditCards,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get paymentAccountId => integer()
      .references(
        Accounts,
        #id,
        onDelete: KeyAction.setNull,
      )
      .nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {creditCardId, month, year},
      ];
}
