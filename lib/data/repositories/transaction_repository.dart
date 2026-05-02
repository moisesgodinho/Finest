import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_transaction_request.dart';
import '../models/update_credit_card_expense_request.dart';
import '../models/update_transaction_request.dart';

abstract class TransactionRepository {
  Stream<List<FinanceTransaction>> watchTransactions(int userId);

  Future<List<FinanceTransaction>> findTransactions(int userId);

  Future<int> createTransaction(CreateTransactionRequest request);

  Future<void> markTransactionAsPaid({
    required int userId,
    required int transactionId,
  });

  Future<void> updateTransaction(UpdateTransactionRequest request);

  Future<void> updateCreditCardExpense(UpdateCreditCardExpenseRequest request);

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
      CreditCardInvoice? invoice;
      final invoiceMonth = request.invoiceMonth ?? DateTime.now().month;
      final invoiceYear = request.invoiceYear ?? DateTime.now().year;

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

        invoice = await _database.creditCardInvoicesDao.findByCardMonth(
          userId: request.userId,
          creditCardId: creditCard.id,
          month: invoiceMonth,
          year: invoiceYear,
        );
        if (invoice?.status == 'paid') {
          throw StateError('Esta fatura já foi paga.');
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
          invoiceMonth: Value(
            request.paymentMethod == 'credit_card' ? invoiceMonth : null,
          ),
          invoiceYear: Value(
            request.paymentMethod == 'credit_card' ? invoiceYear : null,
          ),
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
        await _addAmountToInvoice(
          userId: request.userId,
          card: creditCard,
          invoice: invoice,
          month: invoiceMonth,
          year: invoiceYear,
          amountDelta: request.amountCents,
        );
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
  Future<void> markTransactionAsPaid({
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
      if (transaction.isPaid) {
        return;
      }

      final account = await _database.accountsDao.findByIdForUser(
        id: transaction.accountId,
        userId: userId,
      );
      if (account == null) {
        throw StateError('Conta não encontrada.');
      }

      if (transaction.paymentMethod == 'credit_card' &&
          transaction.creditCardId != null) {
        final creditCard = await _database.creditCardsDao.findByIdForUser(
          id: transaction.creditCardId!,
          userId: userId,
        );
        if (creditCard == null) {
          throw StateError('Cartão de crédito não encontrado.');
        }

        final invoiceMonth = transaction.invoiceMonth ?? DateTime.now().month;
        final invoiceYear = transaction.invoiceYear ?? DateTime.now().year;
        final invoice = await _database.creditCardInvoicesDao.findByCardMonth(
          userId: userId,
          creditCardId: creditCard.id,
          month: invoiceMonth,
          year: invoiceYear,
        );

        await _addAmountToInvoice(
          userId: userId,
          card: creditCard,
          invoice: invoice,
          month: invoiceMonth,
          year: invoiceYear,
          amountDelta: transaction.amount,
        );
      } else {
        await _database.accountsDao.updateCurrentBalance(
          id: account.id,
          userId: userId,
          currentBalance:
              account.currentBalance + _transactionDelta(transaction),
        );
      }

      final affectedRows = await _database.transactionsDao.updatePaymentStatus(
        id: transactionId,
        userId: userId,
        isPaid: true,
      );
      if (affectedRows == 0) {
        throw StateError('Lançamento não atualizado.');
      }
    });
  }

