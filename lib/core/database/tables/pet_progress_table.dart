import 'package:drift/drift.dart';

import 'users_table.dart';

class PetProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get petName => text().withLength(min: 1, max: 80)();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  TextColumn get currentStage => text().withDefault(const Constant('seed'))();
  IntColumn get totalInvested => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastEvolutionAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
