import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_credit_card_request.dart';
import '../models/update_credit_card_request.dart';

abstract class CreditCardRepository {
  Stream<List<CreditCard>> watchCards(int userId);

  Stream<List<CreditCardInvoice>> watchInvoices(int userId);

  Future<List<CreditCard>> findCards(int userId);

  Future<List<CreditCardInvoice>> findInvoices(int userId);

  Future<int> createCard(CreateCreditCardRequest request);

  Future<void> updateCard(UpdateCreditCardRequest request);

  Future<void> deleteCard({
    required int userId,
    required int cardId,
  });

  Future<void> payCurrentInvoice({
    required int userId,
    required int cardId,
  });

  Future<void> payInvoice({
    required int userId,
    required int invoiceId,
  });
}

class DriftCreditCardRepository implements CreditCardRepository {
  const DriftCreditCardRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<CreditCard>> watchCards(int userId) {
    return _database.creditCardsDao.watchByUser(userId);
  }

  @override
  Stream<List<CreditCardInvoice>> watchInvoices(int userId) {
    return _database.creditCardInvoicesDao.watchByUser(userId);
  }

  @override
  Future<List<CreditCard>> findCards(int userId) {
    return _database.creditCardsDao.findByUser(userId);
  }

  @override
  Future<List<CreditCardInvoice>> findInvoices(int userId) {
    return _database.creditCardInvoicesDao.findByUser(userId);
  }

