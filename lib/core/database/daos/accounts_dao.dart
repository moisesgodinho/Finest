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

  Future<int> insertAccount(AccountsCompanion account) {
    return into(accounts).insert(account);
  }

  Future<bool> updateAccount(AccountsCompanion account) {
    return update(accounts).replace(account);
  }

  Future<int> deleteAccount(int id) {
    return (delete(accounts)..where((table) => table.id.equals(id))).go();
  }
}