  @override
  Future<void> updateTransaction(UpdateTransactionRequest request) async {
    _validateTransactionFields(
      description: request.description,
      amountCents: request.amountCents,
      type: request.type,
      transactionKind: request.transactionKind,
      totalInstallments: request.totalInstallments,
    );

    await _database.transaction(() async {
      final transaction = await _database.transactionsDao.findByIdForUser(
        id: request.transactionId,
        userId: request.userId,
      );
      if (transaction == null) {
        throw StateError('Lançamento não encontrado.');
      }
      if (transaction.paymentMethod == 'credit_card') {
        throw StateError('Edite compras no cartão pela fatura.');
      }

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

      final accountDeltas = <int, int>{};
      if (transaction.isPaid) {
        _addAccountDelta(
          accountDeltas,
          transaction.accountId,
          -_transactionDelta(transaction),
        );
      }
      if (request.isPaid) {
        _addAccountDelta(
          accountDeltas,
          request.accountId,
          _requestDelta(request),
        );
      }

      for (final entry in accountDeltas.entries) {
        if (entry.value == 0) {
          continue;
        }
        final balanceAccount = await _database.accountsDao.findByIdForUser(
          id: entry.key,
          userId: request.userId,
        );
        if (balanceAccount == null) {
          throw StateError('Conta não encontrada.');
        }
        await _database.accountsDao.updateCurrentBalance(
          id: balanceAccount.id,
          userId: request.userId,
          currentBalance: balanceAccount.currentBalance + entry.value,
        );
      }

      final kind = request.transactionKind;
      final isInstallment = kind == 'installment';
      final affectedRows = await _database.transactionsDao.updateTransaction(
        id: transaction.id,
        userId: request.userId,
        transaction: FinancialTransactionsCompanion(
          accountId: Value(request.accountId),
          categoryId: Value(request.categoryId),
          subcategoryId: Value(request.subcategoryId),
          type: Value(request.type),
          description: Value(request.description.trim()),
          amount: Value(request.amountCents),
          date: Value(request.date),
          dueDate: Value(request.dueDate),
          expenseKind: Value(kind),
          installmentNumber: Value(
            isInstallment
                ? request.installmentNumber ??
                    transaction.installmentNumber ??
                    1
                : null,
          ),
          totalInstallments:
              Value(isInstallment ? request.totalInstallments : null),
          isPaid: Value(request.isPaid),
          isRecurring: Value(kind == 'fixed_monthly'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (affectedRows == 0) {
        throw StateError('Lançamento não atualizado.');
      }
    });
  }

  @override
  Future<void> updateCreditCardExpense(
    UpdateCreditCardExpenseRequest request,
  ) async {
    if (request.amountCents <= 0) {
      throw ArgumentError('O valor da compra deve ser maior que zero.');
    }

    await _database.transaction(() async {
      final transaction = await _database.transactionsDao.findByIdForUser(
        id: request.transactionId,
        userId: request.userId,
      );
      if (transaction == null) {
        throw StateError('Compra nÃ£o encontrada.');
      }
      if (transaction.paymentMethod != 'credit_card' ||
          transaction.creditCardId == null ||
          transaction.type != 'expense') {
        throw StateError('Esta compra nÃ£o pertence a uma fatura de cartÃ£o.');
      }

      final category = await _database.categoriesDao.findByIdForUser(
        id: request.categoryId,
        userId: request.userId,
      );
      if (category == null) {
        throw StateError('Categoria nÃ£o encontrada.');
      }
      if (category.type != 'expense') {
        throw StateError('Categoria incompatÃ­vel com despesa.');
      }

      if (request.subcategoryId != null) {
        final subcategory =
            await _database.categoriesDao.findSubcategoryByIdForUser(
          id: request.subcategoryId!,
          userId: request.userId,
        );
        if (subcategory == null || subcategory.categoryId != category.id) {
          throw StateError('Subcategoria incompatÃ­vel com a categoria.');
        }
      }

      final creditCard = await _database.creditCardsDao.findByIdForUser(
        id: transaction.creditCardId!,
        userId: request.userId,
      );
      if (creditCard == null) {
        throw StateError('CartÃ£o de crÃ©dito nÃ£o encontrado.');
      }

      final invoiceMonth = transaction.invoiceMonth ?? DateTime.now().month;
      final invoiceYear = transaction.invoiceYear ?? DateTime.now().year;
      final invoice = await _database.creditCardInvoicesDao.findByCardMonth(
        userId: request.userId,
        creditCardId: creditCard.id,
        month: invoiceMonth,
        year: invoiceYear,
      );
      if (invoice?.status == 'paid') {
        throw StateError('Esta fatura jÃ¡ foi paga.');
      }

      final amountDelta = request.amountCents - transaction.amount;
      if (transaction.isPaid && amountDelta != 0) {
        await _addAmountToInvoice(
          userId: request.userId,
          card: creditCard,
          invoice: invoice,
          month: invoiceMonth,
          year: invoiceYear,
          amountDelta: amountDelta,
        );
      }

      final affectedRows = await _database.transactionsDao.updateTransaction(
        id: transaction.id,
        userId: request.userId,
        transaction: FinancialTransactionsCompanion(
          description: Value(request.description.trim()),
          amount: Value(request.amountCents),
          categoryId: Value(request.categoryId),
          subcategoryId: Value(request.subcategoryId),
          date: Value(request.date),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (affectedRows == 0) {
        throw StateError('Compra nÃ£o atualizada.');
      }
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

      if (transaction.isPaid &&
          transaction.paymentMethod == 'credit_card' &&
          transaction.creditCardId != null) {
        final creditCard = await _database.creditCardsDao.findByIdForUser(
          id: transaction.creditCardId!,
          userId: userId,
        );
        if (creditCard != null) {
          final invoiceMonth = transaction.invoiceMonth ?? DateTime.now().month;
          final invoiceYear = transaction.invoiceYear ?? DateTime.now().year;
          final invoice = await _database.creditCardInvoicesDao.findByCardMonth(
            userId: userId,
            creditCardId: creditCard.id,
            month: invoiceMonth,
            year: invoiceYear,
          );

          await _addAmountToInvoice(
            userId: userId,
            card: creditCard,
            invoice: invoice,
            month: invoiceMonth,
            year: invoiceYear,
            amountDelta: -transaction.amount,
          );
        }
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

      if (transaction.paymentMethod != 'credit_card') {
        await _database.accountsDao.updateCurrentBalance(
          id: account.id,
          userId: userId,
          currentBalance:
              account.currentBalance - _transactionDelta(transaction),
        );
      }
    });
  }

  Future<void> _addAmountToInvoice({
    required int userId,
    required CreditCard card,
    required CreditCardInvoice? invoice,
    required int month,
    required int year,
    required int amountDelta,
  }) async {
    if (invoice?.status == 'paid') {
      throw StateError('Esta fatura já foi paga.');
    }

    final now = DateTime.now();
    final newAmount =
        ((invoice?.amount ?? 0) + amountDelta).clamp(0, 1 << 31).toInt();

    if (invoice == null) {
      if (newAmount <= 0) {
        return;
      }
      await _database.creditCardInvoicesDao.insertInvoice(
        CreditCardInvoicesCompanion.insert(
          userId: userId,
          creditCardId: card.id,
          month: month,
          year: year,
          amount: Value(newAmount),
          status: const Value('open'),
          dueDate:
              _invoiceDueDate(month: month, year: year, dueDay: card.dueDay),
          paymentAccountId: Value(card.defaultPaymentAccountId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _database.creditCardInvoicesDao.updateInvoice(
        id: invoice.id,
        userId: userId,
        invoice: CreditCardInvoicesCompanion(
          amount: Value(newAmount),
          updatedAt: Value(now),
        ),
      );
    }

    if (_isCurrentInvoice(month, year)) {
      await _database.creditCardsDao.updateCurrentInvoice(
        id: card.id,
        userId: userId,
        currentInvoice: newAmount,
      );
    }
  }

  int _balanceDelta(CreateTransactionRequest request) {
    return request.type == 'income'
        ? request.amountCents
        : -request.amountCents;
  }

  int _requestDelta(UpdateTransactionRequest request) {
    return request.type == 'income'
        ? request.amountCents
        : -request.amountCents;
  }

  int _transactionDelta(FinanceTransaction transaction) {
    return transaction.type == 'income'
        ? transaction.amount
        : -transaction.amount;
  }

  void _addAccountDelta(Map<int, int> deltas, int accountId, int delta) {
    deltas[accountId] = (deltas[accountId] ?? 0) + delta;
  }

  void _validateTransactionFields({
    required String description,
    required int amountCents,
    required String type,
    String? transactionKind,
    int? totalInstallments,
  }) {
    if (description.trim().isEmpty) {
      throw ArgumentError('Informe a descrição do lançamento.');
    }
    if (amountCents <= 0) {
      throw ArgumentError('O valor do lançamento deve ser maior que zero.');
    }
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Tipo de lançamento inválido.');
    }
    if (transactionKind != null && !_validKinds.contains(transactionKind)) {
      throw ArgumentError('Recorrência inválida.');
    }
    if (transactionKind == 'installment' && ((totalInstallments ?? 0) < 2)) {
      throw ArgumentError('Informe 2 parcelas ou mais.');
    }
  }

  static const _validKinds = {
    'single',
    'installment',
    'fixed_monthly',
  };

  DateTime _invoiceDueDate({
    required int month,
    required int year,
    required int dueDay,
  }) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dueDay.clamp(1, lastDay));
  }

  bool _isCurrentInvoice(int month, int year) {
    final now = DateTime.now();
    return month == now.month && year == now.year;
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(appDatabaseProvider));
});
