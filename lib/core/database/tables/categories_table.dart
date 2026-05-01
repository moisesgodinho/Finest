import 'package:drift/drift.dart';

import 'users_table.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text().withLength(min: 1, max: 30)();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().withDefault(const Constant('#006B4F'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
