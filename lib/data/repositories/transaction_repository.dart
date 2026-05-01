import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_transaction_request.dart';

abstract class TransactionRepository {
  Stream<List<FinanceTransaction>> watchTransactions(int userId);

  Future<List<FinanceTransaction>> findTransactions(int userId);

  Future<int> createTransaction(CreateTransactionRequest request);

  Future<void> deleteTransaction({
    required int userId,
    required int transactionId,
  });
}

class DriftTransactionRepository implements TransactionRepository {
  const DriftTransactionRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<FinanceTransaction>> watchTransactions(int userId) {
    return _database.transactionsDao.watchByUser(userId);
  }

  @override
  Future<List<FinanceTransaction>> findTransactions(int userId) {
    return _database.transactionsDao.findByUser(userId);
  }

  @override
  Future<int> createTransaction(CreateTransactionRequest request) async {
    if (request.amountCents <= 0) {
      throw ArgumentError('O valor do lançamento deve ser maior que zero.');
    }
    if (request.type != 'income' && request.type != 'expense') {
      throw ArgumentError('Tipo de lançamento inválido.');
    }

    return _database.transaction(() async {
      final account = await _database.accountsDao.findByIdForUser(
        id: request.accountId,
        userId: request.userId,
      );
      if (account == null) {
        throw StateError('Conta não encontrada.');
      }

      final category = await _database.categoriesDao.findByIdForUser(
        id: request.categoryId,
        userId: request.userId,
      );
      if (category == null) {
        throw StateError('Categoria não encontrada.');
      }
      if (category.type != request.type) {
        throw StateError('Categoria incompatível com o tipo de lançamento.');
      }

      final now = DateTime.now();
      final transactionId = await _database.transactionsDao.insertTransaction(
        FinancialTransactionsCompanion.insert(
          userId: request.userId,
          accountId: request.accountId,
          creditCardId: Value(request.creditCardId),
          categoryId: request.categoryId,
          type: request.type,
          description: request.description.trim(),
          amount: request.amountCents,
          date: request.date,
          paymentMethod: request.paymentMethod,
          installmentNumber: Value(request.installmentNumber),
          totalInstallments: Value(request.totalInstallments),
          isRecurring: Value(request.isRecurring),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _database.accountsDao.updateCurrentBalance(
        id: account.id,
        userId: request.userId,
        currentBalance: account.currentBalance + _balanceDelta(request),
      );

      return transactionId;
    });
  }

  @override
  Future<void> deleteTransaction({
    required int userId,
    required int transactionId,
  }) async {
    await _database.transaction(() async {
      final transaction = await _database.transactionsDao.findByIdForUser(
        id: transactionId,
        userId: userId,
      );
      if (transaction == null) {
        throw StateError('Lançamento não encontrado.');
      }

      final account = await _database.accountsDao.findByIdForUser(
        id: transaction.accountId,
        userId: userId,
      );
      if (account == null) {
        throw StateError('Conta não encontrada.');
      }

      final deletedRows = await _database.transactionsDao.deleteTransaction(
        id: transactionId,
        userId: userId,
      );
      if (deletedRows == 0) {
        throw StateError('Lançamento não removido.');
      }

      await _database.accountsDao.updateCurrentBalance(
        id: account.id,
        userId: userId,
        currentBalance: account.currentBalance - _transactionDelta(transaction),
      );
    });
  }

  int _balanceDelta(CreateTransactionRequest request) {
    return request.type == 'income'
        ? request.amountCents
        : -request.amountCents;
  }

  int _transactionDelta(FinanceTransaction transaction) {
    return transaction.type == 'income'
        ? transaction.amount
        : -transaction.amount;
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
});
