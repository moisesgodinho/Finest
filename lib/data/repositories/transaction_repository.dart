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

      if (request.subcategoryId != null) {
        final subcategory =
            await _database.categoriesDao.findSubcategoryByIdForUser(
          id: request.subcategoryId!,
          userId: request.userId,
        );
        if (subcategory == null || subcategory.categoryId != category.id) {
          throw StateError('Subcategoria incompatível com a categoria.');
        }
      }

      CreditCard? creditCard;
      if (request.paymentMethod == 'credit_card') {
        final creditCardId = request.creditCardId;
        if (creditCardId == null) {
          throw StateError('Informe o cartão de crédito.');
        }

        creditCard = await _database.creditCardsDao.findByIdForUser(
          id: creditCardId,
          userId: request.userId,
        );
        if (creditCard == null) {
          throw StateError('Cartão de crédito não encontrado.');
        }
        if (creditCard.defaultPaymentAccountId != account.id) {
          throw StateError('Conta padrão incompatível com o cartão.');
        }
      }

      final now = DateTime.now();
      final transactionId = await _database.transactionsDao.insertTransaction(
        FinancialTransactionsCompanion.insert(
          userId: request.userId,
          accountId: request.accountId,
          creditCardId: Value(request.creditCardId),
          categoryId: request.categoryId,
          subcategoryId: Value(request.subcategoryId),
          type: request.type,
          description: request.description.trim(),
          amount: request.amountCents,
          date: request.date,
          dueDate: Value(request.dueDate),
          paymentMethod: request.paymentMethod,
          invoiceMonth: Value(request.invoiceMonth),
          invoiceYear: Value(request.invoiceYear),
          expenseKind: Value(request.expenseKind),
          installmentNumber: Value(request.installmentNumber),
          totalInstallments: Value(request.totalInstallments),
          isPaid: Value(request.isPaid),
          isRecurring: Value(request.isRecurring),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      if (!request.isPaid) {
        return transactionId;
      }

      if (request.paymentMethod == 'credit_card' && creditCard != null) {
        if (_shouldAffectCurrentInvoice(request)) {
          await _database.creditCardsDao.updateCurrentInvoice(
            id: creditCard.id,
            userId: request.userId,
            currentInvoice: creditCard.currentInvoice + request.amountCents,
          );
        }
      } else {
        await _database.accountsDao.updateCurrentBalance(
          id: account.id,
          userId: request.userId,
          currentBalance: account.currentBalance + _balanceDelta(request),
        );
      }

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

      if (!transaction.isPaid) {
        return;
      }

      if (transaction.paymentMethod == 'credit_card' &&
          transaction.creditCardId != null) {
        final creditCard = await _database.creditCardsDao.findByIdForUser(
          id: transaction.creditCardId!,
          userId: userId,
        );
        if (creditCard != null &&
            _transactionAffectsCurrentInvoice(transaction)) {
          await _database.creditCardsDao.updateCurrentInvoice(
            id: creditCard.id,
            userId: userId,
            currentInvoice: (creditCard.currentInvoice - transaction.amount)
                .clamp(0, 1 << 31),
          );
        }
      } else {
        await _database.accountsDao.updateCurrentBalance(
          id: account.id,
          userId: userId,
          currentBalance:
              account.currentBalance - _transactionDelta(transaction),
        );
      }
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

  bool _shouldAffectCurrentInvoice(CreateTransactionRequest request) {
    final now = DateTime.now();
    return request.invoiceMonth == null ||
        request.invoiceYear == null ||
        (request.invoiceMonth == now.month && request.invoiceYear == now.year);
  }

  bool _transactionAffectsCurrentInvoice(FinanceTransaction transaction) {
    final now = DateTime.now();
    return transaction.invoiceMonth == null ||
        transaction.invoiceYear == null ||
        (transaction.invoiceMonth == now.month &&
            transaction.invoiceYear == now.year);
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
});
