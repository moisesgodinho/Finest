import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/transactions_table.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [FinancialTransactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Stream<List<FinanceTransaction>> watchByUser(int userId) {
    final query = select(financialTransactions)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.date)]);

    return query.watch();
  }

  Future<List<FinanceTransaction>> findByUser(int userId) {
    final query = select(financialTransactions)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.date)]);

    return query.get();
  }

  Future<int> insertTransaction(
    FinancialTransactionsCompanion transaction,
  ) {
    return into(financialTransactions).insert(transaction);
  }

  Future<int> deleteTransaction(int id) {
    return (delete(financialTransactions)..where((table) => table.id.equals(id)))
        .go();
  }
}
