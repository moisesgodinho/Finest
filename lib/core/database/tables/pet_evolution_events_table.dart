import 'package:drift/drift.dart';

import 'users_table.dart';

@DataClassName('PetEvolutionEvent')
class PetEvolutionEvents extends Table {
  @override
  String get tableName => 'pet_evolution_events';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(
        Users,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get fromLevel => integer().nullable()();
  IntColumn get toLevel => integer()();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  TextColumn get stage => text().withLength(min: 1, max: 80)();
  TextColumn get reason => text().withLength(min: 1, max: 240)();
  IntColumn get totalInvested => integer().withDefault(const Constant(0))();
  IntColumn get monthlyContribution =>
      integer().withDefault(const Constant(0))();
  RealColumn get savingsRate => real().withDefault(const Constant(0))();
  RealColumn get runwayMonths => real().withDefault(const Constant(0))();
  IntColumn get contributionStreakMonths =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
