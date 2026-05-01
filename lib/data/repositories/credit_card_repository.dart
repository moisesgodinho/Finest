import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_credit_card_request.dart';
import '../models/update_credit_card_request.dart';

abstract class CreditCardRepository {
  Stream<List<CreditCard>> watchCards(int userId);

  Future<List<CreditCard>> findCards(int userId);

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
}

class DriftCreditCardRepository implements CreditCardRepository {
  const DriftCreditCardRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<CreditCard>> watchCards(int userId) {
    return _database.creditCardsDao.watchByUser(userId);
  }

  @override
  Future<List<CreditCard>> findCards(int userId) {
    return _database.creditCardsDao.findByUser(userId);
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
      return _database.creditCardsDao.insertCard(
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
      if (card.currentInvoice <= 0) {
        throw StateError('Este cartão não tem fatura em aberto.');
      }

      final accountId = card.defaultPaymentAccountId;
      if (accountId == null) {
        throw StateError('Defina uma conta padrão para pagar a fatura.');
      }

      final account = await _database.accountsDao.findByIdForUser(
        id: accountId,
        userId: userId,
      );
      if (account == null) {
        throw StateError('Conta padrão de pagamento não encontrada.');
      }

      await _database.accountsDao.updateCurrentBalance(
        id: account.id,
        userId: userId,
        currentBalance: account.currentBalance - card.currentInvoice,
      );
      await _database.creditCardsDao.updateCurrentInvoice(
        id: card.id,
        userId: userId,
        currentInvoice: 0,
      );
    });
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
}

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  return DriftCreditCardRepository(ref.watch(appDatabaseProvider));
});
