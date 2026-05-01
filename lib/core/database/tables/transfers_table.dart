import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'users_table.dart';

@DataClassName('AccountTransfer')
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  @ReferenceName('outgoingTransfers')
  IntColumn get fromAccountId => integer().references(
        Accounts,
        #id,
        onDelete: KeyAction.restrict,
      )();
  @ReferenceName('incomingTransfers')
  IntColumn get toAccountId => integer().references(
        Accounts,
        #id,
        onDelete: KeyAction.restrict,
      )();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  IntColumn get amount => integer()();
  TextColumn get transferKind => text().withLength(min: 1, max: 30)();
  DateTimeColumn get dueDate => dateTime()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(true))();
  IntColumn get installmentNumber => integer().nullable()();
  IntColumn get totalInstallments => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
