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

  Future<List<FinanceTransaction>> findByCreditCardInvoice({
    required int userId,
    required int creditCardId,
    required int month,
    required int year,
  }) {
    final query = select(financialTransactions)
      ..where(
        (table) =>
            table.userId.equals(userId) &
            table.creditCardId.equals(creditCardId) &
            table.paymentMethod.equals('credit_card') &
            table.invoiceMonth.equals(month) &
            table.invoiceYear.equals(year),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.date)]);

    return query.get();
  }

  Future<FinanceTransaction?> findByIdForUser({
    required int id,
    required int userId,
  }) {
    return (select(financialTransactions)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<int> insertTransaction(
    FinancialTransactionsCompanion transaction,
  ) {
    return into(financialTransactions).insert(transaction);
  }

  Future<int> updatePaymentStatus({
    required int id,
    required int userId,
    required bool isPaid,
  }) {
    return (update(financialTransactions)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(
      FinancialTransactionsCompanion(
        isPaid: Value(isPaid),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> updateTransaction({
    required int id,
    required int userId,
    required FinancialTransactionsCompanion transaction,
  }) {
    return (update(financialTransactions)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .write(transaction);
  }

  Future<int> deleteTransaction({
    required int id,
    required int userId,
  }) {
    return (delete(financialTransactions)
          ..where((table) => table.id.equals(id) & table.userId.equals(userId)))
        .go();
  }
}