  @override
  Future<int> createCard(CreateCreditCardRequest request) async {
    _validateCardFields(
      name: request.name,
      lastDigits: request.lastDigits,
      limitCents: request.limitCents,
      currentInvoiceCents: request.currentInvoiceCents,
      closingDay: request.closingDay,
      dueDay: request.dueDay,
    );

    return _database.transaction(() async {
      await _ensureAccountBelongsToUser(
        userId: request.userId,
        accountId: request.defaultPaymentAccountId,
      );

      final cardCount = await _database.creditCardsDao.countByUser(
        request.userId,
      );
      final shouldBePrimary = request.isPrimary || cardCount == 0;
      if (shouldBePrimary) {
        await _database.creditCardsDao.clearPrimaryCards(request.userId);
      }

      final now = DateTime.now();
      final cardId = await _database.creditCardsDao.insertCard(
        CreditCardsCompanion.insert(
          userId: request.userId,
          name: request.name.trim(),
          bankName: Value(_blankToNull(request.bankName)),
          lastDigits: request.lastDigits,
          brand: Value(request.brand),
          limit: Value(request.limitCents),
          currentInvoice: Value(request.currentInvoiceCents),
          defaultPaymentAccountId: Value(request.defaultPaymentAccountId),
          closingDay: request.closingDay,
          dueDay: request.dueDay,
          isPrimary: Value(shouldBePrimary),
          color: Value(request.color),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      if (request.currentInvoiceCents > 0) {
        await _setInvoiceAmount(
          userId: request.userId,
          creditCardId: cardId,
          month: now.month,
          year: now.year,
          amount: request.currentInvoiceCents,
          dueDay: request.dueDay,
          paymentAccountId: request.defaultPaymentAccountId,
        );
      }

      return cardId;
    });
  }

  @override
  Future<void> updateCard(UpdateCreditCardRequest request) async {
    _validateCardFields(
      name: request.name,
      lastDigits: request.lastDigits,
      limitCents: request.limitCents,
      currentInvoiceCents: request.currentInvoiceCents,
      closingDay: request.closingDay,
      dueDay: request.dueDay,
    );

    await _database.transaction(() async {
      final card = await _database.creditCardsDao.findByIdForUser(
        id: request.id,
        userId: request.userId,
      );
      if (card == null) {
        throw StateError('Cartão não encontrado.');
      }

      await _ensureAccountBelongsToUser(
        userId: request.userId,
        accountId: request.defaultPaymentAccountId,
      );

      final cardCount = await _database.creditCardsDao.countByUser(
        request.userId,
      );
      final shouldBePrimary = request.isPrimary || cardCount <= 1;
      if (shouldBePrimary) {
        await _database.creditCardsDao.clearPrimaryCards(request.userId);
      }

      final affectedRows = await _database.creditCardsDao.updateCard(
        id: request.id,
        userId: request.userId,
        card: CreditCardsCompanion(
          name: Value(request.name.trim()),
          bankName: Value(_blankToNull(request.bankName)),
          lastDigits: Value(request.lastDigits),
          brand: Value(request.brand),
          limit: Value(request.limitCents),
          currentInvoice: Value(request.currentInvoiceCents),
          defaultPaymentAccountId: Value(request.defaultPaymentAccountId),
          closingDay: Value(request.closingDay),
          dueDay: Value(request.dueDay),
          isPrimary: Value(shouldBePrimary),
          color: Value(request.color),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (affectedRows == 0) {
        throw StateError('Cartão não atualizado.');
      }

      final now = DateTime.now();
      await _setInvoiceAmount(
        userId: request.userId,
        creditCardId: card.id,
        month: now.month,
        year: now.year,
        amount: request.currentInvoiceCents,
        dueDay: request.dueDay,
        paymentAccountId: request.defaultPaymentAccountId,
      );

      await _ensureOnePrimaryCard(request.userId);
    });
  }

  @override
  Future<void> deleteCard({
    required int userId,
    required int cardId,
  }) async {
    await _database.transaction(() async {
      final affectedRows = await _database.creditCardsDao.deleteCard(
        id: cardId,
        userId: userId,
      );
      if (affectedRows == 0) {
        throw StateError('Cartão não encontrado para remoção.');
      }

      await _ensureOnePrimaryCard(userId);
    });
  }

  @override
  Future<void> payCurrentInvoice({
    required int userId,
    required int cardId,
  }) async {
    await _database.transaction(() async {
      final card = await _database.creditCardsDao.findByIdForUser(
        id: cardId,
        userId: userId,
      );
      if (card == null) {
        throw StateError('Cartão não encontrado.');
      }

      final now = DateTime.now();
      var invoice = await _database.creditCardInvoicesDao.findByCardMonth(
        userId: userId,
        creditCardId: card.id,
        month: now.month,
        year: now.year,
      );

      if (invoice == null && card.currentInvoice > 0) {
        final invoiceId = await _setInvoiceAmount(
          userId: userId,
          creditCardId: card.id,
          month: now.month,
          year: now.year,
          amount: card.currentInvoice,
          dueDay: card.dueDay,
          paymentAccountId: card.defaultPaymentAccountId,
        );
        invoice = await _database.creditCardInvoicesDao.findByIdForUser(
          id: invoiceId,
          userId: userId,
        );
      }

      if (invoice == null) {
        throw StateError('Este cartão não tem fatura em aberto.');
      }

      await _payInvoice(invoice: invoice, card: card);
    });
  }

  @override
  Future<void> payInvoice({
    required int userId,
    required int invoiceId,
  }) async {
    await _database.transaction(() async {
      final invoice = await _database.creditCardInvoicesDao.findByIdForUser(
        id: invoiceId,
        userId: userId,
      );
      if (invoice == null) {
        throw StateError('Fatura não encontrada.');
      }

      final card = await _database.creditCardsDao.findByIdForUser(
        id: invoice.creditCardId,
        userId: userId,
      );
      if (card == null) {
        throw StateError('Cartão não encontrado.');
      }

      await _payInvoice(invoice: invoice, card: card);
    });
  }

  Future<void> _payInvoice({
    required CreditCardInvoice invoice,
    required CreditCard card,
  }) async {
    if (invoice.status == 'paid') {
      throw StateError('Esta fatura já foi paga.');
    }
    final transactionTotal = await _invoiceTransactionTotal(invoice);
    final amountToPay =
        transactionTotal > 0 ? transactionTotal : invoice.amount;

    if (amountToPay <= 0) {
      throw StateError('Esta fatura não tem valor em aberto.');
    }

    final accountId = invoice.paymentAccountId ?? card.defaultPaymentAccountId;
    if (accountId == null) {
      throw StateError('Defina uma conta padrão para pagar a fatura.');
    }

    final account = await _database.accountsDao.findByIdForUser(
      id: accountId,
      userId: invoice.userId,
    );
    if (account == null) {
      throw StateError('Conta padrão de pagamento não encontrada.');
    }

    await _database.accountsDao.updateCurrentBalance(
      id: account.id,
      userId: invoice.userId,
      currentBalance: account.currentBalance - amountToPay,
    );

    final now = DateTime.now();
    await _database.creditCardInvoicesDao.updateInvoice(
      id: invoice.id,
      userId: invoice.userId,
      invoice: CreditCardInvoicesCompanion(
        amount: Value(amountToPay),
        status: const Value('paid'),
        paymentAccountId: Value(account.id),
        paidAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    if (_isCurrentInvoice(invoice.month, invoice.year)) {
      await _database.creditCardsDao.updateCurrentInvoice(
        id: card.id,
        userId: invoice.userId,
        currentInvoice: 0,
      );
    }
  }

  Future<int> _invoiceTransactionTotal(CreditCardInvoice invoice) async {
    final transactions =
        await _database.transactionsDao.findByCreditCardInvoice(
      userId: invoice.userId,
      creditCardId: invoice.creditCardId,
      month: invoice.month,
      year: invoice.year,
    );

    return transactions.fold<int>(
      0,
      (total, transaction) => total + _invoiceAmountDelta(transaction),
    );
  }

  int _invoiceAmountDelta(FinanceTransaction transaction) {
    return transaction.type == 'income'
        ? -transaction.amount
        : transaction.amount;
  }

  Future<void> _ensureAccountBelongsToUser({
    required int userId,
    required int accountId,
  }) async {
    final account = await _database.accountsDao.findByIdForUser(
      id: accountId,
      userId: userId,
    );
    if (account == null) {
      throw StateError('Conta padrão de pagamento não encontrada.');
    }
  }

  Future<void> _ensureOnePrimaryCard(int userId) async {
    final cards = await _database.creditCardsDao.findByUser(userId);
    if (cards.isEmpty || cards.any((card) => card.isPrimary)) {
      return;
    }

    await _database.creditCardsDao.updateCard(
      id: cards.first.id,
      userId: userId,
      card: CreditCardsCompanion(
        isPrimary: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> _setInvoiceAmount({
    required int userId,
    required int creditCardId,
    required int month,
    required int year,
    required int amount,
    required int dueDay,
    required int? paymentAccountId,
  }) async {
    final existing = await _database.creditCardInvoicesDao.findByCardMonth(
      userId: userId,
      creditCardId: creditCardId,
      month: month,
      year: year,
    );
    final now = DateTime.now();
    final status = amount > 0 ? 'open' : 'paid';

    if (existing == null) {
      if (amount <= 0) {
        return 0;
      }
      return _database.creditCardInvoicesDao.insertInvoice(
        CreditCardInvoicesCompanion.insert(
          userId: userId,
          creditCardId: creditCardId,
          month: month,
          year: year,
          amount: Value(amount),
          status: Value(status),
          dueDate: _invoiceDueDate(month: month, year: year, dueDay: dueDay),
          paymentAccountId: Value(paymentAccountId),
          paidAt: Value(amount > 0 ? null : now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    await _database.creditCardInvoicesDao.updateInvoice(
      id: existing.id,
      userId: userId,
      invoice: CreditCardInvoicesCompanion(
        amount: Value(amount),
        status: Value(status),
        dueDate: Value(
          _invoiceDueDate(month: month, year: year, dueDay: dueDay),
        ),
        paymentAccountId: Value(paymentAccountId),
        paidAt: Value(amount > 0 ? null : existing.paidAt ?? now),
        updatedAt: Value(now),
      ),
    );
    return existing.id;
  }

  void _validateCardFields({
    required String name,
    required String lastDigits,
    required int limitCents,
    required int currentInvoiceCents,
    required int closingDay,
    required int dueDay,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome do cartão.');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(lastDigits)) {
      throw ArgumentError('Informe os 4 últimos dígitos do cartão.');
    }
    if (limitCents <= 0) {
      throw ArgumentError('O limite deve ser maior que zero.');
    }
    if (currentInvoiceCents < 0) {
      throw ArgumentError('A fatura atual não pode ser negativa.');
    }
    if (closingDay < 1 || closingDay > 31) {
      throw ArgumentError('O fechamento deve estar entre 1 e 31.');
    }
    if (dueDay < 1 || dueDay > 31) {
      throw ArgumentError('O vencimento deve estar entre 1 e 31.');
    }
  }

  String? _blankToNull(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

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

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  return DriftCreditCardRepository(ref.watch(appDatabaseProvider));
});
