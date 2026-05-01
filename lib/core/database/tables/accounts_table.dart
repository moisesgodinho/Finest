import 'package:drift/drift.dart';

import 'users_table.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text().withLength(min: 1, max: 40)();
  TextColumn get bankName => text().nullable()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  IntColumn get emergencyReserveTarget => integer().nullable()();
  TextColumn get color => text().withDefault(const Constant('#006B4F'))();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
