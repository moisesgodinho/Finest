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

  Future<void> deleteAccount({
    required int userId,
    required int accountId,
  });

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
        emergencyReserveTarget: Value(request.emergencyReserveTarget),
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
        emergencyReserveTarget: Value(request.emergencyReserveTarget),
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
