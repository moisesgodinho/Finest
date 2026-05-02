import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_transfer_request.dart';
import '../models/update_transfer_request.dart';

abstract class TransferRepository {
  Stream<List<AccountTransfer>> watchTransfers(int userId);

  Future<List<AccountTransfer>> findTransfers(int userId);

  Future<int> createTransfer(CreateTransferRequest request);

  Future<void> markTransferAsPaid({
    required int userId,
    required int transferId,
  });

  Future<void> updateTransfer(UpdateTransferRequest request);

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
  Future<void> markTransferAsPaid({
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
      if (transfer.isPaid) {
        return;
      }

      final fromAccount = await _database.accountsDao.findByIdForUser(
        id: transfer.fromAccountId,
        userId: userId,
      );
      if (fromAccount == null) {
        throw StateError('Conta de origem não encontrada.');
      }

      final toAccount = await _database.accountsDao.findByIdForUser(
        id: transfer.toAccountId,
        userId: userId,
      );
      if (toAccount == null) {
        throw StateError('Conta de destino não encontrada.');
      }

      await _database.accountsDao.updateCurrentBalance(
        id: fromAccount.id,
        userId: userId,
        currentBalance: fromAccount.currentBalance - transfer.amount,
      );
      await _database.accountsDao.updateCurrentBalance(
        id: toAccount.id,
        userId: userId,
        currentBalance: toAccount.currentBalance + transfer.amount,
      );

      final affectedRows = await _database.transfersDao.updatePaymentStatus(
        id: transferId,
        userId: userId,
        isPaid: true,
      );
      if (affectedRows == 0) {
        throw StateError('Transferência não atualizada.');
      }
    });
  }

  @override
  Future<void> updateTransfer(UpdateTransferRequest request) async {
    _validateTransferFields(
      name: request.name,
      amountCents: request.amountCents,
      transferKind: request.transferKind,
      fromAccountId: request.fromAccountId,
      toAccountId: request.toAccountId,
      totalInstallments: request.totalInstallments,
    );

    await _database.transaction(() async {
      final transfer = await _database.transfersDao.findByIdForUser(
        id: request.transferId,
        userId: request.userId,
      );
      if (transfer == null) {
        throw StateError('Transferência não encontrada.');
      }

      await _ensureAccountExists(
        userId: request.userId,
        accountId: request.fromAccountId,
        message: 'Conta de origem não encontrada.',
      );
      await _ensureAccountExists(
        userId: request.userId,
        accountId: request.toAccountId,
        message: 'Conta de destino não encontrada.',
      );

      final accountDeltas = <int, int>{};
      if (transfer.isPaid) {
        _addAccountDelta(
            accountDeltas, transfer.fromAccountId, transfer.amount);
        _addAccountDelta(accountDeltas, transfer.toAccountId, -transfer.amount);
      }
      if (request.isPaid) {
        _addAccountDelta(
          accountDeltas,
          request.fromAccountId,
          -request.amountCents,
        );
        _addAccountDelta(
          accountDeltas,
          request.toAccountId,
          request.amountCents,
        );
      }

      for (final entry in accountDeltas.entries) {
        if (entry.value == 0) {
          continue;
        }
        final account = await _database.accountsDao.findByIdForUser(
          id: entry.key,
          userId: request.userId,
        );
        if (account == null) {
          throw StateError('Conta não encontrada.');
        }
        await _database.accountsDao.updateCurrentBalance(
          id: account.id,
          userId: request.userId,
          currentBalance: account.currentBalance + entry.value,
        );
      }

      final isInstallment = request.transferKind == 'installment';
      final affectedRows = await _database.transfersDao.updateTransfer(
        id: transfer.id,
        userId: request.userId,
        transfer: TransfersCompanion(
          fromAccountId: Value(request.fromAccountId),
          toAccountId: Value(request.toAccountId),
          name: Value(request.name.trim()),
          amount: Value(request.amountCents),
          transferKind: Value(request.transferKind),
          dueDate: Value(request.dueDate),
          isPaid: Value(request.isPaid),
          installmentNumber: Value(
            isInstallment
                ? request.installmentNumber ?? transfer.installmentNumber ?? 1
                : null,
          ),
          totalInstallments:
              Value(isInstallment ? request.totalInstallments : null),
          date: Value(request.date),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (affectedRows == 0) {
        throw StateError('Transferência não atualizada.');
      }
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

  void _validateTransferFields({
    required String name,
    required int amountCents,
    required String transferKind,
    required int fromAccountId,
    required int toAccountId,
    int? totalInstallments,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome da transferência.');
    }
    if (amountCents <= 0) {
      throw ArgumentError('O valor da transferência deve ser maior que zero.');
    }
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Escolha contas diferentes para a transferência.');
    }
    if (!_validKinds.contains(transferKind)) {
      throw ArgumentError('Tipo de transferência inválido.');
    }
    if (transferKind == 'installment' && ((totalInstallments ?? 0) < 2)) {
      throw ArgumentError('Informe 2 parcelas ou mais.');
    }
  }

  Future<void> _ensureAccountExists({
    required int userId,
    required int accountId,
    required String message,
  }) async {
    final account = await _database.accountsDao.findByIdForUser(
      id: accountId,
      userId: userId,
    );
    if (account == null) {
      throw StateError(message);
    }
  }

  void _addAccountDelta(Map<int, int> deltas, int accountId, int delta) {
    deltas[accountId] = (deltas[accountId] ?? 0) + delta;
  }
}

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return DriftTransferRepository(ref.watch(appDatabaseProvider));
});
