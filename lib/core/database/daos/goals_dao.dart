import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/goals_table.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Stream<List<Goal>> watchByUser(int userId) {
    final query = select(goals)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm(expression: table.targetDate)]);

    return query.watch();
  }

  Future<List<Goal>> findByUser(int userId) {
    final query = select(goals)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm(expression: table.targetDate)]);

    return query.get();
  }

  Future<Goal?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(goals)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> insertGoal(GoalsCompanion goal) {
    return into(goals).insert(goal);
  }

  Future<int> updateGoal({
    required int id,
    required int userId,
    required GoalsCompanion goal,
  }) {
    return (update(goals)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(goal);
  }

  Future<int> deleteGoal({
    required int id,
    required int userId,
  }) {
    return (delete(goals)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .go();
  }
}
