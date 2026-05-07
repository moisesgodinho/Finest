import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_goal_request.dart';
import '../models/update_goal_request.dart';

abstract class GoalRepository {
  Stream<List<Goal>> watchGoals(int userId);

  Future<List<Goal>> findGoals(int userId);

  Future<int> createGoal(CreateGoalRequest request);

  Future<void> updateGoal(UpdateGoalRequest request);

  Future<void> deleteGoal({
    required int userId,
    required int goalId,
  });
}

class DriftGoalRepository implements GoalRepository {
  const DriftGoalRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Goal>> watchGoals(int userId) {
    return _database.goalsDao.watchByUser(userId);
  }

  @override
  Future<List<Goal>> findGoals(int userId) {
    return _database.goalsDao.findByUser(userId);
  }

  @override
  Future<int> createGoal(CreateGoalRequest request) async {
    if (request.targetAmountCents <= 0) {
      throw ArgumentError('O valor da meta deve ser maior que zero.');
    }

    final linkedAccount = await _database.accountsDao.findByIdForUser(
      id: request.linkedAccountId,
      userId: request.userId,
    );
    if (linkedAccount == null || linkedAccount.type == 'goal') {
      throw StateError('Conta vinculada nao encontrada.');
    }

    final now = DateTime.now();
    return _database.goalsDao.insertGoal(
      GoalsCompanion.insert(
        userId: request.userId,
        name: request.name.trim(),
        linkedAccountId: Value(request.linkedAccountId),
        targetAmount: Value(request.targetAmountCents),
        targetDate: Value(request.targetDate),
        color: Value(request.color),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> updateGoal(UpdateGoalRequest request) async {
    if (request.targetAmountCents <= 0) {
      throw ArgumentError('O valor da meta deve ser maior que zero.');
    }

    final linkedAccount = await _database.accountsDao.findByIdForUser(
      id: request.linkedAccountId,
      userId: request.userId,
    );
    if (linkedAccount == null || linkedAccount.type == 'goal') {
      throw StateError('Conta vinculada nao encontrada.');
    }

    final affectedRows = await _database.goalsDao.updateGoal(
      id: request.id,
      userId: request.userId,
      goal: GoalsCompanion(
        name: Value(request.name.trim()),
        linkedAccountId: Value(request.linkedAccountId),
        targetAmount: Value(request.targetAmountCents),
        targetDate: Value(request.targetDate),
        color: Value(request.color),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (affectedRows == 0) {
      throw StateError('Meta nao encontrada para atualizacao.');
    }
  }

  @override
  Future<void> deleteGoal({
    required int userId,
    required int goalId,
  }) async {
    final affectedRows = await _database.goalsDao.deleteGoal(
      id: goalId,
      userId: userId,
    );

    if (affectedRows == 0) {
      throw StateError('Meta nao encontrada para remocao.');
    }
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return DriftGoalRepository(ref.watch(appDatabaseProvider));
});
