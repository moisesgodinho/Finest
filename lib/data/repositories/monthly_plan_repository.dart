import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';

abstract class MonthlyPlanRepository {
  Stream<MonthlyPlan?> watchPlan({
    required int userId,
    required int month,
    required int year,
  });

  Future<void> savePlan({
    required int userId,
    required int month,
    required int year,
    required int plannedIncomeCents,
    required int plannedExpenseCents,
    required int initialMonthBalanceCents,
  });
}

class DriftMonthlyPlanRepository implements MonthlyPlanRepository {
  const DriftMonthlyPlanRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<MonthlyPlan?> watchPlan({
    required int userId,
    required int month,
    required int year,
  }) {
    final query = _database.select(_database.monthlyPlans)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.month.equals(month) &
            table.year.equals(year),
      )
      ..limit(1);

    return query.watchSingleOrNull();
  }

  @override
  Future<void> savePlan({
    required int userId,
    required int month,
    required int year,
    required int plannedIncomeCents,
    required int plannedExpenseCents,
    required int initialMonthBalanceCents,
  }) async {
    if (plannedIncomeCents < 0 || plannedExpenseCents < 0) {
      throw ArgumentError(
          'Receita e despesa planejadas nao podem ser negativas.');
    }

    final existing = await _findPlan(
      userId: userId,
      month: month,
      year: year,
    );
    final now = DateTime.now();

    if (existing == null) {
      await _database.into(_database.monthlyPlans).insert(
            MonthlyPlansCompanion.insert(
              userId: userId,
              month: month,
              year: year,
              plannedIncome: Value(plannedIncomeCents),
              plannedExpense: Value(plannedExpenseCents),
              initialMonthBalance: Value(initialMonthBalanceCents),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return;
    }

    await (_database.update(_database.monthlyPlans)
          ..where(
            (table) =>
                table.id.equals(existing.id) & table.userId.equals(userId),
          ))
        .write(
      MonthlyPlansCompanion(
        plannedIncome: Value(plannedIncomeCents),
        plannedExpense: Value(plannedExpenseCents),
        initialMonthBalance: Value(initialMonthBalanceCents),
        updatedAt: Value(now),
      ),
    );
  }

  Future<MonthlyPlan?> _findPlan({
    required int userId,
    required int month,
    required int year,
  }) {
    final query = _database.select(_database.monthlyPlans)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.month.equals(month) &
            table.year.equals(year),
      )
      ..limit(1);

    return query.getSingleOrNull();
  }
}

final monthlyPlanRepositoryProvider = Provider<MonthlyPlanRepository>((ref) {
  return DriftMonthlyPlanRepository(ref.watch(appDatabaseProvider));
});
