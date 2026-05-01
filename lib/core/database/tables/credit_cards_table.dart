import 'package:drift/drift.dart';

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
  IntColumn get limit => integer().withDefault(const Constant(0))();
  IntColumn get closingDay => integer()();
  IntColumn get dueDay => integer()();
  TextColumn get color => text().withDefault(const Constant('#006B4F'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
