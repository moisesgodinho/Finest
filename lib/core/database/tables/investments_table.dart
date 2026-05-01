import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'users_table.dart';

class Investments extends Table {
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
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get type => text().withLength(min: 1, max: 60)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
