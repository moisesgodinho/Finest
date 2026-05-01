import 'package:drift/drift.dart';

import 'users_table.dart';

class MonthlyPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
  IntColumn get plannedIncome => integer().withDefault(const Constant(0))();
  IntColumn get plannedExpense => integer().withDefault(const Constant(0))();
  IntColumn get initialMonthBalance => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
