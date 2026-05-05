import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';

class PetProgressUpdate {
  const PetProgressUpdate({
    required this.userId,
    required this.petName,
    required this.level,
    required this.xp,
    required this.currentStage,
    required this.totalInvestedCents,
    this.lastEvolutionAt,
  });

  final int userId;
  final String petName;
  final int level;
  final int xp;
  final String currentStage;
  final int totalInvestedCents;
  final DateTime? lastEvolutionAt;
}

class PetEvolutionEventInput {
  const PetEvolutionEventInput({
    required this.userId,
    required this.fromLevel,
    required this.toLevel,
    required this.xp,
    required this.stage,
    required this.reason,
    required this.totalInvestedCents,
    required this.monthlyContributionCents,
    required this.savingsRate,
    required this.runwayMonths,
    required this.contributionStreakMonths,
  });

  final int userId;
  final int? fromLevel;
  final int toLevel;
  final int xp;
  final String stage;
  final String reason;
  final int totalInvestedCents;
  final int monthlyContributionCents;
  final double savingsRate;
  final double runwayMonths;
  final int contributionStreakMonths;
}

abstract class PetRepository {
  Stream<PetProgressData?> watchProgress(int userId);

  Stream<List<PetEvolutionEvent>> watchEvolutionEvents(int userId);

  Stream<List<Investment>> watchInvestments(int userId);

  Future<void> saveProgress(PetProgressUpdate update);

  Future<void> saveEvolutionEvent(PetEvolutionEventInput input);
}

class DriftPetRepository implements PetRepository {
  const DriftPetRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<PetProgressData?> watchProgress(int userId) {
    final query = _database.select(_database.petProgress)
      ..where((progress) => progress.userId.equals(userId))
      ..orderBy([(progress) => OrderingTerm.asc(progress.id)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  @override
  Stream<List<Investment>> watchInvestments(int userId) {
    final query = _database.select(_database.investments)
      ..where((investment) => investment.userId.equals(userId))
      ..orderBy([(investment) => OrderingTerm.desc(investment.date)]);
    return query.watch();
  }

  @override
  Stream<List<PetEvolutionEvent>> watchEvolutionEvents(int userId) {
    final query = _database.select(_database.petEvolutionEvents)
      ..where((event) => event.userId.equals(userId))
      ..orderBy([(event) => OrderingTerm.desc(event.createdAt)])
      ..limit(20);
    return query.watch();
  }

  @override
  Future<void> saveProgress(PetProgressUpdate update) async {
    final existing = await (_database.select(_database.petProgress)
          ..where((progress) => progress.userId.equals(update.userId))
          ..orderBy([(progress) => OrderingTerm.asc(progress.id)])
          ..limit(1))
        .getSingleOrNull();

    final now = DateTime.now();
    final companion = PetProgressCompanion(
      userId: Value(update.userId),
      petName: Value(update.petName),
      level: Value(update.level),
      xp: Value(update.xp),
      currentStage: Value(update.currentStage),
      totalInvested: Value(update.totalInvestedCents),
      lastEvolutionAt: Value(update.lastEvolutionAt),
      updatedAt: Value(now),
      createdAt: existing == null ? Value(now) : const Value.absent(),
    );

    if (existing == null) {
      await _database.into(_database.petProgress).insert(companion);
      return;
    }

    await (_database.update(_database.petProgress)
          ..where((progress) => progress.id.equals(existing.id)))
        .write(companion);
  }

  @override
  Future<void> saveEvolutionEvent(PetEvolutionEventInput input) async {
    await _database.into(_database.petEvolutionEvents).insert(
          PetEvolutionEventsCompanion.insert(
            userId: input.userId,
            fromLevel: Value(input.fromLevel),
            toLevel: input.toLevel,
            xp: Value(input.xp),
            stage: input.stage,
            reason: input.reason,
            totalInvested: Value(input.totalInvestedCents),
            monthlyContribution: Value(input.monthlyContributionCents),
            savingsRate: Value(input.savingsRate),
            runwayMonths: Value(input.runwayMonths),
            contributionStreakMonths: Value(input.contributionStreakMonths),
          ),
        );
  }
}

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return DriftPetRepository(ref.watch(appDatabaseProvider));
});
