import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../models/create_account_request.dart';
import '../models/update_account_request.dart';

abstract class AccountRepository {
  Stream<List<Account>> watchAccounts(int userId);

  Future<List<Account>> findAccounts(int userId);

  Future<int> createAccount(CreateAccountRequest request);

  Future<void> updateAccount(UpdateAccountRequest request);

  Future<void> updateIncludeInTotalBalance({
    required int userId,
    required int accountId,
    required bool includeInTotalBalance,
  });

  Future<void> deleteAccount({
    required int userId,
    required int accountId,
  });

  Future<void> reconcileBalances(int userId);

  Future<int> totalBalanceCents(int userId);
}

class DriftAccountRepository implements AccountRepository {
  const DriftAccountRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Account>> watchAccounts(int userId) {
    return _database.accountsDao.watchByUser(userId);
  }

  @override
  Future<List<Account>> findAccounts(int userId) {
    return _database.accountsDao.findByUser(userId);
  }

  @override
  Future<int> createAccount(CreateAccountRequest request) {
    final now = DateTime.now();

    return _database.accountsDao.insertAccount(
      AccountsCompanion.insert(
        userId: request.userId,
        name: request.name,
        type: request.type,
        bankName: Value(request.bankName),
        initialBalance: Value(request.initialBalance),
        currentBalance: Value(request.initialBalance),
        currencyCode: Value(request.currencyCode.toUpperCase()),
        emergencyReserveTarget: Value(request.emergencyReserveTarget),
        goalLinkedAccountId: Value(request.goalLinkedAccountId),
        goalTargetDate: Value(request.goalTargetDate),
        includeInTotalBalance: Value(request.includeInTotalBalance),
        color: Value(request.color),
        icon: Value(request.icon),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> updateAccount(UpdateAccountRequest request) async {
    final affectedRows = await _database.accountsDao.updateAccount(
      id: request.id,
      userId: request.userId,
      account: AccountsCompanion(
        name: Value(request.name),
        type: Value(request.type),
        bankName: Value(request.bankName),
        initialBalance: Value(request.initialBalance),
        currentBalance: Value(request.currentBalance),
        currencyCode: Value(request.currencyCode.toUpperCase()),
        emergencyReserveTarget: Value(request.emergencyReserveTarget),
        goalLinkedAccountId: Value(request.goalLinkedAccountId),
        goalTargetDate: Value(request.goalTargetDate),
        includeInTotalBalance: Value(request.includeInTotalBalance),
        color: Value(request.color),
        icon: Value(request.icon),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (affectedRows == 0) {
      throw StateError('Conta não encontrada para atualização.');
    }
  }

  @override
  Future<void> updateIncludeInTotalBalance({
    required int userId,
    required int accountId,
    required bool includeInTotalBalance,
  }) async {
    final affectedRows =
        await _database.accountsDao.updateIncludeInTotalBalance(
      id: accountId,
      userId: userId,
      includeInTotalBalance: includeInTotalBalance,
    );

    if (affectedRows == 0) {
      throw StateError('Conta nao encontrada para atualizacao.');
    }
  }

  @override
  Future<void> deleteAccount({
    required int userId,
    required int accountId,
  }) async {
    final affectedRows = await _database.accountsDao.deleteAccount(
      id: accountId,
      userId: userId,
    );

    if (affectedRows == 0) {
      throw StateError('Conta não encontrada para remoção.');
    }
  }

  @override
  Future<void> reconcileBalances(int userId) async {
    await _database.transaction(() async {
      final accounts = await _database.accountsDao.findByUser(userId);
      final balances = {
        for (final account in accounts) account.id: account.initialBalance,
      };

      final transactions = await _database.transactionsDao.findByUser(userId);
      for (final transaction in transactions) {
        if (!transaction.isPaid ||
            transaction.paymentMethod == 'credit_card' ||
            !balances.containsKey(transaction.accountId)) {
          continue;
        }

        balances[transaction.accountId] = balances[transaction.accountId]! +
            (transaction.type == 'income'
                ? transaction.amount
                : -transaction.amount);
      }

      final transfers = await _database.transfersDao.findByUser(userId);
      for (final transfer in transfers) {
        if (!transfer.isPaid) {
          continue;
        }
        if (balances.containsKey(transfer.fromAccountId)) {
          balances[transfer.fromAccountId] =
              balances[transfer.fromAccountId]! - transfer.amount;
        }
        if (balances.containsKey(transfer.toAccountId)) {
          balances[transfer.toAccountId] = balances[transfer.toAccountId]! +
              (transfer.convertedAmount ?? transfer.amount);
        }
      }

      final invoices = await _database.creditCardInvoicesDao.findByUser(userId);
      for (final invoice in invoices) {
        final paymentAccountId = invoice.paymentAccountId;
        if (invoice.status != 'paid' ||
            paymentAccountId == null ||
            !balances.containsKey(paymentAccountId)) {
          continue;
        }

        balances[paymentAccountId] =
            balances[paymentAccountId]! - invoice.amount;
      }

      for (final account in accounts) {
        final reconciledBalance =
            balances[account.id] ?? account.initialBalance;
        if (reconciledBalance == account.currentBalance) {
          continue;
        }

        await _database.accountsDao.updateCurrentBalance(
          id: account.id,
          userId: userId,
          currentBalance: reconciledBalance,
        );
      }
    });
  }

  @override
  Future<int> totalBalanceCents(int userId) async {
    final accounts = await findAccounts(userId);
    return accounts.fold<int>(
      0,
      (total, account) => account.includeInTotalBalance
          ? total + account.currentBalance
          : total,
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return DriftAccountRepository(ref.watch(appDatabaseProvider));
});
