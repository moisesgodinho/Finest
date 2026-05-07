import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'users_table.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get linkedAccountId => integer().nullable().references(
        Accounts,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get targetAmount => integer().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get color => text().withDefault(const Constant('#006B4F'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
