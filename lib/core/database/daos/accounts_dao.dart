import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  Stream<List<Account>> watchByUser(int userId) {
    final query = select(accounts)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);

    return query.watch();
  }

  Future<List<Account>> findByUser(int userId) {
    final query = select(accounts)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);

    return query.get();
  }

  Future<Account?> findById(int id) {
    return (select(accounts)..where((table) => table.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Account?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(accounts)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> insertAccount(AccountsCompanion account) {
    return into(accounts).insert(account);
  }

  Future<int> updateAccount({
    required int id,
    required int userId,
    required AccountsCompanion account,
  }) {
    return (update(accounts)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(account);
  }

  Future<int> updateCurrentBalance({
    required int id,
    required int userId,
    required int currentBalance,
  }) {
    return (update(accounts)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(
      AccountsCompanion(
        currentBalance: Value(currentBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteAccount({
    required int id,
    required int userId,
  }) {
    return (delete(accounts)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .go();
  }
}
