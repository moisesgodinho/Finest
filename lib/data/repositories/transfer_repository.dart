import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_transfer_request.dart';

abstract class TransferRepository {
  Stream<List<AccountTransfer>> watchTransfers(int userId);

  Future<List<AccountTransfer>> findTransfers(int userId);

  Future<int> createTransfer(CreateTransferRequest request);

  Future<void> deleteTransfer({
    required int userId,
    required int transferId,
  });
}

class DriftTransferRepository implements TransferRepository {
  const DriftTransferRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<AccountTransfer>> watchTransfers(int userId) {
    return _database.transfersDao.watchByUser(userId);
  }

  @override
  Future<List<AccountTransfer>> findTransfers(int userId) {
    return _database.transfersDao.findByUser(userId);
  }

  @override
  Future<int> createTransfer(CreateTransferRequest request) async {
    if (request.name.trim().isEmpty) {
      throw ArgumentError('Informe o nome da transferência.');
    }
    if (request.amountCents <= 0) {
      throw ArgumentError('O valor da transferência deve ser maior que zero.');
    }
    if (request.fromAccountId == request.toAccountId) {
      throw ArgumentError('Escolha contas diferentes para a transferência.');
    }
    if (!_validKinds.contains(request.transferKind)) {
      throw ArgumentError('Tipo de transferência inválido.');
    }
    if (request.transferKind == 'installment' &&
        ((request.totalInstallments ?? 0) < 2)) {
      throw ArgumentError('Informe 2 parcelas ou mais.');
    }

    return _database.transaction(() async {
      final fromAccount = await _database.accountsDao.findByIdForUser(
        id: request.fromAccountId,
        userId: request.userId,
      );
      if (fromAccount == null) {
        throw StateError('Conta de origem não encontrada.');
      }

      final toAccount = await _database.accountsDao.findByIdForUser(
        id: request.toAccountId,
        userId: request.userId,
      );
      if (toAccount == null) {
        throw StateError('Conta de destino não encontrada.');
      }

      final now = DateTime.now();
      final transferId = await _database.transfersDao.insertTransfer(
        TransfersCompanion.insert(
          userId: request.userId,
          fromAccountId: request.fromAccountId,
          toAccountId: request.toAccountId,
          name: request.name.trim(),
          amount: request.amountCents,
          transferKind: request.transferKind,
          dueDate: request.dueDate,
          isPaid: Value(request.isPaid),
          installmentNumber: Value(request.installmentNumber),
          totalInstallments: Value(request.totalInstallments),
          date: request.date,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      if (request.isPaid) {
        await _database.accountsDao.updateCurrentBalance(
          id: fromAccount.id,
          userId: request.userId,
          currentBalance: fromAccount.currentBalance - request.amountCents,
        );
        await _database.accountsDao.updateCurrentBalance(
          id: toAccount.id,
          userId: request.userId,
          currentBalance: toAccount.currentBalance + request.amountCents,
        );
      }

      return transferId;
    });
  }

  @override
  Future<void> deleteTransfer({
    required int userId,
    required int transferId,
  }) async {
    await _database.transaction(() async {
      final transfer = await _database.transfersDao.findByIdForUser(
        id: transferId,
        userId: userId,
      );
      if (transfer == null) {
        throw StateError('Transferência não encontrada.');
      }

      final fromAccount = await _database.accountsDao.findByIdForUser(
        id: transfer.fromAccountId,
        userId: userId,
      );
      final toAccount = await _database.accountsDao.findByIdForUser(
        id: transfer.toAccountId,
        userId: userId,
      );

      final deletedRows = await _database.transfersDao.deleteTransfer(
        id: transferId,
        userId: userId,
      );
      if (deletedRows == 0) {
        throw StateError('Transferência não removida.');
      }

      if (!transfer.isPaid || fromAccount == null || toAccount == null) {
        return;
      }

      await _database.accountsDao.updateCurrentBalance(
        id: fromAccount.id,
        userId: userId,
        currentBalance: fromAccount.currentBalance + transfer.amount,
      );
      await _database.accountsDao.updateCurrentBalance(
        id: toAccount.id,
        userId: userId,
        currentBalance: toAccount.currentBalance - transfer.amount,
      );
    });
  }

  static const _validKinds = {
    'single',
    'installment',
    'fixed_monthly',
  };
}

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return DriftTransferRepository(ref.watch(appDatabaseProvider));
});
