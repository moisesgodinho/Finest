import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account_preview.dart';
import '../../data/models/create_account_request.dart';
import '../../data/models/update_account_request.dart';
import '../../data/repositories/account_repository.dart';

class AccountsState {
  const AccountsState({
    required this.accounts,
    this.isBalanceVisible = true,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AccountPreview> accounts;
  final bool isBalanceVisible;
  final bool isLoading;
  final String? errorMessage;

  int get totalBalanceCents {
    return accounts.fold<int>(
      0,
      (total, account) => total + account.balanceCents,
    );
  }

  int get checkingBalanceCents {
    return accounts
        .where((account) => account.type.toLowerCase().contains('corrente'))
        .fold<int>(0, (total, account) => total + account.balanceCents);
  }

  int get savingsBalanceCents {
    return accounts
        .where((account) => account.type.toLowerCase().contains('poupança'))
        .fold<int>(0, (total, account) => total + account.balanceCents);
  }

  AccountsState copyWith({
    List<AccountPreview>? accounts,
    bool? isBalanceVisible,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AccountsViewModel extends StateNotifier<AccountsState> {
  AccountsViewModel({
    required AccountRepository accountRepository,
    required int? userId,
  })  : _accountRepository = accountRepository,
        _userId = userId,
        super(const AccountsState(accounts: [], isLoading: true)) {
    _watchAccounts();
  }

  final AccountRepository _accountRepository;
  final int? _userId;
  StreamSubscription<List<Account>>? _accountsSubscription;

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }

  Future<void> createAccount({
    required String name,
    required String type,
    required int initialBalance,
    String? bankName,
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.createAccount(
        CreateAccountRequest(
          userId: userId,
          name: name,
          type: type,
          bankName: bankName,
          initialBalance: initialBalance,
          color: color,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateAccount({
    required AccountPreview account,
    required String name,
    required String type,
    required int balanceCents,
    String? bankName,
    String color = '#006B4F',
  }) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.updateAccount(
        UpdateAccountRequest(
          id: account.id,
          userId: userId,
          name: name,
          type: type,
          bankName: bankName,
          initialBalance: balanceCents,
          currentBalance: balanceCents,
          color: color,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> deleteAccount(AccountPreview account) async {
    final userId = _requireUserId();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _accountRepository.deleteAccount(
        userId: userId,
        accountId: account.id,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  void _watchAccounts() {
    if (_userId == null) {
      state = const AccountsState(accounts: []);
      return;
    }

    _accountsSubscription = _accountRepository.watchAccounts(_userId).listen(
      (accounts) {
        state = state.copyWith(
          accounts: accounts.map(_mapAccount).toList(),
          isLoading: false,
          clearError: true,
        );
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Usuário não autenticado.');
    }
    return userId;
  }

  AccountPreview _mapAccount(Account account) {
    return AccountPreview(
      id: account.id,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      lastDigits: account.id.toString().padLeft(4, '0'),
      balanceCents: account.currentBalance,
      color: _parseColor(account.color),
      colorHex: account.color,
    );
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse('FF$normalized', radix: 16);
    return parsed == null ? AppColors.primary : Color(parsed);
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    super.dispose();
  }
}

final accountsViewModelProvider =
    StateNotifierProvider<AccountsViewModel, AccountsState>((ref) {
  final userId = ref.watch(
    authStateProvider.select((state) => state.user?.id),
  );

  return AccountsViewModel(
    accountRepository: ref.watch(accountRepositoryProvider),
    userId: userId,
  );
});
